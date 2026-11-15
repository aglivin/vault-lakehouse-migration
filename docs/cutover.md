# Cut-over: Snowflake to Databricks

## Reconciliation

Model `recon__table_stats` (`dbt/models/recon/recon__table_stats.sql`) returns one row per table, 35 tables: all hubs, links, same-as links, satellites, the business vault masters and the marts. Grain: one row per table.

| Column | Meaning |
|---|---|
| `row_count` | `count(*)` |
| `distinct_keys`, `key_min`, `key_max` | on the upper-case hex of the hash key |
| `key_checksum` | sum of the first 8 hex digits of every key, read as a number |
| `measure_sums` | sums of real measures (kwh, net amount, tax or VAT amount, prices, fees), each row cast to `decimal(38,4)`, total rounded to 2 decimals |
| `min_load_date`, `max_load_date` | load date of satellites as `YYYY-MM-DD` |

Snowflake stores hash keys as `BINARY`, Databricks as upper-case hex `STRING`. The macro `hex_key` (`dbt/macros/compat/hex_key.sql`) turns both into the same string, so the keys are compared by value and hashing is not changed. Sums are rounded to 2 decimals so that float noise does not count as a difference.

Run on each target, then compare:

```
uv run dbt show -s recon__table_stats --target snowflake_dev --output json --limit -1 --quiet > docs/recon/snowflake_dev.json
uv run dbt show -s recon__table_stats --target databricks_dev --output json --limit -1 --quiet > docs/recon/databricks_dev.json
uv run python scripts/compare_recon.py docs/recon/snowflake_dev.json docs/recon/databricks_dev.json
```

`compare_recon.py` exits 0 when every cell matches. Otherwise it exits 1 and prints a Markdown table with table, column and both values. A table that exists on one side only is a difference.

Result after load date 2026-01-05 (committed evidence in `docs/recon/`): 0 differences in 35 tables. Each of the 5 load dates, built one at a time on both targets, ended with `dbt build` PASS=195, ERROR=0.

## Plan

1. Parallel run. Both platforms load the same landing files and run `dbt build --vars "{load_date: <date>}"` for every load date. Snowflake stays the system of record, consumers stay on Snowflake.
2. Daily recon. After each load date run the three commands above and keep the output.
3. Go/no-go. Go when recon shows 0 differences for N consecutive load dates, with `dbt build` at ERROR=0 on Databricks on the same dates. This repo has 5 load dates, so N = 5 here. A real project sets N to cover at least one month-end. Any difference is no-go until the cause is fixed and N restarts from 0.
4. Switch consumers, one group per step, each after the recon of that day is clean:
   1. Marts consumers: BI dashboards and exports read `marts` on Databricks.
   2. Airflow: the DAG points to the Databricks target with the same DAG logic.
   3. Business vault consumers.
   4. Raw vault and staging consumers (ad-hoc queries, audits).
5. Stop the Snowflake loads only after step 4 has run clean for the rollback window.

## Rollback

- Snowflake becomes read-only after step 4 and stays the source of truth during the rollback window. Suggested window: 14 days, covering one full invoicing cycle.
- Trigger: a recon difference, a failed `dbt build` on Databricks, or a consumer reporting wrong numbers.
- Action: point consumers back to Snowflake in the reverse order of the switch. No data is lost: Snowflake was read-only, and the landing files are kept, so any load date can be rebuilt on either platform.
- After the window: drop write access to Snowflake, keep a final export, and remove the Snowflake target from CI.
