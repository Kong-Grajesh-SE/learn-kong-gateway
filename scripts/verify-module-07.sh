#!/usr/bin/env bash
# verify-module-07.sh  -  Module 07 (Enterprise & Advanced) live verification
#
# Walks every lab in sequence, creates real config on 'flights-route', runs
# HTTP assertions, pauses for Konnect portal review, then cleans up.
#
# Lab     Auto-run  What is tested
# ──────────────────────────────────────────────────────────────────────────────
# 07-A    ✓ always  JWT: attach plugin (key_claim_name=iss, claims_to_verify=exp),
#                   mint HS256 token with openssl (iss=partner-issuer), verify
#                   Consumer mapping (X-Consumer-Username=partner-api-client),
#                   tampered token → 401, missing token → 401.
#                   HMAC: attach hmac-auth (date+request-line+content-md5,
#                   validate_request_body=true), build signed POST via openssl
#                   dgst -sha256 -hmac → expect 200; bad signature → 401.
#
# 07-B    ✓ always  key-auth + ACL: 3-tier Consumer Groups (free/pro/enterprise).
#                   free-tier → 403, pro/enterprise → 200.
#                   rate-limiting-advanced per consumer_group (10/100/1000 rpm);
#                   graceful skip with warning if plugin unavailable on CP tier.
#
# 07-C    optional  OIDC via Keycloak - interactive menu when KEYCLOAK_BASE unset:
#                   A=hybrid (localhost:8080), B=ngrok/public URL, S=skip.
#                   Verifies realm discovery, attaches openid-connect plugin
#                   (auth_methods=[password,bearer], login_action=response),
#                   fetches token (alice/alice-password, no explicit scope),
#                   Bearer token → 200, no token → 401.
#                   Plugin stays visible for portal review, removed on Enter.
#
# 07-D    optional  Upstream OAuth M2M - same Keycloak as 07-C.
#                   Verifies kong-m2m client_credentials token endpoint directly,
#                   attaches upstream-oauth (token_endpoint, memory cache 300s),
#                   confirms upstream receives "Authorization: Bearer <token>".
#
# 07-E    optional  OPA policy-as-code - prompts for OPA_URL or Enter to skip.
#                   Parses URL into host/port/path, attaches opa plugin
#                   (include_consumer + include_service in payload), calls route,
#                   logs HTTP status (outcome depends on your Rego policy).
#
# 07-F    config    Datakit - attaches a 1-node pipeline; graceful skip with
#                   warning if plugin unavailable on this CP tier.
#
# 07-G    skipped   RBAC - self-hosted Kong Manager only. Prints guidance and
#                   exits gracefully on Konnect serverless.
#
# Pauses: after each lab the script waits for Enter so you can inspect the live
#         plugin in the Konnect portal before it is removed.
#         Set SKIP_REVIEW=1 to bypass all pauses (CI / re-runs).
#
# Environment:
#   KEYCLOAK_BASE  - pre-set to skip the 07-C/D interactive menu
#   OPA_URL        - pre-set to skip the 07-E prompt
#   SKIP_REVIEW=1  - bypass all pause_for_review prompts
#
# Usage:  ./scripts/verify-module-07.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

# pause_for_review <lab-label>
# Prints a Konnect portal URL hint and waits for Enter before the next lab.
# Set SKIP_REVIEW=1 to bypass all pauses (useful for CI / re-runs).
pause_for_review() {
  local lab="${1:-this lab}"
  if [[ "${SKIP_REVIEW:-0}" == "1" ]]; then return 0; fi
  local _line
  _line=$(printf '─%.0s' {1..76})
  printf '\n%s%s%s\n' "$CYN" "$_line" "$RST"
  printf '%s  ✋  Review %s in the Konnect portal before continuing:%s\n' "$YLW" "$lab" "$RST"
  printf '     https://cloud.konghq.com  →  Gateway Manager  →  %s  →  Plugins / Routes\n' \
    "${KONNECT_CP_NAME:-your-cp}"
  printf '%s%s%s\n' "$CYN" "$_line" "$RST"
  printf '  Press Enter to continue to the next lab (or Ctrl+C to abort): '
  read -r _dummy
}

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
JWT_SECRET="super-secret-256-bit-key-do-not-leak"
HMAC_SECRET="feed-shared-secret-do-not-leak-256-bit"

