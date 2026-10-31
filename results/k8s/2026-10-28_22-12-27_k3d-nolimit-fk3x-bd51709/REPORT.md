# FerrisKey vs Keycloak

- FerrisKey: `sha-bd51709`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 3 x (1 CPU request, no CPU limit, 1Gi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 198 | 1460 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 3196 (13) | < lowest step | - | 3196 | - | - |
| password | 159 (84) | < lowest step | - | 159 | - | - |
| refresh | 801 (96) | < lowest step | - | 1114 | - | - |
| introspect | 6396 (3) | < lowest step | - | 6396 | - | - |
| userinfo | 6380 (10) | < lowest step | - | 6380 | - | - |
| jwks | 6399 (2) | < lowest step | - | 6399 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 1.7 | 6.2 | 8.0 | 0.00% | 0.12 | 198 | 0.02 |
| 100 | ferriskey | 100 | 1.5 | 4.7 | 5.6 | 0.00% | 0.19 | 198 | 0.03 |
| 200 | ferriskey | 200 | 1.4 | 3.3 | 4.2 | 0.00% | 0.27 | 199 | 0.05 |
| 400 | ferriskey | 400 | 1.3 | 2.7 | 3.7 | 0.00% | 0.41 | 200 | 0.05 |
| 800 | ferriskey | 799 | 1.2 | 2.5 | 13.7 | 0.00% | 0.80 | 208 | 0.10 |
| 1600 | ferriskey | 1597 | 1.4 | 3.3 | 43.4 | 0.00% | 1.58 | 215 | 0.19 |
| 3200 | ferriskey | 3196 | 2.5 | 13.0 | 61.4 | 0.00% | 2.92 | 227 | 0.37 |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 10 | ferriskey | 10 | 24.7 | 33.6 | 36.9 | 0.00% | 0.16 | 280 | 0.05 |
| 20 | ferriskey | 20 | 23.5 | 26.8 | 31.9 | 0.00% | 0.31 | 279 | 0.08 |
| 40 | ferriskey | 40 | 23.7 | 28.0 | 37.3 | 0.00% | 0.60 | 286 | 0.13 |
| 80 | ferriskey | 80 | 24.3 | 31.6 | 48.4 | 0.00% | 1.24 | 307 | 0.25 |
| 160 | ferriskey | 159 | 28.0 | 83.7 | 267.3 | 0.00% | 2.88 | 538 | 0.50 |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 9.7 | 13.9 | 16.3 | 0.00% | 0.20 | 580 | 0.10 |
| 100 | ferriskey | 100 | 9.2 | 11.9 | 17.2 | 0.00% | 0.34 | 580 | 0.16 |
| 200 | ferriskey | 200 | 8.9 | 12.9 | 24.2 | 0.00% | 0.69 | 580 | 0.30 |
| 400 | ferriskey | 400 | 8.2 | 14.4 | 30.8 | 0.00% | 1.33 | 615 | 0.51 |
| 800 | ferriskey | 801 | 15.6 | 96.4 | 161.8 | 0.00% | 2.88 | 936 | 1.08 |
| 1600 | ferriskey | 1114 | 262.5 | 366.7 | 455.4 | 0.00% | 3.70 | 1234 | 1.49 |

## introspect

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 1.1 | 3.2 | 4.9 | 0.00% | 0.04 | 1232 | 0.03 |
| 100 | ferriskey | 100 | 0.8 | 2.7 | 4.0 | 0.00% | 0.06 | 1232 | 0.05 |
| 200 | ferriskey | 200 | 0.7 | 2.2 | 3.5 | 0.00% | 0.11 | 1233 | 0.07 |
| 400 | ferriskey | 400 | 0.7 | 2.0 | 3.3 | 0.00% | 0.18 | 1233 | 0.10 |
| 800 | ferriskey | 800 | 0.6 | 1.6 | 2.7 | 0.00% | 0.26 | 1268 | 0.14 |
| 1600 | ferriskey | 1600 | 0.6 | 1.8 | 3.6 | 0.00% | 0.35 | 1358 | 0.22 |
| 3200 | ferriskey | 3198 | 0.5 | 1.6 | 4.3 | 0.00% | 0.58 | 1387 | 0.38 |
| 6400 | ferriskey | 6396 | 0.7 | 2.8 | 8.2 | 0.00% | 1.05 | 1424 | 0.73 |

## userinfo

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 1.8 | 4.8 | 6.7 | 0.00% | 0.06 | 1422 | 0.05 |
| 100 | ferriskey | 100 | 1.5 | 4.0 | 5.8 | 0.00% | 0.11 | 1421 | 0.07 |
| 200 | ferriskey | 200 | 1.0 | 2.9 | 4.3 | 0.00% | 0.15 | 1425 | 0.09 |
| 400 | ferriskey | 400 | 0.9 | 2.4 | 3.8 | 0.00% | 0.24 | 1426 | 0.14 |
| 800 | ferriskey | 800 | 0.9 | 2.2 | 3.7 | 0.00% | 0.37 | 1426 | 0.22 |
| 1600 | ferriskey | 1600 | 0.8 | 1.9 | 4.2 | 0.00% | 0.58 | 1460 | 0.37 |
| 3200 | ferriskey | 3196 | 1.0 | 3.3 | 9.4 | 0.00% | 1.06 | 1426 | 0.71 |
| 6400 | ferriskey | 6380 | 1.9 | 10.1 | 31.0 | 0.00% | 1.73 | 1431 | 1.37 |

## jwks

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 100 | ferriskey | 100 | 0.5 | 1.4 | 2.4 | 0.00% | 0.03 | 1434 | 0.01 |
| 200 | ferriskey | 200 | 0.4 | 1.3 | 2.5 | 0.00% | 0.06 | 1434 | 0.02 |
| 400 | ferriskey | 400 | 0.4 | 1.3 | 2.3 | 0.00% | 0.10 | 1435 | 0.01 |
| 800 | ferriskey | 800 | 0.3 | 1.2 | 2.3 | 0.00% | 0.14 | 1433 | 0.01 |
| 1600 | ferriskey | 1600 | 0.3 | 1.1 | 2.2 | 0.00% | 0.19 | 1433 | 0.01 |
| 3200 | ferriskey | 3200 | 0.3 | 1.2 | 2.6 | 0.00% | 0.28 | 1433 | 0.01 |
| 6400 | ferriskey | 6399 | 0.4 | 1.5 | 3.2 | 0.00% | 0.43 | 1434 | 0.01 |
