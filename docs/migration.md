# Migration: Snowflake to Databricks

The same dbt project builds on `snowflake_dev` and `databricks_dev` (Unity Catalog catalog `vdwh_dev`, Delta tables). Models contain no `if target.type`. Where the two platforms behave differently, a macro with `adapter.dispatch` holds the platform-specific SQL.

## Constructs met in this project

| Snowflake construct | Databricks equivalent | How solved | File |
|---|---|---|---|
| Internal stage `create stage ... file_format = (type = csv ...)` | Unity Catalog volume `create volume` | `create_landing_area` dispatches to `snowflake__` and `databricks__` | `dbt/macros/raw/create_raw_tables.sql` |
| `snow stage copy` to `@VDWH_DEV.RAW.LANDING` | `databricks fs cp` to `dbfs:/Volumes/vdwh_dev/raw/landing` | Upload script takes `--target snowflake` or `--target databricks` | `scripts/upload_landing.py` |
| `copy into ... from (select $1, $2, ... from @stage)` with `files`, `force = true` and the stage file format | `copy into ... from (select <column names> from '/Volumes/...')` with `fileformat = csv`, `format_options ('header' = 'true', 'escape' = '"')`, `copy_options ('force' = 'true')` | `copy_into_raw` dispatches to `snowflake__` and `databricks__`. Databricks reads CSV columns by header name, Snowflake by position. | `dbt/macros/raw/load_raw.sql` |
| `'2026-01-01'::date` | `cast('2026-01-01' as date)` | `::` stays only in the Snowflake branch. Shared SQL uses `cast`. | `dbt/macros/raw/load_raw.sql`, `dbt/macros/staging/stage_raw.sql` |
| `date_trunc('month', <date>)` returns `DATE` | `date_trunc('month', <date>)` returns `TIMESTAMP`. `trunc(<date>, 'MM')` returns `DATE`. | `month_trunc` dispatches to `snowflake__`, `databricks__` and `default__`. `invoice_month` is `DATE` on both targets (`dbt/analyses/mart_columns.sql`). | `dbt/macros/compat/month_trunc.sql`, `dbt/models/marts/billing/billing__revenue_by_tariff_month.sql` |
| Hash keys: automate_dv `SHA` hashing casts to `BINARY` | automate_dv casts to `STRING` (upper-case hex) when `enable_native_hashes` is off | Accepted difference. Hashing does not change. Keys are compared as upper-case hex across platforms. | automate_dv `type_binary`, `dbt/dbt_project.yml` (`hash: SHA`) |
| `QUALIFY` | `QUALIFY` is supported natively | No change | `dbt/models/marts/core/fct_invoice_line.sql`, `dbt/models/marts/core/dim_tariff.sql` |
| Unquoted identifiers fold to upper case. `information_schema` returns upper-case names. | Identifiers are case-insensitive and stored in lower case | Staging column names stay upper case (`LOAD_DATETIME`, `*_HK`) and work on both. Queries on `information_schema` compare with `upper()` and return `lower()`. | `dbt/macros/staging/stage_raw.sql`, `dbt/analyses/mart_columns.sql` |
| `information_schema.columns.ordinal_position` starts at 1 | Starts at 0 | Compare columns by name, not by position | `dbt/analyses/mart_columns.sql` |

## Not met in this project, check in a real DWH

- `VARIANT`, `OBJECT`, `ARRAY` columns and `LATERAL FLATTEN`: Databricks uses `VARIANT` or `STRUCT`/`ARRAY` with `explode` and the `:` path syntax. The synthetic sources have no semi-structured data.
- Time travel (`AT`/`BEFORE`, `UNDROP`) vs Delta `VERSION AS OF` / `TIMESTAMP AS OF` and `RESTORE`, with different retention defaults.
- `MERGE` behaviour of incremental models: default `incremental_strategy`, duplicate source rows, schema evolution.
- Transient tables, clustering keys, search optimization vs Delta `CLUSTER BY` (liquid clustering), `OPTIMIZE`, `VACUUM`.
- Streams and tasks vs Lakeflow pipelines and jobs.
- Snowflake functions without a direct equivalent: `IFF`, `TRY_TO_*`, `TO_VARCHAR` with a format, `SPLIT_PART` index rules, `CONVERT_TIMEZONE`, `TIMESTAMP_LTZ`/`TZ` semantics.
- Collation and case-sensitive string comparison.
- Secure views, masking and row access policies vs Unity Catalog row filters and column masks.

## Result

Each load date 2026-01-01 to 2026-01-05 was built on `databricks_dev` one date at a time (load landing, `load_raw`, `dbt build --vars "{load_date: <date>}"`). Every build passed with 0 errors. Mart totals vs the seed `expected_totals` after 2026-01-05, from `dbt/analyses/mart_vs_expected_totals.sql`:

| Target | Expected invoices | Mart invoices | Expected net total | Mart net total |
|---|---|---|---|---|
| snowflake_dev | 4421 | 4421 | 461626.22 | 461626.22 |
| databricks_dev | 4421 | 4421 | 461626.22 | 461626.22 |
