# CLAUDE.md - Project Intelligence

## Project Overview

**IAM Performance Tester** is a performance testing suite for benchmarking IAM (Identity & Access Management) systems. It targets **FerrisKey** (Rust) and **Keycloak** (Java) through the same OpenID Connect endpoints.

The suite uses **k6** for load testing, **Python with uv** for test data seeding/cleanup, and **docker compose** to boot either backend from its published image.

## Tech Stack

- **k6** 1.x / 2.x - Load testing framework (scenarios written in JavaScript)
- **Python 3.12+** with **uv** package manager
- **requests** + **python-dotenv** for Python scripts
- **docker compose** profiles: `keycloak` (quay.io/keycloak/keycloak) and `ferriskey` (ghcr.io/ferriskey/ferriskey-api), each with its own PostgreSQL 18
- **GitHub Actions** - CI/CD

## Project Structure

```
IAM-performance-tester/
├── k6/
│   ├── scenarios/           # Performance test scenarios
│   │   ├── token_client_credentials.js   # OAuth2 client credentials grant
│   │   ├── token_password.js             # OAuth2 password grant
│   │   ├── jwks.js                       # JWKS endpoint test
│   │   ├── userinfo.js                   # OpenID Connect userinfo
│   │   └── mixed_workload.js             # Realistic weighted traffic
│   └── lib/                 # Shared k6 libraries
│       ├── config.js        # Thresholds, scenarios, base config
│       ├── auth.js          # Authentication helpers
│       └── data.js          # User pool (SharedArray, sized by USER_COUNT)
├── scripts/                 # Python setup/teardown + shell helpers
│   ├── seed_test_data.py           # Seeding (uses IAM_PROVIDER)
│   ├── cleanup_test_data.py        # Deletes the test realm (uses IAM_PROVIDER)
│   ├── run_all.sh                  # Every scenario in sequence, results per run
│   ├── wait_for_iam.sh             # Polls OIDC discovery until the server is up
│   ├── container_memory_kb.sh      # Memory of a compose service, for the nightly
│   └── lib/                        # Shared Python library
│       ├── __init__.py
│       ├── config.py               # Configuration loading
│       ├── console.py              # Colored output helpers
│       ├── base_provider.py        # Abstract IAMProvider class
│       ├── ferriskey_provider.py   # FerrisKey implementation
│       └── keycloak_provider.py    # Keycloak implementation
├── results/                 # Test output (gitignored)
├── docker-compose.yml       # keycloak / ferriskey profiles
├── .github/workflows/
│   ├── perf-smoke.yml       # PR smoke tests, matrix over both providers
│   └── perf-nightly.yml     # Nightly load + soak + memory tracking
├── .env.example             # Minimal configuration template
├── pyproject.toml           # uv project
└── uv.lock
```

## Key Commands

### Setup
```bash
uv sync                              # Install Python dependencies
cp .env.example .env                 # Create environment config (minimal config needed)
```

### Start a backend (optional)
```bash
docker compose --profile keycloak up -d --wait     # :8080, admin/admin
docker compose --profile ferriskey up -d --wait    # :3333, admin/admin
scripts/wait_for_iam.sh                            # blocks until BASE_URL answers
```
`.env` is also read by compose: `KEYCLOAK_PORT`, `FERRISKEY_PORT`, `KEYCLOAK_VERSION`, `FERRISKEY_VERSION`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`.

### Seed Test Data
```bash
uv run python scripts/seed_test_data.py                      # provider from .env
IAM_PROVIDER=keycloak uv run python scripts/seed_test_data.py

# Seeder auto-generates CLIENT_ID and retrieves CLIENT_SECRET from server
# Creates .env.test with all k6 configuration
```

### Run k6 Tests
```bash
# Use generated .env.test (contains CLIENT_ID, CLIENT_SECRET, USER_COUNT, etc.)
set -a && source .env.test && set +a

# Individual scenarios
k6 run k6/scenarios/token_client_credentials.js
k6 run k6/scenarios/token_password.js
k6 run k6/scenarios/jwks.js
k6 run k6/scenarios/userinfo.js
k6 run k6/scenarios/mixed_workload.js

# With custom VUs and duration
k6 run --env VUS=100 --env DURATION=5m k6/scenarios/mixed_workload.js

