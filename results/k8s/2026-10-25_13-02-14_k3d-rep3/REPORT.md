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
| ferriskey | 110 | 142 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 1196 (37) | < lowest step | - | 1712 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 200 | ferriskey | 200 | 2.1 | 2.7 | 3.7 | 0.00% | 0.35 | 110 | 0.20 |
| 400 | ferriskey | 399 | 2.2 | 5.3 | 27.3 | 0.00% | 0.77 | 120 | 0.47 |
| 800 | ferriskey | 800 | 2.5 | 5.5 | 13.9 | 0.00% | 1.39 | 142 | 0.70 |
| 1200 | ferriskey | 1196 | 4.2 | 36.8 | 94.0 | 0.30% | 1.99 | 125 | 1.19 |
| 1600 | ferriskey | 1558 | 28.0 | 98.0 | 157.1 | 2.57% | 2.66 | 123 | 1.24 |
| 2000 | ferriskey | 1712 | 51.9 | 100.0 | 148.6 | 14.38% | 2.81 | 139 | 1.32 |
