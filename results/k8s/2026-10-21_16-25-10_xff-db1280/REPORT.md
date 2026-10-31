# FerrisKey vs Keycloak

- FerrisKey: `sha-4a964dd`
- Keycloak: `quay.io/keycloak/keycloak:26.6.4`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 1280Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node
- **Variant**: one X-Forwarded-For per k6 VU, FerrisKey `SERVER_TRUST_FORWARDED_FOR=true`, to measure past the FerrisKey per-IP `/token` in-flight cap
- FerrisKey results: this run (2026-10-21 16:25), DB 1 CPU / 1280Mi, no DB restart.
- Keycloak results: run 2026-10-21 06:35 with DB 1 CPU / 768Mi. Its DB peaked at 244 MiB and 51 connections, so the lower limit never constrained it.
- Keycloak tokens do not need X-Forwarded-For spreading: it has no per-IP cap on /token.

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 27 | 519 |
| keycloak | 511 | 808 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 200 (99) | 400 (113) | 0.50x | 398 | 530 | 0.75x |
| password | 20 (119) | 20 (98) | 1.00x | 45 | 35 | 1.28x |
| refresh | 100 (215) | 200 (31) | 0.50x | 186 | 263 | 0.70x |
| introspect | 1600 (32) | 1600 (84) | 1.00x | 2572 | 2008 | 1.28x |
| userinfo | 400 (169) | 1601 (18) | 0.25x | 600 | 2389 | 0.25x |
| jwks | 3193 (37) | 3049 (135) | 1.05x | 3193 | 3049 | 1.05x |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 27.7 | 46.7 | 60.4 | 0.00% | 0.41 | 27 | 0.50 |
| 50 | keycloak | 50 | 10.6 | 15.0 | 19.2 | 0.00% | 0.44 | 511 | 0.08 |
| 100 | ferriskey | 100 | 27.5 | 49.3 | 76.2 | 0.00% | 0.69 | 28 | 0.75 |
| 100 | keycloak | 100 | 10.3 | 16.5 | 22.8 | 0.00% | 0.58 | 528 | 0.13 |
| 200 | ferriskey | 200 | 36.5 | 98.8 | 178.7 | 0.00% | 1.14 | 34 | 0.79 |
| 200 | keycloak | 200 | 9.9 | 15.9 | 22.9 | 0.00% | 1.14 | 530 | 0.23 |
| 400 | ferriskey | 393 | 314.1 | 716.7 | 961.3 | 0.00% | 1.82 | 60 | 1.71 |
| 400 | keycloak | 400 | 11.6 | 113.4 | 176.0 | 0.00% | 1.85 | 784 | 0.24 |
| 800 | ferriskey | 398 | 728.4 | 963.6 | 1339.2 | 0.00% | 1.83 | 63 | 1.57 |
| 800 | keycloak | 530 | 555.3 | 679.4 | 793.1 | 0.00% | 2.00 | 792 | 0.44 |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 10 | ferriskey | 10 | 86.2 | 110.7 | 158.6 | 0.00% | 0.48 | 70 | 0.26 |
| 10 | keycloak | 10 | 83.8 | 104.8 | 114.9 | 0.00% | 0.74 | 792 | 0.10 |
| 20 | ferriskey | 20 | 85.9 | 119.2 | 141.1 | 0.00% | 1.00 | 77 | 0.39 |
| 20 | keycloak | 20 | 74.7 | 97.8 | 127.1 | 0.00% | 1.26 | 799 | 0.13 |
| 40 | ferriskey | 40 | 107.7 | 431.8 | 529.9 | 0.00% | 1.91 | 141 | 0.69 |
| 40 | keycloak | 35 | 3850.6 | 4360.3 | 4693.0 | 11.06% | 2.00 | 808 | 0.19 |
| 80 | ferriskey | 45 | 7017.8 | 8333.8 | 8805.0 | 0.00% | 1.97 | 417 | 0.53 |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 65.7 | 96.0 | 119.0 | 0.00% | 0.75 | 136 | 0.65 |
| 50 | keycloak | 50 | 8.5 | 24.8 | 29.9 | 0.00% | 0.36 | 731 | 0.07 |
| 100 | ferriskey | 100 | 89.5 | 214.8 | 343.4 | 0.00% | 1.33 | 289 | 1.11 |
| 100 | keycloak | 100 | 8.1 | 24.2 | 30.9 | 0.00% | 0.78 | 734 | 0.08 |
| 200 | ferriskey | 186 | 1471.9 | 1903.9 | 2149.7 | 0.00% | 1.94 | 331 | 1.48 |
| 200 | keycloak | 200 | 8.6 | 31.3 | 63.7 | 0.00% | 1.47 | 751 | 0.17 |
| 400 | ferriskey | 176 | 1716.0 | 2098.3 | 2254.1 | 0.00% | 1.63 | 234 | 1.51 |
| 400 | keycloak | 263 | 1101.0 | 1408.1 | 1506.8 | 0.09% | 2.00 | 755 | 0.71 |

