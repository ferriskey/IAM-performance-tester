#!/usr/bin/env bash
# Prints the current memory usage of a compose service's container in KiB.
#
#   scripts/container_memory_kb.sh <compose-service>
#
# Relies on COMPOSE_PROFILES (or --profile) so compose can resolve the service.
set -euo pipefail

service="$1"
cid="$(docker compose ps -q "$service")"
if [[ -z "$cid" ]]; then
  echo "No running container for service '$service'" >&2
  exit 1
fi

usage="$(docker stats --no-stream --format '{{.MemUsage}}' "$cid" | awk '{print $1}')"
awk -v u="$usage" 'BEGIN {
  n = u; sub(/[A-Za-z]+$/, "", n)
  unit = u; sub(/^[0-9.]+/, "", unit)
  f["B"] = 1 / 1024; f["KiB"] = 1; f["kB"] = 1000 / 1024
  f["MiB"] = 1024; f["MB"] = 1000000 / 1024
  f["GiB"] = 1048576; f["GB"] = 1000000000 / 1024
  if (!(unit in f)) { print "Unknown unit: " unit > "/dev/stderr"; exit 1 }
  printf "%d\n", n * f[unit]
}'
