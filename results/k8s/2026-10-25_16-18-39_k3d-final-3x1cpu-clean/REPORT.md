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
| ferriskey | 97 | 123 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 1592 (87) | < lowest step | - | 1717 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 200 | ferriskey | 200 | 1.9 | 3.3 | 6.0 | 0.00% | 0.33 | 115 | 0.05 |
| 400 | ferriskey | 400 | 2.0 | 4.4 | 19.8 | 0.00% | 0.69 | 97 | 0.09 |
| 800 | ferriskey | 800 | 1.9 | 5.5 | 19.5 | 0.00% | 1.28 | 101 | 0.15 |
| 1200 | ferriskey | 1198 | 2.3 | 15.8 | 76.4 | 0.00% | 1.93 | 114 | 0.20 |
| 1600 | ferriskey | 1592 | 10.1 | 87.2 | 148.3 | 0.30% | 2.47 | 122 | 0.25 |
| 2000 | ferriskey | 1717 | 97.9 | 208.2 | 296.2 | 13.22% | 2.60 | 123 | 0.27 |
