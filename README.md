# vault-lakehouse-migration

An end-to-end Data Vault 2.0 warehouse for a fictional energy utility, built with **dbt Core** on **Snowflake**,
orchestrated by **Airflow**, deployed through **GitHub Actions**, and then migrated to **Databricks** with the same dbt project.

The repo has two goals:

1. Close my hands-on gaps in the target stack.
2. Show working, reviewable code for each claim on my CV.

All data is synthetic. No client code, schemas or data are used.

## Target stack

| Area | Tool |
|---|---|
| Warehouse (current) | Snowflake |
| Warehouse (target) | Databricks (Unity Catalog, SQL Warehouse) |
| Transformation | dbt Core, `automate_dv` (Data Vault 2.0 macros), `dbt_utils`, `dbt_expectations` |
| Orchestration | Apache Airflow (Astro CLI, `astronomer-cosmos` for dbt) |
| CI/CD | GitHub Actions |
| Language | SQL, Python |
| Quality | dbt tests, `sqlfluff`, `pre-commit` |
| AI tooling | Claude Code |

## Business scenario

A utility sells electricity and gas to residential customers. Data comes from two operational systems:

- **Billing** (contracts, meter readings, invoices, payments, tariffs, tax lines)
- **CRM** (customers, addresses, campaigns, call-centre contacts)

Mid-project, both systems are **replaced** (Billing v1 → v2, CRM v1 → v2) with new keys and new structures.
The Data Vault must absorb the change with no break in history and no change for the consumers.

Business data products on top:

- **Billing**: invoiced revenue per tariff and month, open receivables
- **Sales / Commercial steering**: new contracts, churn, price-adjustment impact
- **Tax**: VAT and energy-tax lines per invoice
- **Call centre**: contacts per customer, first-contact resolution

## Architecture

```
sources (CSV / Parquet, synthetic)
   │
   ▼
staging        dbt views: rename, cast, hash keys, hashdiffs, load metadata
   │
   ▼
raw vault      hubs, links, satellites (automate_dv), multi-active and effectivity satellites
   │
   ▼
business vault PIT tables, bridge tables, computed satellites, same-as links (v1 ↔ v2 keys)
   │
   ▼
marts          star schemas and data products (billing, sales, tax, call centre)
```

## Roadmap

### Phase 0 — Accounts and local setup

- [x] Snowflake trial account (30 days), warehouse `XS`, role `TRANSFORMER`, database `VDWH_DEV`
- [x] Databricks Free Edition workspace (personal, not a client workspace), Unity Catalog `vdwh_dev`
- [x] Docker Desktop running; Astro CLI installed
- [x] `uv` project with `dbt-core`, `dbt-snowflake`, `dbt-databricks`, `sqlfluff`, `pre-commit`
- [x] Snowflake CLI (`snow`) installed
- [x] `profiles.yml` with targets `snowflake_dev` and `databricks_dev`; secrets only in env vars
- [ ] GitHub Actions secrets for Snowflake and Databricks

### Phase 1 — Synthetic sources

- [x] Python generator for Billing v1, CRM v1 (Faker, fixed seed, default 2000 customers, scalable with `--customers`)
- [ ] Billing v2, CRM v2 with new keys, renamed columns and a key-mapping table
- [x] Daily incremental loads with inserts, updates and deletes (for CDC behaviour)
- [x] Load to Snowflake stage and to a Databricks volume

### Phase 2 — dbt on Snowflake: Data Vault 2.0

- [ ] Staging models with hash keys and hashdiffs (`automate_dv.stage`)
- [x] Hubs: customer, contract, meter, invoice, tariff
- [ ] Links: customer–contract, contract–meter, contract–invoice, invoice–tariff
- [ ] Satellites with history; one multi-active satellite (customer phone numbers)
- [ ] Effectivity satellite for customer–contract
- [ ] Record-tracking satellite for deletes
- [ ] Incremental loads tested over 3 load dates
- [ ] dbt tests: unique and not-null keys, relationships, freshness, row-count reconciliation to source

### Phase 3 — Source system change (v1 → v2)

