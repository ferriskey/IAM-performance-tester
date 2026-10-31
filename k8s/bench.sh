#!/usr/bin/env bash
# FerrisKey vs Keycloak benchmark on Kubernetes. See k8s/README.md.
#
#   ./bench.sh platform                 label/taint nodes, install CNPG + kube-prometheus-stack
#   ./bench.sh deploy                   Postgres x2, FerrisKey (chart), Keycloak
#   ./bench.sh seed [system...]         realm, client, users through the admin API
#   ./bench.sh run [system...]          rate ladder per scenario, results in results/k8s/<run>
#   ./bench.sh rescan <run-dir>         recompute CPU/memory of a run from Prometheus
#   ./bench.sh report <run-dir>         rebuild REPORT.md from the JSON results
#   ./bench.sh down                     delete the iam-bench namespace (platform stays)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"

CTX="${KUBE_CONTEXT:-$(kubectl config current-context)}"
NS=iam-bench
FERRISKEY_TAG="${FERRISKEY_TAG:-sha-a5d4df3}"
FERRISKEY_CHART_VERSION="${FERRISKEY_CHART_VERSION:-0.9.0}"
KEYCLOAK_IMAGE="${KEYCLOAK_IMAGE:-quay.io/keycloak/keycloak:26.8.1}"
CNPG_CHART_VERSION="${CNPG_CHART_VERSION:-0.29.1}"
KPS_CHART_VERSION="${KPS_CHART_VERSION:-92.11.0}"
NODE_LOADGEN="${NODE_LOADGEN:-}"
NODE_SUT="${NODE_SUT:-}"
NODE_DB="${NODE_DB:-}"

USER_COUNT="${USER_COUNT:-1000}"
# Resources of the system under test. An empty *_CPU_LIMIT means no CPU limit.
FERRISKEY_REPLICAS="${FERRISKEY_REPLICAS:-1}"
FERRISKEY_CPU="${FERRISKEY_CPU:-2}"
FERRISKEY_CPU_LIMIT="${FERRISKEY_CPU_LIMIT-2}"
FERRISKEY_MEMORY="${FERRISKEY_MEMORY:-1536Mi}"
KEYCLOAK_CPU="${KEYCLOAK_CPU:-2}"
KEYCLOAK_CPU_LIMIT="${KEYCLOAK_CPU_LIMIT-2}"
KEYCLOAK_MEMORY="${KEYCLOAK_MEMORY:-1536Mi}"
# Extra JVM options, e.g. -XX:ActiveProcessorCount=3 when Keycloak has no CPU limit.
KEYCLOAK_JAVA_OPTS="${KEYCLOAK_JAVA_OPTS:-}"
# Same spec for both databases. FerrisKey opens up to 100 connections per replica.
DB_MEMORY="${DB_MEMORY:-1280Mi}"
DB_MAX_CONNECTIONS="${DB_MAX_CONNECTIONS:-200}"
NODE_TYPE="${NODE_TYPE:-Scaleway DEV1-M (3 vCPU, 4 GB)}"
# Workaround for the FerrisKey per-IP /token cap (see README): FerrisKey trusts X-Forwarded-For
# and k6 sends one address per VU. Both default to off.
FERRISKEY_TRUST_XFF="${FERRISKEY_TRUST_XFF:-false}"
SPREAD_IPS="${SPREAD_IPS:-false}"
RUN_LABEL="${RUN_LABEL:-}"
SCENARIOS="${SCENARIOS:-client_credentials password refresh introspect userinfo jwks}"
DURATION="${DURATION:-60}"
WARMUP="${WARMUP:-15}"
COOLDOWN="${COOLDOWN:-10}"
# true: measure every step of the ladder, even after saturation.
FULL_LADDER="${FULL_LADDER:-false}"
RATES_client_credentials="${RATES_client_credentials:-50 100 200 400 800 1600}"
RATES_password="${RATES_password:-10 20 40 80 160}"
RATES_refresh="${RATES_refresh:-50 100 200 400 800 1600}"
RATES_introspect="${RATES_introspect:-50 100 200 400 800 1600 3200}"
RATES_userinfo="${RATES_userinfo:-50 100 200 400 800 1600 3200}"
RATES_jwks="${RATES_jwks:-100 200 400 800 1600 3200}"

k() { kubectl --context "$CTX" "$@"; }
h() { helm --kube-context "$CTX" "$@"; }
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

