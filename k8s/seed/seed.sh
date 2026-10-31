#!/bin/sh
# Seeds the same test data in FerrisKey or Keycloak through the admin API:
#   realm $REALM, confidential client $CLIENT_ID (service account + password grant),
#   users ${USER_PREFIX}001..N with password $USER_PASSWORD.
# Then stores the connection details in Secret bench-${SYSTEM} for the k6 Jobs.
# Idempotent: existing realm, client and users are kept.
set -eu

: "${SYSTEM:?}" "${ADMIN_PASSWORD:?}"
REALM="${REALM:-perf}"
CLIENT_ID="${CLIENT_ID:-perf-client}"
USER_COUNT="${USER_COUNT:-1000}"
USER_PREFIX="${USER_PREFIX:-perf-user-}"
# FerrisKey enforces a password policy (uppercase, digit, entropy).
USER_PASSWORD="${USER_PASSWORD:-Bench@FerrisKey2024!}"
PARALLEL="${PARALLEL:-8}"

case "$SYSTEM" in
  ferriskey)
    BASE_URL="http://ferriskey-api:3333/api"
    HEALTH="$BASE_URL/health/ready"
    ADMIN="$BASE_URL"
    ;;
  keycloak)
    BASE_URL="http://keycloak:8080"
    HEALTH="http://keycloak:9000/health/ready"
    ADMIN="$BASE_URL/admin"
    ;;
  *) echo "unknown SYSTEM $SYSTEM"; exit 1 ;;
esac

token() {
  curl -sf -X POST "$BASE_URL/realms/master/protocol/openid-connect/token" \
    -d grant_type=password -d client_id=admin-cli \
    --data-urlencode "username=admin" --data-urlencode "password=$ADMIN_PASSWORD" \
    | jq -r .access_token
}

api() {
  method="$1"; path="$2"; shift 2
  curl -s -X "$method" "$ADMIN$path" -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' "$@"
}

# Child mode used by xargs: create one FerrisKey user (or find it) and set its password.
if [ "${1:-}" = user ]; then
  name="$2"
  id=$(api POST "/realms/$REALM/users" -d "{\"username\":\"$name\",\"firstname\":\"Perf\",
    \"lastname\":\"User\",\"email\":\"$name@test.local\",\"email_verified\":true}" | jq -r '.data.id // empty')
  [ -n "$id" ] || id=$(api GET "/realms/$REALM/users?username=$name" | jq -r --arg u "$name" '.data[] | select(.username == $u) | .id')
  [ -n "$id" ] || { echo "user $name: not created" >&2; exit 1; }
  pw=$(jq -n --arg v "$USER_PASSWORD" '{value: $v, temporary: false, credential_type: "password"}')
  code=$(api PUT "/realms/$REALM/users/$id/reset-password" -o /tmp/reset-$$ -w '%{http_code}' -d "$pw")
  [ "$code" = 200 ] || { echo "user $name: password HTTP $code $(cat /tmp/reset-$$)" >&2; exit 1; }
  exit 0
fi

seed_keycloak_users() {
  jq -n --argjson s "$1" --argjson e "$2" --arg p "$USER_PREFIX" --arg pw "$USER_PASSWORD" '{
    ifResourceExists: "OVERWRITE",
    users: [range($s; $e + 1) | ($p + (tostring | if length < 3 then ("00" + .)[-3:] else . end)) as $u | {
      username: $u, email: ($u + "@test.local"), emailVerified: true, enabled: true,
      firstName: "Perf", lastName: "User",
      credentials: [{type: "password", value: $pw, temporary: false}]}]}' \
    | api POST "/realms/$REALM/partialImport" -o /dev/null -w '%{http_code}' -d @- | grep -q 200
}

echo "waiting for $SYSTEM"
until curl -sf "$HEALTH" >/dev/null; do sleep 2; done

TOKEN=$(token)
[ -n "$TOKEN" ] && [ "$TOKEN" != null ] || { echo "admin login failed"; exit 1; }

echo "realm $REALM, client $CLIENT_ID"
if [ "$SYSTEM" = ferriskey ]; then
  api POST /realms -o /dev/null -d "{\"name\":\"$REALM\"}"
  api POST "/realms/$REALM/clients" -o /dev/null -d "{
    \"client_id\":\"$CLIENT_ID\",\"name\":\"$CLIENT_ID\",\"client_type\":\"confidential\",
    \"protocol\":\"openid-connect\",\"enabled\":true,\"public_client\":false,
    \"service_account_enabled\":true,\"direct_access_grants_enabled\":true}"
  CLIENT_UUID=$(api GET "/realms/$REALM/clients" | jq -r --arg c "$CLIENT_ID" '(.data // .)[] | select(.client_id == $c) | .id')
  CLIENT_SECRET=$(api GET "/realms/$REALM/clients/$CLIENT_UUID/client-secret" | jq -r .client_secret)
else
  # TLS is off for both systems; Keycloak needs it said explicitly.
  api POST /realms -o /dev/null -d "{\"realm\":\"$REALM\",\"enabled\":true,\"sslRequired\":\"none\"}"
  api PUT "/realms/$REALM" -o /dev/null -d '{"sslRequired":"none"}'
  api POST "/realms/$REALM/clients" -o /dev/null -d "{
    \"clientId\":\"$CLIENT_ID\",\"enabled\":true,\"publicClient\":false,\"protocol\":\"openid-connect\",
    \"serviceAccountsEnabled\":true,\"directAccessGrantsEnabled\":true,\"standardFlowEnabled\":false}"
  CLIENT_UUID=$(api GET "/realms/$REALM/clients?clientId=$CLIENT_ID" | jq -r '.[0].id')
  CLIENT_SECRET=$(api GET "/realms/$REALM/clients/$CLIENT_UUID/client-secret" | jq -r .value)
  # Keycloak only introspects tokens whose audience contains the calling client.
  api POST "/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" -o /dev/null -d "{
    \"name\":\"audience-$CLIENT_ID\",\"protocol\":\"openid-connect\",\"protocolMapper\":\"oidc-audience-mapper\",
    \"config\":{\"included.client.audience\":\"$CLIENT_ID\",\"access.token.claim\":\"true\",\"id.token.claim\":\"false\"}}"
fi
[ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != null ] || { echo "no client secret"; exit 1; }

echo "users 1..$USER_COUNT"
export SYSTEM ADMIN_PASSWORD REALM USER_PASSWORD
i=1
while [ "$i" -le "$USER_COUNT" ]; do
  end=$((i + 99)); [ "$end" -gt "$USER_COUNT" ] && end=$USER_COUNT
  TOKEN=$(token); export TOKEN
  if [ "$SYSTEM" = ferriskey ]; then
    seq "$i" "$end" | while read -r n; do printf '%s%03d\n' "$USER_PREFIX" "$n"; done \
      | xargs -P "$PARALLEL" -n 1 sh "$0" user
  else
    seed_keycloak_users "$i" "$end" || { echo "keycloak import failed at $i"; exit 1; }
  fi
  echo "  $end/$USER_COUNT"
  i=$((end + 1))
done

kubectl create secret generic "bench-$SYSTEM" \
  --from-literal=BASE_URL="$BASE_URL" \
  --from-literal=REALM="$REALM" \
  --from-literal=CLIENT_ID="$CLIENT_ID" \
  --from-literal=CLIENT_SECRET="$CLIENT_SECRET" \
  --from-literal=USER_COUNT="$USER_COUNT" \
  --from-literal=USER_PREFIX="$USER_PREFIX" \
  --from-literal=USER_PASSWORD="$USER_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "seed $SYSTEM done"
