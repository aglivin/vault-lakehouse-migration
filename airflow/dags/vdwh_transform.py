import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import Param, dag
from cosmos import (
    DbtTaskGroup,
    ExecutionConfig,
    ProfileConfig,
    ProjectConfig,
    RenderConfig,
)
from cosmos.constants import TestIndirectSelection
from cosmos.operators.local import (
    DbtRunOperationLocalOperator,
    DbtSeedLocalOperator,
    DbtTestLocalOperator,
)

DBT_PROJECT_DIR = Path(os.environ.get("DBT_PROJECT_DIR", "/usr/local/airflow/dbt"))
DBT_EXECUTABLE = os.environ.get("DBT_EXECUTABLE", "/usr/local/airflow/dbt_venv/bin/dbt")
CROSS_LAYER_TESTS = ["tag:cross_layer"]
LAYERS = ["staging", "raw_vault", "business_vault", "marts"]

profile_config = ProfileConfig(
    profile_name="vdwh",
    target_name=os.environ.get("DBT_TARGET", "snowflake_dev"),
    profiles_yml_filepath=DBT_PROJECT_DIR / "profiles.yml",
)
project_config = ProjectConfig(dbt_project_path=DBT_PROJECT_DIR, install_dbt_deps=False)
execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE,
    install_dbt_deps=False,
    test_indirect_selection=TestIndirectSelection.CAUTIOUS,
)
operator_args = {
    "append_env": True,
    "vars": {"load_date": "{{ ds }}"},
    "full_refresh": "{{ params.full_refresh }}",
}


@dag(
    dag_id="vdwh_transform",
    schedule="@daily",
    start_date=datetime(2026, 1, 1),
    end_date=datetime(2026, 1, 5),
    catchup=False,
    is_paused_upon_creation=True,
    max_active_runs=1,
    render_template_as_native_obj=True,
    params={
        "full_refresh": Param(
            False,
            type="boolean",
            description="Rebuilds the incremental vault from the run date only. Use it for the first date.",
        )
    },
    default_args={"retries": 2, "retry_delay": timedelta(minutes=1)},
)
def vdwh_transform():
    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"{DBT_EXECUTABLE} deps --project-dir {DBT_PROJECT_DIR}",
    )
    dbt_seed = DbtSeedLocalOperator(
        task_id="dbt_seed",
        project_dir=str(DBT_PROJECT_DIR),
        profile_config=profile_config,
        dbt_executable_path=DBT_EXECUTABLE,
        append_env=True,
        install_deps=False,
    )
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
    dbt_deps >> dbt_seed >> load_raw
    previous = load_raw
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
        vars={"load_date": "{{ ds }}"},
    )
    previous >> cross_layer_tests


vdwh_transform()
