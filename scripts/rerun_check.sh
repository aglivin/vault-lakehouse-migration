#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
last=$("$here/build_by_load_date.sh" --last-date)
read -ra rerun_dates <<< "${RERUN_DATES:-2026-01-04 $last 2026-01-02}"

vault_row_counts() {
  uv run dbt show "$@" --select vault_row_counts --limit 100 --vars "{load_date: '$last'}" | grep '^|' | sort
}

"$here/build_by_load_date.sh" "$@"
before=$(vault_row_counts "$@")

for load_date in "${rerun_dates[@]}"; do
  echo "::group::rerun load_date $load_date"
  uv run dbt build "$@" --exclude-resource-type test --vars "{load_date: '$load_date'}"
  echo "::endgroup::"
done

after=$(vault_row_counts "$@")
echo "$after"
status=0
uv run dbt test "$@" --select raw_vault --vars "{load_date: '$last'}" || status=1
diff <(echo "$before") <(echo "$after") || status=1
exit "$status"
