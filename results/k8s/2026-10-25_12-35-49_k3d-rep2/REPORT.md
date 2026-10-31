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
| ferriskey | 81 | 102 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 798 (8) | < lowest step | - | 1254 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 200 | ferriskey | 200 | 2.2 | 3.0 | 6.5 | 0.00% | 0.35 | 81 | 0.19 |
| 400 | ferriskey | 400 | 2.2 | 4.4 | 24.7 | 0.00% | 0.69 | 96 | 0.34 |
| 800 | ferriskey | 798 | 2.7 | 8.3 | 37.0 | 0.18% | 1.35 | 84 | 0.70 |
| 1200 | ferriskey | 1161 | 24.2 | 88.4 | 147.3 | 3.13% | 1.57 | 102 | 0.70 |
| 1600 | ferriskey | 1254 | 50.3 | 104.8 | 142.4 | 21.67% | 1.76 | 94 | 0.57 |
