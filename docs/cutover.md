# Cut-over: Snowflake to Databricks

## Reconciliation

Model `recon__table_stats` (`dbt/models/recon/recon__table_stats.sql`) returns one row per table, 35 tables: all hubs, links, same-as links, satellites, the business vault masters and the marts. Grain: one row per table.

| Column | Meaning |
|---|---|
| `row_count` | `count(*)` |
| `distinct_keys`, `key_min`, `key_max` | on the upper-case hex of the hash key |
| `key_checksum` | sum of the first two 8-digit hex chunks (digits 1-8 and 9-16) of every key, read as numbers |
| `hashdiff_distinct`, `hashdiff_checksum` | the same for the hashdiff of every satellite, so the payload is covered |
| `measure_sums` | sums of real measures (kwh, net amount, tax or VAT amount, prices, fees), each row cast to `decimal(38,4)`, total rounded to 2 decimals |
| `min_load_date`, `max_load_date` | load date as `YYYY-MM-DD`, for every table that has `load_datetime` (not the business vault masters and marts) |

Snowflake stores hash keys as `BINARY`, Databricks as upper-case hex `STRING`. The macro `hex_key` (`dbt/macros/compat/hex_key.sql`) turns both into the same string, so the keys are compared by value and hashing is not changed. Sums are rounded to 2 decimals so that float noise does not count as a difference.

Run on each target, then compare:

```
uv run dbt show -s recon__table_stats --target snowflake_dev --output json --limit -1 --quiet > data/recon/snowflake_dev.json
uv run dbt show -s recon__table_stats --target databricks_dev --output json --limit -1 --quiet > data/recon/databricks_dev.json
uv run python scripts/compare_recon.py data/recon/snowflake_dev.json data/recon/databricks_dev.json
```

`compare_recon.py` exits 0 when every cell matches. It exits 1 and prints a Markdown table with table, column and both values when a cell differs. A table that exists on one side only is a difference. It exits 2 on an empty result or a duplicate table name.

Result after load date 2026-01-05 (committed evidence in `data/recon/`): 0 differences in 35 tables.

## Plan

1. Parallel run. Both platforms load the same landing files and run `dbt build --vars "{load_date: <date>}"` for every load date. Snowflake is the system of record and all consumers stay on Snowflake.
2. Daily recon. After each load date run the three commands above and keep the output.
3. Go/no-go. Go when recon shows 0 differences for N consecutive load dates. This repo has 5 load dates, so N = 5 here. A real project sets N to cover at least one month-end. Any difference is no-go until the cause is fixed and N restarts from 0.
4. Switch consumers, one group per step, each after the recon of that day is clean:
   1. Marts consumers: BI dashboards and exports read `marts` on Databricks.
   2. Business vault consumers.
   3. Raw vault and staging consumers (ad-hoc queries, audits).
5. Switch the loader. Airflow runs the same DAG against the Databricks target. This is a loader change, not a consumer change. Loads keep running on both platforms until the rollback window ends.
6. End of the rollback window. Stop the Snowflake loads, keep a final export, and remove the Snowflake target from CI.

## Rollback

- Read-only means: after step 4 no consumer reads from or writes to Snowflake. The Snowflake loads continue, so Snowflake stays complete and current.
- The rollback window starts at step 4 and lasts 14 days, covering one full invoicing cycle. Recon runs daily during the window.
- Trigger: a recon difference, a failed `dbt build` on Databricks, or a consumer reporting wrong numbers.
- Action: switch the consumers back to Snowflake in the reverse order of the switch. No replay is needed, because the Snowflake loads never stopped.
- Rollback is no longer possible after step 6.