# Exercise endpoints without failing on SLOs
k6 run --no-thresholds k6/scenarios/mixed_workload.js

# Whole suite, results in results/<label>-<timestamp>/ (exit code = failed scenarios)
scripts/run_all.sh [ENV_FILE]        # VUS, DURATION, SCENARIOS, K6_FLAGS override
```

### Cleanup
```bash
uv run python scripts/cleanup_test_data.py          # asks for confirmation
uv run python scripts/cleanup_test_data.py --yes    # no prompt
docker compose --profile keycloak --profile ferriskey down -v
```

## Environment Variables

### IAM Provider
| Variable | Description | Default |
|----------|-------------|---------|
| `IAM_PROVIDER` | IAM backend: `ferriskey` or `keycloak` | `ferriskey` |

### Server Connection
| Variable | Description | Default |
|----------|-------------|---------|
| `BASE_URL` | IAM server URL | `http://localhost:3333` (FK) / `http://localhost:8080` (KC) |
| `REQUEST_TIMEOUT` | HTTP request timeout in seconds | `30` |

### Admin Authentication
| Variable | Description | Default |
|----------|-------------|---------|
| `ADMIN_REALM` | Realm for admin authentication | `master` |
| `ADMIN_USERNAME` | Admin username | `admin` |
| `ADMIN_PASSWORD` | Admin password | `admin` |
| `ADMIN_CLIENT_ID` | Client used for the admin password grant (public on both providers) | `admin-cli` |
| `ADMIN_CLIENT_SECRET` | Only if `ADMIN_CLIENT_ID` is confidential | (none) |

### Realm & Client
| Variable | Description | Default |
|----------|-------------|---------|
| `PERF_REALM` | Performance test realm | `perf-realm` (FK) / `perf` (KC) |
| `CLIENT_ID` | OAuth2 client ID (optional, auto-generated) | `perf-client-{random}` |
| `CLIENT_SECRET` | OAuth2 client secret (optional, retrieved from server) | (server-generated) |

### User Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `USER_COUNT` | Number of test users to create (and size of the k6 pool) | `50` |
| `USER_PASSWORD` | Password for all test users | `Perf-User-Pass-2026!` |
| `USER_PREFIX` | Username prefix (e.g., `perf-user-`) | `perf-user-` |
| `USER_FIRSTNAME` | First name for test users | `Perf` |
| `USER_LASTNAME_PREFIX` | Last name prefix (e.g., `User001`) | `User` |
| `USER_EMAIL_PREFIX` | Email prefix (e.g., `perf001@...`) | `perf` |
| `USER_EMAIL_DOMAIN` | Email domain | `test.local` |

### k6 Test Parameters (written to `.env.test` by the seeder)
| Variable | Description | Default |
|----------|-------------|---------|
| `REALM` | Realm k6 targets | `PERF_REALM` |
| `USER_PREFIX`, `USER_COUNT` | User pool for the password grant | from seeder |
| `TEST_USERNAME` | Primary test username | `perf-user-001` |
| `TEST_PASSWORD` | Primary test password | `Perf-User-Pass-2026!` |
| `VUS` | k6 virtual users | `50` |
| `DURATION` | k6 test duration | `5m` |

### docker compose
| Variable | Description | Default |
|----------|-------------|---------|
| `KEYCLOAK_VERSION` | quay.io/keycloak/keycloak tag | `26.8.1` |
| `KEYCLOAK_PORT` | Host port for Keycloak | `8080` |
| `FERRISKEY_VERSION` | ghcr.io/ferriskey/ferriskey-api tag | `latest` |
| `FERRISKEY_PORT` | Host port for FerrisKey | `3333` |
| `POSTGRES_VERSION` | postgres image tag for both databases | `18` |

## SLO Thresholds

| Endpoint | p95 | p99 | Error Rate |
|----------|-----|-----|------------|
| Token | < 100ms | < 250ms | < 1% |
| JWKS | < 20ms | < 50ms | < 0.1% |
| Userinfo | < 50ms | < 100ms | < 1% |

## k6 Scenario Profiles

- **smoke**: 5 VUs, 30s - Quick validation
- **load**: 50 VUs, 5m - Standard load test
- **stress**: Ramp 50→200 VUs, 16m - Find breaking point
- **soak**: 30 VUs, 30m - Memory leak detection