check_context() {
  # grep -q closes the pipe early: under pipefail kubectl then dies on SIGPIPE and the test flakes.
  grep -qx "$CTX" <<<"$(kubectl config get-contexts -o name)" || die "context $CTX not found"
  log "context $CTX"
}

cmd_platform() {
  [ -n "$NODE_LOADGEN" ] && [ -n "$NODE_SUT" ] && [ -n "$NODE_DB" ] ||
    { echo "set NODE_LOADGEN, NODE_SUT and NODE_DB to the names of 3 nodes" >&2; exit 1; }
  log "labelling and tainting nodes"
  k label node "$NODE_LOADGEN" bench.ferriskey.rs/role=loadgen --overwrite
  k label node "$NODE_SUT" bench.ferriskey.rs/role=sut --overwrite
  k label node "$NODE_DB" bench.ferriskey.rs/role=db --overwrite
  k taint node "$NODE_SUT" bench.ferriskey.rs/role=sut:NoSchedule --overwrite
  k taint node "$NODE_DB" bench.ferriskey.rs/role=db:NoSchedule --overwrite

  helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
  helm repo update cnpg prometheus-community >/dev/null

  log "CloudNativePG $CNPG_CHART_VERSION"
  h upgrade --install cnpg cnpg/cloudnative-pg --version "$CNPG_CHART_VERSION" \
    -n cnpg-system --create-namespace -f "$HERE/platform/cnpg-values.yaml" --wait

  log "kube-prometheus-stack $KPS_CHART_VERSION"
  h upgrade --install kps prometheus-community/kube-prometheus-stack --version "$KPS_CHART_VERSION" \
    -n monitoring --create-namespace -f "$HERE/platform/kps-values.yaml" --wait --timeout 15m

  log "Grafana dashboard"
  k create configmap -n monitoring iam-bench-dashboard --from-file="$HERE/dashboards/iam-bench.json" \
    --dry-run=client -o yaml | k label --local -f - grafana_dashboard=1 -o yaml | k apply -f -
}

cmd_deploy() {
  log "Postgres"
  k apply -f "$HERE/postgres/namespace.yaml"
  k apply -f "$HERE/postgres/podmonitor.yaml"
  for db in ferriskey-db keycloak-db; do
    sed -e "s/DB_MEMORY/$DB_MEMORY/g" -e "s/DB_MAX_CONNECTIONS/$DB_MAX_CONNECTIONS/" "$HERE/postgres/$db.yaml" | k apply -f -
  done
  # The db node holds one database at a time: Keycloak's starts hibernated, `activate` wakes it.
  k annotate -n "$NS" cluster/keycloak-db cnpg.io/hibernation=on --overwrite
  for db in ferriskey-db keycloak-db; do
    [ "$(k get -n "$NS" "cluster/$db" -o jsonpath='{.metadata.annotations.cnpg\.io/hibernation}')" = on ] && continue
    k wait -n "$NS" "cluster/$db" --for=condition=Ready --timeout=10m
  done

  log "FerrisKey $FERRISKEY_TAG (chart $FERRISKEY_CHART_VERSION)"
  h upgrade --install ferriskey oci://ghcr.io/ferriskey/charts/ferriskey \
    --version "$FERRISKEY_CHART_VERSION" -n "$NS" -f "$HERE/ferriskey/values.yaml" \
    --set common.image.tag="$FERRISKEY_TAG" \
    --set api.image.tag="$FERRISKEY_TAG" \
    --set databaseMigrations.image.tag="$FERRISKEY_TAG" \
    --set api.replicas=0 \
    --set-string api.resources.requests.cpu="$FERRISKEY_CPU" \
    --set api.resources.requests.memory="$FERRISKEY_MEMORY" \
    --set api.resources.limits.memory="$FERRISKEY_MEMORY" \
    ${FERRISKEY_CPU_LIMIT:+--set-string api.resources.limits.cpu=$FERRISKEY_CPU_LIMIT} \
    --set api.env[0].name=SERVER_TRUST_FORWARDED_FOR --set-string api.env[0].value="$FERRISKEY_TRUST_XFF" \
    --wait --timeout 10m

  log "Keycloak $KEYCLOAK_IMAGE"
  if ! k get secret -n "$NS" keycloak-admin >/dev/null 2>&1; then
    k create secret generic -n "$NS" keycloak-admin --from-literal=password="$(openssl rand -hex 16)"
  fi
  sed -e "s|KEYCLOAK_IMAGE|$KEYCLOAK_IMAGE|" -e "s|KEYCLOAK_JAVA_OPTS|$KEYCLOAK_JAVA_OPTS|" \
    -e "s|KEYCLOAK_CPU_REQUEST|$KEYCLOAK_CPU|" -e "s|KEYCLOAK_MEMORY|$KEYCLOAK_MEMORY|g" \
    -e "s|KEYCLOAK_CPU_LIMIT|${KEYCLOAK_CPU_LIMIT:+cpu: \"$KEYCLOAK_CPU_LIMIT\", }|" \
    "$HERE/keycloak/keycloak.yaml" | k apply -f -
  k scale -n "$NS" deploy/keycloak --replicas=0
}

