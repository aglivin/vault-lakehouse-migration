import os
from pathlib import Path

from airflow.providers.standard.operators.bash import BashOperator
from cosmos import ProfileConfig

DBT_PROJECT_DIR = Path(os.environ.get("DBT_PROJECT_DIR", "/usr/local/airflow/dbt"))
DBT_EXECUTABLE = os.environ.get("DBT_EXECUTABLE", "/usr/local/airflow/dbt_venv/bin/dbt")

profile_config = ProfileConfig(
    profile_name="vdwh",
    target_name=os.environ.get("DBT_TARGET", "snowflake_dev"),
    profiles_yml_filepath=DBT_PROJECT_DIR / "profiles.yml",
)


def dbt_deps_task() -> BashOperator:
    return BashOperator(
        task_id="dbt_deps",
        bash_command=f"{DBT_EXECUTABLE} deps --project-dir {DBT_PROJECT_DIR}",
    )
