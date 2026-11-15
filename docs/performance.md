# Performance and cost

The volumes here are small: 50 000 customers give 442 044 rows in `fct_invoice_line`. Every probe query runs in well under a second; build times are dominated by fixed per-statement overhead, not scan work.

All numbers come from one series of sequential runs on 2026-11-15 (UTC) on a warm warehouse. "Fastest" below means fastest in this run, not a benchmark result.

## Setup

| Item | Value | Source |
|---|---|---|
| Data | `uv run python -m data_generator --customers 50000 --seed 42 --out data/out_perf`, load dates 2026-01-01 to 2026-01-05 | generator |
| Raw schema | `raw_perf` (the shared `raw` schema keeps the 2000-customer data) | var `raw_schema`, `scripts/upload_landing.py --raw-schema raw_perf` |
| Model schemas | target schema `perf` (`perf_raw_vault`, `perf_marts`, ...) | `DBT_DEV_SCHEMA=perf` (default `dev`) on `snowflake_dev` / `databricks_dev`. The 2026-11-15 run used a private copy of `dbt/profiles.yml` with `schema: perf`, which gives the same schemas. |
| Snowflake warehouse | X-Small | `warehouse_size` in `perf_history_snowflake.sql` |
| Databricks warehouse | Serverless Starter Warehouse, PRO, serverless, Photon, 2X-Small | `databricks warehouses get <id> --profile personal` |
| Rows in `fct_invoice_line` | 442 044 | `rows_produced` of `fct_invoice_line` in `perf_history_snowflake.sql`, window 2026-11-15 13:36:00 to 13:37:35 (one statement, last load date), or `perf_probe.sql` without filters |

All timings come from the platform query history, not from wall clock:

- Snowflake: `dbt/analyses/perf_history_snowflake.sql` reads `snowflake.account_usage.query_history`.
- Databricks: `dbt/analyses/perf_history_databricks.sql` reads `system.query.history`.

Both analyses take `perf_since` and `perf_until` (UTC) and return one row per run group: a probe label, an incremental strategy, or a dbt model (from the `node_id` in the dbt query comment). `elapsed_ms` is the sum of total elapsed time of all statements in the group. Each section below gives the time window used.

Probe labels have the form `<phase>_<shape>_<run>`, for example `before_tariff_2`: lower-case letters and `_`, then `_` and the run number. The history analyses find them with the regex `([a-z_]+_[0-9]+). as perf_probe`; other labels are not grouped.

Retention: Snowflake `ACCOUNT_USAGE.QUERY_HISTORY` keeps 365 days, so the timings and partition counts can be re-derived until 2027-11-15. `GET_QUERY_OPERATOR_STATS` works for about 14 days, so the query profile below can be re-derived until about 2026-11-29. Databricks `system.query.history` follows the account system table retention (check `min(start_time)`); after that the Databricks numbers are only in this document.

Steps:

1. `dbt run-operation create_raw_tables --vars "{raw_schema: raw_perf}"`.
2. For each load date: `python -m scripts.upload_landing --target <platform> --load-date <d> --out data/out_perf --raw-schema raw_perf`, `dbt run-operation load_raw --args "{load_date: '<d>'}" --vars "{raw_schema: raw_perf}"`, `dbt build --vars "{load_date: '<d>', raw_schema: raw_perf}"` (first date with `--full-refresh`).
3. Probe queries `dbt/analyses/perf_probe.sql` without clustering (`before_*`), then `dbt run -s fct_invoice_line --vars "{..., perf_clustering: true}"` and the same probes (`after_*`). Each probe runs 3 times with a unique label, so the result cache cannot answer it. Snowflake runs with `use_cached_result = false`.
4. Incremental strategies: `dbt run -s perf_invoice_line_incremental --vars "{..., perf_strategy: <strategy>}"`, first with `--full-refresh`, then 3 incremental runs per strategy.

## Slowest models

Full 50k build, 5 load dates. Top 3 per platform by `elapsed_ms`.

