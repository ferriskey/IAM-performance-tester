// Open-model benchmark of one OIDC operation at a fixed arrival rate.
// Same script for FerrisKey and Keycloak: only BASE_URL and the client secret differ.
//
// Env: SCENARIO (client_credentials|password|refresh|introspect|userinfo|jwks),
//      RATE (req/s), DURATION (s, measured), WARMUP (s, not measured), MAX_VUS,
//      BASE_URL, REALM, CLIENT_ID, CLIENT_SECRET, USER_COUNT, USER_PREFIX, USER_PASSWORD,
//      SPREAD_IPS (true: each VU sends its own X-Forwarded-For, see k8s/README.md).
//
// Only the operation under test is recorded in op_duration / op_errors / op_ok.
// Helper calls (getting a token to introspect, refresh or call userinfo) are not.
// The result is printed as one JSON line between BENCH_RESULT markers.

import http from 'k6/http';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';

const SCENARIO = __ENV.SCENARIO;
const RATE = Number(__ENV.RATE || 100);
const DURATION = Number(__ENV.DURATION || 60);
const WARMUP = Number(__ENV.WARMUP || 15);
const MAX_VUS = Number(__ENV.MAX_VUS || 300);

const BASE_URL = __ENV.BASE_URL;
const REALM = __ENV.REALM;
const CLIENT_ID = __ENV.CLIENT_ID;
const CLIENT_SECRET = __ENV.CLIENT_SECRET;
const USER_COUNT = Number(__ENV.USER_COUNT || 1000);
const USER_PREFIX = __ENV.USER_PREFIX || 'perf-user-';
const USER_PASSWORD = __ENV.USER_PASSWORD || 'Bench@FerrisKey2024!';

const OIDC = `${BASE_URL}/realms/${REALM}/protocol/openid-connect`;
// One fake client address per VU, so per-IP limits see many clients instead of one pod.
const XFF = __ENV.SPREAD_IPS === 'true'
  ? { 'X-Forwarded-For': `10.${(__VU >> 16) & 255}.${(__VU >> 8) & 255}.${__VU & 255}` }
  : {};
const FORM = { headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...XFF }, timeout: '10s' };

const opDuration = new Trend('op_duration', true);
const opDurationOk = new Trend('op_duration_ok', true);
const opErrors = new Rate('op_errors');
const opOk = new Counter('op_ok');
const opShed = new Counter('op_shed');

export const options = {
  discardResponseBodies: false,
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  scenarios: {
    bench: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: `${WARMUP + DURATION}s`,
      preAllocatedVUs: Number(__ENV.PRE_VUS) || Math.min(Math.max(Math.ceil(RATE / 10), 10), MAX_VUS),
      maxVUs: MAX_VUS,
    },
  },
};

function randomUser() {
  const n = 1 + Math.floor(Math.random() * USER_COUNT);
  return `${USER_PREFIX}${String(n).padStart(3, '0')}`;
}

function passwordGrant() {
  return http.post(`${OIDC}/token`, {
    grant_type: 'password',
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    username: randomUser(),
    password: USER_PASSWORD,
    scope: 'openid',
  }, FORM);
}

function clientCredentialsGrant() {
  return http.post(`${OIDC}/token`, {
    grant_type: 'client_credentials',
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
  }, FORM);
}

function json(res, field) {
  try {
    return res.json(field);
  } catch (_) {
    return undefined;
  }
}

// Per-VU state, reused across iterations.
let accessToken = null;
let accessTokenExpiry = 0;
let refreshTokenValue = null;

function userAccessToken() {
  if (!accessToken || Date.now() > accessTokenExpiry) {
    const res = passwordGrant();
    accessToken = json(res, 'access_token') || null;
    accessTokenExpiry = Date.now() + ((json(res, 'expires_in') || 60) - 10) * 1000;
  }
  return accessToken;
}