## introspect

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 6.7 | 12.1 | 17.8 | 0.00% | 0.10 | 240 | 0.12 |
| 50 | keycloak | 50 | 4.1 | 6.5 | 8.6 | 0.00% | 0.16 | 750 | 0.03 |
| 100 | ferriskey | 100 | 6.3 | 10.2 | 14.5 | 0.00% | 0.18 | 254 | 0.15 |
| 100 | keycloak | 100 | 3.9 | 6.3 | 8.5 | 0.00% | 0.33 | 751 | 0.03 |
| 200 | ferriskey | 200 | 6.1 | 10.8 | 15.8 | 0.00% | 0.34 | 435 | 0.28 |
| 200 | keycloak | 200 | 3.5 | 5.8 | 8.3 | 0.00% | 0.49 | 752 | 0.04 |
| 400 | ferriskey | 400 | 6.5 | 14.7 | 26.2 | 0.00% | 0.59 | 425 | 0.52 |
| 400 | keycloak | 400 | 3.3 | 6.8 | 10.3 | 0.00% | 0.91 | 756 | 0.04 |
| 800 | ferriskey | 800 | 7.2 | 15.8 | 23.8 | 0.00% | 0.88 | 411 | 0.78 |
| 800 | keycloak | 800 | 3.1 | 8.0 | 13.6 | 0.00% | 1.33 | 756 | 0.05 |
| 1600 | ferriskey | 1600 | 10.6 | 32.1 | 58.1 | 0.00% | 1.33 | 519 | 1.28 |
| 1600 | keycloak | 1600 | 4.9 | 84.4 | 190.3 | 0.00% | 1.95 | 756 | 0.04 |
| 3200 | ferriskey | 2572 | 95.7 | 179.4 | 273.1 | 0.00% | 1.73 | 434 | 1.98 |
| 3200 | keycloak | 2008 | 143.8 | 191.4 | 219.2 | 0.00% | 2.00 | 756 | 0.03 |

## userinfo

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 27.8 | 45.6 | 58.5 | 0.00% | 0.34 | 214 | 0.38 |
| 50 | keycloak | 50 | 3.7 | 5.8 | 8.1 | 0.00% | 0.14 | 751 | 0.03 |
| 100 | ferriskey | 100 | 33.1 | 57.6 | 71.2 | 0.00% | 0.57 | 250 | 0.59 |
| 100 | keycloak | 100 | 3.6 | 5.7 | 7.5 | 0.00% | 0.25 | 752 | 0.03 |
| 200 | ferriskey | 200 | 46.7 | 103.6 | 210.0 | 0.00% | 0.93 | 349 | 0.96 |
| 200 | keycloak | 200 | 3.3 | 5.4 | 7.7 | 0.00% | 0.44 | 753 | 0.04 |
| 400 | ferriskey | 400 | 63.6 | 168.7 | 391.2 | 0.00% | 1.40 | 412 | 1.76 |
| 400 | keycloak | 400 | 2.9 | 6.0 | 12.3 | 0.00% | 0.74 | 756 | 0.04 |
| 800 | ferriskey | 600 | 485.7 | 625.4 | 759.2 | 0.00% | 1.76 | 231 | 2.22 |
| 800 | keycloak | 800 | 2.6 | 6.0 | 9.6 | 0.00% | 1.13 | 755 | 0.04 |
| 1600 | keycloak | 1601 | 3.3 | 18.4 | 51.3 | 0.00% | 1.77 | 757 | 0.03 |
| 3200 | keycloak | 2389 | 98.0 | 213.1 | 317.3 | 0.00% | 1.99 | 761 | 0.03 |

## jwks

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 100 | ferriskey | 100 | 2.3 | 4.0 | 6.1 | 0.00% | 0.08 | 230 | 0.04 |
| 100 | keycloak | 100 | 3.2 | 5.3 | 7.1 | 0.00% | 0.21 | 758 | 0.03 |
| 200 | ferriskey | 200 | 2.2 | 3.8 | 5.7 | 0.00% | 0.14 | 230 | 0.04 |
| 200 | keycloak | 200 | 2.9 | 4.8 | 6.8 | 0.00% | 0.35 | 756 | 0.04 |
| 400 | ferriskey | 400 | 1.9 | 3.6 | 6.1 | 0.00% | 0.22 | 230 | 0.05 |
| 400 | keycloak | 400 | 2.7 | 5.6 | 9.1 | 0.00% | 0.61 | 756 | 0.04 |
| 800 | ferriskey | 800 | 1.8 | 4.6 | 9.0 | 0.00% | 0.39 | 230 | 0.04 |
| 800 | keycloak | 800 | 2.4 | 5.3 | 8.1 | 0.00% | 0.92 | 757 | 0.03 |
| 1600 | ferriskey | 1600 | 2.0 | 6.9 | 13.8 | 0.00% | 0.68 | 230 | 0.05 |
| 1600 | keycloak | 1600 | 2.9 | 9.0 | 19.6 | 0.00% | 1.47 | 759 | 0.03 |
| 3200 | ferriskey | 3193 | 3.5 | 36.6 | 68.5 | 0.00% | 1.07 | 230 | 0.05 |
| 3200 | keycloak | 3049 | 52.2 | 134.7 | 187.2 | 0.00% | 1.98 | 763 | 0.03 |
