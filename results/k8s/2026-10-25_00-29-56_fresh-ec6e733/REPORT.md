# FerrisKey vs Keycloak

- FerrisKey: `sha-ec6e733`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 88 | 141 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 399 (113) | < lowest step | - | 503 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 17.1 | 25.7 | 42.8 | 0.00% | 0.32 | 88 | 0.48 |
| 100 | ferriskey | 100 | 18.5 | 34.0 | 61.4 | 0.00% | 0.58 | 88 | 0.76 |
| 200 | ferriskey | 200 | 20.2 | 49.4 | 91.5 | 0.00% | 1.00 | 92 | 1.26 |
| 400 | ferriskey | 399 | 38.9 | 113.0 | 203.5 | 0.00% | 1.64 | 103 | 1.78 |
| 800 | ferriskey | 503 | 547.6 | 752.1 | 880.9 | 0.00% | 1.82 | 141 | 1.70 |
