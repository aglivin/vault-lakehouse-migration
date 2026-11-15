# Source system change: Billing v1 / CRM v1 to Billing v2 / CRM v2

Until 2026-01-03, data comes from Billing v1 and CRM v1. From 2026-01-04 (dbt var `cutover_date`), it comes from Billing v2 and CRM v2. The new systems use new business keys and renamed columns. Each system sends a `key_map` table that maps a v1 key to its v2 key. The vault absorbs the change without a break in history, and the marts look the same to their consumers.

## What changed in each layer

| Layer | What changed | Why |
|---|---|---|
| Raw | New tables `crm_v2__*` and `billing_v2__*`, loaded from 2026-01-04. v1 tables keep their history and get no new rows. | Raw is a copy of the source. A new source gets new tables. |
| Staging | New `stg_crm_v2__*` and `stg_billing_v2__*` models. They hash the v2 columns and rename only the business key to the hub's key column (for example `account_uuid` to `customer_no`). | Hubs and links can union v1 and v2 staging. The v2 attribute names stay as they are. |
| Hubs | Each hub has a second source model, the v2 staging. v1 keys and v2 keys live in the same hub. | They are the same business concept. The key formats never collide (customer number vs uuid, `K…` vs `AGR-…`, `INV…` vs `DOC-…`). |
| Links | The customer-contract, contract-meter, contract-invoice and invoice-tariff links also read v2 staging. | A v2 relationship is the same relationship, so it goes into the same link. |
| Same-as links | New `sal_customer`, `sal_contract`, `sal_invoice`, `sal_tariff` and `sal_meter`, one row per `key_map` row. Each row has two keys into the same hub: the v1 key and the v2 key. | They record that two keys name one business entity. Hub keys are never rewritten. |
| Satellites | New `*_v2` satellites with the v2 column names. v1 satellites are closed, not dropped. `sts_contract` also reads v2 agreements, so v2 deletes are tracked. | The raw vault keeps source semantics. The v1 history stays. The test `assert_v1_satellites_closed_after_cutover` proves that v1 satellites get no rows after the cutover. |
| Business vault | New `bv_<entity>_master` models, one row per hub key. A v2 key with a same-as row gets the v1 key as its master. Every other key is its own master. | Consumers need one key per business entity. A v1 key without a pair and a v2-only key both survive (test `assert_unmapped_keys_survive`). |
| Marts | `fct_invoice_line` and `dim_tariff` read v1 and v2 satellites through the master keys and map v2 column names to the mart columns. Columns and grain do not change. | A re-issued v2 invoice replaces its v1 invoice and is not counted twice. `billing__revenue_by_tariff_month` does not change. |

## Numbers

Expected totals (seed `expected_totals`) vs mart totals. I took them after the whole-project build for each load date on snowflake_dev, with `dbt/analyses/mart_vs_expected_totals.sql`:

| Load date | Expected invoices | Mart invoices | Expected net total | Mart net total |
|---|---|---|---|---|
| 2026-01-01 | 2000 | 2000 | 209018.23 | 209018.23 |
| 2026-01-02 | 2631 | 2631 | 275337.96 | 275337.96 |
| 2026-01-03 | 3256 | 3256 | 343273.21 | 343273.21 |
| 2026-01-04 | 3845 | 3845 | 404273.55 | 404273.55 |
| 2026-01-05 | 4421 | 4421 | 461626.22 | 461626.22 |

Same-as rows vs `key_map` after 2026-01-05, from `dbt/analyses/source_change_counts.sql`. Business entities = hub rows − same-as rows.

| Entity | key_map rows | Same-as rows | v2 keys missing in hub | v1 keys | v2 keys | v2 keys without v1 | Hub rows | Business entities |
|---|---|---|---|---|---|---|---|---|
| customer | 2081 | 2081 | 0 | 2081 | 2123 | 42 | 4204 | 2123 |
| contract | 2030 | 2030 | 0 | 2081 | 2072 | 42 | 4153 | 2123 |
| invoice | 3191 | 3191 | 0 | 3256 | 4356 | 1165 | 7612 | 4421 |
| tariff | 6 | 6 | 0 | 6 | 6 | 0 | 12 | 6 |
| meter | 2081 | 2081 | 0 | 2081 | 2123 | 42 | 4204 | 2123 |

The same query shows that the last load of each v1 satellite is before the cutover: 2026-01-03, and 2026-01-01 for the tariff satellite.

`dbt/analyses/mart_columns.sql` gives the same column names, order and types for `fct_invoice_line` and `billing__revenue_by_tariff_month` before the switch (2026-01-03) and after it (2026-01-05).

## Known limitations and follow-ups

- v2 phones (`account_phones`) and interactions are loaded to raw only. They have no staging and no satellites yet.
- Payments: v1 `payments` are staged in `stg_billing_v1__payments` and loaded to `nhl_payment_billing_v1`. v2 `settlements` are staged in `stg_billing_v2__settlements` and loaded to `nhl_payment_billing_v2`. The v2 feed repeats the v1 payments of migrated invoices, so `fct_payment` pairs them. It numbers the rows inside each source by (master invoice, payment date, amount) and joins v1 to v2 on those three values plus the number. A v1 row pairs with at most one v2 row, so two equal instalments of one invoice stay two payments. `dbt/analyses/payment_dedup_counts.sql` gives the counts, and `assert_fct_payment_counts_each_payment_once` checks them.
- `eff_sat_customer_contract` reads v1 contracts only. Its v2 feed is a follow-up.
- The phone set is empty for v2 customers. `sat_customer_phone_ma` stops at 2026-01-03, so a migrated customer keeps the last v1 phone set, and a v2-only customer has none.