const operations = {
  client_credentials() {
    const res = clientCredentialsGrant();
    return [res, res.status === 200 && !!json(res, 'access_token')];
  },

  password() {
    const res = passwordGrant();
    return [res, res.status === 200 && !!json(res, 'access_token')];
  },

  refresh() {
    if (!refreshTokenValue) {
      refreshTokenValue = json(passwordGrant(), 'refresh_token') || null;
      if (!refreshTokenValue) return [null, false];
    }
    const res = http.post(`${OIDC}/token`, {
      grant_type: 'refresh_token',
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      refresh_token: refreshTokenValue,
    }, FORM);
    const next = json(res, 'refresh_token');
    refreshTokenValue = res.status === 200 && next ? next : null;
    return [res, res.status === 200 && !!json(res, 'access_token')];
  },

  // A user token: Keycloak reports client_credentials tokens as inactive (no session).
  introspect() {
    const token = userAccessToken();
    if (!token) return [null, false];
    const res = http.post(`${OIDC}/token/introspect`, {
      token,
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
    }, FORM);
    return [res, res.status === 200 && json(res, 'active') === true];
  },

  userinfo() {
    const token = userAccessToken();
    if (!token) return [null, false];
    const res = http.get(`${OIDC}/userinfo`, {
      headers: { Authorization: `Bearer ${token}`, ...XFF },
      timeout: '10s',
    });
    if (res.status === 401) accessToken = null;
    return [res, res.status === 200 && !!json(res, 'sub')];
  },

  jwks() {
    const res = http.get(`${OIDC}/certs`, { headers: XFF, timeout: '10s' });
    const keys = json(res, 'keys');
    return [res, res.status === 200 && Array.isArray(keys) && keys.length > 0];
  },
};

export function setup() {
  if (!operations[SCENARIO]) throw new Error(`unknown SCENARIO ${SCENARIO}`);
  const res = clientCredentialsGrant();
  if (res.status !== 200) throw new Error(`client login failed: ${res.status} ${res.body}`);
}

export default function () {
  const [res, ok] = operations[SCENARIO]();
  const measured = Date.now() - exec.scenario.startTime >= WARMUP * 1000;
  if (!measured) return;
  if (res) opDuration.add(res.timings.duration);
  opErrors.add(!ok);
  if (res && res.status === 503) opShed.add(1);
  if (ok) {
    opOk.add(1);
    opDurationOk.add(res.timings.duration);
  }
  if (!ok && res && Math.random() < 0.01) {
    console.warn(`${SCENARIO} failed: ${res.status} ${String(res.body).slice(0, 200)}`);
  }
}

export function handleSummary(data) {
  const m = data.metrics;
  const trend = (m.op_duration && m.op_duration.values) || {};
  const trendOk = (m.op_duration_ok && m.op_duration_ok.values) || {};
  const ok = (m.op_ok && m.op_ok.values.count) || 0;
  const result = {
    system: __ENV.SYSTEM,
    scenario: SCENARIO,
    target_rps: RATE,
    duration_s: DURATION,
    window_end_ms: Date.now(),
    achieved_rps: ok / DURATION,
    shed: (m.op_shed && m.op_shed.values.count) || 0,
    error_rate: (m.op_errors && m.op_errors.values.rate) || 0,
    dropped_iterations: (m.dropped_iterations && m.dropped_iterations.values.count) || 0,
    vus_max: (m.vus_max && m.vus_max.values.max) || 0,
    latency_ms: {
      avg: trend.avg, min: trend.min, p50: trend.med, p90: trend['p(90)'],
      p95: trend['p(95)'], p99: trend['p(99)'], max: trend.max,
    },
    latency_ok_ms: { p50: trendOk.med, p95: trendOk['p(95)'], p99: trendOk['p(99)'] },
  };
  return { stdout: `BENCH_RESULT_BEGIN\n${JSON.stringify(result)}\nBENCH_RESULT_END\n` };
}