- [ ] Add v2 staging models next to v1
- [ ] Same-as link between v1 and v2 business keys
- [ ] New satellites for v2 attributes; old satellites closed, not dropped
- [ ] Marts unchanged for consumers; reconciliation proves equal totals before and after the switch
- [ ] Write-up: what changed in each layer and why

### Phase 4 — Business vault and marts

- [ ] PIT tables and bridge tables for query performance
- [ ] Star schema: `fct_invoice_line`, `fct_payment`, `dim_customer` (SCD2), `dim_contract`, `dim_tariff`, `dim_date`
- [ ] Data products: billing, sales, tax, call centre
- [ ] dbt docs and exposures; semantic definitions for the main metrics
- [ ] Model contracts and versions on public marts

### Phase 5 — Airflow

- [ ] Astro project, local Airflow in Docker
- [ ] DAG: ingest → `dbt build` per layer with Cosmos (one task per model, tests included)
- [ ] Sensors / dataset-driven scheduling between ingest and transform
- [ ] Retries, SLAs, alerting on failure
- [ ] Backfill of a past load date

### Phase 6 — GitHub Actions CI/CD

- [ ] PR workflow: `sqlfluff lint`, `dbt build --select state:modified+` (slim CI) against a PR schema
- [ ] Main workflow: deploy to `prod` target, generate and publish dbt docs to GitHub Pages
- [ ] Secrets in GitHub Actions secrets and environments; no secrets in YAML
- [ ] Branch protection: required review, required green build
- [x] Attribution check: build fails on AI co-author trailers

### Phase 7 — Migration Snowflake → Databricks

- [ ] Inventory of Snowflake-specific SQL (`QUALIFY`, `VARIANT`, `FLATTEN`, time travel, `MERGE` behaviour, hash functions)
- [ ] Cross-database macros (`dbt.dispatch`) so the same models run on both targets
- [ ] Hash-key compatibility check: identical keys on both platforms
- [ ] Run the full project on `databricks_dev` (Delta tables, Unity Catalog)
- [ ] Data reconciliation job: row counts, sums and hash comparison per table, Snowflake vs Databricks
- [ ] Airflow DAG switched to the Databricks target with no DAG logic change
- [ ] Cut-over plan and rollback plan

### Phase 8 — Performance and cost

- [ ] Snowflake: warehouse sizing, clustering keys, query profile of the slowest model
- [ ] Databricks: Liquid Clustering, `OPTIMIZE`, Photon, serverless SQL warehouse sizing
- [ ] Incremental strategies compared (`merge`, `insert_overwrite`, `microbatch`)
- [ ] Before/after numbers in a short table

### Phase 9 — Show and tell

- [ ] Architecture diagram
- [ ] 5-minute walkthrough script: business problem → vault → change of source → migration → CI/CD
- [ ] Short notes on how Claude Code was used, and where it was wrong

## Interview topics to prepare

- Data Vault 2.0: hubs, links, satellites; business vs raw vault; PIT and bridge; hash keys vs sequence keys; when *not* to use Data Vault
- Kimball vs Inmon vs Data Vault; SCD types
- dbt: materializations, incremental strategies, snapshots, macros, packages, tests, contracts, slim CI, state, `dispatch`
- Snowflake: virtual warehouses, micro-partitions, clustering, time travel, zero-copy clone, streams and tasks, RBAC
- Databricks: Delta Lake, Unity Catalog, Liquid Clustering, Photon, serverless, DLT vs dbt
- Migration: dialect differences, validation strategy, parallel run, cut-over
- Airflow: scheduler, executors, idempotent DAGs, backfill, datasets, Cosmos
- CI/CD: GitHub Actions workflows, environments, approvals, secrets (and how this maps to Azure DevOps pipelines)
- SQL: window functions, gaps-and-islands, deduplication, slowly changing history queries

## Repository layout (planned)

```
data_generator/   Python synthetic source generator
dbt/              dbt project (staging, raw_vault, business_vault, marts)
airflow/          Astro project and DAGs
.github/workflows GitHub Actions
docs/             diagrams and write-ups
```

## Status

Work in progress.
