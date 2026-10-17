# IAM Performance Tester

Performance testing suite for [FerrisKey](https://github.com/ferriskey/ferriskey) and [Keycloak](https://www.keycloak.org/) using [k6](https://k6.io/).

## Features

- **Token Endpoint** - OAuth2 client credentials and password grants
- **JWKS Endpoint** - JSON Web Key Set retrieval
- **Userinfo Endpoint** - OpenID Connect userinfo
- **Mixed Workload** - Realistic traffic patterns
- **Multi-Provider** - Works with FerrisKey and Keycloak
- **Batteries included** - `docker compose` profiles boot either backend from its published image

## Prerequisites

- [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) 1.x or 2.x
- [uv](https://docs.astral.sh/uv/) (Python package manager, downloads Python 3.12+ on demand)
- Docker with Compose v2 (only if you want the bundled IAM backends)

## Quick Start

### 1. Setup

```bash
git clone https://github.com/ferriskey/IAM-performance-tester.git
cd IAM-performance-tester

uv sync
cp .env.example .env
```

### 2. Start an IAM backend

Bring your own server, or boot one from the published images:

```bash
# Keycloak 26.8.1 on http://localhost:8080 (admin/admin)
docker compose --profile keycloak up -d --wait

# FerrisKey latest on http://localhost:3333 (admin/admin)
docker compose --profile ferriskey up -d --wait
```

Pick `KEYCLOAK_PORT`, `FERRISKEY_PORT`, `KEYCLOAK_VERSION` or `FERRISKEY_VERSION` in `.env` to change ports or image tags.

### 3. Configure `.env`

```bash
# IAM provider: "ferriskey" or "keycloak"
IAM_PROVIDER=keycloak

# Server URL
BASE_URL=http://localhost:8080

# Admin credentials
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin
```

That's it. The seeder authenticates through the public `admin-cli` client both providers ship, auto-generates `CLIENT_ID` and retrieves `CLIENT_SECRET` from the server.

### 4. Seed Test Data

```bash
scripts/wait_for_iam.sh            # optional, blocks until the server answers
uv run python scripts/seed_test_data.py
```

This will:
1. Create a performance test realm
2. Create a confidential test client (auto-generated ID)
3. Retrieve the client secret from the server
4. Create test users (`USER_COUNT`, default 50)
5. Generate `.env.test` with all k6 configuration

### 5. Run Performance Tests

```bash
# Use the generated .env.test
set -a && source .env.test && set +a

# Run tests
k6 run k6/scenarios/token_client_credentials.js
k6 run k6/scenarios/token_password.js
k6 run k6/scenarios/jwks.js
k6 run k6/scenarios/userinfo.js
k6 run k6/scenarios/mixed_workload.js

# With custom VUs and duration
k6 run --env VUS=100 --env DURATION=5m k6/scenarios/mixed_workload.js
```

Or run the whole suite in one go. Results land in `results/<label>-<timestamp>/` with a summary JSON and a log per scenario:

```bash
scripts/run_all.sh                                   # all five scenarios, VUS/DURATION from .env.test
VUS=100 DURATION=10m scripts/run_all.sh              # heavier
SCENARIOS="jwks userinfo" scripts/run_all.sh         # a subset
K6_FLAGS="--no-thresholds" scripts/run_all.sh        # exercise endpoints without failing on SLOs
scripts/run_all.sh .env.test.keycloak                # another seeded config
```

### 6. Cleanup (Optional)

```bash
uv run python scripts/cleanup_test_data.py          # deletes the test realm, asks first
uv run python scripts/cleanup_test_data.py --yes    # no prompt (CI)

docker compose --profile keycloak --profile ferriskey down -v
```

## Project Structure

```
IAM-performance-tester/
├── k6/
│   ├── scenarios/           # Test scenarios
│   │   ├── token_client_credentials.js
│   │   ├── token_password.js
│   │   ├── jwks.js
│   │   ├── userinfo.js
│   │   └── mixed_workload.js
│   └── lib/                 # Shared libraries
│       ├── config.js
│       ├── auth.js
│       └── data.js
├── scripts/
│   ├── seed_test_data.py        # Seeder (uses IAM_PROVIDER)
│   ├── cleanup_test_data.py     # Deletes the test realm (uses IAM_PROVIDER)
│   ├── run_all.sh               # Runs every scenario, keeps results per run
│   ├── wait_for_iam.sh          # Polls OIDC discovery until the server is up
│   ├── container_memory_kb.sh   # Memory of a compose service (nightly CI)
│   └── lib/                     # Provider implementations
│       ├── base_provider.py
│       ├── ferriskey_provider.py
│       └── keycloak_provider.py
├── docker-compose.yml       # keycloak / ferriskey profiles
├── .env.example             # Minimal configuration template
├── .env.test                # Generated k6 configuration (after seeding)
└── README.md
```

## Configuration

### Seeder Configuration (`.env`)

| Variable | Description | Default |
|----------|-------------|---------|
| `IAM_PROVIDER` | `ferriskey` or `keycloak` | `ferriskey` |
| `BASE_URL` | Server URL | `localhost:3333` (FK) / `localhost:8080` (KC) |
| `ADMIN_USERNAME` | Admin username | `admin` |
| `ADMIN_PASSWORD` | Admin password | `admin` |
| `ADMIN_REALM` | Realm holding the admin user | `master` |
| `ADMIN_CLIENT_ID` | Client used for the admin token | `admin-cli` |
| `PERF_REALM` | Test realm name | `perf-realm` (FK) / `perf` (KC) |
| `USER_COUNT` | Number of test users | `50` |
| `USER_PASSWORD` | Test user password | `Perf-User-Pass-2026!` |

### Generated k6 Configuration (`.env.test`)

After seeding, `.env.test` contains everything k6 needs:

```bash
BASE_URL=http://localhost:8080
REALM=perf
CLIENT_ID=perf-client-abc123    # Auto-generated
CLIENT_SECRET=xK9mLp2n...       # Retrieved from server
USER_PREFIX=perf-user-
USER_COUNT=50                   # k6 draws password-grant users from this pool
TEST_USERNAME=perf-user-001
TEST_PASSWORD=Perf-User-Pass-2026!
VUS=50
DURATION=5m
```

## Test Scenarios

| Scenario | Description | p95 Threshold |
|----------|-------------|---------------|
| `token_client_credentials.js` | OAuth2 client credentials grant | < 100ms |
| `token_password.js` | OAuth2 password grant | < 150ms |
| `jwks.js` | JWKS endpoint | < 20ms |
| `userinfo.js` | OpenID Connect userinfo | < 50ms |
| `mixed_workload.js` | Weighted mix (40% CC, 20% PW, 30% UI, 10% JWKS) | varies |

Thresholds live in `k6/lib/config.js`. k6 exits non-zero when one fails; pass `--no-thresholds` to only exercise the endpoints.

## CI

- **Performance Smoke Test** (`perf-smoke.yml`): on every pull request, for both providers. Boots the backend with `docker compose`, seeds 20 users, runs 30s token and JWKS tests plus a 1m mixed workload.
- **Performance Nightly** (`perf-nightly.yml`): 2 AM UTC, for both providers. 5m load tests per scenario, 10m mixed soak, memory growth of the IAM container recorded every 10s and flagged above 50%.

Both can be triggered by hand with custom image tags (and durations for the nightly).

## Troubleshooting

### "Failed to get admin token"

1. Check the server is running at `BASE_URL` (`scripts/wait_for_iam.sh` tells you when it is)
2. Verify admin credentials
3. Ensure `ADMIN_REALM=master` unless your admin lives elsewhere

### "Connection refused"

Check the `BASE_URL` in your `.env` matches where your IAM server is running.

### k6 "undefined" errors

Make sure to source `.env.test` before running k6:
```bash
set -a && source .env.test && set +a && k6 run ...
```

### Password grant fails for most users

k6 draws users from `USER_PREFIX` 001 to `USER_COUNT`. Both come from `.env.test`; reseed after changing `USER_COUNT`.

## License

MIT License - see [LICENSE](LICENSE)
