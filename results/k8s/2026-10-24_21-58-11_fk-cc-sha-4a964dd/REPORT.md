# FerrisKey vs Keycloak

- FerrisKey: `sha-4a964dd`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 85 | 88 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 100 (41) | < lowest step | - | 308 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 22.8 | 34.2 | 46.2 | 0.00% | 0.40 | 85 | 0.42 |
| 100 | ferriskey | 100 | 25.6 | 40.9 | 54.9 | 0.00% | 0.68 | 85 | 0.63 |
| 200 | ferriskey | 198 | 29.0 | 50.7 | 69.1 | 1.06% | 1.10 | 86 | 1.11 |
| 400 | ferriskey | 308 | 41.2 | 66.7 | 81.4 | 23.12% | 1.52 | 88 | 1.52 |
