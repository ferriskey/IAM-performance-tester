# FerrisKey vs Keycloak

- FerrisKey: `local-final`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 1 CPU / 512Mi per pod (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 94 | 122 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 1593 (75) | < lowest step | - | 1731 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 200 | ferriskey | 200 | 1.9 | 2.7 | 5.1 | 0.00% | 0.34 | 112 | 0.05 |
| 400 | ferriskey | 400 | 1.9 | 3.6 | 7.2 | 0.00% | 0.67 | 114 | 0.09 |
| 800 | ferriskey | 800 | 2.0 | 5.0 | 36.4 | 0.00% | 1.31 | 98 | 0.15 |
| 1200 | ferriskey | 1198 | 2.0 | 8.9 | 71.2 | 0.03% | 1.84 | 94 | 0.18 |
| 1600 | ferriskey | 1593 | 4.3 | 75.4 | 121.9 | 0.31% | 2.35 | 118 | 0.22 |
| 2000 | ferriskey | 1731 | 108.7 | 213.0 | 295.8 | 12.01% | 2.59 | 122 | 0.24 |
