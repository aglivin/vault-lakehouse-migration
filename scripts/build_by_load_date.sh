#!/usr/bin/env bash
set -euo pipefail

load_dates=(2026-01-01 2026-01-02 2026-01-03 2026-01-04 2026-01-05)
last=$(( ${#load_dates[@]} - 1 ))

if [ "${1:-}" = --last-date ]; then
  echo "${load_dates[$last]}"
  exit 0
fi

for i in "${!load_dates[@]}"; do
  flags=()
  [ "$i" -eq 0 ] && flags+=(--full-refresh)
  [ "$i" -lt "$last" ] && flags+=(--exclude-resource-type test)
  echo "::group::load_date ${load_dates[$i]}"
  uv run dbt build "$@" ${flags[@]+"${flags[@]}"} --vars "{load_date: '${load_dates[$i]}'}"
  echo "::endgroup::"
done
