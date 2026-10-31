# FerrisKey vs Keycloak

- FerrisKey: `local-shed`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 80 | 114 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 800 (4) | < lowest step | - | 1338 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 2.8 | 5.1 | 5.8 | 0.00% | 0.13 | 86 | 0.09 |
| 100 | ferriskey | 100 | 2.2 | 3.7 | 5.4 | 0.00% | 0.20 | 80 | 0.12 |
| 200 | ferriskey | 200 | 2.0 | 2.5 | 3.5 | 0.00% | 0.33 | 111 | 0.18 |
| 400 | ferriskey | 399 | 2.0 | 3.4 | 8.2 | 0.01% | 0.67 | 114 | 0.36 |
| 800 | ferriskey | 800 | 2.1 | 4.0 | 7.0 | 0.00% | 1.22 | 96 | 0.51 |
| 1600 | ferriskey | 1338 | 49.4 | 65.5 | 76.1 | 16.45% | 1.92 | 104 | 0.79 |
