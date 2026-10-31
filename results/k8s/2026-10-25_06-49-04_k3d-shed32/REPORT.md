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
| ferriskey | 51 | 64 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 792 (5) | < lowest step | - | 1067 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 2.9 | 5.3 | 9.2 | 0.00% | 0.14 | 54 | 0.08 |
| 100 | ferriskey | 100 | 2.3 | 3.8 | 10.9 | 0.00% | 0.21 | 60 | 0.13 |
| 200 | ferriskey | 199 | 2.0 | 2.9 | 58.7 | 0.06% | 0.37 | 64 | 0.16 |
| 400 | ferriskey | 397 | 2.0 | 3.5 | 27.8 | 0.39% | 0.69 | 59 | 0.35 |
| 800 | ferriskey | 792 | 2.2 | 5.4 | 46.3 | 0.75% | 1.22 | 51 | 0.52 |
| 1600 | ferriskey | 1067 | 27.5 | 78.7 | 145.7 | 29.46% | 1.56 | 51 | 0.60 |