# Only one system runs at a time: they share the sut node and the same CPU budget.
deployment_of() { [ "$1" = ferriskey ] && echo ferriskey-api || echo keycloak; }
# Deployment pods only (<name>-<rs hash>-<pod hash>): keycloak-.* would also match keycloak-db-1.
pod_regex_of() { [ "$1" = ferriskey ] && echo 'ferriskey-api-[a-z0-9]+-[a-z0-9]{5}' || echo 'keycloak-[a-z0-9]+-[a-z0-9]{5}'; }

activate() {
  local sys="$1" other
  other=$([ "$sys" = ferriskey ] && echo keycloak || echo ferriskey)
  log "activating $sys"
  k scale -n "$NS" "deploy/$(deployment_of "$other")" --replicas=0
  while [ "$(k get -n "$NS" "deploy/$(deployment_of "$other")" -o jsonpath='{.status.replicas}')" -gt 0 ] 2>/dev/null; do sleep 2; done
  # The db node holds one database at full size: hibernate the other one (data is kept).
  k annotate -n "$NS" "cluster/$other-db" cnpg.io/hibernation=on --overwrite
  k annotate -n "$NS" "cluster/$sys-db" cnpg.io/hibernation=off --overwrite
  until k get -n "$NS" "pod/$sys-db-1" >/dev/null 2>&1; do sleep 3; done
  k wait -n "$NS" "pod/$sys-db-1" --for=condition=Ready --timeout=10m
  k scale -n "$NS" "deploy/$(deployment_of "$sys")" --replicas="$([ "$sys" = ferriskey ] && echo "$FERRISKEY_REPLICAS" || echo 1)"
  k rollout status -n "$NS" "deploy/$(deployment_of "$sys")" --timeout=10m
  if [ "$sys" = keycloak ]; then
    # Pod IPs (100.64.0.0/10) are not "private" for Keycloak, so sslRequired=external
    # rejects every call. localhost is allowed: fix the master realm from inside the pod.
    k exec -n "$NS" deploy/keycloak -- bash -c '/opt/keycloak/bin/kcadm.sh config credentials \
      --server http://localhost:8080 --realm master --user admin --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" \
      --config /tmp/kcadm.config >/dev/null && /opt/keycloak/bin/kcadm.sh update realms/master \
      -s sslRequired=NONE --config /tmp/kcadm.config'
  fi
}

admin_secret_of() { [ "$1" = ferriskey ] && echo ferriskey-api-admin || echo keycloak-admin; }

cmd_seed() {
  local systems="${*:-ferriskey keycloak}"
  k apply -f "$HERE/seed/rbac.yaml"
  k create configmap -n "$NS" bench-seed-script --from-file="$HERE/seed/seed.sh" \
    --dry-run=client -o yaml | k apply -f -
  for sys in $systems; do
    activate "$sys"
    log "seeding $sys ($USER_COUNT users)"
    k delete job -n "$NS" "seed-$sys" --ignore-not-found
    sed -e "s/__SYSTEM__/$sys/g" -e "s/__ADMIN_SECRET__/$(admin_secret_of "$sys")/" -e "s/__USER_COUNT__/$USER_COUNT/" \
      "$HERE/seed/job.yaml" | k apply -f -
    k wait -n "$NS" "job/seed-$sys" --for=condition=complete --timeout=30m \
      || { k logs -n "$NS" "job/seed-$sys" --tail=30; die "seed $sys failed"; }
    k logs -n "$NS" "job/seed-$sys" --tail=3
  done
}

PROM_PORT="${PROM_PORT:-19090}"

start_prometheus_forward() {
  k port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus "$PROM_PORT:9090" >/dev/null 2>&1 &
  PROM_PF_PID=$!
  trap 'kill "$PROM_PF_PID" 2>/dev/null || true' EXIT
  until curl -sf "http://localhost:$PROM_PORT/-/ready" >/dev/null; do sleep 1; done
}

