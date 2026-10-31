# FerrisKey vs Keycloak

- FerrisKey: `sha-4a964dd`
- Keycloak: `quay.io/keycloak/keycloak:26.6.4`
- System under test: 2 CPU / 1536Mi (Guaranteed), alone on a Scaleway DEV1-M (3 vCPU, 4 GB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU / 768Mi, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node
- **Variant**: one X-Forwarded-For per k6 VU, FerrisKey `SERVER_TRUST_FORWARDED_FOR=true`, to measure past the FerrisKey per-IP `/token` in-flight cap

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 47 | 225 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| client_credentials | 200 (69) | < lowest step | - | 411 | - | - |
| password | 10 (139) | < lowest step | - | 15 | - | - |
| refresh | 100 (159) | < lowest step | - | 179 | - | - |

## client_credentials

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 24.2 | 39.6 | 52.9 | 0.00% | 0.39 | 47 | 0.46 |
| 100 | ferriskey | 100 | 27.3 | 49.2 | 92.5 | 0.00% | 0.72 | 47 | 0.77 |
| 200 | ferriskey | 200 | 38.1 | 69.1 | 89.6 | 0.00% | 1.18 | 47 | 1.19 |
| 400 | ferriskey | 399 | 124.3 | 295.3 | 401.3 | 0.00% | 1.83 | 50 | 1.64 |
| 800 | ferriskey | 411 | 709.2 | 963.2 | 1126.5 | 0.00% | 1.82 | 63 | 1.69 |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 10 | ferriskey | 10 | 90.5 | 139.3 | 244.3 | 0.00% | 0.43 | 70 | 0.51 |
| 20 | ferriskey | 15 | 267.5 | 9999.5 | 10000.6 | 14.30% | 0.52 | 77 | 1.80 |

## refresh

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 50 | ferriskey | 50 | 67.9 | 113.8 | 146.7 | 0.00% | 0.73 | 175 | 0.58 |
| 100 | ferriskey | 100 | 85.4 | 159.4 | 218.9 | 0.00% | 1.31 | 225 | 0.81 |
| 200 | ferriskey | 179 | 1545.1 | 1974.2 | 2223.5 | 0.00% | 1.90 | 185 | 1.52 |
