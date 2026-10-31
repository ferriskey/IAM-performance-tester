# FerrisKey vs Keycloak

- FerrisKey: `sha-4a964dd`
- Keycloak: `quay.io/keycloak/keycloak:26.6.4`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 768Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 27 | 187 |
| keycloak | 511 | 808 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 199 (39) | 400 (113) | 0.50x | 296 | 530 | 0.56x |
| password | 40 (129) | 20 (98) | 2.00x | 48 | 35 | 1.37x |
| refresh | 50 (81) | 200 (31) | 0.25x | 98 | 263 | 0.37x |
| introspect | 3122 (103) | 1600 (84) | 1.95x | 3122 | 2008 | 1.55x |
| userinfo | 400 (63) | 1601 (18) | 0.25x | 656 | 2389 | 0.27x |
| jwks | 100 (3) | 3049 (135) | 0.03x | 150 | 3049 | 0.05x |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 20.9 | 30.4 | 41.8 | 0.00% | 0.31 | 27 | 0.45 |
| 50 | keycloak | 50 | 10.6 | 15.0 | 19.2 | 0.00% | 0.44 | 511 | 0.08 |
| 100 | ferriskey | 100 | 22.8 | 36.8 | 64.4 | 0.05% | 0.58 | 28 | 0.72 |
| 100 | keycloak | 100 | 10.3 | 16.5 | 22.8 | 0.00% | 0.58 | 528 | 0.13 |
| 200 | ferriskey | 199 | 23.9 | 39.4 | 53.4 | 0.58% | 0.92 | 29 | 1.05 |
| 200 | keycloak | 200 | 9.9 | 15.9 | 22.9 | 0.00% | 1.14 | 530 | 0.23 |
| 400 | ferriskey | 296 | 32.5 | 54.4 | 71.4 | 26.05% | 1.29 | 30 | 1.35 |
| 400 | keycloak | 400 | 11.6 | 113.4 | 176.0 | 0.00% | 1.85 | 784 | 0.24 |
| 800 | keycloak | 530 | 555.3 | 679.4 | 793.1 | 0.00% | 2.00 | 792 | 0.44 |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 10 | ferriskey | 10 | 74.2 | 104.1 | 137.7 | 0.00% | 0.40 | 37 | 0.21 |
| 10 | keycloak | 10 | 83.8 | 104.8 | 114.9 | 0.00% | 0.74 | 792 | 0.10 |
| 20 | ferriskey | 20 | 77.8 | 100.9 | 121.7 | 0.00% | 0.83 | 44 | 0.36 |
| 20 | keycloak | 20 | 74.7 | 97.8 | 127.1 | 0.00% | 1.26 | 799 | 0.13 |
| 40 | ferriskey | 40 | 85.2 | 129.5 | 168.0 | 0.00% | 1.67 | 58 | 0.59 |
| 40 | keycloak | 35 | 3850.6 | 4360.3 | 4693.0 | 11.06% | 2.00 | 808 | 0.19 |
| 80 | ferriskey | 48 | 241.0 | 471.8 | 572.8 | 40.10% | 1.99 | 152 | 0.61 |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 53.0 | 81.4 | 113.7 | 0.00% | 0.60 | 159 | 0.45 |
| 50 | keycloak | 50 | 8.5 | 24.8 | 29.9 | 0.00% | 0.36 | 731 | 0.07 |
| 100 | ferriskey | 98 | 62.3 | 111.7 | 152.9 | 2.33% | 0.92 | 159 | 1.01 |
| 100 | keycloak | 100 | 8.1 | 24.2 | 30.9 | 0.00% | 0.78 | 734 | 0.08 |
| 200 | ferriskey | 18 | 13.9 | 310.8 | 385.4 | 90.87% | 2.00 | 160 | 0.69 |
| 200 | keycloak | 200 | 8.6 | 31.3 | 63.7 | 0.00% | 1.47 | 751 | 0.17 |
| 400 | keycloak | 263 | 1101.0 | 1408.1 | 1506.8 | 0.09% | 2.00 | 755 | 0.71 |

