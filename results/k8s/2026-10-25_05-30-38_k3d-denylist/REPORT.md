# FerrisKey vs Keycloak

- FerrisKey: `local-denylist`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 93 | 136 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 800 (4) | < lowest step | - | 1198 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 2.9 | 5.5 | 6.3 | 0.00% | 0.14 | 111 | 0.10 |
| 100 | ferriskey | 100 | 2.3 | 3.6 | 5.0 | 0.00% | 0.20 | 102 | 0.12 |
| 200 | ferriskey | 200 | 2.0 | 2.8 | 4.3 | 0.00% | 0.30 | 93 | 0.19 |
| 400 | ferriskey | 400 | 2.0 | 3.3 | 4.8 | 0.00% | 0.67 | 124 | 0.36 |
| 800 | ferriskey | 800 | 2.0 | 3.7 | 6.3 | 0.00% | 1.20 | 117 | 0.51 |
| 1600 | ferriskey | 1198 | 245.6 | 312.5 | 370.0 | 0.00% | 1.60 | 136 | 0.42 |
