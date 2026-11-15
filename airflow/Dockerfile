FROM astrocrpublic.azurecr.io/runtime:3.3-12

RUN pip install --no-cache-dir uv \
    && uv venv /usr/local/airflow/dbt_venv --python 3.12 \
    && uv pip install --python /usr/local/airflow/dbt_venv/bin/python dbt-snowflake dbt-databricks