## introspect

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 5.3 | 8.4 | 13.0 | 0.00% | 0.06 | 160 | 0.09 |
| 50 | keycloak | 50 | 4.1 | 6.5 | 8.6 | 0.00% | 0.16 | 750 | 0.03 |
| 100 | ferriskey | 100 | 5.4 | 8.2 | 11.2 | 0.00% | 0.13 | 160 | 0.17 |
| 100 | keycloak | 100 | 3.9 | 6.3 | 8.5 | 0.00% | 0.33 | 751 | 0.03 |
| 200 | ferriskey | 200 | 5.2 | 10.1 | 16.9 | 0.00% | 0.26 | 160 | 0.28 |
| 200 | keycloak | 200 | 3.5 | 5.8 | 8.3 | 0.00% | 0.49 | 752 | 0.04 |
| 400 | ferriskey | 400 | 5.0 | 8.7 | 12.7 | 0.00% | 0.36 | 160 | 0.45 |
| 400 | keycloak | 400 | 3.3 | 6.8 | 10.3 | 0.00% | 0.91 | 756 | 0.04 |
| 800 | ferriskey | 800 | 5.1 | 10.2 | 15.8 | 0.00% | 0.70 | 162 | 0.70 |
| 800 | keycloak | 800 | 3.1 | 8.0 | 13.6 | 0.00% | 1.33 | 756 | 0.05 |
| 1600 | ferriskey | 1600 | 6.6 | 20.7 | 62.7 | 0.00% | 1.12 | 171 | 1.13 |
| 1600 | keycloak | 1600 | 4.9 | 84.4 | 190.3 | 0.00% | 1.95 | 756 | 0.04 |
| 3200 | ferriskey | 3122 | 39.4 | 102.6 | 148.6 | 0.00% | 1.72 | 183 | 1.79 |
| 3200 | keycloak | 2008 | 143.8 | 191.4 | 219.2 | 0.00% | 2.00 | 756 | 0.03 |

## userinfo

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 21.0 | 30.9 | 41.2 | 0.00% | 0.24 | 182 | 0.33 |
| 50 | keycloak | 50 | 3.7 | 5.8 | 8.1 | 0.00% | 0.14 | 751 | 0.03 |
| 100 | ferriskey | 100 | 20.8 | 33.7 | 49.5 | 0.00% | 0.37 | 182 | 0.58 |
| 100 | keycloak | 100 | 3.6 | 5.7 | 7.5 | 0.00% | 0.25 | 752 | 0.03 |
| 200 | ferriskey | 200 | 24.0 | 39.7 | 52.9 | 0.00% | 0.73 | 182 | 0.88 |
| 200 | keycloak | 200 | 3.3 | 5.4 | 7.7 | 0.00% | 0.44 | 753 | 0.04 |
| 400 | ferriskey | 400 | 30.2 | 62.8 | 97.0 | 0.00% | 1.11 | 182 | 1.47 |
| 400 | keycloak | 400 | 2.9 | 6.0 | 12.3 | 0.00% | 0.74 | 756 | 0.04 |
| 800 | ferriskey | 656 | 426.7 | 604.2 | 765.5 | 0.00% | 1.34 | 187 | 2.46 |
| 800 | keycloak | 800 | 2.6 | 6.0 | 9.6 | 0.00% | 1.13 | 755 | 0.04 |
| 1600 | keycloak | 1601 | 3.3 | 18.4 | 51.3 | 0.00% | 1.77 | 757 | 0.03 |
| 3200 | keycloak | 2389 | 98.0 | 213.1 | 317.3 | 0.00% | 1.99 | 761 | 0.03 |

## jwks

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 100 | ferriskey | 100 | 2.0 | 2.9 | 4.2 | 0.00% | 0.06 | 187 | 1.61 |
| 100 | keycloak | 100 | 3.2 | 5.3 | 7.1 | 0.00% | 0.21 | 758 | 0.03 |
| 200 | ferriskey | 150 | 1.9 | 4907.4 | 9999.7 | 3.22% | 0.09 | 187 | 0.13 |
| 200 | keycloak | 200 | 2.9 | 4.8 | 6.8 | 0.00% | 0.35 | 756 | 0.04 |
| 400 | keycloak | 400 | 2.7 | 5.6 | 9.1 | 0.00% | 0.61 | 756 | 0.04 |
| 800 | keycloak | 800 | 2.4 | 5.3 | 8.1 | 0.00% | 0.92 | 757 | 0.03 |
| 1600 | keycloak | 1600 | 2.9 | 9.0 | 19.6 | 0.00% | 1.47 | 759 | 0.03 |
| 3200 | keycloak | 3049 | 52.2 | 134.7 | 187.2 | 0.00% | 1.98 | 763 | 0.03 |