| Platform | Window (UTC) | Model | Statements | Elapsed ms |
|---|---|---|---|---|
| Snowflake | 2026-11-15 13:30:00 to 13:37:35 | `recon__table_stats` | 5 | 26194 |
| Snowflake | same | `fct_invoice_line` | 5 | 12804 |
| Snowflake | same | `sat_invoice_line_billing_v2` | 26 | 10155 |
| Databricks | 2026-11-15 13:31:00 to 13:44:41 | `recon__table_stats` | 10 | 24469 |
| Databricks | same | `sat_invoice_line_billing_v1` | 31 | 18891 |
| Databricks | same | `sat_customer_phone_ma` | 31 | 18333 |

`recon__table_stats` is the reconciliation model, not part of the data path. `fct_invoice_line` is the slowest business model on Snowflake. On Databricks the incremental vault models are slower than any mart, because each one runs about 6 statements per load date and every statement has a fixed overhead of a few hundred ms.

Query profile of the Snowflake `fct_invoice_line` build without clustering (query `01c86db1-0000-bcbd-0001-4cee00057172`, last load date), from `dbt/analyses/perf_operator_stats_snowflake.sql`:

| Operator | Count | Share of query time % | Input rows | Partitions scanned |
|---|---|---|---|---|
| CreateTableAsSelect | 1 | 48.3 | 442044 | |
| WindowFunction | 3 | 24.1 | 1141344 | |
| Join | 8 | 13.8 | 3553242 | |
| Filter | 4 | 3.4 | 981930 | |
| TableScan | 9 | 3.4 | | 22 of 22 |
| JoinFilter | 8 | 3.4 | 1521804 | |

Writing the table and the `qualify` window functions (latest satellite row) take most of the time. Scans are cheap.

## Clustering `fct_invoice_line`

Config, only with `--vars "{perf_clustering: true}"`: `cluster_by=['tariff_code', 'invoice_date']` (Snowflake) and `liquid_clustered_by=['tariff_code', 'invoice_date']` (Databricks, dbt-databricks runs `OPTIMIZE` after the build). Each adapter ignores the other key. Without the var both are `none` and the build SQL is the same as before. Columns, grain and results do not change: the probes return the same counts and totals before and after.

Probes (`perf_probe.sql`):

- `both`: `invoice_date = 2026-01-05 and tariff_code = 'EL-GREEN'` (9452 lines)
- `tariff`: `tariff_code = 'EL-GREEN'` (73228 lines)
- `date`: `invoice_date = 2026-01-05` (57632 lines)

Snowflake, 2026-11-15, window 13:42:30 to 13:52:05 UTC. Bytes are per run (each run scans the same bytes):

| Probe | Before ms (runs 1/2/3) | After ms (runs 1/2/3) | Before partitions scanned | After partitions scanned | Before bytes | After bytes |
|---|---|---|---|---|---|---|
| both | 67 / 61 / 64 | 131 / 83 / 67 | 1 of 5 | 2 of 8 | 217088 | 204800 |
| tariff | 83 / 74 / 83 | 70 / 79 / 61 | 5 of 5 | 2 of 8 | 1755648 | 249856 |
| date | 54 / 63 / 57 | 71 / 72 / 89 | 1 of 5 | 6 of 8 | 110592 | 765952 |

Databricks, 2026-11-15, window 13:44:41 to 13:52:05 UTC. Bytes are per run:

| Probe | Before ms (runs 1/2/3) | After ms (runs 1/2/3) | Files read | Files pruned | Before bytes | After bytes |
|---|---|---|---|---|---|---|
| both | 612 / 379 / 457 | 647 / 331 / 349 | 1 | 0 | 741155 | 671276 |
| tariff | 338 / 304 / 341 | 367 / 359 / 364 | 1 | 0 | 686472 | 641660 |
| date | 328 / 337 / 316 | 326 / 321 / 328 | 1 | 0 | 676284 | 642543 |

Build cost of `fct_invoice_line` (last load date, 50k, 2026-11-15, windows in UTC):

| Platform | Before ms (statements) | After ms (statements) | Window before | Window after |
|---|---|---|---|---|
| Snowflake | 2658 (1) | 2631 (2, adds `alter table ... cluster by`) | 13:36:00 to 13:37:35 | 13:47:14 to 13:47:49 |
| Databricks | 3514 (2) | 12756 (3, adds `OPTIMIZE`) | 13:41:22 to 13:44:41 | 13:47:14 to 13:47:49 |

