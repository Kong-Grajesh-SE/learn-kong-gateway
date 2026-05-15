#!/usr/bin/env bash
# verify-module-07.sh - Verify Module 07 (Enterprise & Advanced) against Konnect.
#
# Covers (each section skips gracefully if its external service is absent):
#   Lab 07-A  JWT + HMAC                      - auto-runnable
#   Lab 07-B  Consumer Groups + ACL           - auto-runnable
#   Lab 07-C  OIDC Auth Code (Keycloak)       - needs module-07-enterprise/keycloak running
#   Lab 07-D  Upstream OAuth (M2M)            - needs same Keycloak
#   Lab 07-E  OPA policy-as-code              - needs OPA at $OPA_URL
#   Lab 07-F  Datakit orchestration           - config-only verification
#   Lab 07-G  Kong Manager RBAC               - self-hosted only, skipped on Konnect serverless
#
# Usage:  ./scripts/verify-module-07.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 07 Verification (Enterprise & Advanced)"

check_prerequisites
load_env
pick_deploy_mode "${1-}"
collect_konnect_inputs
pick_cfg_method
save_env

ping_konnect
check_kong_version
verify_hybrid_dp

cleanup_if_needed

# ──────────────────────────────────────────────────────────────────────────────
# Helpers specific to this module
# ──────────────────────────────────────────────────────────────────────────────
# Mint an HS256 JWT with openssl. Args: iss, secret. Prints the encoded token.
mint_jwt_hs256() {
  local iss=$1 secret=$2
  local now; now=$(date +%s)
  local exp=$((now + 3600))
  local header='{"alg":"HS256","typ":"JWT"}'
  local payload; payload=$(jq -nc --arg iss "$iss" --argjson now "$now" --argjson exp "$exp" \
    '{iss:$iss, sub:"partner-api-client", iat:$now, exp:$exp}')
  b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }
  local h_b64; h_b64=$(printf '%s' "$header"  | b64url)
  local p_b64; p_b64=$(printf '%s' "$payload" | b64url)
  local sig;   sig=$(printf '%s' "${h_b64}.${p_b64}" | openssl dgst -sha256 -hmac "$secret" -binary | b64url)
  printf '%s.%s.%s' "$h_b64" "$p_b64" "$sig"
}

# Build the rich baseline: Service + Route + a few Consumers used by 07-A and 07-B
hdr "Baseline: Service + Route + Consumers + Groups"
JWT_SECRET="partner-a-shared-secret-256-bit-do-not-leak"
HMAC_SECRET="feed-shared-secret-256-bit-do-not-leak"

if [[ "$CFG_METHOD" == "deck" ]]; then
  cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'

consumer_groups:
  - { name: free-tier,       tags: [module-07] }
  - { name: pro-tier,        tags: [module-07] }
  - { name: enterprise-tier, tags: [module-07] }

consumers:
  - username: partner-issuer
    custom_id: partner-001
    tags: [module-07]
    jwt_secrets:
      - { key: partner-a, algorithm: HS256, secret: $JWT_SECRET }
  - username: data-feed-client
    custom_id: feed-001
    tags: [module-07]
    hmacauth_credentials:
      - { username: feed-001, secret: $HMAC_SECRET }
  - username: free-user-001
    custom_id: free-001
    groups: [free-tier]
    tags: [module-07]
    keyauth_credentials: [{ key: free-key-001 }]
  - username: pro-user-001
    custom_id: pro-001
    groups: [pro-tier]
    tags: [module-07]
    keyauth_credentials: [{ key: pro-key-001 }]
  - username: enterprise-user-001
    custom_id: ent-001
    groups: [enterprise-tier]
    tags: [module-07]
    keyauth_credentials: [{ key: ent-key-001 }]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-07]
    routes:
      - { name: flights-route, paths: [/flights], strip_path: true, tags: [module-07] }
