from datetime import datetime, timedelta

from airflow.sdk import dag, task
from cosmos import DbtTaskGroup, ExecutionConfig, ProjectConfig, RenderConfig
from cosmos.constants import TestIndirectSelection
from cosmos.operators.local import DbtSeedLocalOperator, DbtTestLocalOperator

from include.vdwh_alerts import notify_failure, run_deadline
from include.vdwh_assets import RAW_LANDED, single_load_date
from include.vdwh_dbt import DBT_EXECUTABLE, DBT_PROJECT_DIR, profile_config

CROSS_LAYER_TESTS = ["tag:cross_layer"]
LAYERS = ["staging", "raw_vault", "business_vault", "marts"]
LOAD_DATE = "{{ ti.xcom_pull(task_ids='resolve_load_date') }}"

project_config = ProjectConfig(dbt_project_path=DBT_PROJECT_DIR, install_dbt_deps=False)
execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE,
    install_dbt_deps=False,
    test_indirect_selection=TestIndirectSelection.CAUTIOUS,
)
operator_args = {"append_env": True, "vars": {"load_date": LOAD_DATE}}


@task
def resolve_load_date(*, triggering_asset_events) -> str:
    return single_load_date(triggering_asset_events)


@dag(
    dag_id="vdwh_transform",
    schedule=[RAW_LANDED],
    start_date=datetime(2026, 1, 1),
    catchup=False,
    is_paused_upon_creation=True,
    max_active_runs=1,
    render_template_as_native_obj=True,
    deadline=run_deadline(timedelta(minutes=60)),
    default_args={
        "retries": 2,
        "retry_delay": timedelta(minutes=1),
        "on_failure_callback": notify_failure,
    },
)
def vdwh_transform():
    dbt_seed = DbtSeedLocalOperator(
        task_id="dbt_seed",
        project_dir=str(DBT_PROJECT_DIR),
        profile_config=profile_config,
        dbt_executable_path=DBT_EXECUTABLE,
        append_env=True,
        install_deps=False,
    )
    previous = resolve_load_date() >> dbt_seed
    for layer in LAYERS:
        group = DbtTaskGroup(
            group_id=layer,
            project_config=project_config,
            profile_config=profile_config,
            execution_config=execution_config,
            render_config=RenderConfig(select=[f"path:models/{layer}"]),
            operator_args=operator_args,
        )
        previous >> group
        previous = group
    cross_layer_tests = DbtTestLocalOperator(
        task_id="cross_layer_tests",
        project_dir=str(DBT_PROJECT_DIR),
        profile_config=profile_config,
        dbt_executable_path=DBT_EXECUTABLE,
        append_env=True,
        install_deps=False,
        select=CROSS_LAYER_TESTS,
        vars={"load_date": LOAD_DATE},
    )
    previous >> cross_layer_tests


vdwh_transform()
