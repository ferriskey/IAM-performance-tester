#!/usr/bin/env bash
# Local k3d cluster for the FerrisKey vs Keycloak benchmark. See k8s/README.md.
#
#   ./k3d.sh up                  create the cluster, storage classes and node roles
#   ./k3d.sh import <image>...   copy local docker images into the cluster
#   ./k3d.sh env                 print the variables bench.sh needs for this cluster
#   ./k3d.sh down                delete the cluster
#
# The three agents are containers of the same Docker VM: they share its CPUs, so the
# loadgen, the system under test and the database compete for the same cores.
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-iam-bench}"
AGENTS=(loadgen sut db)

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

up() {
  if ! k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
    log "creating k3d cluster $CLUSTER"
    k3d cluster create "$CLUSTER" --servers 1 --agents "${#AGENTS[@]}" --no-lb \
      --k3s-arg "--disable=traefik@server:0" --wait
  fi
  local ctx="k3d-$CLUSTER"
  log "storage classes"
  for class in sbs-15k sbs-default; do
    kubectl --context "$ctx" apply -f - >/dev/null <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: $class }
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
  done
  log "context $ctx ready"
}

import() {
  [ "$#" -gt 0 ] || { echo "usage: k3d.sh import <image>..." >&2; exit 1; }
  k3d image import "$@" -c "$CLUSTER"
}

env_vars() {
  local i
  echo "export KUBE_CONTEXT=k3d-$CLUSTER"
  for i in "${!AGENTS[@]}"; do
    local role="${AGENTS[$i]}"
    echo "export NODE_$(echo "$role" | tr a-z A-Z)=k3d-$CLUSTER-agent-$i"
  done
}

case "${1:-}" in
  up) up ;;
  import) shift; import "$@" ;;
  env) env_vars ;;
  down) k3d cluster delete "$CLUSTER" ;;
  *) sed -n 2,9p "$0"; exit 1 ;;
esac