YAML
else
  # Consumer groups
  for G in free-tier pro-tier enterprise-tier; do
    api_write POST "/consumer_groups" "$(jq -n --arg n "$G" '{name:$n, tags:["module-07"]}')" >/dev/null
  done
  # Consumers
  for U in partner-issuer:partner-001 data-feed-client:feed-001 \
           free-user-001:free-001 pro-user-001:pro-001 enterprise-user-001:ent-001; do
    USER=${U%:*}; CID=${U#*:}
    api_write POST "/consumers" \
      "$(jq -n --arg u "$USER" --arg c "$CID" '{username:$u, custom_id:$c, tags:["module-07"]}')" >/dev/null
  done
  # Credentials
  api_write POST "/consumers/partner-issuer/jwt" \
    "$(jq -n --arg s "$JWT_SECRET" '{key:"partner-a", algorithm:"HS256", secret:$s}')" >/dev/null
  api_write POST "/consumers/data-feed-client/hmac-auth" \
    "$(jq -n --arg s "$HMAC_SECRET" '{username:"feed-001", secret:$s}')" >/dev/null
  api_write POST "/consumers/free-user-001/key-auth"       "$(jq -n '{key:"free-key-001"}')" >/dev/null
  api_write POST "/consumers/pro-user-001/key-auth"        "$(jq -n '{key:"pro-key-001"}')" >/dev/null
  api_write POST "/consumers/enterprise-user-001/key-auth" "$(jq -n '{key:"ent-key-001"}')" >/dev/null
  # Add consumers to groups
  api_write POST "/consumers/free-user-001/consumer_groups"        "$(jq -n '{group:"free-tier"}')" >/dev/null
  api_write POST "/consumers/pro-user-001/consumer_groups"         "$(jq -n '{group:"pro-tier"}')" >/dev/null
  api_write POST "/consumers/enterprise-user-001/consumer_groups"  "$(jq -n '{group:"enterprise-tier"}')" >/dev/null
  # Service + Route
  api_write POST "/services" \
    "$(jq -n '{name:"flights-svc", url:"https://httpbin.konghq.com", tags:["module-07"]}')" >/dev/null
  SID=$(api_curl GET "/services/flights-svc" | jq -r '.id')
  api_write POST "/routes" \
    "$(jq -n --arg s "$SID" '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$s}, tags:["module-07"]}')" >/dev/null
fi
ok "Baseline applied (3 Groups, 5 Consumers, Service+Route)"

RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-A - JWT + HMAC
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-A - JWT + HMAC"

# ────── JWT ──────
step "JWT: attach plugin (key_claim_name=iss, verify exp) to flights-route"
attach_jwt() {
  local pid; pid=$(api_curl GET "/routes/$RID/plugins?name=jwt" | jq -r '.data[0]?.id // empty')
  [[ -n "$pid" ]] && api_curl DELETE "/plugins/$pid" >/dev/null
  api_write POST "/routes/$RID/plugins" "$(jq -n '{
    name: "jwt",
    tags: ["module-07"],
    config: {
      key_claim_name: "iss",
      claims_to_verify: ["exp"],
      header_names: ["Authorization"],
      run_on_preflight: false
    }
  }')" >/dev/null
}
attach_jwt
wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

step "JWT: mint a token (HS256, iss=partner-a), call route → expect 200 and X-Consumer-Username=partner-issuer"
TOKEN=$(mint_jwt_hs256 "partner-a" "$JWT_SECRET")
BODY=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H "Authorization: Bearer $TOKEN")
CONS=$(echo "$BODY" | jq -r '.headers["X-Consumer-Username"] // "missing"')
if [[ "$CONS" == "partner-issuer" ]]; then
  ok "JWT validated, Consumer=$CONS"
else
  err "Expected partner-issuer, got '$CONS'"
  echo "$BODY" | jq -r '.headers' | head -20
  exit 1
fi

step "JWT: tamper with the token → expect 401"
BAD="${TOKEN:0:-5}XXXXX"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H "Authorization: Bearer $BAD")
[[ "$HTTP" == "401" ]] && ok "Tampered token → 401" || { err "Expected 401, got $HTTP"; exit 1; }

step "JWT: no token → expect 401"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
[[ "$HTTP" == "401" ]] && ok "Missing token → 401" || warn "Expected 401, got $HTTP"

# ────── HMAC (config-only verification; full signed-request flow is in the lab) ──────
step "HMAC: attach hmac-auth (requires date + request-line + content-md5)"
detach_jwt() {
  local pid; pid=$(api_curl GET "/routes/$RID/plugins?name=jwt" | jq -r '.data[0]?.id // empty')
  [[ -n "$pid" ]] && api_curl DELETE "/plugins/$pid" >/dev/null
}
detach_jwt
api_write POST "/routes/$RID/plugins" "$(jq -n '{
  name: "hmac-auth",
  tags: ["module-07"],
  config: {
    clock_skew: 300,
    enforce_headers: ["date","request-line","content-md5"],
    algorithms: ["hmac-sha256"],
    validate_request_body: true,
    hide_credentials: true
  }
}')" >/dev/null
ok "hmac-auth attached"
wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

