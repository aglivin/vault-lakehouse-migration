# Airflow

Astro project in `airflow/`, Airflow 3.3 (Astro Runtime 3.3), dbt through `astronomer-cosmos`.

## DAGs

| DAG | Schedule | Tasks |
|---|---|---|
| `vdwh_ingest` | `@daily`, 2026-01-01 to 2026-01-05, catchup off, paused on creation | `dbt_deps` → `load_raw` (`dbt run-operation load_raw --args {load_date: <ds>}`) → `publish_raw_landed` |
| `vdwh_transform` | asset `vdwh/raw_landed` | `resolve_load_date` → `dbt_deps` → `dbt_seed` → `staging` → `raw_vault` → `business_vault` → `marts` → `cross_layer_tests` |

The landing files are already in the Snowflake stage and the Databricks volume. `scripts/upload_landing.py` needs the `snow` and `databricks` CLIs, so it runs outside the container.

## Asset scheduling

`publish_raw_landed` emits an event on `Asset("vdwh/raw_landed")` with the extra `{"load_date": "<ds>"}`. Every event queues one `vdwh_transform` run.

`resolve_load_date` reads `triggering_asset_events` and returns the load date. All dbt tasks of the run read it with `ti.xcom_pull(task_ids='resolve_load_date')`. The task fails, and nothing is built, when:

- the run has no triggering event (a manual trigger of `vdwh_transform`);
- an event has no `load_date`;
- the run has events with two different load dates.

To build a date, trigger `vdwh_ingest` for it. Do not trigger `vdwh_transform` by hand.

## Alerts

- `on_failure_callback` (`include/vdwh_alerts.py:notify_failure`) on every task of both DAGs. It writes one line: `VDWH ALERT: task failed dag_id=... task_id=... run_id=... try_number=... error=...`. It runs after the last retry (2 retries, 1 minute apart). The line is in the task log; when the task process was killed (heartbeat lost), the dag processor runs the callback and the line is in `logs/dag_processor/<date>/dags-folder/<dag file>.log`.
- Webhook (Slack incoming webhook or any URL that accepts `{"text": ...}`): off by default. To switch it on, create an Airflow connection whose host is the webhook URL and set `VDWH_ALERT_CONN_ID=<connection id>` in `airflow/.env`. No webhook URL is in the repo.
- SLA: Airflow 3 removed SLAs. Both DAGs use a Deadline Alert (Airflow 3.1+): reference `DAGRUN_QUEUED_AT`, 15 minutes for `vdwh_ingest` and 60 minutes for `vdwh_transform`. When a run is not finished by then, the triggerer runs `log_missed_deadline`, which writes `VDWH ALERT: deadline missed dag_id=... run_id=... deadline_time=...` to the triggerer log.

## Local run

Copy `airflow/.env.example` to `airflow/.env` and fill it in. `SNOWFLAKE_KEY_FILE` is the host path of the Snowflake key; it must be exported in the shell that runs `astro dev start`, because Docker Compose reads it for the volume mount.

```
cd airflow
astro dev start
astro dev run dags unpause vdwh_ingest
astro dev run dags unpause vdwh_transform
astro dev run dags trigger vdwh_ingest --logical-date 2026-01-01T00:00:00+00:00
```

Run the load dates in order: the raw vault is insert-only and a later date must not land before an earlier one.

Cosmos runs one dbt process per model, and every process parses the project. On a laptop with 8 GB for Docker, 16 parallel parses starve the task heartbeats and the scheduler kills the tasks. Set `AIRFLOW__CORE__PARALLELISM=4` in `airflow/.env` to prevent this.

## Backfill

Airflow 3 runs backfills in the scheduler. Create one with:

```
astro dev run backfill create --dag-id vdwh_ingest \
  --from-date 2026-01-02 --to-date 2026-01-03 \
  --reprocess-behavior completed --max-active-runs 1
```

Each backfill run of `vdwh_ingest` emits one `vdwh/raw_landed` event, and each event queues one `vdwh_transform` run for that load date. `max_active_runs=1` on both DAGs keeps the dates in order.

The loads are idempotent, so a rerun of a date writes no new rows. A backfill of an old date still leaves the latest state built from that date, so after a backfill run the later dates again in order (here 2026-01-04 and 2026-01-05).

## Target switch

The dbt target comes from the environment variable `DBT_TARGET` (default `snowflake_dev`). The DAG files do not change.

- `snowflake_dev`: key-pair auth, schema `dev`.
- `databricks_ci`: token auth (`DATABRICKS_TOKEN`), schema `ci`. `databricks_dev` uses OAuth in the browser and cannot run headless in a container.

Set `DBT_TARGET=databricks_ci` in `airflow/.env`, run `astro dev restart`, and trigger `vdwh_ingest` for a date.
