# FerrisKey vs Keycloak

- FerrisKey: `local-rtp-eca0f82`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 1 x (3 CPU request, no CPU limit, 1536Mi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 374 | 576 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| refresh | 1567 (164) | < lowest step | - | 1567 | - | - |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 800 | ferriskey | 800 | 4.9 | 52.6 | 220.2 | 0.00% | 1.51 | 374 | 0.60 |
| 1600 | ferriskey | 1567 | 19.5 | 164.1 | 317.6 | 0.00% | 3.00 | 576 | 1.13 |
