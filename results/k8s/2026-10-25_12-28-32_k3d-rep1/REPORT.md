# FerrisKey vs Keycloak

- FerrisKey: `local-shed`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 1 CPU / 512Mi per pod (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 46 | 68 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 395 (7) | < lowest step | - | 588 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 200 | ferriskey | 199 | 2.1 | 3.3 | 48.6 | 0.45% | 0.35 | 65 | 0.19 |
| 400 | ferriskey | 395 | 2.1 | 7.1 | 123.5 | 0.87% | 0.66 | 68 | 0.35 |
| 800 | ferriskey | 588 | 52.5 | 113.1 | 155.8 | 26.45% | 0.90 | 46 | 0.33 |