prom_query() {
  curl -sf "http://localhost:$PROM_PORT/api/v1/query" --data-urlencode "query=$1" --data-urlencode "time=$2" \
    | python3 -c 'import json, sys; r = json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else "null")' \
    2>/dev/null || echo null
}

# Average CPU (cores) and peak working-set memory (MiB) of a pod set over the measured window.
resources_json() {
  local pods="$1" end_s="$2" window="$3" cpu mem
  [ "$window" -ge 30 ] || window=30  # cAdvisor is scraped every 10s
  cpu=$(prom_query "sum(rate(container_cpu_usage_seconds_total{namespace=\"$NS\",pod=~\"$pods\",container!=\"\"}[${window}s]))" "$end_s")
  mem=$(prom_query "max_over_time(sum(container_memory_working_set_bytes{namespace=\"$NS\",pod=~\"$pods\",container!=\"\"})[${window}s:5s]) / 1048576" "$end_s")
  printf '{"cpu_cores": %s, "memory_mib": %s}' "$cpu" "$mem"
}

run_step() {
  local sys="$1" scenario="$2" rate="$3" duration="$4" out="$5"
  local name="k6-$sys-${scenario//_/-}-$rate"
  k delete job -n "$NS" "$name" --ignore-not-found >/dev/null
  sed -e "s/__NAME__/$name/" -e "s/__SYSTEM__/$sys/g" -e "s/__SCENARIO__/$scenario/" \
    -e "s/__RATE__/$rate/" -e "s/__DURATION__/$duration/" -e "s/__WARMUP__/$WARMUP/" -e "s/__SPREAD_IPS__/$SPREAD_IPS/" -e "s/__PRE_VUS__/${PRE_VUS:-}/" \
    "$HERE/k6/job.yaml" | k apply -f - >/dev/null
  k wait -n "$NS" "job/$name" --for=condition=complete --timeout="$((duration + WARMUP + 300))s" >/dev/null 2>&1 || true
  local result
  result=$(k logs -n "$NS" "job/$name" | sed -n '/BENCH_RESULT_BEGIN/,/BENCH_RESULT_END/p' | sed '1d;$d')
  [ -n "$result" ] || { k logs -n "$NS" "job/$name" --tail=20 >&2; echo "no result for $name" >&2; return 1; }

  local end_s window sut db
  end_s=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["window_end_ms"] / 1000)' "$result")
  sleep 10  # let Prometheus scrape the end of the window
  sut=$(resources_json "$(pod_regex_of "$sys")" "$end_s" "$duration")
  db=$(resources_json "$sys-db-[0-9]+" "$end_s" "$duration")
  python3 - "$result" "$sut" "$db" "$out" <<'EOF'
import json, sys
r = json.loads(sys.argv[1])
r["sut"] = json.loads(sys.argv[2])
r["db"] = json.loads(sys.argv[3])
json.dump(r, open(sys.argv[4], "w"), indent=2)
l = r["latency_ms"]
print(f'  {r["target_rps"]:>5} rps -> {r["achieved_rps"]:8.1f} ok/s  p50 {l["p50"] or 0:7.1f}  p95 {l["p95"] or 0:7.1f}  '
      f'p99 {l["p99"] or 0:7.1f} ms  err {r["error_rate"]*100:5.2f}%  cpu {r["sut"]["cpu_cores"]}  mem {r["sut"]["memory_mib"]} MiB')
EOF
}

# A step is saturated when errors pass 5%, p95 passes 2s, or less than 90% of the target rate succeeds.
saturated() {
  python3 - "$1" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1]))
bad = r["error_rate"] > 0.05 or (r["latency_ms"]["p95"] or 0) > 2000 or r["achieved_rps"] < 0.9 * r["target_rps"]
sys.exit(0 if bad else 1)
EOF
}

sut_resources() {
  printf 'FerrisKey %s x (%s CPU request, %s, %s) / Keycloak 1 x (%s CPU request, %s, %s%s)' \
    "$FERRISKEY_REPLICAS" "$FERRISKEY_CPU" "${FERRISKEY_CPU_LIMIT:+limit $FERRISKEY_CPU_LIMIT CPU}${FERRISKEY_CPU_LIMIT:-no CPU limit}" \
    "$FERRISKEY_MEMORY" "$KEYCLOAK_CPU" "${KEYCLOAK_CPU_LIMIT:+limit $KEYCLOAK_CPU_LIMIT CPU}${KEYCLOAK_CPU_LIMIT:-no CPU limit}" \
    "$KEYCLOAK_MEMORY" "${KEYCLOAK_JAVA_OPTS:+, $KEYCLOAK_JAVA_OPTS}"
}

