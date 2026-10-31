# FerrisKey vs Keycloak

- FerrisKey: `local-sign`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 1 CPU / 512Mi per pod (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 90 | 127 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 1599 (21) | < lowest step | - | 1821 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 200 | ferriskey | 200 | 1.9 | 2.8 | 4.6 | 0.00% | 0.33 | 103 | 0.04 |
| 400 | ferriskey | 400 | 1.9 | 3.1 | 5.2 | 0.00% | 0.61 | 90 | 0.07 |
| 800 | ferriskey | 800 | 1.9 | 3.9 | 7.7 | 0.00% | 1.22 | 114 | 0.13 |
| 1200 | ferriskey | 1200 | 2.2 | 5.7 | 21.0 | 0.01% | 1.77 | 127 | 0.20 |
| 1600 | ferriskey | 1599 | 3.2 | 21.3 | 50.8 | 0.05% | 2.41 | 124 | 0.27 |
| 2000 | ferriskey | 1821 | 45.7 | 97.2 | 129.3 | 8.87% | 2.97 | 101 | 0.28 |