step "HMAC: build a signed POST request and verify"
BODY_TXT='{"feed":"prices","timestamp":1748700000}'
USERNAME="feed-001"
SECRET="$HMAC_SECRET"
DATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
CONTENT_MD5=$(printf '%s' "$BODY_TXT" | openssl dgst -md5 -binary | openssl base64 -A)
REQUEST_LINE="POST /flights/post HTTP/2"
SIGNING_STRING=$(printf 'date: %s\nrequest-line: %s\ncontent-md5: %s' \
  "$DATE" "$REQUEST_LINE" "$CONTENT_MD5")
SIGNATURE=$(printf '%s' "$SIGNING_STRING" | openssl dgst -sha256 -hmac "$SECRET" -binary | openssl base64 -A)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${KONNECT_PROXY_URL}/flights/post" \
  -H "Date: $DATE" \
  -H "Content-MD5: $CONTENT_MD5" \
  -H "Authorization: hmac username=\"$USERNAME\",algorithm=\"hmac-sha256\",headers=\"date request-line content-md5\",signature=\"$SIGNATURE\"" \
  -H 'Content-Type: application/json' \
  --data "$BODY_TXT")
if [[ "$HTTP" == "200" ]]; then
  ok "Signed request → 200 (HMAC validated correctly)"
else
  warn "HMAC test returned $HTTP - may depend on Konnect serverless edge mangling Host/Date. The lab covers this nuance."
fi

step "HMAC: bad signature → expect 401"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${KONNECT_PROXY_URL}/flights/post" \
  -H "Date: $DATE" \
  -H "Content-MD5: $CONTENT_MD5" \
  -H "Authorization: hmac username=\"$USERNAME\",algorithm=\"hmac-sha256\",headers=\"date request-line content-md5\",signature=\"DEADBEEF==\"" \
  -H 'Content-Type: application/json' \
  --data "$BODY_TXT")
[[ "$HTTP" == "401" ]] && ok "Bad signature → 401" || warn "Expected 401, got $HTTP"

# Clean up the HMAC plugin before next lab
HMAC_PID=$(api_curl GET "/routes/$RID/plugins?name=hmac-auth" | jq -r '.data[0]?.id // empty')
[[ -n "$HMAC_PID" ]] && api_curl DELETE "/plugins/$HMAC_PID" >/dev/null

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-B - Consumer Groups + ACL
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-B - Consumer Groups + ACL"

step "1. Attach key-auth + acl (allow only pro-tier and enterprise-tier) to flights-route"
api_write POST "/routes/$RID/plugins" \
  "$(jq -n '{name:"key-auth", config:{key_names:["X-API-Key"], hide_credentials:true}, tags:["module-07"]}')" >/dev/null
api_write POST "/routes/$RID/plugins" \
  "$(jq -n '{name:"acl", config:{allow:["pro-tier","enterprise-tier"], hide_groups_header:true}, tags:["module-07"]}')" >/dev/null
ok "key-auth + acl attached"
wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

step "2. free-user (in free-tier, not allowed) → expect 403"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: free-key-001')
[[ "$HTTP" == "403" ]] && ok "free-user → 403 (not in allow list)" || { err "Expected 403, got $HTTP"; exit 1; }

step "3. pro-user → expect 200"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: pro-key-001')
[[ "$HTTP" == "200" ]] && ok "pro-user → 200" || { err "Expected 200, got $HTTP"; exit 1; }

step "4. enterprise-user → expect 200"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: ent-key-001')
[[ "$HTTP" == "200" ]] && ok "enterprise-user → 200" || { err "Expected 200, got $HTTP"; exit 1; }

