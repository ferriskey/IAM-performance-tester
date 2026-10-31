# FerrisKey vs Keycloak

- FerrisKey: `local-cache`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 1 CPU / 512Mi per pod (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 97 | 98 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | < lowest step | < lowest step | - | 1368 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 1200 | ferriskey | 1180 | 16.1 | 82.0 | 156.4 | 1.14% | 2.63 | 98 | 0.65 |
| 1600 | ferriskey | 1368 | 63.3 | 126.0 | 195.4 | 13.95% | 2.77 | 97 | 0.57 |