cmd_run() {
  local systems="${*:-ferriskey keycloak}"
  local run_dir="$REPO/results/k8s/$(date +%Y-%m-%d_%H-%M-%S)${RUN_LABEL:+_$RUN_LABEL}"
  mkdir -p "$run_dir"
  k create configmap -n "$NS" bench-k6-script --from-file="$HERE/k6/bench.js" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  cat > "$run_dir/meta.json" <<EOF
{"ferriskey_tag": "$FERRISKEY_TAG", "keycloak_image": "$KEYCLOAK_IMAGE", "user_count": $USER_COUNT,
 "duration_s": $DURATION, "warmup_s": $WARMUP, "context": "$CTX",
 "ferriskey_trust_xff": $FERRISKEY_TRUST_XFF, "spread_ips": $SPREAD_IPS,
 "sut_resources": "$(sut_resources)", "ferriskey_replicas": $FERRISKEY_REPLICAS,
 "full_ladder": $FULL_LADDER, "db_resources": "1 CPU request / $DB_MEMORY, max_connections $DB_MAX_CONNECTIONS", "node_type": "$NODE_TYPE"}
EOF
  log "results in $run_dir"
  start_prometheus_forward

  for sys in $systems; do
    activate "$sys"
    sleep 45  # let the process settle and cAdvisor scrape it before the idle sample
    local idle_end
    idle_end=$(date +%s)
    resources_json "$(pod_regex_of "$sys")" "$idle_end" 30 > "$run_dir/$sys-idle.json"
    log "$sys warmup (client_credentials 100 rps, 60s, discarded)"
    run_step "$sys" client_credentials 100 60 /dev/null >/dev/null || true

    for scenario in $SCENARIOS; do
      local rates_var="RATES_$scenario"
      mkdir -p "$run_dir/$sys"
      log "$sys / $scenario"
      for rate in ${!rates_var}; do
        local out="$run_dir/$sys/$scenario-$rate.json"
        run_step "$sys" "$scenario" "$rate" "$DURATION" "$out" || break
        sleep "$COOLDOWN"
        if saturated "$out"; then
          [ "$FULL_LADDER" = true ] && { log "  saturated at $rate rps, ladder continues"; continue; }
          log "  saturated at $rate rps, next scenario"
          break
        fi
      done
    done
  done

  python3 "$HERE/report.py" "$run_dir"
  log "report: $run_dir/REPORT.md"
}

# Recomputes the sut/db resources of every step of a run from Prometheus (7 days retention).
cmd_rescan() {
  local run_dir="${1:-}"
  [ -d "$run_dir" ] || die "usage: bench.sh rescan <run-dir>"
  start_prometheus_forward
  for sys in ferriskey keycloak; do
    for f in "$run_dir/$sys"/*.json; do
      [ -f "$f" ] || continue
      local end_s duration sut db
      end_s=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["window_end_ms"] / 1000)' "$f")
      duration=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["duration_s"])' "$f")
      sut=$(resources_json "$(pod_regex_of "$sys")" "$end_s" "$duration")
      db=$(resources_json "$sys-db-[0-9]+" "$end_s" "$duration")
      python3 - "$f" "$sut" "$db" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
r["sut"], r["db"] = json.loads(sys.argv[2]), json.loads(sys.argv[3])
json.dump(r, open(sys.argv[1], "w"), indent=2)
PY
      echo "  $f"
    done
  done
  python3 "$HERE/report.py" "$run_dir"
}

cmd_report() {
  [ -d "${1:-}" ] || die "usage: bench.sh report <run-dir>"
  python3 "$HERE/report.py" "$1"
}

cmd_down() {
  h uninstall ferriskey -n "$NS" --ignore-not-found
  k delete namespace "$NS" --ignore-not-found
}

main() {
  local cmd="${1:-}"; shift || true
  check_context
  case "$cmd" in
    platform|deploy|seed|run|rescan|report|down) "cmd_$cmd" "$@" ;;
    *) die "usage: bench.sh <platform|deploy|seed|run|rescan|report|down>" ;;
  esac
}

main "$@"