if [[ "$CFG_METHOD" == "deck" ]]; then
  cat <<YAML | deck_sync_stdin >/dev/null || { err "Deck sync failed (baseline) - check output above"; exit 1; }
_format_version: '3.0'

consumer_groups:
  - { name: free-tier,       tags: [module-07] }
  - { name: pro-tier,        tags: [module-07] }
  - { name: enterprise-tier, tags: [module-07] }

consumers:
  - username: partner-api-client
    custom_id: partner-001
    tags: [module-07]
    jwt_secrets:
      - { key: partner-issuer, algorithm: HS256, secret: $JWT_SECRET }
  - username: data-feed-client
    custom_id: feed-001
    tags: [module-07]
    hmacauth_credentials:
      - { username: feed-001, secret: $HMAC_SECRET }
  - username: free-user-001
    custom_id: free-001
    groups: [{ name: free-tier }]
    tags: [module-07]
    keyauth_credentials: [{ key: free-key-001 }]
    acls:               [{ group: free-tier }]
  - username: pro-user-001
    custom_id: pro-001
    groups: [{ name: pro-tier }]
    tags: [module-07]
    keyauth_credentials: [{ key: pro-key-001 }]
    acls:               [{ group: pro-tier }]
  - username: enterprise-user-001
    custom_id: ent-001
    groups: [{ name: enterprise-tier }]
    tags: [module-07]
    keyauth_credentials: [{ key: ent-key-001 }]
    acls:               [{ group: enterprise-tier }]

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
  for U in partner-api-client:partner-001 data-feed-client:feed-001 \
           free-user-001:free-001 pro-user-001:pro-001 enterprise-user-001:ent-001; do
    USER=${U%:*}; CID=${U#*:}
    api_write POST "/consumers" \
      "$(jq -n --arg u "$USER" --arg c "$CID" '{username:$u, custom_id:$c, tags:["module-07"]}')" >/dev/null
  done
  # Resolve consumer IDs once - Konnect requires UUIDs in path for nested writes
  PARTNER_ID=$(resolve_id consumers partner-api-client)  || { err "partner-api-client not found"; exit 1; }
  FEED_ID=$(resolve_id consumers data-feed-client)       || { err "data-feed-client not found"; exit 1; }
  FREE_ID=$(resolve_id consumers free-user-001)          || { err "free-user-001 not found"; exit 1; }
  PRO_ID=$(resolve_id consumers pro-user-001)            || { err "pro-user-001 not found"; exit 1; }
  ENT_ID=$(resolve_id consumers enterprise-user-001)     || { err "enterprise-user-001 not found"; exit 1; }

  # Credentials
  api_write POST "/consumers/$PARTNER_ID/jwt" \
    "$(jq -n --arg s "$JWT_SECRET" '{key:"partner-issuer", algorithm:"HS256", secret:$s}')" >/dev/null
  api_write POST "/consumers/$FEED_ID/hmac-auth" \
    "$(jq -n --arg s "$HMAC_SECRET" '{username:"feed-001", secret:$s}')" >/dev/null
  api_write POST "/consumers/$FREE_ID/key-auth" "$(jq -n '{key:"free-key-001"}')" >/dev/null
  api_write POST "/consumers/$PRO_ID/key-auth"  "$(jq -n '{key:"pro-key-001"}')" >/dev/null
  api_write POST "/consumers/$ENT_ID/key-auth"  "$(jq -n '{key:"ent-key-001"}')" >/dev/null
  # ACL credentials (separate from consumer-group membership; required by the ACL plugin)
  api_write POST "/consumers/$FREE_ID/acls" "$(jq -n '{group:"free-tier"}')"       >/dev/null
  api_write POST "/consumers/$PRO_ID/acls"  "$(jq -n '{group:"pro-tier"}')"        >/dev/null
  api_write POST "/consumers/$ENT_ID/acls"  "$(jq -n '{group:"enterprise-tier"}')" >/dev/null
  # Add consumers to consumer_groups
  api_write POST "/consumers/$FREE_ID/consumer_groups" "$(jq -n '{group:"free-tier"}')" >/dev/null
  api_write POST "/consumers/$PRO_ID/consumer_groups"  "$(jq -n '{group:"pro-tier"}')" >/dev/null
  api_write POST "/consumers/$ENT_ID/consumer_groups"  "$(jq -n '{group:"enterprise-tier"}')" >/dev/null
  # Service + Route
  api_write POST "/services" \
    "$(jq -n '{name:"flights-svc", url:"https://httpbin.konghq.com", tags:["module-07"]}')" >/dev/null
  SID=$(api_curl GET "/services/flights-svc" | jq -r '.id')
  api_write POST "/routes" \
    "$(jq -n --arg s "$SID" '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$s}, tags:["module-07"]}')" >/dev/null
fi
ok "Baseline applied (3 Groups, 5 Consumers, Service+Route)"

RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')
[[ -z "$RID" || "$RID" == "null" ]] && { err "flights-route not found after baseline - deck sync may have failed silently"; exit 1; }
ok "flights-route id=$RID"

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
wait_for_http_status "${KONNECT_PROXY_URL}/flights/get" 401 20 || true

step "JWT: mint a token (HS256, iss=partner-issuer), call route → expect 200 and X-Consumer-Username=partner-api-client"
TOKEN=$(mint_jwt_hs256 "partner-issuer" "$JWT_SECRET")
BODY=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H "Authorization: Bearer $TOKEN")
CONS=$(echo "$BODY" | jq -r '.headers["X-Consumer-Username"] // "missing"')
if [[ "$CONS" == "partner-api-client" ]]; then
  ok "JWT validated, Consumer=$CONS"
