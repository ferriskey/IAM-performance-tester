# FerrisKey vs Keycloak

- FerrisKey: `local-rtp-93cc26e`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 1 x (3 CPU request, no CPU limit, 1536Mi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 498 | 500 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| refresh | 1590 (66) | < lowest step | - | 1590 | - | - |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 800 | ferriskey | 800 | 2.8 | 5.7 | 28.4 | 0.00% | 1.51 | 498 | 0.35 |
| 1600 | ferriskey | 1590 | 5.6 | 66.5 | 201.1 | 0.00% | 2.95 | 500 | 0.70 |