What this shows:

- Snowflake: the unclustered CTAS happened to keep load-date order, so without a clustering key the table was already pruned well by date. The key `(tariff_code, invoice_date)` cuts the tariff probe from 5 of 5 to 2 of 8 partitions and 7x fewer bytes, but the date probe gets worse (1 of 5 to 6 of 8). A clustering key is a choice of which filter to serve. Times stay under 150 ms either way.
- Databricks: every probe reads 1 file and prunes 0, before and after. The table is too small for more than one file, so there is nothing to skip. Liquid clustering only adds the `OPTIMIZE` cost (about 9 s per build here). It starts to pay off when the table has many files.
- Kept as an opt-in pattern (`perf_clustering`, default off); not worth it at this volume. On a real volume, check that the filter used most is the first clustering column, and watch automatic clustering credits on Snowflake.

## Incremental strategies

Model `dbt/models/perf/perf_invoice_line_incremental.sql`, enabled only when the var `perf_strategy` is set. It copies `fct_invoice_line` and reprocesses the last invoice date on each incremental run (57632 rows). Unique key `(invoice_no, line_no)`, `partition_by=['invoice_date']` (Databricks only), `event_time='invoice_date'`, `batch_size='day'` for microbatch. Microbatch runs with `--event-time-start 2026-01-05 --event-time-end 2026-01-06`. After all runs every strategy table had 442044 rows and the net total 11541702.27, the same as `fct_invoice_line`. The check on 2026-11-15 was an ad-hoc count and sum before the `perf` schemas were dropped; `perf_probe.sql --vars "{perf_relation: <schema>.perf_invoice_line_<strategy>}"` runs the same check.

Snowflake has no partition-wise `insert_overwrite`: dbt-snowflake runs `insert overwrite` of the whole table, which would delete the earlier dates. It is left out.

Snowflake, 2026-11-15, full refresh window 13:52:42 to 13:53:19 UTC, incremental window 13:53:19 to 13:54:47 UTC. Times, statements, bytes and partitions are summed over the 3 incremental runs:

| Strategy | Full refresh ms (statements) | 3 incremental runs ms (statements) | Bytes scanned, sum of 3 runs | Partitions scanned of total, sum of 3 runs |
|---|---|---|---|---|
| merge | 739 (2) | 5507 (21) | 31829504 | 29 of 38 |
| delete+insert | 781 (2) | 7912 (24) | 34986496 | 69 of 79 |
| microbatch | 7090 (34, 5 batches) | 4484 (24) | 15603712 | 36 of 51 |

12 statements of the incremental runs (1769 ms) carry the model `node_id` but not the table name (transaction control). The analysis lists them as `perf_invoice_line_incremental`.

Databricks, 2026-11-15, full refresh window 13:54:52 to 13:56:19 UTC, incremental window 13:56:19 to 13:59:48 UTC. Summed over the 3 incremental runs:

| Strategy | Full refresh ms (statements) | 3 incremental runs ms (statements) | Bytes read, sum of 3 runs | Files read / pruned, sum of 3 runs |
|---|---|---|---|---|
| merge | 2893 (2) | 9148 (30) | 13284260 | 21 / 12 |
| insert_overwrite | 2016 (2) | 6407 (30) | 7317027 | 6 / 12 |
| delete+insert | 2113 (2) | 6015 (27) | 12254799 | 18 / 0 |
| microbatch | 9062 (38, 5 batches) | 5997 (24) | 6530595 | 3 / 0 |

What this shows:

- On Snowflake `delete+insert` is slower than `merge` and scans more partitions (69 of 79 against 29 of 38), because it runs a separate delete and insert.
- Strategies that replace a date slice (`insert_overwrite` on the `invoice_date` partition on Databricks, `microbatch` on both) read about half the bytes of `merge`.
- `microbatch` is the slowest for a full refresh, because it runs one batch per day. For the daily run it was the fastest in this run on Snowflake and level with `delete+insert` on Databricks, and a failed batch can be retried alone.
- A mart that is rebuilt per day fits `microbatch` (both platforms) or `insert_overwrite` (Databricks). `merge` stays the choice when rows of any date can change.