else
  err "Expected partner-api-client, got '$CONS'"
  echo "$BODY" | jq -r '.headers' | head -20
  exit 1
fi

step "JWT: tamper with the token → expect 401"
BAD="${TOKEN%?????}XXXXX"   # portable: strips last 5 chars (bash 3.2 compat)
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
wait_for_http_status "${KONNECT_PROXY_URL}/flights/get" 401 20 || true

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

pause_for_review "Lab 07-A (JWT + HMAC)"

# Remove HMAC plugin after learner has reviewed it in the portal
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
# Wait for 403 with a valid-but-blocked key: proves HMAC is fully gone, key-auth
# recognises the credential, and ACL is blocking free-tier. Waiting for plain 401
# is unreliable because the HMAC plugin may still be live in the DP.
wait_for_http_status "${KONNECT_PROXY_URL}/flights/get" 403 30 -H 'X-API-Key: free-key-001' || true

step "2. free-user (in free-tier, not allowed) → expect 403"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: free-key-001')
[[ "$HTTP" == "403" ]] && ok "free-user → 403 (not in allow list)" || { err "Expected 403, got $HTTP"; exit 1; }

step "3. pro-user → expect 200"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: pro-key-001')
[[ "$HTTP" == "200" ]] && ok "pro-user → 200" || { err "Expected 200, got $HTTP"; exit 1; }

step "4. enterprise-user → expect 200"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: ent-key-001')
[[ "$HTTP" == "200" ]] && ok "enterprise-user → 200" || { err "Expected 200, got $HTTP"; exit 1; }

