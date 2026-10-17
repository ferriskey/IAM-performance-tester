#!/usr/bin/env bash
# Polls the OIDC discovery document of the admin realm until the server answers.
#
#   scripts/wait_for_iam.sh [BASE_URL] [ADMIN_REALM]
#
# Falls back to the BASE_URL / ADMIN_REALM environment variables, then to
# http://localhost:8080 and "master". WAIT_TIMEOUT (seconds) defaults to 180.
set -euo pipefail

base_url="${1:-${BASE_URL:-http://localhost:8080}}"
realm="${2:-${ADMIN_REALM:-master}}"
timeout="${WAIT_TIMEOUT:-180}"
url="${base_url%/}/realms/${realm}/.well-known/openid-configuration"

for ((i = 0; i < timeout; i++)); do
  if curl -fsS -o /dev/null "$url"; then
    echo "IAM server ready at ${base_url}"
    exit 0
  fi
  sleep 1
done

echo "Timed out after ${timeout}s waiting for ${url}" >&2
exit 1
