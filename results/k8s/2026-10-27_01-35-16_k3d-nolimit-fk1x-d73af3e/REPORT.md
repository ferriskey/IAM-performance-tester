# FerrisKey vs Keycloak

- FerrisKey: `sha-d73af3e`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 1 x (3 CPU request, no CPU limit, 1536Mi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node
- Keycloak results copied from run 2026-10-26_21-22-42 (same cluster, DB spec and ladder); only FerrisKey was run here

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 103 | 623 |
| keycloak | 533 | 677 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 3200 (21) | 3200 (11) | 1.00x | 3200 | 3200 | 1.00x |
| password | 160 (73) | 160 (32) | 1.00x | 268 | 160 | 1.68x |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 5.1 | 7.9 | 10.1 | 0.00% | 0.21 | 103 | 0.03 |
| 50 | keycloak | 50 | 5.0 | 8.0 | 9.1 | 0.00% | 0.29 | 533 | 0.03 |
| 100 | ferriskey | 100 | 3.3 | 5.3 | 6.3 | 0.00% | 0.30 | 104 | 0.04 |
| 100 | keycloak | 100 | 3.4 | 6.7 | 7.5 | 0.00% | 0.34 | 539 | 0.04 |
| 200 | ferriskey | 200 | 2.0 | 4.3 | 5.1 | 0.00% | 0.39 | 104 | 0.05 |
| 200 | keycloak | 200 | 2.5 | 3.6 | 5.5 | 0.00% | 0.29 | 543 | 0.04 |
| 400 | ferriskey | 400 | 1.7 | 2.5 | 3.7 | 0.00% | 0.59 | 104 | 0.06 |
| 400 | keycloak | 400 | 1.7 | 2.6 | 3.9 | 0.00% | 0.60 | 547 | 0.05 |
| 800 | ferriskey | 800 | 1.4 | 2.0 | 2.9 | 0.00% | 0.96 | 106 | 0.09 |
| 800 | keycloak | 800 | 1.4 | 2.0 | 3.5 | 0.00% | 0.94 | 535 | 0.08 |
| 1600 | ferriskey | 1600 | 1.5 | 2.9 | 4.6 | 0.00% | 1.91 | 113 | 0.16 |
| 1600 | keycloak | 1600 | 1.5 | 3.7 | 6.7 | 0.00% | 2.02 | 563 | 0.15 |
| 3200 | ferriskey | 3200 | 3.5 | 20.8 | 45.8 | 0.00% | 3.92 | 123 | 0.33 |
| 3200 | keycloak | 3200 | 3.2 | 10.5 | 22.5 | 0.00% | 3.63 | 671 | 0.32 |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 10 | ferriskey | 10 | 32.7 | 38.8 | 42.4 | 0.00% | 0.22 | 151 | 0.07 |
| 10 | keycloak | 10 | 27.6 | 32.6 | 36.5 | 0.00% | 0.30 | 660 | 0.02 |
| 20 | ferriskey | 20 | 23.8 | 27.4 | 33.9 | 0.00% | 0.31 | 157 | 0.07 |
| 20 | keycloak | 20 | 18.6 | 21.5 | 23.6 | 0.00% | 0.31 | 672 | 0.02 |
| 40 | ferriskey | 40 | 23.4 | 27.0 | 31.5 | 0.00% | 0.62 | 157 | 0.12 |
| 40 | keycloak | 40 | 18.0 | 20.1 | 22.7 | 0.00% | 0.72 | 673 | 0.02 |
| 80 | ferriskey | 80 | 24.2 | 29.7 | 45.7 | 0.00% | 1.09 | 198 | 0.23 |
| 80 | keycloak | 80 | 18.4 | 20.9 | 26.7 | 0.00% | 1.46 | 674 | 0.05 |
| 160 | ferriskey | 160 | 30.3 | 72.7 | 179.1 | 0.00% | 3.11 | 368 | 0.51 |
| 160 | keycloak | 160 | 21.5 | 32.3 | 40.9 | 0.00% | 3.29 | 677 | 0.10 |
| 320 | ferriskey | 268 | 1082.9 | 1250.0 | 1351.1 | 0.00% | 5.79 | 604 | 0.80 |
| 320 | keycloak | 152 | 2018.2 | 2215.5 | 2265.6 | 0.00% | 3.52 | 595 | 0.08 |
| 640 | ferriskey | 261 | 1124.0 | 1492.1 | 1768.7 | 0.00% | 5.85 | 623 | 0.86 |
| 640 | keycloak | 155 | 1992.1 | 2076.5 | 2124.4 | 0.00% | 3.40 | 614 | 0.08 |