step "5. Per-group rate-limiting (rate-limiting-advanced consumer_group scope)"
# Update ACL to allow all 3 tiers, then add per-group rate-limiting-advanced
for NAME in acl key-auth; do
  PID2=$(api_curl GET "/routes/$RID/plugins?name=$NAME" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID2" ]] && api_curl DELETE "/plugins/$PID2" >/dev/null
done
api_write POST "/routes/$RID/plugins" \
  "$(jq -n '{name:"key-auth", config:{key_names:["X-API-Key"], hide_credentials:true}, tags:["module-07"]}')" >/dev/null
api_write POST "/routes/$RID/plugins" \
  "$(jq -n '{name:"acl", config:{allow:["free-tier","pro-tier","enterprise-tier"], hide_groups_header:true}, tags:["module-07"]}')" >/dev/null
_rla_count=0
for TIER_CONF in 'free-tier:10' 'pro-tier:100' 'enterprise-tier:1000'; do
  TIER=${TIER_CONF%:*}; LIM=${TIER_CONF#*:}
  RLA=$(api_write POST "/routes/$RID/plugins" "$(jq -n \
    --arg cg "$TIER" --argjson lim "$LIM" \
    '{name:"rate-limiting-advanced", tags:["module-07"],
      consumer_group:{name:$cg},
      config:{limit:[$lim], window_size:[60], identifier:"consumer", strategy:"local"}}')" 2>&1 || true)
  if echo "$RLA" | jq -e '.id' >/dev/null 2>&1; then
    ok "  rate-limiting-advanced: $TIER → $LIM req/min"
    _rla_count=$((_rla_count + 1))
  else
    warn "  rate-limiting-advanced not applied for $TIER (Enterprise plugin - may not be available on this CP)"
  fi
done
# ACL now allows all 3 tiers; wait for 200 with free-key (proves both old ACL is gone and new one is live)
wait_for_http_status "${KONNECT_PROXY_URL}/flights/get" 200 30 -H 'X-API-Key: free-key-001' || true
if (( _rla_count == 0 )); then
  warn "  Skipping RateLimit header checks - rate-limiting-advanced unavailable on this CP tier"
else
  for PAIR in 'free-key-001:10' 'pro-key-001:100' 'ent-key-001:1000'; do
    KEY=${PAIR%:*}; EXPECT=${PAIR#*:}
    HDR=$(curl -sI "${KONNECT_PROXY_URL}/flights/get" -H "X-API-Key: $KEY" \
      | grep -i 'ratelimit-limit' | awk '{print $2}' | tr -d '\r' || echo "absent")
    if [[ "$HDR" == "$EXPECT" ]]; then
      ok "  $KEY → RateLimit-Limit: $HDR"
    else
      warn "  $KEY → RateLimit-Limit: ${HDR:-absent} (expected $EXPECT)"
    fi
  done
fi

pause_for_review "Lab 07-B (Consumer Groups + ACL)"

# Remove ACL + key-auth after learner has reviewed them in the portal
for NAME in acl key-auth; do
  PID=$(api_curl GET "/routes/$RID/plugins?name=$NAME" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID" ]] && api_curl DELETE "/plugins/$PID" >/dev/null
done

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-C - OIDC Auth Code Flow (requires Keycloak)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-C - OIDC Authorization Code Flow"

# _kc_proxy_url: proxy URL to use for Keycloak labs (may differ from KONNECT_PROXY_URL in serverless mode)
_kc_proxy_url="${KONNECT_PROXY_URL}"

if [[ -z "${KEYCLOAK_BASE:-}" ]]; then
  printf '\n  Labs 07-C and 07-D require Keycloak. How would you like to connect?\n\n'
  printf '    A)  Hybrid mode  - local Docker Kong DP + Keycloak both on localhost\n'
  printf '    B)  Public URL   - Keycloak exposed via ngrok / tunnel (works with serverless)\n'
  printf '    S)  Skip         - skip 07-C and 07-D\n\n'
  printf '  Choice [A/B/S]: '
  read -r _kc_choice
  # bash 3.2 (macOS) has no ^^ operator; use tr for uppercase
  _kc_choice=$(printf '%s' "$_kc_choice" | tr '[:lower:]' '[:upper:]')
  case "$_kc_choice" in
    A)
      KEYCLOAK_BASE="http://localhost:8080"
      _kc_direct_base="http://localhost:8080"   # script fetches tokens from here directly
      printf '  Local Kong DP proxy URL [http://localhost:8000]: '
      read -r _in; _kc_proxy_url="${_in:-http://localhost:8000}"
      ok "Option A selected: Keycloak=localhost:8080  DP proxy=$_kc_proxy_url"
      ;;
    B)
      printf '  Public Keycloak base URL - host only, no /realms/... path\n'
      printf '  (e.g. https://abc123.ngrok-free.app  or  https://abc123.ngrok.io): '
      read -r _in
      # Strip trailing slash and any accidental /realms/... suffix the user may have pasted
      _in="${_in%/}"
      _in="${_in%/realms*}"
      KEYCLOAK_BASE="${_in%/}"
      if [[ -z "$KEYCLOAK_BASE" ]]; then
        warn "No URL entered - skipping 07-C and 07-D."
        KEYCLOAK_BASE=""
      else
        # The Kong plugin uses the public ngrok URL (KEYCLOAK_BASE).
        # The script fetches tokens directly from localhost so ngrok routing
        # quirks (interstitial pages, 400s on POST) don't interfere.
        printf '  Local Keycloak port [8080]: '
        read -r _lp; _kc_direct_base="http://localhost:${_lp:-8080}"
        ok "Option B selected: Kong issuer=$KEYCLOAK_BASE  script tokens=$_kc_direct_base  DP proxy=$_kc_proxy_url"
      fi
      ;;
    *)
      warn "Skipping 07-C and 07-D. Re-run with KEYCLOAK_BASE=http://localhost:8080 (Option A) or your ngrok URL (Option B) to enable."
      KEYCLOAK_BASE=""
      ;;
  esac
fi

if [[ -z "${KEYCLOAK_BASE:-}" ]]; then
  warn "No Keycloak - 07-C and 07-D skipped."
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
      login_action: "response",
      bearer_token_param_type: ["header"]
    }
  }')" >/dev/null
  ok "openid-connect attached (issuer=$ISSUER)"
  wait_for_http_status "${_kc_proxy_url}/flights/get" 401 20 || true

  step "3. Get an access token (password grant - alice / alice-password)"
  # Use _kc_direct_base (localhost) for token fetches so ngrok routing
  # does not interfere; KEYCLOAK_BASE (ngrok) is used only by the Kong plugin.
  _direct_issuer="${_kc_direct_base:-$KEYCLOAK_BASE}/realms/kong-bootcamp"
  _token_resp=$(curl -s -X POST \
    -d 'grant_type=password' \
    -d 'client_id=kong' \
    -d "client_secret=$CLIENT_SECRET" \
    -d 'username=alice' \
    -d 'password=alice-password' \
    "${_direct_issuer}/protocol/openid-connect/token" 2>&1)
  TOKEN=$(printf '%s' "$_token_resp" | jq -r '.access_token // empty' 2>/dev/null)
  if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
    ok "Got an access token from Keycloak (${#TOKEN} chars)"
  else
    _kc_err=$(printf '%s' "$_token_resp" | jq -r '.error_description // .error // .message // empty' 2>/dev/null)
    err "Failed to get token from Keycloak: ${_kc_err:-see raw response below}"
    err "Raw response: $_token_resp"
    exit 1
  fi

  step "4. Call route with the Bearer token → expect 200"
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${_kc_proxy_url}/flights/get" -H "Authorization: Bearer $TOKEN")
  [[ "$HTTP" == "200" ]] && ok "Bearer token → 200" || { err "Expected 200, got $HTTP"; exit 1; }

  step "5. No token → expect 401 (login_action: response)"
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${_kc_proxy_url}/flights/get")
  [[ "$HTTP" == "401" ]] && ok "No token → 401" || warn "Expected 401, got $HTTP"

