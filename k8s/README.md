# FerrisKey vs Keycloak on Kubernetes

Compares an unreleased FerrisKey build with Keycloak on the same Kubernetes cluster,
same resources, same database, same load, same data.

## Quick start

```bash
cd k8s
./bench.sh platform     # once per cluster: node roles, CNPG, kube-prometheus-stack
./bench.sh deploy       # Postgres x2, FerrisKey, Keycloak
./bench.sh seed         # realm perf, client perf-client, 1000 users, in both systems
./bench.sh run          # every scenario, both systems, ~1h30 worst case
```

The report is written to `results/k8s/<date>/REPORT.md`.

## Topology

The cluster has 3 nodes. Each one has a single role, set by `bench.sh platform`:

| Role | Label `bench.ferriskey.rs/role` | Runs | Taint |
|---|---|---|---|
| loadgen | `loadgen` | k6 Jobs, seed Jobs, Prometheus, operators | none |
| sut | `sut` | FerrisKey **or** Keycloak, never both | `NoSchedule` |
| db | `db` | `ferriskey-db` and `keycloak-db` (CNPG), Grafana | `NoSchedule` |

Only one system runs at a time. `bench.sh` scales the other one to 0 before each phase.

## Fairness rules

| Parameter | FerrisKey | Keycloak |
|---|---|---|
| CPU / memory | 2 / 1536Mi, Guaranteed | 2 / 1536Mi, Guaranteed |
| Mode | chart `0.9.0`, image `FERRISKEY_TAG` | `start` (production mode, not `start-dev`) |
| Password hash | Argon2id m=7168 t=5 p=1 (default) | Argon2id m=7168 t=5 p=1 (default) |
| DB pool max | 100 (hardcoded) | 100 (`KC_DB_POOL_MAX_SIZE`) |
| PostgreSQL | 17, 1 CPU, 768Mi, same parameters | same |
| Cache | in-process | `KC_CACHE=local` (single node) |

## Scenarios

`k6/bench.js` runs one operation at a fixed arrival rate (open model). Only that operation
is measured. Helper calls, such as getting the token that is then introspected, are excluded.

| Scenario | Measured call |
|---|---|
| `client_credentials` | `POST /token` grant client_credentials |
| `password` | `POST /token` grant password, scope openid (Argon2 bound) |
| `refresh` | `POST /token` grant refresh_token, with rotation |
| `introspect` | `POST /token/introspect` of a user access token |
| `userinfo` | `GET /userinfo` |
| `jwks` | `GET /certs` |

Each scenario climbs a rate ladder (`RATES_<scenario>`). Each step runs `WARMUP` + `DURATION`
seconds. The ladder stops when a step is saturated: more than 5% errors, p95 above 2 s, or
less than 90% of the target rate served.

For every step the report gives served req/s, p50/p95/p99, error rate, and the average CPU
and peak memory of the system under test and of its database (from Prometheus/cAdvisor).

## Settings

All settings are environment variables of `bench.sh`.

| Variable | Default |
|---|---|
| `KUBE_CONTEXT` | the current kubectl context |
| `FERRISKEY_TAG` | `sha-a5d4df3` |
| `KEYCLOAK_IMAGE` | `quay.io/keycloak/keycloak:26.8.1` |
| `USER_COUNT` | `1000` |
| `SCENARIOS` | all six |
| `DURATION` / `WARMUP` / `COOLDOWN` | `60` / `15` / `10` seconds |
| `RATES_<scenario>` | see `bench.sh` |
| `NODE_LOADGEN`, `NODE_SUT`, `NODE_DB` | none, required by `bench.sh platform` |
| `FERRISKEY_TRUST_XFF` / `SPREAD_IPS` | `false` / `false` (see Known limits) |
| `RUN_LABEL` | suffix of the results directory |
| `FERRISKEY_REPLICAS` | `1` |
| `FERRISKEY_CPU` / `FERRISKEY_CPU_LIMIT` / `FERRISKEY_MEMORY` | `2` / `2` / `1536Mi` per pod (empty limit: no CPU limit) |
| `KEYCLOAK_CPU` / `KEYCLOAK_CPU_LIMIT` / `KEYCLOAK_MEMORY` | `2` / `2` / `1536Mi` (empty limit: no CPU limit) |
| `KEYCLOAK_JAVA_OPTS` | empty, e.g. `-XX:ActiveProcessorCount=3` |
| `FULL_LADDER` | `false` (`true`: measure every step, even after saturation) |
| `DB_MEMORY` / `DB_MAX_CONNECTIONS` | `1280Mi` / `200`, both databases (FerrisKey opens up to 100 connections per replica) |
| `NODE_TYPE` | text written in the report |

