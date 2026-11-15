# Walkthrough: 5 minutes

A script for a live demo. Six steps, about 5 minutes. Each step says what to open and what to say.

## 1. README and scenario (30 s)

Open: [`README.md`](../README.md), the diagram and the results table.

- A fictional energy utility sells electricity and gas. Data comes from Billing and CRM.
- I built a Data Vault 2.0 warehouse with dbt on Snowflake, then ran the same project on Databricks.
- Mid-project, both source systems are replaced. The vault must absorb that, and the marts must not change for consumers.

## 2. Raw vault (60 s)

Open: [`dbt/models/raw_vault/hubs/hub_customer.sql`](../dbt/models/raw_vault/hubs/hub_customer.sql), [`dbt/models/raw_vault/links/link_customer_contract.sql`](../dbt/models/raw_vault/links/link_customer_contract.sql), [`dbt/models/raw_vault/sats/sat_customer_details_crm_v1.sql`](../dbt/models/raw_vault/sats/sat_customer_details_crm_v1.sql), then the [vault model diagram](architecture-vault-model.drawio.svg).

- Five hubs hold business keys, four links hold relationships, satellites hold history. A satellite gets a new row only when its hashdiff changes.
- Staging keeps every source row; a blank key becomes a NULL hash key, and the hub skips it (test `assert_no_empty_business_key`).
- Loads are idempotent per load date. [`scripts/build_by_load_date.sh`](../scripts/build_by_load_date.sh) builds one date per run, and a rerun adds no rows.

## 3. Source change (75 s)

Open: [`docs/source-change.md`](source-change.md), then [`dbt/models/raw_vault/links/sal_customer.sql`](../dbt/models/raw_vault/links/sal_customer.sql) and [`dbt/models/business_vault/bv_customer_master.sql`](../dbt/models/business_vault/bv_customer_master.sql).

- From 2026-01-04 the data comes from Billing v2 and CRM v2, with new keys and renamed columns.
- v1 and v2 keys live in the same hubs. The same-as link `sal_customer` records which v2 key names which v1 key. No key is rewritten, and v1 satellites are closed, not dropped.
- `bv_customer_master` gives one key per business entity. The tables at the end of the doc show that mart totals equal the expected totals on every load date.

## 4. Migration (75 s)

Open: [`docs/migration.md`](migration.md), [`dbt/macros/compat/month_trunc.sql`](../dbt/macros/compat/month_trunc.sql), [`docs/cutover.md`](cutover.md).

- The models contain no `if target.type`. Where the platforms differ, a macro with `adapter.dispatch` holds the SQL. Example: `month_trunc` returns a `DATE` on both targets.
- `recon__table_stats` gives one row per table: row count, key checksums, measure sums. Run it on both targets and compare.
- Run `uv run python scripts/compare_recon.py data/recon/snowflake_dev.json data/recon/databricks_dev.json`. It prints `0 differences in 35 tables`.
- The cut-over plan has a parallel run, a go/no-go rule and a 14-day rollback window.

## 5. Airflow and CI (45 s)

Open: [`docs/img/airflow_graph.png`](img/airflow_graph.png), [`docs/airflow.md`](airflow.md), [`.github/workflows/ci.yml`](../.github/workflows/ci.yml), [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml).

- `vdwh_ingest` loads one date and emits the asset `vdwh/raw_landed` with that date. `vdwh_transform` runs on the asset and builds that date. Cosmos renders dbt models as tasks. The env var `DBT_TARGET` switches Snowflake to Databricks without a DAG change.
- Slim CI on a pull request builds `state:modified+` against a PR schema. It fetches the prod manifest from GitHub Pages.
- A push to `main` deploys to prod and publishes the dbt docs.

## 6. Honest close (15 s)

- This is a thin slice, not a platform. The data is synthetic and the volumes are small (2000 customers).
- The Databricks DAG run and the warehouse sizing comparison are still open; the Unity Catalog table quota of the free workspace is full. The roadmap in the README shows what is done and what is not.