## Test Data Patterns

- Test users: `{USER_PREFIX}001` through `{USER_PREFIX}{USER_COUNT}` (default: `perf-user-001` to `perf-user-050`)
- User emails: `{USER_EMAIL_PREFIX}001@{USER_EMAIL_DOMAIN}` (default: `perf001@test.local`)
- Confidential client: `CLIENT_ID` (random `perf-client-xxxxxxxx`), service account + direct access grants enabled, full scope disabled on Keycloak
- Test realm: configurable via `PERF_REALM`

## API Differences: FerrisKey vs Keycloak

| Operation | FerrisKey | Keycloak |
|-----------|-----------|----------|
| Token endpoint | `/realms/{realm}/protocol/openid-connect/token` | Same |
| Admin API base | `/realms/` | `/admin/realms/` |
| Default port | 3333 | 8080 |
| Admin token client | `admin-cli` (public, in master) | `admin-cli` (public, in master) |
| Client secret | Read from `GET /realms/{r}/clients/{uuid}` | `GET /admin/realms/{r}/clients/{uuid}/client-secret` |
| Realm deletion | `DELETE /realms/{r}` | `DELETE /admin/realms/{r}` |

## CI/CD Workflows

Both workflows run a matrix over `ferriskey` and `keycloak`, boot the backend with `docker compose up -d --wait` (profile via `COMPOSE_PROFILES`), wait with `scripts/wait_for_iam.sh`, seed, then source `.env.test` before each `k6 run`. Each k6 step has `continue-on-error` so every scenario runs; the Summary step fails the job if any did.

### perf-smoke.yml (On PR, manual)
- 20 test users
- Runs: token (5 VUs, 30s), JWKS (5 VUs, 30s), mixed workload (10 VUs, 1m)
- Inputs: `ferriskey_version`, `keycloak_version`
- Artifacts: results + server log, 7-day retention

### perf-nightly.yml (2 AM UTC Daily, manual)
- 200 test users
- Runs: token, password, JWKS, userinfo (5m each), mixed soak (10m)
- Memory of the IAM container sampled every 10s via `docker stats`; growth above 50% is a warning
- Inputs: image tags, `test_duration`, `soak_duration`
- Artifacts: 30-day retention

## Code Patterns

### k6 Custom Metrics
Each scenario defines custom Trend, Rate, and Counter metrics for per-endpoint monitoring:
```javascript
const tokenDuration = new Trend('token_client_credentials_duration');
const tokenErrors = new Rate('token_client_credentials_errors');
```

### Token Caching (userinfo.js)
Tokens are cached per VU with automatic refresh before expiry.

### User Pool Rotation (token_password.js)
Uses SharedArray with random user selection for realistic auth patterns. The pool is `USER_PREFIX` 001..`USER_COUNT`, so it must match what was seeded.

### Think Time
Simulates realistic user behavior with randomized delays between requests.

### IAM Provider Architecture (Python)
The seeding and cleanup scripts use a provider pattern for multi-backend support:
```
IAMProvider (abstract base class)
├── FerrisKeyProvider  # FerrisKey-specific API calls
└── KeycloakProvider   # Keycloak-specific API calls
```
To add a new IAM backend:
1. Create `scripts/lib/newprovider_provider.py` implementing `IAMProvider` (including `delete_realm`)
2. Register it in `scripts/seed_test_data.py` `get_provider()` function
3. Add a compose profile in `docker-compose.yml` and a matrix entry in both workflows

## Adding New Tests

1. Create scenario in `k6/scenarios/`
2. Import helpers from `k6/lib/`
3. Define custom metrics and thresholds
4. Add to mixed_workload.js if applicable
5. Update CI workflows if needed

## Common Issues

- **Token errors**: Check CLIENT_SECRET in .env.test matches seeded client (reseed if the realm was recreated)
- **Connection refused**: Ensure IAM server is running on correct port; `scripts/wait_for_iam.sh` polls until it is
- **User not found / password grant failing for most users**: `USER_COUNT` in `.env.test` must match what was seeded
- **Threshold failures**: May indicate performance regression or server issues; `--no-thresholds` to only check functionality
- **Port 8080 already in use**: set `KEYCLOAK_PORT` in `.env` (compose and seeder both read it when `BASE_URL` matches)
