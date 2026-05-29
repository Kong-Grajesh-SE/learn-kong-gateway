#!/usr/bin/env bash
# verify-module-08.sh - Capstone acceptance test.
#
# Two modes:
#   1) "apply" - build the reference Capstone gateway from scratch, then run the 15-step test.
#                Useful when you want to see a known-good solution end-to-end.
#   2) "test"  - run the 15-step acceptance script against whatever YOU built, without touching
#                the CP. This is the "did I pass the Capstone" check.
#
# Usage:
#   ./scripts/verify-module-08.sh [serverless|hybrid] [apply|test]
#
# Defaults: deploy_mode from .env / prompt, mode prompted at startup.

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 08 Capstone Verification"

check_prerequisites
load_env
pick_deploy_mode "${1-}"
collect_konnect_inputs
pick_cfg_method
save_env

ping_konnect
check_kong_version
verify_hybrid_dp

# Pick mode (apply / test)
RUN_MODE=${2-}
if [[ -z "$RUN_MODE" ]]; then
  echo
  echo "${BOLD}Capstone mode${RST}"
  echo "  1) apply   - Build a reference Capstone solution AND run the 15-step test"
  echo "  2) test    - Just run the 15-step test against YOUR current config (no changes)"
  printf 'Choose [1/2]: '
  read -r choice
  case "${choice:-2}" in 1) RUN_MODE=apply ;; 2) RUN_MODE=test ;; *) err "Invalid choice"; exit 1 ;; esac
fi
ok "Capstone mode: ${BOLD}${RUN_MODE}${RST}"

JWT_SECRET="partner-a-shared-secret-256-bit-do-not-leak"

mint_jwt_hs256() {
  local iss=$1 secret=$2
  local now; now=$(date +%s); local exp=$((now + 3600))
  local header='{"alg":"HS256","typ":"JWT"}'
  local payload; payload=$(jq -nc --arg iss "$iss" --argjson now "$now" --argjson exp "$exp" \
    '{iss:$iss, sub:"partner", iat:$now, exp:$exp}')
  b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }
  local h; h=$(printf '%s' "$header" | b64url)
  local p; p=$(printf '%s' "$payload" | b64url)
  local s; s=$(printf '%s' "${h}.${p}" | openssl dgst -sha256 -hmac "$secret" -binary | b64url)
  printf '%s.%s.%s' "$h" "$p" "$s"
}

# ──────────────────────────────────────────────────────────────────────────────
# APPLY MODE - build the reference Capstone gateway
# ──────────────────────────────────────────────────────────────────────────────
if [[ "$RUN_MODE" == "apply" ]]; then
  hdr "Apply: building the reference Capstone solution"
  cleanup_if_needed
  snapshot_deck_dump "module-08" "pre-apply"

  # Use a public IP service - httpbin.konghq.com is on the internal network and
  # returns a private IP that Kong DP (cloud) never sees.
  MY_IP=$(curl -s "https://api.ipify.org" | tr -d '[:space:]')
  [[ -z "$MY_IP" ]] && MY_IP=$(curl -s "https://checkip.amazonaws.com" | tr -d '[:space:]')
  info "Your public IP (added to ip-restriction allow list for /admin): $MY_IP"

  if [[ "$CFG_METHOD" == "deck" ]]; then
    # ── decK path ─────────────────────────────────────────────────────────────
    # Pass 1: create Consumer Groups + Consumers + Service + Routes (no plugins)
    # so we can resolve the anonymous consumer UUID for the jwt/key-auth anonymous= fields.
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'

consumer_groups:
  - { name: free,     tags: [module-08] }
  - { name: partner,  tags: [module-08] }
  - { name: internal, tags: [module-08] }

consumers:
  - { username: anonymous, tags: [module-08] }
  - username: free-user
    custom_id: free-001
    groups: [{name: free}]
    acls: [{group: free}]
    tags: [module-08]
    keyauth_credentials: [{ key: FREE-KEY-001 }]
  - username: partner-issuer-a
    custom_id: partner-a-001
    groups: [{name: partner}]
    acls: [{group: partner}]
    tags: [module-08]
    jwt_secrets:
      - { key: partner-a, algorithm: HS256, secret: $JWT_SECRET }
  - username: internal-svc
    custom_id: internal-001
    groups: [{name: internal}]
    acls: [{group: internal}]
    tags: [module-08]
    keyauth_credentials: [{ key: INTERNAL-KEY-001 }]

