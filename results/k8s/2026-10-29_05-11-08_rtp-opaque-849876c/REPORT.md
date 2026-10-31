# FerrisKey vs Keycloak

- FerrisKey: `local-rtp-849876c`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 1 x (3 CPU request, no CPU limit, 1536Mi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 270 | 688 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| refresh | 1595 (135) | < lowest step | - | 1767 | - | - |
| userinfo | 6389 (3) | < lowest step | - | 6389 | - | - |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 400 | ferriskey | 400 | 5.5 | 17.5 | 84.6 | 0.00% | 0.79 | 270 | 0.24 |
| 800 | ferriskey | 800 | 6.1 | 125.0 | 328.0 | 0.00% | 1.68 | 396 | 0.52 |
| 1600 | ferriskey | 1595 | 22.7 | 134.9 | 175.1 | 0.00% | 3.04 | 438 | 0.68 |
| 3200 | ferriskey | 1767 | 166.1 | 208.5 | 238.9 | 0.00% | 3.43 | 544 | 0.82 |

## userinfo

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 3200 | ferriskey | 3200 | 0.6 | 2.1 | 3.8 | 0.00% | 0.77 | 603 | 0.03 |
| 6400 | ferriskey | 6389 | 0.7 | 2.6 | 4.6 | 0.00% | 1.35 | 688 | 0.03 |
