#!/usr/bin/env bash
# Runs every k6 scenario against one seeded backend and keeps the results.
#
#   scripts/run_all.sh [ENV_FILE]            # default: .env.test (written by the seeder)
#
#   VUS=100 DURATION=10m scripts/run_all.sh .env.test.keycloak
#   SCENARIOS="jwks userinfo" scripts/run_all.sh
#   K6_FLAGS="--no-thresholds" scripts/run_all.sh
#
# Output goes to results/<label>-<timestamp>/ with one summary JSON and one
# log per scenario. Exit code is the number of scenarios that failed.
set -uo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

env_file="${1:-.env.test}"
if [[ ! -f "$env_file" ]]; then
  echo "No $env_file. Run the seeder first: uv run python scripts/seed_test_data.py" >&2
  exit 2
fi

# Values given on the command line win over the ones written in the env file.
cli_vus="${VUS:-}"
cli_duration="${DURATION:-}"

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

vus="${cli_vus:-${VUS:-50}}"
duration="${cli_duration:-${DURATION:-5m}}"
scenarios="${SCENARIOS:-token_client_credentials jwks userinfo token_password mixed_workload}"
k6_flags="${K6_FLAGS:-}"

label="$(basename "$env_file" | sed -E 's/^\.env\.test\.?//')"
label="${label:-run}"
out_dir="results/${label}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out_dir"

echo "Target:    $BASE_URL (realm $REALM)"
echo "Load:      $vus VUs for $duration per scenario"
echo "Scenarios: $scenarios"
echo "Results:   $out_dir"
echo

failed=0
declare -a report=()
for scenario in $scenarios; do
  script="k6/scenarios/${scenario}.js"
  if [[ ! -f "$script" ]]; then
    echo "Unknown scenario: $scenario" >&2
    failed=$((failed + 1))
    report+=("$scenario|missing")
    continue
  fi

  echo "=== $scenario"
  # shellcheck disable=SC2086
  if k6 run \
      --env VUS="$vus" --env DURATION="$duration" \
      --summary-mode=compact \
      --summary-export "$out_dir/${scenario}.summary.json" \
      $k6_flags \
      "$script" 2>&1 | tee "$out_dir/${scenario}.log"; then
    report+=("$scenario|pass")
  else
    failed=$((failed + 1))
    report+=("$scenario|FAIL")
  fi
  echo
done

echo "=== Summary ($out_dir)"
printf '%-28s %s\n' "Scenario" "Result"
for line in "${report[@]}"; do
  printf '%-28s %s\n' "${line%%|*}" "${line##*|}"
done

exit "$failed"
