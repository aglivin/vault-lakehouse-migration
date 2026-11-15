# How Claude Code was used

Claude Code wrote most of the first drafts in this repo. I reviewed every diff before merge. The cases below come from this project's history.

## Method

- Small pull requests, at most 500 changed code lines, one logical step each.
- Every number in the docs comes from a query or script in the repo.
- A separate reviewer model reviews every task before it is merged.
- I read every diff myself. I author, commit and merge as myself.
- There is no AI attribution in commits, PR bodies or comments. CI job `attribution` fails the build if it finds any.

## Where it helped

1. **Synthetic generator.** It produced a deterministic world with CDC operations (insert, update, delete) and a delete followed by a re-create. This was needed to test the status-tracking satellite (PR 4).
2. **Cross-database macros.** It found that `date_trunc('month', ...)` returns `DATE` on Snowflake and `TIMESTAMP` on Databricks. It wrote the `month_trunc` dispatch macro (PR 13).
3. **Reconciliation design.** It proposed comparing the upper-case hex of every key, so Snowflake `BINARY` keys and Databricks `STRING` keys compare by value without changing the hashing (PR 18).
4. **Multi-active satellite.** It saw that raw deltas hold only changed phones, while a multi-active satellite needs the full set per load. It wrote the staging model that rebuilds the active set (PR 8).
5. **CI workflows.** It wrote the slim CI job (`state:modified+` with defer against the prod manifest from GitHub Pages) and the deploy job (PR 15, PR 17).

## Where it was wrong

Reviews caught each case before merge.

1. **VAT in the net amount.** Generator v1 first put VAT into `net_amount`. The review ruled that VAT belongs only on the VAT line.
2. **Silent row loss.** A staging filter on blank keys dropped rows without a trace. I removed it. Hubs now reject NULL keys.
3. **A claim before the proof.** A public doc stated a cross-platform hash comparison before it existed (`docs/migration.md`). I corrected it, and the comparison came later with `recon__table_stats`.

Other findings, all fixed before merge or in flight:

- `automate_dv` satellites broke on multi-date batches (4 unique-combination test errors). The vault is now built one load date per run.
- The status-tracking satellite was not idempotent on reruns. It now anti-joins on existing rows.
- The v2 initial load produced same-day CDC duplicates. It now keeps one end-of-day row per key.
- Payment dedup across v1 and v2 could merge equal payments of the same source. In review of the star-schema PR, `dim_contract.status` mixed `active` and `ACTIVE` after the source change. Both are being fixed.
