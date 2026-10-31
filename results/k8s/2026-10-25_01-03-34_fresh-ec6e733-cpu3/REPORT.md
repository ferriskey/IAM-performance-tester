# FerrisKey vs Keycloak

- FerrisKey: `sha-a5d4df3`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 31 | 90 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 401 (74) | < lowest step | - | 641 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 16.5 | 23.2 | 31.0 | 0.00% | 0.31 | 31 | 0.35 |
| 100 | ferriskey | 100 | 17.0 | 25.9 | 34.1 | 0.00% | 0.59 | 31 | 0.75 |
| 200 | ferriskey | 200 | 19.1 | 34.0 | 54.1 | 0.00% | 1.03 | 34 | 1.21 |
| 400 | ferriskey | 401 | 30.6 | 74.1 | 132.7 | 0.00% | 1.77 | 45 | 1.64 |
| 800 | ferriskey | 641 | 407.9 | 576.5 | 666.8 | 0.00% | 2.46 | 90 | 1.98 |