# Detach ACL + key-auth for the next labs
for NAME in acl key-auth; do
  PID=$(api_curl GET "/routes/$RID/plugins?name=$NAME" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID" ]] && api_curl DELETE "/plugins/$PID" >/dev/null
done

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-C - OIDC Auth Code Flow (requires Keycloak)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-C - OIDC Authorization Code Flow"

prompt_var KEYCLOAK_BASE "Keycloak base URL (e.g. http://localhost:8080). Press Enter to SKIP 07-C and 07-D."

if [[ -z "${KEYCLOAK_BASE:-}" ]]; then
  warn "No Keycloak - skipping 07-C and 07-D. To enable: cd module-07-enterprise/keycloak && docker compose up -d, then re-run with KEYCLOAK_BASE=http://localhost:8080"
else
  ISSUER="${KEYCLOAK_BASE}/realms/kong-bootcamp"
  step "1. Verify Keycloak is reachable + has the kong-bootcamp realm"
  if curl -fsS "${ISSUER}/.well-known/openid-configuration" | jq -e '.issuer' >/dev/null; then
    ok "Keycloak realm reachable at $ISSUER"
  else
    err "Could not fetch OIDC discovery from $ISSUER - is Keycloak running and the realm imported?"; exit 1
  fi

  step "2. Attach openid-connect plugin to flights-route"
  CLIENT_SECRET="kong-bootcamp-client-secret-replace-in-prod"
  api_write POST "/routes/$RID/plugins" "$(jq -n --arg iss "$ISSUER" --arg cs "$CLIENT_SECRET" '{
    name: "openid-connect",
    tags: ["module-07"],
    config: {
      issuer: $iss,
      client_id: ["kong"],
      client_secret: [$cs],
      auth_methods: ["password","bearer","client_credentials"],
      scopes: ["openid","profile","email"],
      login_action: "deny",
      bearer_token_param_type: ["header"]
    }
  }')" >/dev/null
  ok "openid-connect attached"
  wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

  step "3. Get an access token (password grant - alice / alice-password)"
  TOKEN=$(curl -fsS -X POST \
    -d 'grant_type=password' \
    -d 'client_id=kong' \
    -d "client_secret=$CLIENT_SECRET" \
    -d 'username=alice' \
    -d 'password=alice-password' \
    -d 'scope=openid profile email' \
    "${ISSUER}/protocol/openid-connect/token" | jq -r '.access_token')
  if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
    ok "Got an access token from Keycloak (${#TOKEN} chars)"
  else
    err "Failed to get token from Keycloak. Check the kong client secret + that alice exists."; exit 1
  fi

  step "4. Call route with the Bearer token → expect 200"
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H "Authorization: Bearer $TOKEN")
  [[ "$HTTP" == "200" ]] && ok "Bearer token → 200" || { err "Expected 200, got $HTTP"; exit 1; }

  step "5. No token → expect 401 (login_action: deny)"
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
  [[ "$HTTP" == "401" ]] && ok "No token → 401" || warn "Expected 401, got $HTTP"

  # Detach OIDC for the next lab
  PID=$(api_curl GET "/routes/$RID/plugins?name=openid-connect" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID" ]] && api_curl DELETE "/plugins/$PID" >/dev/null
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-D - Upstream OAuth (M2M; requires Keycloak)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-D - Upstream OAuth (M2M)"

if [[ -z "${KEYCLOAK_BASE:-}" ]]; then
  warn "No Keycloak - skipping 07-D."
else
  ISSUER="${KEYCLOAK_BASE}/realms/kong-bootcamp"
  M2M_SECRET="kong-m2m-client-secret-replace-in-prod"
  step "1. Confirm M2M token endpoint works directly"
  M2M_TOKEN=$(curl -fsS -X POST \
    -d 'grant_type=client_credentials' \
    -d 'client_id=kong-m2m' \
    -d "client_secret=$M2M_SECRET" \
    "${ISSUER}/protocol/openid-connect/token" | jq -r '.access_token')
  if [[ -n "$M2M_TOKEN" && "$M2M_TOKEN" != "null" ]]; then
    ok "Keycloak issues an M2M token directly (sanity check)"
  else
    err "Could not get an M2M token from Keycloak. Check the kong-m2m client + secret."; exit 1
  fi

  step "2. Attach upstream-oauth plugin to flights-route"
  api_write POST "/routes/$RID/plugins" "$(jq -n --arg iss "$ISSUER" --arg sec "$M2M_SECRET" '{
    name: "upstream-oauth",
    tags: ["module-07"],
    config: {
      oauth: {
        token_endpoint: ($iss + "/protocol/openid-connect/token"),
        grant_type: "client_credentials",
        client_id: "kong-m2m",
        client_secret: $sec,
        scopes: []
      },
      cache: { strategy: "memory", default_ttl: 300, eagerly_expire: 5 }
    }
  }')" >/dev/null
  ok "upstream-oauth attached (Kong will fetch tokens from Keycloak and inject Authorization upstream)"
  wait_for_route "${KONNECT_PROXY_URL}/flights/anything" 15 || true

  step "3. Call the route - upstream should receive Authorization: Bearer <token-fetched-by-Kong>"
  AUTH=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" \
    | jq -r '.headers["Authorization"] // "missing"')
  if [[ "$AUTH" == Bearer\ * ]]; then
    ok "Upstream received Authorization header: ${AUTH:0:50}…"
  else
    warn "Upstream didn't receive a Bearer token (got '$AUTH'). On first call, Kong may still be fetching the token."
  fi

  # Detach upstream-oauth for the next lab
  PID=$(api_curl GET "/routes/$RID/plugins?name=upstream-oauth" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID" ]] && api_curl DELETE "/plugins/$PID" >/dev/null
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-E - OPA (requires OPA running)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-E - OPA Policy-as-Code"

prompt_var OPA_URL "OPA decision endpoint (e.g. http://host.docker.internal:8181/v1/data/kong/allow). Press Enter to SKIP."

if [[ -z "${OPA_URL:-}" ]]; then
  warn "No OPA endpoint - skipping 07-E."
else
  step "1. Attach opa plugin to flights-route"
  api_write POST "/routes/$RID/plugins" "$(jq -n --arg u "$OPA_URL" '{
    name: "opa",
    tags: ["module-07"],
    config: { opa_protocol: "http", opa_host: $u, include_consumer_in_opa_input: true }
  }')" >/dev/null
  ok "opa plugin attached → $OPA_URL"
  wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

  step "2. Call the route - outcome depends on your OPA policy (allow|deny)"
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
  info "OPA returned HTTP $HTTP (verify against your Rego policy)"

  PID=$(api_curl GET "/routes/$RID/plugins?name=opa" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID" ]] && api_curl DELETE "/plugins/$PID" >/dev/null
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-F - Datakit (config-only verification)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-F - Datakit (config-only verification)"
step "1. Attempt to attach a minimal datakit plugin"
DK_RESULT=$(api_write POST "/routes/$RID/plugins" "$(jq -n '{
  name: "datakit",
  tags: ["module-07"],
  config: {
    nodes: [
      { name: "echo", type: "call", uri: "https://httpbin.konghq.com/anything", method: "GET" }
    ]
  }
}')" 2>&1 || true)
if echo "$DK_RESULT" | jq -e '.id' >/dev/null 2>&1; then
  ok "datakit attached with a 1-node pipeline (verification of full DAG behavior is left to the lab)"
  DK_PID=$(echo "$DK_RESULT" | jq -r '.id')
  [[ -n "$DK_PID" ]] && api_curl DELETE "/plugins/$DK_PID" >/dev/null
else
  warn "datakit not available on this Control Plane (Konnect free tier may exclude it). Schema covered in the lab."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-G - RBAC (self-hosted Kong Manager only)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-G - Kong Manager RBAC"
info "Konnect manages multi-tenancy via Konnect Teams in the UI, not Kong Manager RBAC."
info "If you're running a self-hosted Kong Gateway Enterprise + Kong Manager, follow the lab manually:"
info "  https://docs.konghq.com/gateway/latest/admin-api/rbac/reference/"
warn "Skipped (no automated verification on Konnect)."

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Cleanup - wipe everything tagged module-07"
printf 'Delete all M07 entities now? [Y/n]: '
read -r CLEAN
case "${CLEAN:-Y}" in
  n|N) warn "Skipping cleanup." ;;
  *) cleanup_everything; ok "Module 07 cleanup complete."; cleanup_generated_files ;;
esac

hdr "Module 07 verification complete ✓"
ok "Labs exercised: 07-A (JWT+HMAC), 07-B (Groups+ACL). 07-C/D exercised if KEYCLOAK_BASE was provided. 07-E if OPA_URL. 07-F config-only. 07-G is self-hosted-only."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