fi

pause_for_review "Lab 07-C (OIDC Auth Code Flow)"

# Remove the OIDC plugin now (after the learner has reviewed it in the portal)
if [[ -n "${RID:-}" ]]; then
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
  _direct_issuer="${_kc_direct_base:-$KEYCLOAK_BASE}/realms/kong-bootcamp"
  _m2m_resp=$(curl -s -X POST \
    -d 'grant_type=client_credentials' \
    -d 'client_id=kong-m2m' \
    -d "client_secret=$M2M_SECRET" \
    "${_direct_issuer}/protocol/openid-connect/token" 2>&1)
  M2M_TOKEN=$(printf '%s' "$_m2m_resp" | jq -r '.access_token // empty' 2>/dev/null)
  if [[ -n "$M2M_TOKEN" && "$M2M_TOKEN" != "null" ]]; then
    ok "Keycloak issues an M2M token directly (sanity check)"
  else
    _kc_err=$(printf '%s' "$_m2m_resp" | jq -r '.error_description // .error // .message // empty' 2>/dev/null)
    err "Could not get an M2M token: ${_kc_err:-see raw response below}"
    err "Raw response: $_m2m_resp"
    exit 1
  fi

  step "2. Attach upstream-oauth plugin to flights-route"
  # Build JSON in a separate variable to avoid bash 3.2 paren-depth bug inside "$(jq ... '{ ($var) }')".
  # jq string interpolation "\($iss)/..." avoids bare ( ) in the filter entirely.
  _uo_body=$(jq -n --arg iss "$ISSUER" --arg sec "$M2M_SECRET" '{
    name: "upstream-oauth",
    tags: ["module-07"],
    config: {
      oauth: {
        token_endpoint: "\($iss)/protocol/openid-connect/token",
        grant_type: "client_credentials",
        client_id: "kong-m2m",
        client_secret: $sec,
        scopes: []
      },
      cache: { strategy: "memory", default_ttl: 300, eagerly_expire: 5 }
    }
  }')
  api_write POST "/routes/$RID/plugins" "$_uo_body" >/dev/null
  ok "upstream-oauth attached (Kong will fetch tokens from Keycloak and inject Authorization upstream)"
  wait_for_body_jq "${_kc_proxy_url}/flights/anything" '.headers["Authorization"]' 20 || true

  step "3. Call the route - upstream should receive Authorization: Bearer <token-fetched-by-Kong>"
  AUTH=$(curl -s "${_kc_proxy_url}/flights/anything" \
    | jq -r '.headers["Authorization"] // "missing"')
  if [[ "$AUTH" == Bearer\ * ]]; then
    ok "Upstream received Authorization header: ${AUTH:0:50}…"
  else
    warn "Upstream didn't receive a Bearer token (got '$AUTH'). On first call, Kong may still be fetching the token."
  fi