services:
  - name: travel-svc
    url: https://httpbin.konghq.com
    tags: [module-08]
    routes:
      - { name: flights-route,  paths: [/v3/flights],  strip_path: true, tags: [module-08] }
      - { name: bookings-route, paths: [/v3/bookings], strip_path: true, tags: [module-08] }
      - { name: admin-route,    paths: [/v3/admin],    strip_path: true, tags: [module-08] }
      - { name: popular-route,  paths: [/v3/flights/popular], strip_path: true, methods: [GET], tags: [module-08] }
YAML
    ok "Pass 1: Consumer Groups + Consumers + Service + Routes created"

    ANON_ID=$(api_curl GET "/consumers/anonymous" | jq -r '.id')
    [[ -z "$ANON_ID" || "$ANON_ID" == "null" ]] && { err "Could not resolve anonymous consumer ID"; exit 1; }
    info "Anonymous Consumer ID: $ANON_ID"

    # Pass 2: full config with all plugins
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'

consumer_groups:
  - { name: free,     tags: [module-08] }
  - { name: partner,  tags: [module-08] }
  - { name: internal, tags: [module-08] }

consumers:
  - { username: anonymous, tags: [module-08] }
  - username: free-user
    custom_id: free-001
    groups: [{name: free}]
    acls: [{group: free}]
    tags: [module-08]
    keyauth_credentials: [{ key: FREE-KEY-001 }]
  - username: partner-issuer-a
    custom_id: partner-a-001
    groups: [{name: partner}]
    acls: [{group: partner}]
    tags: [module-08]
    jwt_secrets:
      - { key: partner-a, algorithm: HS256, secret: $JWT_SECRET }
  - username: internal-svc
    custom_id: internal-001
    groups: [{name: internal}]
    acls: [{group: internal}]
    tags: [module-08]
    keyauth_credentials: [{ key: INTERNAL-KEY-001 }]

