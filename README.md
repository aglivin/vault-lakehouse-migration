# vault-lakehouse-migration

[![ci](https://github.com/aglivin/vault-lakehouse-migration/actions/workflows/ci.yml/badge.svg)](https://github.com/aglivin/vault-lakehouse-migration/actions/workflows/ci.yml)
[![deploy](https://github.com/aglivin/vault-lakehouse-migration/actions/workflows/deploy.yml/badge.svg)](https://github.com/aglivin/vault-lakehouse-migration/actions/workflows/deploy.yml)

A Data Vault 2.0 warehouse for a fictional energy utility, built with dbt Core on Snowflake, orchestrated by Airflow, deployed by GitHub Actions and migrated to Databricks with the same dbt project.
All data is synthetic. See the [dbt docs](https://aglivin.github.io/vault-lakehouse-migration/).

## Architecture

```mermaid
flowchart LR
    subgraph AF["Airflow (Astro CLI, Cosmos)"]
        ING["DAG vdwh_ingest"] --> AST(["Asset vdwh/raw_landed"]) --> TRF["DAG vdwh_transform<br/>staging, raw_vault, business_vault, marts"]
    end
    GEN["Generator<br/>Billing v1/v2, CRM v1/v2, key_map"]
    subgraph SF["Snowflake lane (snowflake_dev)"]
        direction LR
        SL["stage @VDWH_DEV.RAW.LANDING"] --> SR["raw.system__entity"] --> SS["staging"] --> SV["raw vault"] --> SB["business vault"] --> SM["marts"]
    end
    subgraph DB["Databricks lane (databricks_dev)"]
        direction LR
        DL["volume /Volumes/vdwh_dev/raw/landing"] --> DR["raw.system__entity"] --> DS["staging"] --> DV["raw vault"] --> DB2["business vault"] --> DM["marts"]
    end
    REC["recon__table_stats<br/>scripts/compare_recon.py"]
    CON["Consumers: billing, sales, tax, call centre"]
    GEN --> SL
    GEN --> DL
    SM --> CON
    DM --> CON
    SM -.-> REC
    DM -.-> REC
    AF -.-> SF
    subgraph GH["GitHub Actions"]
        PR["PR: checks, dbt-slim, no-ai-attribution"]
        MAIN["main: deploy, dbt docs"]
    end
```

Full diagram, 3 pages: [platform](docs/architecture-platform.drawio.svg), [vault model](docs/architecture-vault-model.drawio.svg), [source change and migration timeline](docs/architecture-change-migration.drawio.svg). Editable source: [`docs/architecture.drawio`](docs/architecture.drawio).

## What to look at in 5 minutes

1. **Vault model**: [`dbt/models/raw_vault`](dbt/models/raw_vault) and the [vault model diagram](docs/architecture-vault-model.drawio.svg).
2. **Source change** (Billing and CRM replaced mid-project, marts unchanged): [`docs/source-change.md`](docs/source-change.md).
3. **Migration** Snowflake to Databricks: [`docs/migration.md`](docs/migration.md) and [`docs/cutover.md`](docs/cutover.md).
4. **Airflow DAG**: [`docs/img/airflow_graph.png`](docs/img/airflow_graph.png). The screenshot lands with the Airflow PR.
5. **CI**: [runs of `ci.yml`](https://github.com/aglivin/vault-lakehouse-migration/actions/workflows/ci.yml), lint and slim build on every PR.

A timed script for a live demo: [`docs/walkthrough.md`](docs/walkthrough.md). How AI tooling was used: [`docs/ai-notes.md`](docs/ai-notes.md).

## Results

Hub, link and mart numbers measured on `databricks_dev` after load date 2026-01-05. Every number comes from a query or script in the repo.

| What | Result | Source |
|---|---|---|
| Hubs | customer 4204, contract 4153, meter 4204, invoice 7612, tariff 12 | `dbt/analyses/vault_row_counts.sql` |
| Links | customer-contract 4153, contract-meter 4153, contract-invoice 7612, invoice-tariff 7612 | `dbt/analyses/vault_row_counts.sql` |
| Mart vs expected totals | 4421 invoices, net total 461626.22 on both sides | `dbt/analyses/mart_vs_expected_totals.sql` |
| Snowflake vs Databricks | 0 differences in 35 tables | `scripts/compare_recon.py` on `data/recon/*.json` |
| dbt tests | 139 | `uv run dbt ls --project-dir dbt --profiles-dir dbt --resource-type test \| wc -l` |

## Quickstart

Needs Python 3.12 with `uv`, the Snowflake CLI connection `personal` and the Databricks CLI profile `personal` (the upload script uses them), and a Snowflake or Databricks account.

```bash
git clone https://github.com/aglivin/vault-lakehouse-migration.git && cd vault-lakehouse-migration
uv sync
cp .env.example .env
set -a; source .env; set +a
uv run dbt deps --project-dir dbt --profiles-dir dbt --target snowflake_dev
uv run python -m data_generator
uv run dbt run-operation create_raw_tables --project-dir dbt --profiles-dir dbt --target snowflake_dev
for d in 2026-01-0{1..5}; do uv run python -m scripts.upload_landing --target snowflake --load-date $d && uv run dbt run-operation load_raw --args "{load_date: $d}" --project-dir dbt --profiles-dir dbt --target snowflake_dev; done
scripts/build_by_load_date.sh --project-dir dbt --profiles-dir dbt --target snowflake_dev
```

Fill in `.env` after the copy. `dbt/profiles.yml` reads env vars only. For Databricks use `--target databricks_dev` and `--target databricks` in the upload script. The build script runs `dbt build` once per load date.

## Roadmap

### Phase 0 — Accounts and local setup

- [x] Snowflake trial account (30 days), warehouse `XS`, role `TRANSFORMER`, database `VDWH_DEV`
- [x] Databricks Free Edition workspace (personal, not a client workspace), Unity Catalog `vdwh_dev`
- [x] Docker Desktop running; Astro CLI installed
- [x] `uv` project with `dbt-core`, `dbt-snowflake`, `dbt-databricks`, `sqlfluff`, `pre-commit`
- [x] Snowflake CLI (`snow`) installed
- [x] `profiles.yml` with targets `snowflake_dev` and `databricks_dev`; secrets only in env vars
- [x] GitHub Actions secrets for Snowflake and Databricks

### Phase 1 — Synthetic sources

- [x] Python generator for Billing v1, CRM v1 (Faker, fixed seed, default 2000 customers, scalable with `--customers`)
- [x] Billing v2, CRM v2 with new keys, renamed columns and a key-mapping table
- [x] Daily incremental loads with inserts, updates and deletes (for CDC behaviour)
- [x] Load to Snowflake stage and to a Databricks volume

### Phase 2 — dbt on Snowflake: Data Vault 2.0

- [x] Staging models with hash keys and hashdiffs (`automate_dv.stage`)
- [x] Hubs: customer, contract, meter, invoice, tariff
- [x] Links: customer–contract, contract–meter, contract–invoice, invoice–tariff
- [x] Satellites with history; one multi-active satellite (customer phone numbers)
- [x] Effectivity satellite for customer–contract
- [x] Status-tracking satellite (CDC deletes)
- [x] Incremental loads tested over 3 load dates
- [x] dbt tests: unique and not-null keys, relationships, freshness, row-count reconciliation to source

### Phase 3 — Source system change (v1 → v2)

- [x] Add v2 staging models next to v1
- [x] Same-as link between v1 and v2 business keys
- [x] New satellites for v2 attributes; old satellites closed, not dropped
- [x] Marts unchanged for consumers; reconciliation proves equal totals before and after the switch
- [x] Write-up: what changed in each layer and why ([docs/source-change.md](docs/source-change.md))

### Phase 4 — Business vault and marts

- [x] PIT tables and bridge tables for query performance
- [x] Star schema: `fct_invoice_line`, `fct_payment`, `dim_customer` (SCD2), `dim_contract`, `dim_tariff`, `dim_date`
- [x] Data products: billing, sales, tax, call centre
- [x] dbt docs and exposures; semantic definitions for the main metrics
- [x] Model contracts and versions on public marts

### Phase 5 — Airflow

- [x] Astro project, local Airflow in Docker
- [x] DAG: ingest → `dbt build` per layer with Cosmos (one task per model, tests included)
- [ ] Sensors / dataset-driven scheduling between ingest and transform
- [ ] Retries, SLAs, alerting on failure
- [ ] Backfill of a past load date (load rule and replay: [docs/loading.md](docs/loading.md))

### Phase 6 — GitHub Actions CI/CD

- [x] PR workflow: `sqlfluff lint`, `dbt build --select state:modified+` (slim CI) against a PR schema
- [x] Main workflow: deploy to `prod` target, generate and publish dbt docs to GitHub Pages ([dbt docs](https://aglivin.github.io/vault-lakehouse-migration/))
- [x] Secrets in GitHub Actions secrets, no secrets in YAML; the deploy job runs in environment `prod`, limited to protected branches. In this demo CI and prod share one Snowflake account and credentials; prod is isolated by schema prefix
- [x] Branch protection on `main`: required green build (`checks`, `no-ai-attribution`, branch up to date); 1 approval in team mode (not enforced in this single-author repo)
- [x] Attribution check: build fails on AI co-author trailers

### Phase 7 — Migration Snowflake → Databricks

- [x] Inventory of Snowflake-specific SQL (`QUALIFY`, `VARIANT`, `FLATTEN`, time travel, `MERGE` behaviour, hash functions) ([docs/migration.md](docs/migration.md))
- [x] Cross-database macros (`dbt.dispatch`) so the same models run on both targets
- [x] Hash-key compatibility check: identical keys on both platforms
- [x] Run the full project on `databricks_dev` (Delta tables, Unity Catalog)
- [x] Data reconciliation job: row counts, sums and hash comparison per table, Snowflake vs Databricks
- [ ] Airflow DAG switched to the Databricks target with no DAG logic change
- [x] Cut-over plan and rollback plan

### Phase 8 — Performance and cost

- [x] Snowflake: clustering keys, query profile of the slowest model ([performance.md](docs/performance.md))
- [x] Databricks: Liquid Clustering and `OPTIMIZE` measured on a serverless Photon warehouse
- [ ] Warehouse sizing comparison on both platforms (only X-Small and 2X-Small measured)
- [x] Incremental strategies compared (`merge`, `insert_overwrite`, `delete+insert`, `microbatch`)
- [x] Before/after numbers in a short table

### Phase 9 — Show and tell

- [x] Architecture diagram
- [x] 5-minute walkthrough script: business problem → vault → change of source → migration → CI/CD
- [x] Short notes on how Claude Code was used, and where it was wrong

## Repository layout

```
data_generator/   synthetic source generator (Billing v1/v2, CRM v1/v2)
dbt/              dbt project: staging, raw_vault, business_vault, marts, recon
scripts/          landing upload, per-date build, Snowflake vs Databricks comparison
.github/workflows CI, deploy, attribution check
docs/             diagram, walkthrough, source change, migration, cut-over, AI notes
```

Work in progress. Unticked boxes are not done.
