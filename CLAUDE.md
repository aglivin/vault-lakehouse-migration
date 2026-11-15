# CLAUDE.md

Public portfolio repo: Data Vault 2.0 with dbt Core on Snowflake, orchestrated by Airflow, CI/CD on GitHub Actions,
migrated to Databricks. Roadmap and scope: `README.md`.

## Authorship (hard rule)

- Every commit, tag, PR, review comment and deployment is made **as Andrei Glivinschi** (the local git user and the `gh` account `aglivin`).
- No AI attribution anywhere: no `Co-Authored-By: Claude`, no "Generated with Claude Code", no `noreply@anthropic.com`, no bot accounts.
- Never change `git config user.name` / `user.email`. Never pass `--author`.
- `.claude/settings.json` sets `attribution` to empty; keep it that way.
- CI job `attribution` fails the build if AI attribution appears in history.
- Deployments run from GitHub Actions with Andrei's secrets, or locally with Andrei's CLI logins. No service account named after an AI tool.

## Public repo hygiene

- No client names, client code, client schemas, rates or interview details. All data is synthetic.
- No secrets in files. Credentials live in `.env` (git-ignored) locally and in GitHub Actions secrets in CI.
- Never use the work Databricks profiles (`DEFAULT`, `PROD`, `OLD`) or the work Azure login. Personal profile only: `personal`.

## Stack and commands

- Python 3.12 via `uv`. Run tools with `uv run`.
- dbt project in `dbt/`, profiles in `dbt/profiles.yml` (env vars only):
  - `set -a; source .env; set +a`
  - `uv run dbt debug --project-dir dbt --profiles-dir dbt --target snowflake_dev`
  - `uv run dbt build --project-dir dbt --profiles-dir dbt --target databricks_dev`
- Snowflake CLI: `snow` (connection `personal` in `~/.snowflake/config.toml`, key-pair auth).
- Databricks CLI: always `--profile personal`.
- Airflow: Astro CLI in `airflow/` (`astro dev start`, needs Docker).
- Lint: `uv run sqlfluff lint dbt/models`.

## Working rules

- Commits: `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci). Small PRs, one logical step each.
- Work on a branch, open a PR with `gh pr create`, merge only when CI is green.
- No comments in code; names and small models carry the meaning.
- Every reported number (row counts, reconciliation totals, performance) must come from a query that is in the repo.
- Keep `README.md` roadmap checkboxes current when a step is done.