Examples:

```bash
# Another FerrisKey build
FERRISKEY_TAG=sha-abc1234 ./bench.sh deploy

# Only the password grant, longer steps
SCENARIOS=password DURATION=180 ./bench.sh run ferriskey keycloak

# No CPU limit: FerrisKey 3 x 1 CPU request, Keycloak 3 CPU request, every step measured
FERRISKEY_REPLICAS=3 FERRISKEY_CPU=1 FERRISKEY_CPU_LIMIT= FERRISKEY_MEMORY=512Mi \
  KEYCLOAK_CPU=3 KEYCLOAK_CPU_LIMIT= KEYCLOAK_JAVA_OPTS=-XX:ActiveProcessorCount=3 ./bench.sh deploy
FERRISKEY_REPLICAS=3 FULL_LADDER=true ./bench.sh run

# Recompute CPU/memory of a past run from Prometheus, then the report
./bench.sh rescan ../results/k8s/2026-10-21_06-00-00

# Rebuild a report
./bench.sh report ../results/k8s/2026-10-21_06-00-00
```

## Local cluster (k3d)

`k3d.sh` creates a local cluster with the same 3 node roles. The nodes share the CPUs of
the Docker VM, so k6, the system under test and Postgres compete for the same cores.

```bash
./k3d.sh up
eval "$(./k3d.sh env)"      # KUBE_CONTEXT and NODE_* for bench.sh
./bench.sh platform && ./bench.sh deploy && ./bench.sh seed && ./bench.sh run
```

## Grafana

`bench.sh platform` loads the dashboard **IAM bench: FerrisKey vs Keycloak**
(`dashboards/iam-bench.json`, ConfigMap `monitoring/iam-bench-dashboard`).

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
# user admin, password:
kubectl -n monitoring get secret kps-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Then open http://localhost:3000/d/iam-bench. Refresh is 10 s.

| Row | What it shows |
|---|---|
| System under test | active system, running k6 step, CPU, memory, CPU throttling, Keycloak JVM heap/GC |
| Server-side traffic | req/s and errors per endpoint, FerrisKey p50/p95/p99, average latency of both |
| PostgreSQL | CPU, connections, transactions/s per database |
| Load generator sanity | k6 CPU and node CPU, to check that k6 is not the bottleneck |

Keycloak exposes no latency histogram by default, so server-side only averages compare.
Client-side p50/p95/p99 for both systems are in `REPORT.md`.

## Known limits

- FerrisKey `/token` takes a token from its "10 failed client auths per minute per IP"
  bucket before handling each request and gives it back afterwards. In practice one IP cannot
  have more than 10 `/token` requests in flight: above that it answers 429, even when every
  request succeeds. k6 runs from one pod, so this caps `client_credentials`, `password` and
  `refresh` on FerrisKey. To measure past it:

  ```bash
  FERRISKEY_TRUST_XFF=true ./bench.sh deploy        # SERVER_TRUST_FORWARDED_FOR=true
  FERRISKEY_TRUST_XFF=true SPREAD_IPS=true RUN_LABEL=xff \
    SCENARIOS="client_credentials password refresh" ./bench.sh run ferriskey
  ./bench.sh deploy                                 # back to the default config
  ```

  With `SPREAD_IPS=true` each k6 VU sends its own `X-Forwarded-For`, so FerrisKey sees up to
  300 clients instead of one.
- `dropped_iterations` counts the warmup too.
- Absolute numbers depend on the DEV1-M nodes (shared vCPU). Compare ratios, not absolutes.
