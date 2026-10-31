# FerrisKey vs Keycloak

- FerrisKey: `sha-d73af3e`
- Keycloak: `quay.io/keycloak/keycloak:26.8.1`
- System under test: FerrisKey 3 x (1 CPU request, no CPU limit, 1Gi Mi) / Keycloak 1 x (3 CPU request, no CPU limit, 1536Mi, -XX:ActiveProcessorCount=3), alone on a k3d on OrbStack (8 vCPU shared by loadgen, SUT and DB)
- PostgreSQL 17 (CNPG), one per system, 1 CPU request / 3Gi, max_connections 400, on a dedicated node
- 1000 users, 60 s measured per step after 15 s warmup
- Load: k6 open model (constant arrival rate), on a dedicated node

## Memory of the system under test

Working set over every measured step, lowest and highest.

| System | Min (MiB) | Max (MiB) |
|---|---|---|
| ferriskey | 1395 | 1423 |
| keycloak | 595 | 614 |

## Throughput

- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served and p95 <= 250 ms.
- **Peak**: most successful requests per second served by any step, whatever the latency.

| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |
|---|---|---|---|---|---|---|
| password | < lowest step | < lowest step | - | 277 | 155 | 1.78x |

## password

| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |
|---|---|---|---|---|---|---|---|---|---|
| 320 | ferriskey | 277 | 1061.6 | 1449.3 | 1627.4 | 0.00% | 6.41 | 1395 | 0.91 |
| 320 | keycloak | 152 | 2018.2 | 2215.5 | 2265.6 | 0.00% | 3.52 | 595 | 0.08 |
| 640 | ferriskey | 275 | 1090.2 | 1529.7 | 1725.0 | 0.00% | 5.96 | 1423 | 0.92 |
| 640 | keycloak | 155 | 1992.1 | 2076.5 | 2124.4 | 0.00% | 3.40 | 614 | 0.08 |