plugins:
  - name: cors
    tags: [module-08]
    config:
      origins: [https://app.mytravel.com, http://localhost:3000]
      methods: [GET, POST, PUT, DELETE, OPTIONS]
      headers: [Content-Type, X-API-Key, Authorization]
      credentials: true
      max_age: 3600
  - name: correlation-id
    tags: [module-08]
    config: { header_name: X-Correlation-ID, generator: uuid#counter, echo_downstream: true }

  - name: rate-limiting
    tags: [module-08]
    consumer_group: free
    config: { minute: 10,   policy: local, limit_by: consumer }
  - name: rate-limiting
    tags: [module-08]
    consumer_group: partner
    config: { minute: 100,  policy: local, limit_by: consumer }
  - name: rate-limiting
    tags: [module-08]
    consumer_group: internal
    config: { minute: 1000, policy: local, limit_by: consumer }

services:
  - name: travel-svc
    url: https://httpbin.konghq.com
    tags: [module-08]
    plugins:
      - name: response-transformer-advanced
        tags: [module-08]
        config:
          remove:
            json: [_debug, internal_id, headers, origin]
          add:
            json: ["_meta.version:v3"]
            headers: ["X-Bootcamp-Module:08"]
    routes:
      - name: flights-route
        paths: [/v3/flights]
        strip_path: true
        tags: [module-08]
        plugins:
          - name: jwt
            tags: [module-08]
            config: { key_claim_name: iss, claims_to_verify: [exp], header_names: [Authorization], anonymous: $ANON_ID }
          - name: key-auth
            tags: [module-08]
            config: { key_names: [X-API-Key], hide_credentials: true, anonymous: $ANON_ID }
          - name: acl
            tags: [module-08]
            config: { allow: [free, partner, internal], hide_groups_header: true }

      - name: bookings-route
        paths: [/v3/bookings]
        strip_path: true
        tags: [module-08]
        plugins:
          - name: jwt
            tags: [module-08]
            config: { key_claim_name: iss, claims_to_verify: [exp], header_names: [Authorization], anonymous: $ANON_ID }
          - name: key-auth
            tags: [module-08]
            config: { key_names: [X-API-Key], hide_credentials: true, anonymous: $ANON_ID }
          - name: acl
            tags: [module-08]
            config: { allow: [partner, internal], hide_groups_header: true }

      - name: admin-route
        paths: [/v3/admin]
        strip_path: true
        tags: [module-08]
        plugins:
          - name: key-auth
            tags: [module-08]
            config: { key_names: [X-API-Key], hide_credentials: true }
          - name: acl
            tags: [module-08]
            config: { allow: [internal], hide_groups_header: true }
          - name: ip-restriction
            tags: [module-08]
            config: { allow: [$MY_IP/32], status: 403, message: "Internal-only endpoint" }

      - name: popular-route
        paths: [/v3/flights/popular]
        strip_path: true
        methods: [GET]
        tags: [module-08]
        plugins:
          - name: request-transformer
            tags: [module-08]
            config:
              replace:
                uri: "/anything"
          - name: proxy-cache
            tags: [module-08]
            config:
              response_code: [200]
              request_method: [GET, HEAD]
              content_type: [application/json]
              cache_ttl: 60
              strategy: memory
              cache_control: false
YAML
    ok "Pass 2: all plugins applied via decK"

    # Prometheus is not available on all Konnect tiers - apply it outside the YAML
    # so a missing-plugin error doesn't abort the sync.
    _prom_id=$(api_write POST "/plugins" \
      '{"name":"prometheus","tags":["module-08"],"config":{"status_code_metrics":true,"latency_metrics":true,"bandwidth_metrics":true,"upstream_health_metrics":true,"per_consumer":false}}' \
      2>/dev/null | jq -r '.id // empty')
    if [[ -n "$_prom_id" ]]; then
      ok "Global plugin: prometheus"
    else
      warn "prometheus unavailable on this CP tier - skipping"
    fi

  else
    # ── Admin API path ─────────────────────────────────────────────────────────
    # Consumer Groups - upsert: POST to create, fall back to list-and-filter if already exists
    # (Konnect does not support GET /consumer_groups/{name}; must search the list)
    FREE_GID=$(api_write POST "/consumer_groups" '{"name":"free","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$FREE_GID" ]] && FREE_GID=$(api_curl GET "/consumer_groups" | jq -r '.data[] | select(.name=="free") | .id')
    [[ -z "$FREE_GID" ]] && { err "Cannot create or find consumer group 'free'"; exit 1; }
    PARTNER_GID=$(api_write POST "/consumer_groups" '{"name":"partner","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$PARTNER_GID" ]] && PARTNER_GID=$(api_curl GET "/consumer_groups" | jq -r '.data[] | select(.name=="partner") | .id')
    [[ -z "$PARTNER_GID" ]] && { err "Cannot create or find consumer group 'partner'"; exit 1; }
    INTERNAL_GID=$(api_write POST "/consumer_groups" '{"name":"internal","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$INTERNAL_GID" ]] && INTERNAL_GID=$(api_curl GET "/consumer_groups" | jq -r '.data[] | select(.name=="internal") | .id')
    [[ -z "$INTERNAL_GID" ]] && { err "Cannot create or find consumer group 'internal'"; exit 1; }
    ok "Consumer groups ready (free / partner / internal)"

    # Consumers - upsert: POST to create, fall back to GET UUID if already exists
    ANON_ID=$(api_write POST "/consumers" '{"username":"anonymous","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$ANON_ID" ]] && ANON_ID=$(resolve_id consumers anonymous)
    [[ -z "$ANON_ID" ]] && { err "Cannot create or find consumer 'anonymous'"; exit 1; }
    info "Anonymous Consumer ID: $ANON_ID"
    FREE_UID=$(api_write POST "/consumers" '{"username":"free-user","custom_id":"free-001","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$FREE_UID" ]] && FREE_UID=$(resolve_id consumers free-user)
    [[ -z "$FREE_UID" ]] && { err "Cannot create or find consumer 'free-user'"; exit 1; }
    PARTNER_UID=$(api_write POST "/consumers" '{"username":"partner-issuer-a","custom_id":"partner-a-001","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$PARTNER_UID" ]] && PARTNER_UID=$(resolve_id consumers partner-issuer-a)
    [[ -z "$PARTNER_UID" ]] && { err "Cannot create or find consumer 'partner-issuer-a'"; exit 1; }
    INTERNAL_UID=$(api_write POST "/consumers" '{"username":"internal-svc","custom_id":"internal-001","tags":["module-08"]}' 2>/dev/null | jq -r '.id // empty' || true)
    [[ -z "$INTERNAL_UID" ]] && INTERNAL_UID=$(resolve_id consumers internal-svc)
    [[ -z "$INTERNAL_UID" ]] && { err "Cannot create or find consumer 'internal-svc'"; exit 1; }

    # Credentials - use consumer UUID in path (Konnect requires UUID, not username)
    api_write POST "/consumers/$FREE_UID/key-auth"     '{"key":"FREE-KEY-001"}'     >/dev/null
    api_write POST "/consumers/$INTERNAL_UID/key-auth" '{"key":"INTERNAL-KEY-001"}' >/dev/null
    _jwt_body=$(jq -n --arg s "$JWT_SECRET" \
      '{"key":"partner-a","algorithm":"HS256","secret":$s,"tags":["module-08"]}')
    api_write POST "/consumers/$PARTNER_UID/jwt" "$_jwt_body" >/dev/null

    # ACL credentials (the acl plugin checks these, separate from Consumer Group membership)
    api_write POST "/consumers/$FREE_UID/acls"        '{"group":"free"}'     >/dev/null
    api_write POST "/consumers/$PARTNER_UID/acls"     '{"group":"partner"}'  >/dev/null
    api_write POST "/consumers/$INTERNAL_UID/acls"    '{"group":"internal"}' >/dev/null

    # Consumer Group memberships - use consumer UUID in path
    api_write POST "/consumers/$FREE_UID/consumer_groups"    '{"group":"free"}'     >/dev/null
    api_write POST "/consumers/$PARTNER_UID/consumer_groups" '{"group":"partner"}'  >/dev/null
    api_write POST "/consumers/$INTERNAL_UID/consumer_groups" '{"group":"internal"}' >/dev/null
    ok "Consumers + credentials + group memberships created"

    # Service
    SID=$(api_write POST "/services" \
      '{"name":"travel-svc","url":"https://httpbin.konghq.com","tags":["module-08"]}' | jq -r '.id')

    # Routes
    _r=$(jq -n --arg s "$SID" \
      '{"name":"flights-route","paths":["/v3/flights"],"strip_path":true,"service":{"id":$s},"tags":["module-08"]}')
    RID_FL=$(api_write POST "/routes" "$_r" | jq -r '.id')
    _r=$(jq -n --arg s "$SID" \
      '{"name":"bookings-route","paths":["/v3/bookings"],"strip_path":true,"service":{"id":$s},"tags":["module-08"]}')
    RID_BK=$(api_write POST "/routes" "$_r" | jq -r '.id')
    _r=$(jq -n --arg s "$SID" \
      '{"name":"admin-route","paths":["/v3/admin"],"strip_path":true,"service":{"id":$s},"tags":["module-08"]}')
    RID_AD=$(api_write POST "/routes" "$_r" | jq -r '.id')
    _r=$(jq -n --arg s "$SID" \
      '{"name":"popular-route","paths":["/v3/flights/popular"],"strip_path":true,"methods":["GET"],"service":{"id":$s},"tags":["module-08"]}')
    RID_POP=$(api_write POST "/routes" "$_r" | jq -r '.id')
    ok "Service travel-svc + 4 routes created"

    # Global plugins: cors, correlation-id, prometheus
    api_write POST "/plugins" \
      '{"name":"cors","tags":["module-08"],"config":{"origins":["https://app.mytravel.com","http://localhost:3000"],"methods":["GET","POST","PUT","DELETE","OPTIONS"],"headers":["Content-Type","X-API-Key","Authorization"],"credentials":true,"max_age":3600}}' >/dev/null
    api_write POST "/plugins" \
      '{"name":"correlation-id","tags":["module-08"],"config":{"header_name":"X-Correlation-ID","generator":"uuid#counter","echo_downstream":true}}' >/dev/null
    ok "Global plugins: cors, correlation-id"

    # Prometheus - not available on all Konnect tiers; apply with soft error handling
    _prom_id=$(api_write POST "/plugins" \
      '{"name":"prometheus","tags":["module-08"],"config":{"status_code_metrics":true,"latency_metrics":true,"bandwidth_metrics":true,"upstream_health_metrics":true,"per_consumer":false}}' \
      2>/dev/null | jq -r '.id // empty')
    if [[ -n "$_prom_id" ]]; then
      ok "Global plugin: prometheus"
    else
      warn "prometheus unavailable on this CP tier - skipping"
    fi

    # Consumer-group rate-limiting - use consumer group UUID in path
    api_write POST "/consumer_groups/$FREE_GID/plugins" \
      '{"name":"rate-limiting","tags":["module-08"],"config":{"minute":10,"policy":"local","limit_by":"consumer"}}' >/dev/null
    api_write POST "/consumer_groups/$PARTNER_GID/plugins" \
      '{"name":"rate-limiting","tags":["module-08"],"config":{"minute":100,"policy":"local","limit_by":"consumer"}}' >/dev/null
    api_write POST "/consumer_groups/$INTERNAL_GID/plugins" \
      '{"name":"rate-limiting","tags":["module-08"],"config":{"minute":1000,"policy":"local","limit_by":"consumer"}}' >/dev/null
    ok "Rate-limiting: free=10 / partner=100 / internal=1000 rpm"

    # Service-level response-transformer-advanced
    _rt=$(jq -n '{"name":"response-transformer-advanced","tags":["module-08"],"config":{"remove":{"json":["_debug","internal_id","headers","origin"]},"add":{"json":["_meta.version:v3"],"headers":["X-Bootcamp-Module:08"]}}}')
    api_write POST "/services/$SID/plugins" "$_rt" >/dev/null
    ok "Service plugin: response-transformer-advanced"

    # Route plugins - shared anonymous jwt + key-auth bodies
    _jwt=$(jq -n --arg anon "$ANON_ID" \
      '{"name":"jwt","tags":["module-08"],"config":{"key_claim_name":"iss","claims_to_verify":["exp"],"header_names":["Authorization"],"anonymous":$anon}}')
    _ka=$(jq -n --arg anon "$ANON_ID" \
      '{"name":"key-auth","tags":["module-08"],"config":{"key_names":["X-API-Key"],"hide_credentials":true,"anonymous":$anon}}')

    # flights-route: jwt + key-auth (anonymous fallback) + acl(free,partner,internal)
    api_write POST "/routes/$RID_FL/plugins" "$_jwt" >/dev/null
    api_write POST "/routes/$RID_FL/plugins" "$_ka"  >/dev/null
    api_write POST "/routes/$RID_FL/plugins" \
      '{"name":"acl","tags":["module-08"],"config":{"allow":["free","partner","internal"],"hide_groups_header":true}}' >/dev/null

    # bookings-route: jwt + key-auth (anonymous fallback) + acl(partner,internal)
    api_write POST "/routes/$RID_BK/plugins" "$_jwt" >/dev/null
    api_write POST "/routes/$RID_BK/plugins" "$_ka"  >/dev/null
    api_write POST "/routes/$RID_BK/plugins" \
      '{"name":"acl","tags":["module-08"],"config":{"allow":["partner","internal"],"hide_groups_header":true}}' >/dev/null
    ok "Route plugins: flights + bookings (jwt + key-auth + acl)"

    # admin-route: key-auth (no anonymous) + acl(internal) + ip-restriction
    api_write POST "/routes/$RID_AD/plugins" \
      '{"name":"key-auth","tags":["module-08"],"config":{"key_names":["X-API-Key"],"hide_credentials":true}}' >/dev/null
    api_write POST "/routes/$RID_AD/plugins" \
      '{"name":"acl","tags":["module-08"],"config":{"allow":["internal"],"hide_groups_header":true}}' >/dev/null
    _ipr=$(jq -n --arg ip "$MY_IP/32" \
      '{"name":"ip-restriction","tags":["module-08"],"config":{"allow":[$ip],"status":403,"message":"Internal-only endpoint"}}')
    api_write POST "/routes/$RID_AD/plugins" "$_ipr" >/dev/null
    ok "Route plugins: admin (key-auth + acl + ip-restriction)"

    # popular-route: request-transformer (rewrite path → /anything) + proxy-cache
    api_write POST "/routes/$RID_POP/plugins" \
      '{"name":"request-transformer","tags":["module-08"],"config":{"replace":{"uri":"/anything"}}}' >/dev/null
    api_write POST "/routes/$RID_POP/plugins" \
      '{"name":"proxy-cache","tags":["module-08"],"config":{"response_code":[200],"request_method":["GET","HEAD"],"content_type":["application/json"],"cache_ttl":60,"strategy":"memory","cache_control":false}}' >/dev/null
    ok "Route plugins: popular-route (request-transformer + proxy-cache)"
  fi

  # Wait for the full plugin chain to propagate to the DP before running tests.
  # FREE-KEY-001 returns 200 on /v3/flights only once jwt+key-auth+acl are all active.
  step "Waiting for plugin chain to be active on the DP…"
  wait_for_http_status "${KONNECT_PROXY_URL}/v3/flights/get" 200 90 \
    -H 'X-API-Key: FREE-KEY-001' \
    || { err "Timed out waiting for FREE-KEY-001 to reach 200 on /v3/flights"; exit 1; }
  # Also confirm ACL is live on bookings: free should be blocked (403)
  wait_for_http_status "${KONNECT_PROXY_URL}/v3/bookings/get" 403 30 \
    -H 'X-API-Key: FREE-KEY-001' || true
  ok "Plugin chain is live - proceeding to acceptance tests"
fi

# ──────────────────────────────────────────────────────────────────────────────
# TEST MODE (and end of apply mode) - the 15-step acceptance script
# ──────────────────────────────────────────────────────────────────────────────
hdr "Capstone acceptance test - 15 steps"

PASS=0; FAIL=0
check_eq() {
  local name=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS+1)); ok "$name (got $actual)"
  else
    FAIL=$((FAIL+1)); err "$name (expected $expected, got $actual)"
  fi
}
check_truthy() {
  local name=$1 value=$2
  if [[ -n "$value" && "$value" != "missing" && "$value" != "null" ]]; then
    PASS=$((PASS+1)); ok "$name"
  else
    FAIL=$((FAIL+1)); err "$name (value was '$value')"
  fi
}

PROXY=$KONNECT_PROXY_URL
PARTNER_TOKEN=$(mint_jwt_hs256 "partner-a" "$JWT_SECRET")
info "Minted partner JWT for tests (iss=partner-a)"
# Ensure auth gate is live before running assertions (critical in test mode where config
# may have just been applied by the learner and not yet propagated to the DP).
step "Confirming auth gate is active on /v3/flights…"
wait_for_http_status "${KONNECT_PROXY_URL}/v3/flights/get" 200 60 \
  -H 'X-API-Key: FREE-KEY-001' \
  || warn "FREE-KEY-001 did not return 200 on /v3/flights within 60s - some tests may fail"

# 1. free → /flights (200)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001')
check_eq "1.  free → /flights"             "200" "$HTTP"

# 2. free → /bookings (403)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$PROXY/v3/bookings/get" -H 'X-API-Key: FREE-KEY-001')
check_eq "2.  free → /bookings"            "403" "$HTTP"

# 3. free → /admin (403)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$PROXY/v3/admin/get" -H 'X-API-Key: FREE-KEY-001')
check_eq "3.  free → /admin"               "403" "$HTTP"

# 4. partner (JWT) → /flights (200)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$PROXY/v3/flights/get" -H "Authorization: Bearer $PARTNER_TOKEN")
check_eq "4.  partner → /flights"          "200" "$HTTP"

# 5. partner (JWT) → /bookings (200)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$PROXY/v3/bookings/get" -H "Authorization: Bearer $PARTNER_TOKEN")
check_eq "5.  partner → /bookings"         "200" "$HTTP"

# 6. internal → /admin (200)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$PROXY/v3/admin/get" -H 'X-API-Key: INTERNAL-KEY-001')
check_eq "6.  internal → /admin"           "200" "$HTTP"

# 7. internal from wrong IP - can't simulate without proxying. Manual check.
warn "7.  internal → /admin from non-office IP - MANUAL CHECK (try from another network)"

# 8. CORS preflight for app.mytravel.com
ALLOW=$(curl -s -i -X OPTIONS "$PROXY/v3/flights/get" \
  -H 'Origin: https://app.mytravel.com' \
  -H 'Access-Control-Request-Method: GET' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^access-control-allow-origin/{print $2}' | tr -d '\r\n')
check_eq "8.  CORS preflight"              "https://app.mytravel.com" "$ALLOW"

# 9. free RL limit = 10
LIMIT=$(curl -sI "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-ratelimit-limit-minute/{print $2}' | tr -d '\r\n')
check_eq "9.  free RL limit = 10"          "10"   "$LIMIT"

# 10. internal RL limit = 1000
LIMIT=$(curl -sI "$PROXY/v3/flights/get" -H 'X-API-Key: INTERNAL-KEY-001' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-ratelimit-limit-minute/{print $2}' | tr -d '\r\n')
check_eq "10. internal RL limit = 1000"    "1000" "$LIMIT"

# 11. Correlation-ID present
CORR=$(curl -sI "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-correlation-id/{print $2}' | tr -d '\r\n')
check_truthy "11. Correlation-ID present" "$CORR"

# 12. _debug field stripped
HAS_DEBUG=$(curl -s "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001' | jq 'has("_debug")')
check_eq "12. _debug stripped"             "false" "$HAS_DEBUG"

# 13. _meta.version = v3 (flat key with literal dot - access via ["_meta.version"])
META_VER=$(curl -s "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001' | jq -r '.["_meta.version"] // "absent"')
check_eq "13. _meta.version = v3"          "v3"    "$META_VER"

# 14. proxy-cache Hit on hot endpoint
curl -s -o /dev/null "$PROXY/v3/flights/popular" -H 'X-API-Key: INTERNAL-KEY-001'   # warm (GET)
sleep 1  # allow the cache entry to be written before the Hit check
STATUS=$(curl -s -D - -o /dev/null "$PROXY/v3/flights/popular" -H 'X-API-Key: INTERNAL-KEY-001' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-cache-status/{print $2}' | tr -d '\r\n')
check_eq "14. proxy-cache Hit"             "Hit"  "$STATUS"

# 15. API key hidden from upstream
HAS_KEY=$(curl -s "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001' \
  | jq -r '.headers["X-Api-Key"] // .headers["X-API-Key"] // "absent"')
check_eq "15. API key hidden from upstream" "absent" "$HAS_KEY"

# ──────────────────────────────────────────────────────────────────────────────
# Result
# ──────────────────────────────────────────────────────────────────────────────
hdr "Capstone result: ${PASS} passed, ${FAIL} failed"
if (( FAIL == 0 )); then
  ok "🎉 Capstone passed - your gateway design holds together end-to-end."
else
  err "Capstone failed on ${FAIL} step(s). Re-read the relevant module and fix the plugin chain."
  exit 1
fi

# Optional cleanup if we built things in apply mode
if [[ "$RUN_MODE" == "apply" ]]; then
  hdr "Cleanup"
  printf 'Wipe all M08 entities now? [Y/n]: '
  read -r CLEAN
  case "${CLEAN:-Y}" in
    n|N) warn "Skipping cleanup." ;;
    *)   cleanup_everything; ok "Module 08 cleanup complete."; cleanup_generated_files ;;
  esac
fi

info "Re-run anytime: $0 ${DEPLOY_MODE} ${RUN_MODE}"
