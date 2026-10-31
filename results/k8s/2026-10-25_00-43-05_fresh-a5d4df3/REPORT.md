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
| ferriskey | 82 | 118 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 400 (136) | < lowest step | - | 463 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 21.5 | 32.0 | 39.9 | 0.00% | 0.30 | 82 | 0.48 |
| 100 | ferriskey | 100 | 22.7 | 35.4 | 45.2 | 0.00% | 0.53 | 82 | 0.70 |
| 200 | ferriskey | 200 | 26.8 | 48.0 | 67.1 | 0.00% | 0.92 | 85 | 1.21 |
| 400 | ferriskey | 400 | 50.5 | 136.1 | 312.8 | 0.00% | 1.65 | 100 | 1.79 |
| 800 | ferriskey | 463 | 630.8 | 791.3 | 893.4 | 0.00% | 1.82 | 118 | 1.85 |
