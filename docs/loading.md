# Loading the raw vault one load date at a time

The vault loads one load date per run: `dbt build --vars "{load_date: <d>}"`. Staging views filter raw data to that date. `scripts/build_by_load_date.sh` builds all dates in order.

## Rule: skip same-or-later load dates

On an incremental run, no vault table inserts a row for a key that already has a row with the same or a later `load_datetime`.

| Object | How |
|---|---|
| Hubs, links, same-as links, non-historised links | automate_dv anti-joins on the hash key. A known key is never inserted again. |
| Satellites (`sat`) | automate_dv option `apply_source_filter`, set for `models/raw_vault/sats` in `dbt_project.yml`. Per key, the stage keeps only rows newer than the newest loaded row. |
| Multi-active satellites, effectivity satellite | The macro `skip_loaded_load_dates` wraps the automate_dv SQL and applies the same rule. automate_dv has no option for them. |
| `sts_contract` | Its `not exists` check compares `load_datetime >=`, so it applies the same rule. |

Why: automate_dv compares the stage only with the newest row per key. Without the rule, a re-run of a past date inserts its rows again whenever they differ from the newest row. With the rule, a re-run of any loaded date, in any order, is a no-op, and the hashdiff chain of a satellite stays in load order.

## Trade-off

A past date that was never loaded is also skipped for every key that already has later rows. Only keys that are new to the vault get rows. The vault does not insert history out of order.

The test `warn_load_date_before_loaded` (severity `warn`) warns when the built `load_date` is earlier than the newest `load_datetime` in the hubs.

## Recover a missed date

Replay from raw. Raw keeps every load date, so a full rebuild gives the same vault as an in-order load:

```bash
set -a; source .env; set +a
DBT_PROJECT_DIR=dbt DBT_PROFILES_DIR=dbt scripts/build_by_load_date.sh --target <target>
```

The first date runs with `--full-refresh`, and the next dates load in order.

## Check

`scripts/rerun_check.sh` builds all dates and records the row counts of all vault tables. Then it re-runs past dates and the last date. Then it runs the raw vault tests and compares the row counts. It fails if a test fails or a row count changes. Set `RERUN_DATES` to choose other dates.

```bash
DBT_PROJECT_DIR=dbt DBT_PROFILES_DIR=dbt scripts/rerun_check.sh --target snowflake_dev
RERUN_DATES="2026-01-03 2026-01-01" DBT_PROJECT_DIR=dbt DBT_PROFILES_DIR=dbt scripts/rerun_check.sh --target snowflake_dev
```
