# FerrisKey vs Keycloak

- FerrisKey: `sha-bd51709`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 1 x (3 CPU request, no CPU limit, 1536Mi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 93 | 666 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 3196 (29) | < lowest step | - | 3196 | - | - |
| password | 160 (67) | < lowest step | - | 160 | - | - |
| refresh | 800 (64) | < lowest step | - | 934 | - | - |
| introspect | 6400 (3) | < lowest step | - | 6400 | - | - |
| userinfo | 6390 (13) | < lowest step | - | 6390 | - | - |
| jwks | 6398 (2) | < lowest step | - | 6398 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 2.1 | 6.3 | 7.9 | 0.00% | 0.12 | 93 | 0.03 |
| 100 | ferriskey | 100 | 1.7 | 4.8 | 5.7 | 0.00% | 0.21 | 93 | 0.03 |
| 200 | ferriskey | 200 | 1.4 | 3.4 | 4.2 | 0.00% | 0.29 | 94 | 0.04 |
| 400 | ferriskey | 400 | 1.3 | 2.9 | 4.0 | 0.00% | 0.44 | 95 | 0.06 |
| 800 | ferriskey | 800 | 1.2 | 2.1 | 3.3 | 0.00% | 0.76 | 97 | 0.09 |
| 1600 | ferriskey | 1597 | 1.3 | 2.9 | 8.7 | 0.00% | 1.48 | 109 | 0.17 |
| 3200 | ferriskey | 3196 | 2.5 | 29.2 | 64.9 | 0.12% | 2.97 | 123 | 0.34 |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 10 | ferriskey | 10 | 24.8 | 34.4 | 37.6 | 0.00% | 0.13 | 137 | 0.04 |
| 20 | ferriskey | 20 | 23.5 | 27.7 | 31.7 | 0.00% | 0.30 | 144 | 0.07 |
| 40 | ferriskey | 40 | 23.7 | 28.4 | 36.8 | 0.00% | 0.52 | 151 | 0.12 |
| 80 | ferriskey | 80 | 24.1 | 31.1 | 44.3 | 0.00% | 1.24 | 158 | 0.22 |
| 160 | ferriskey | 160 | 28.1 | 67.0 | 160.7 | 0.00% | 2.88 | 263 | 0.49 |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 9.7 | 13.5 | 20.8 | 0.00% | 0.20 | 263 | 0.10 |
| 100 | ferriskey | 100 | 9.4 | 12.7 | 19.3 | 0.00% | 0.35 | 263 | 0.13 |
| 200 | ferriskey | 200 | 8.8 | 11.7 | 15.5 | 0.00% | 0.57 | 263 | 0.26 |
| 400 | ferriskey | 400 | 8.2 | 17.6 | 55.0 | 0.00% | 1.29 | 282 | 0.51 |
| 800 | ferriskey | 800 | 12.8 | 63.6 | 154.2 | 0.00% | 2.62 | 426 | 0.99 |
| 1600 | ferriskey | 934 | 314.3 | 373.4 | 451.9 | 0.00% | 3.08 | 502 | 1.14 |

## introspect

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 1.1 | 3.1 | 4.5 | 0.00% | 0.04 | 470 | 0.03 |
| 100 | ferriskey | 100 | 1.1 | 2.9 | 4.6 | 0.00% | 0.07 | 472 | 0.05 |
| 200 | ferriskey | 200 | 0.8 | 2.3 | 3.8 | 0.00% | 0.12 | 479 | 0.07 |
| 400 | ferriskey | 400 | 0.7 | 2.0 | 3.3 | 0.00% | 0.17 | 479 | 0.10 |
| 800 | ferriskey | 800 | 0.6 | 1.8 | 3.0 | 0.00% | 0.25 | 486 | 0.14 |
| 1600 | ferriskey | 1600 | 0.6 | 1.9 | 4.0 | 0.00% | 0.37 | 487 | 0.23 |
| 3200 | ferriskey | 3199 | 0.5 | 1.8 | 6.8 | 0.00% | 0.51 | 565 | 0.35 |
| 6400 | ferriskey | 6400 | 0.9 | 3.2 | 6.8 | 0.00% | 0.91 | 558 | 0.55 |

## userinfo

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 1.8 | 5.1 | 7.3 | 0.00% | 0.07 | 511 | 0.05 |
| 100 | ferriskey | 100 | 1.4 | 4.1 | 5.8 | 0.00% | 0.12 | 511 | 0.06 |
| 200 | ferriskey | 200 | 1.1 | 2.9 | 4.3 | 0.00% | 0.17 | 511 | 0.09 |
| 400 | ferriskey | 400 | 1.0 | 2.6 | 4.0 | 0.00% | 0.24 | 515 | 0.14 |
| 800 | ferriskey | 800 | 0.9 | 2.4 | 4.6 | 0.00% | 0.36 | 523 | 0.22 |
| 1600 | ferriskey | 1600 | 0.8 | 1.9 | 3.9 | 0.00% | 0.47 | 548 | 0.35 |
| 3200 | ferriskey | 3200 | 0.9 | 2.8 | 5.8 | 0.00% | 0.96 | 570 | 0.64 |
| 6400 | ferriskey | 6390 | 1.6 | 12.8 | 34.2 | 0.00% | 1.84 | 666 | 0.96 |

## jwks

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 100 | ferriskey | 100 | 0.5 | 1.3 | 2.1 | 0.00% | 0.03 | 653 | 0.01 |
| 200 | ferriskey | 200 | 0.4 | 1.3 | 2.0 | 0.00% | 0.05 | 653 | 0.02 |
| 400 | ferriskey | 400 | 0.3 | 1.3 | 2.4 | 0.00% | 0.07 | 654 | 0.01 |
| 800 | ferriskey | 800 | 0.3 | 1.3 | 2.4 | 0.00% | 0.11 | 653 | 0.01 |
| 1600 | ferriskey | 1600 | 0.4 | 1.4 | 2.6 | 0.00% | 0.21 | 653 | 0.01 |
| 3200 | ferriskey | 3200 | 0.4 | 1.4 | 2.6 | 0.00% | 0.29 | 653 | 0.01 |
| 6400 | ferriskey | 6398 | 0.5 | 2.0 | 3.6 | 0.00% | 0.52 | 651 | 0.01 |
