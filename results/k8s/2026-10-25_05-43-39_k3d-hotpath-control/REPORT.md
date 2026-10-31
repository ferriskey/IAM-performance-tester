# FerrisKey vs Keycloak

- FerrisKey: `local-hot-path`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 97 | 157 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 800 (10) | < lowest step | - | 1141 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 5.7 | 7.8 | 9.7 | 0.00% | 0.13 | 97 | 0.09 |
| 100 | ferriskey | 100 | 4.7 | 6.7 | 13.8 | 0.00% | 0.22 | 127 | 0.13 |
| 200 | ferriskey | 200 | 3.9 | 5.5 | 14.5 | 0.00% | 0.39 | 118 | 0.26 |
| 400 | ferriskey | 399 | 4.0 | 7.2 | 24.5 | 0.00% | 0.73 | 123 | 0.45 |
| 800 | ferriskey | 800 | 4.5 | 10.5 | 29.5 | 0.00% | 1.34 | 115 | 0.77 |
| 1600 | ferriskey | 1141 | 237.7 | 316.3 | 371.5 | 0.00% | 1.61 | 157 | 0.41 |
