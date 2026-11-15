# Airflow

Astro project in `airflow/`, Airflow 3.3 (Astro Runtime 3.3), dbt through `astronomer-cosmos`.

## DAGs

| DAG | Schedule | Tasks |
|---|---|---|
| `vdwh_ingest` | `@daily`, 2026-01-01 to 2026-01-05, catchup off, paused on creation | `load_raw` (`dbt run-operation load_raw --args {load_date: <ds>}`) → `wait_for_idle_transform` → `publish_raw_landed` |
| `vdwh_transform` | asset `vdwh/raw_landed` | `resolve_load_date` → `dbt_seed` → `staging` → `raw_vault` → `business_vault` → `marts` → `cross_layer_tests` |

The DAGs do not run `dbt deps`. The container mounts `dbt/` from the host, so the packages in `dbt/dbt_packages` are installed once on the host (`uv run dbt deps --project-dir dbt`) before `astro dev start`. A `dbt deps` task in the DAGs would rewrite that shared folder while parallel Cosmos tasks parse the project.

The landing files are already in the Snowflake stage and the Databricks volume. `scripts/upload_landing.py` needs the `snow` and `databricks` CLIs, so it runs outside the container.

## Asset scheduling

`publish_raw_landed` emits an event on `Asset("vdwh/raw_landed")` with the extra `{"load_date": "<ds>"}`. `vdwh_transform` has `max_active_runs=1`; while a run is active, new events wait, and Airflow puts all waiting events into the next run. So an ingest run must not publish while a transform run is queued or running. The sensor `wait_for_idle_transform` (reschedule mode, every 30 seconds) waits until `vdwh_transform` has no queued or running run. With `max_active_runs=1` on `vdwh_ingest`, every event then normally gets its own `vdwh_transform` run, also in a backfill.

Do not trigger `vdwh_ingest` manually while a backfill runs. Backfill runs have their own `--max-active-runs`, so a manual ingest run and a backfill run can pass the sensor at the same time, and their events merge.

If two load dates still reach one run, `resolve_load_date` fails and builds nothing. Recovery: clear the `vdwh_ingest` run of each date of the failed run, one date at a time and in order (Clear on that DAG run in the UI; a new run with the same logical date is refused). The load is idempotent, so the rerun adds no raw rows; its event queues a new `vdwh_transform` run.

`resolve_load_date` reads `triggering_asset_events` and returns the load date. All dbt tasks of the run read it with `ti.xcom_pull(task_ids='resolve_load_date')`. The task fails, and nothing is built, when:

- the run has no triggering event (a manual trigger of `vdwh_transform`);
- an event has no `load_date`;
- the run has events with two different load dates.

To build a date, trigger `vdwh_ingest` for it. Do not trigger `vdwh_transform` by hand. `vdwh_transform` has no params; there is no full-refresh switch, because an incremental run on empty tables builds the first date too.

## Alerts

- `on_failure_callback` (`include/vdwh_alerts.py:notify_failure`) on every task of both DAGs. It writes one line: `VDWH ALERT: task failed dag_id=... task_id=... run_id=... try_number=... error=...`. It runs after the last retry (2 retries, 1 minute apart). The line is in the task log; when the task process was killed (heartbeat lost), the dag processor runs the callback and the line is in `logs/dag_processor/<date>/dags-folder/<dag file>.log`.
- Webhook (Slack incoming webhook or any URL that accepts `{"text": ...}`): off by default. To switch it on, create an Airflow connection and put the full webhook URL in its Host field (for example `airflow connections add vdwh_alert --conn-type http --conn-host https://hooks.slack.com/services/...`) and set `VDWH_ALERT_CONN_ID=<connection id>` in `airflow/.env`. No webhook URL is in the repo.
- SLA: Airflow 3 removed SLAs. Both DAGs use a Deadline Alert (Airflow 3.1+): reference `DAGRUN_QUEUED_AT`, 75 minutes for `vdwh_ingest` (the 60-minute transform deadline plus load time, because ingest waits in `wait_for_idle_transform` for the running transform) and 60 minutes for `vdwh_transform`. Backfill runs are all queued when the backfill is created, so in a long backfill the later ingest runs can still miss the deadline and log an alert. When a run is not finished by then, the triggerer runs `log_missed_deadline`, which writes `VDWH ALERT: deadline missed dag_id=... run_id=... deadline_time=...` to the triggerer log.

## Local run

Copy `airflow/.env.example` to `airflow/.env` and fill it in. `SNOWFLAKE_KEY_FILE` is the host path of the Snowflake key; it must be exported in the shell that runs `astro dev start`, because Docker Compose reads it for the volume mount.

```
cd airflow
astro dev start
astro dev run dags unpause vdwh_ingest
astro dev run dags unpause vdwh_transform
astro dev run dags trigger vdwh_ingest --logical-date 2026-01-01T00:00:00+00:00
```

`load_raw` uses `{{ ds }}`, so a manual trigger of `vdwh_ingest` needs `--logical-date` for the load date; a trigger without it uses the current time as the date.

Run the load dates in order: the raw vault is insert-only and a later date must not land before an earlier one.

Cosmos runs one dbt process per model, and every process parses the project. On a laptop with 8 GB for Docker, 16 parallel parses starve the task heartbeats and the scheduler kills the tasks. Set `AIRFLOW__CORE__PARALLELISM=4` in `airflow/.env` to prevent this.

## Backfill

Airflow 3 runs backfills in the scheduler. Create one with:

```
astro dev run backfill create --dag-id vdwh_ingest \
  --from-date 2026-01-02 --to-date 2026-01-03 \
  --max-active-runs 1
```

`--reprocess-behavior completed` is optional: add it to run again dates that already have a successful run. The verification run used the command above without it, because 2026-01-02 and 2026-01-03 had no runs yet.

Each backfill run of `vdwh_ingest` loads its date, waits in `wait_for_idle_transform` until the `vdwh_transform` run of the previous date is done, and then emits one `vdwh/raw_landed` event. So each date gets its own `vdwh_transform` run, in order. Without the sensor, ingest runs finish faster than transform runs (in the local run on 2026-11-15, about 20 seconds against about 4 minutes; observed, not a benchmark), and the waiting events of three or more dates merge into one failed run.

The loads are idempotent, so a rerun of a date writes no new rows. A backfill of an old date still leaves the latest state built from that date, so after a backfill run the later dates again in order (here 2026-01-04 and 2026-01-05).

## Target switch

The dbt target comes from the environment variable `DBT_TARGET` (default `snowflake_dev`). The DAG files do not change.

- `snowflake_dev`: key-pair auth, schema `dev`.
- `databricks_ci`: token auth (`DATABRICKS_TOKEN`), schema `ci`. `databricks_dev` uses OAuth in the browser and cannot run headless in a container.

Set `DBT_TARGET=databricks_ci` in `airflow/.env`, run `astro dev restart`, and trigger `vdwh_ingest` for a date.
