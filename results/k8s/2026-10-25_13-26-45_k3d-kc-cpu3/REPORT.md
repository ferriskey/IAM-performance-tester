# FerrisKey vs Keycloak

- FerrisKey: `sha-a5d4df3`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: 3 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| keycloak | 552 | 822 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | < lowest step | 1600 (5) | - | - | 1899 | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 1200 | keycloak | 1184 | 2.0 | 13.1 | 122.6 | 0.00% | 1.95 | 552 | 0.16 |
| 1600 | keycloak | 1600 | 1.9 | 4.6 | 13.6 | 0.00% | 1.98 | 807 | 0.17 |
| 2000 | keycloak | 1899 | 118.6 | 193.7 | 235.7 | 0.00% | 2.89 | 811 | 0.32 |
| 2400 | keycloak | 1857 | 149.2 | 203.0 | 248.8 | 0.00% | 3.00 | 822 | 0.33 |