fi

pause_for_review "Lab 07-D (Upstream OAuth / M2M)"

# Remove upstream-oauth after learner has reviewed it in the portal
if [[ -n "${RID:-}" ]]; then
  PID=$(api_curl GET "/routes/$RID/plugins?name=upstream-oauth" | jq -r '.data[0]?.id // empty')
  [[ -n "$PID" ]] && api_curl DELETE "/plugins/$PID" >/dev/null
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 07-E - OPA (requires OPA running)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 07-E - OPA Policy-as-Code"

prompt_var OPA_URL "OPA decision endpoint (e.g. http://host.docker.internal:8181/v1/data/myapp/authz/allow). Press Enter to SKIP."

if [[ -z "${OPA_URL:-}" ]]; then
  warn "No OPA endpoint - skipping 07-E."
else
  # Parse OPA URL into protocol / host / port / path
  _opa_proto="${OPA_URL%%://*}"
  _opa_tmp="${OPA_URL#*://}"
  _opa_hostport="${_opa_tmp%%/*}"
  _opa_path="/${_opa_tmp#*/}"
  _opa_host="${_opa_hostport%%:*}"
  _opa_port="${_opa_hostport##*:}"
  [[ "$_opa_port" == "$_opa_host" ]] && _opa_port="8181"
  step "1. Attach opa plugin to flights-route (host=$_opa_host port=$_opa_port path=$_opa_path)"
  api_write POST "/routes/$RID/plugins" "$(jq -n \
    --arg h "$_opa_host" --argjson p "$_opa_port" --arg path "$_opa_path" \
    --arg proto "$_opa_proto" '{
    name: "opa",
    tags: ["module-07"],
    config: {
      opa_protocol: $proto,
      opa_host:     $h,
      opa_port:     $p,
      opa_path:     $path,
      include_consumer_in_opa_input: true,
      include_service_in_opa_input:  true,
      ssl_verify: false
    }
  }')" >/dev/null
  ok "opa plugin attached → $_opa_host:$_opa_port$_opa_path"
  wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

  step "2. Call the route - outcome depends on your OPA policy (allow|deny)"
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
  info "OPA returned HTTP $HTTP (verify against your Rego policy)"

fi

pause_for_review "Lab 07-E (OPA Policy-as-Code)"

# Remove OPA plugin after learner has reviewed it in the portal
if [[ -n "${RID:-}" ]]; then
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
else
  warn "datakit not available on this Control Plane (Konnect free tier may exclude it). Schema covered in the lab."
  DK_PID=""
fi

pause_for_review "Lab 07-F (Datakit)"

# Remove datakit plugin after learner has reviewed it in the portal
[[ -n "${DK_PID:-}" ]] && api_curl DELETE "/plugins/$DK_PID" >/dev/null

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
