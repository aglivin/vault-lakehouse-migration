from datetime import datetime, timedelta

from airflow.sdk import dag, task
from cosmos.operators.local import DbtRunOperationLocalOperator

from include.vdwh_alerts import notify_failure, run_deadline
from include.vdwh_assets import LOAD_DATE_KEY, RAW_LANDED
from include.vdwh_dbt import DBT_EXECUTABLE, DBT_PROJECT_DIR, profile_config


@task(outlets=[RAW_LANDED])
def publish_raw_landed(*, outlet_events, ds):
    outlet_events[RAW_LANDED].extra = {LOAD_DATE_KEY: ds}


@task.sensor(poke_interval=30, timeout=3600, mode="reschedule")
def wait_for_idle_transform(*, ti) -> bool:
    return ti.get_dr_count(dag_id="vdwh_transform", states=["queued", "running"]) == 0


@dag(
    dag_id="vdwh_ingest",
    schedule="@daily",
    start_date=datetime(2026, 1, 1),
    end_date=datetime(2026, 1, 5),
    catchup=False,
    is_paused_upon_creation=True,
    max_active_runs=1,
    deadline=run_deadline(timedelta(minutes=75)),
    default_args={
        "retries": 2,
        "retry_delay": timedelta(minutes=1),
        "on_failure_callback": notify_failure,
    },
)
def vdwh_ingest():
    load_raw = DbtRunOperationLocalOperator(
        task_id="load_raw",
        macro_name="load_raw",
        args={"load_date": "{{ ds }}"},
        project_dir=str(DBT_PROJECT_DIR),
        profile_config=profile_config,
        dbt_executable_path=DBT_EXECUTABLE,
        append_env=True,
        install_deps=False,
    )
    load_raw >> wait_for_idle_transform() >> publish_raw_landed()


vdwh_ingest()
