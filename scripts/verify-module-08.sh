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

  MY_IP=$(curl -s "https://httpbin.konghq.com/ip" | jq -r '.origin' | cut -d',' -f1 | tr -d ' ')
  info "Your apparent IP (added to ip-restriction allow list for /admin): $MY_IP"

  # Two-pass: create Consumers/Service/Routes first so we can grab anonymous ID
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
    groups: [free]
    tags: [module-08]
    keyauth_credentials: [{ key: FREE-KEY-001 }]
  - username: partner-issuer
    custom_id: partner-001
    groups: [partner]
    tags: [module-08]
    jwt_secrets:
      - { key: partner-a, algorithm: HS256, secret: $JWT_SECRET }
  - username: internal-svc
    custom_id: internal-001
    groups: [internal]
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
  ok "Consumers + Service + Routes created (no plugins yet)"

  ANON_ID=$(api_curl GET "/consumers/anonymous" | jq -r '.id')
  info "Anonymous Consumer ID: $ANON_ID"

  # Pass 2: plugins (global + per-route + per-consumer-group)
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
    groups: [free]
    tags: [module-08]
    keyauth_credentials: [{ key: FREE-KEY-001 }]
  - username: partner-issuer
    custom_id: partner-001
    groups: [partner]
    tags: [module-08]
    jwt_secrets:
      - { key: partner-a, algorithm: HS256, secret: $JWT_SECRET }
  - username: internal-svc
    custom_id: internal-001
    groups: [internal]
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
  - name: prometheus
    tags: [module-08]
    config: { status_code_metrics: true, latency_metrics: true, bandwidth_metrics: true, upstream_health_metrics: true, per_consumer: false }

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
          remove: { if_status: ["2XX"], json: [_debug, internal_id, headers, origin] }
          add:    { if_status: ["2XX"], json: ["_meta.version:v3"], headers: ["X-Bootcamp-Module:08"] }
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
  ok "Plugins applied. Waiting 20s for propagation…"
  sleep 20
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
sleep 2

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

# 13. _meta.version = v3
META_VER=$(curl -s "$PROXY/v3/flights/get" -H 'X-API-Key: FREE-KEY-001' | jq -r '._meta.version // "absent"')
check_eq "13. _meta.version = v3"          "v3"    "$META_VER"

# 14. proxy-cache Hit on hot endpoint
curl -s -o /dev/null "$PROXY/v3/flights/popular" -H 'X-API-Key: INTERNAL-KEY-001'   # warm
STATUS=$(curl -sI "$PROXY/v3/flights/popular" -H 'X-API-Key: INTERNAL-KEY-001' \
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
