import os
from pathlib import Path

from cosmos import ProfileConfig

DBT_PROJECT_DIR = Path(os.environ.get("DBT_PROJECT_DIR", "/usr/local/airflow/dbt"))
DBT_EXECUTABLE = os.environ.get("DBT_EXECUTABLE", "/usr/local/airflow/dbt_venv/bin/dbt")

profile_config = ProfileConfig(
    profile_name="vdwh",
    target_name=os.environ.get("DBT_TARGET", "snowflake_dev"),
    profiles_yml_filepath=DBT_PROJECT_DIR / "profiles.yml",
)

