#!/usr/bin/env bash
# verify-module-05.sh - Verify Module 05 (Transformations) against Konnect.
#
# Covers:
#   Lab 05-A  request-transformer-advanced: add, replace, rename, remove, append + templates
#   Lab 05-B  response-transformer-advanced: add/remove json fields, conditional by status
#
# Usage:  ./scripts/verify-module-05.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 05 Verification (Transformations)"

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
# Baseline: Service + Route + 2 Consumers + key-auth
# ──────────────────────────────────────────────────────────────────────────────
hdr "Baseline: Service + Route + Consumers + key-auth"

# Two-pass setup so we can pin per-Consumer templates after IDs exist
if [[ "$CFG_METHOD" == "deck" ]]; then
  cat <<'YAML' | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - username: web-app
    custom_id: web-001
    tags: [module-05]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-05]
    keyauth_credentials: [{ key: mobile-app-secret-key-002 }]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-05]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-05]
        plugins:
          - name: key-auth
            tags: [module-05]
            config:
              key_names: [X-API-Key]
              hide_credentials: true
YAML
else
  for U in web-app:web-001 mobile-app:mobile-001; do
    USER=${U%:*}; CID=${U#*:}
    api_write POST "/consumers" \
      "$(jq -n --arg u "$USER" --arg c "$CID" '{username:$u, custom_id:$c, tags:["module-05"]}')" >/dev/null
  done
  api_write POST "/consumers/web-app/key-auth"    "$(jq -n '{key:"web-app-secret-key-001"}')" >/dev/null
  api_write POST "/consumers/mobile-app/key-auth" "$(jq -n '{key:"mobile-app-secret-key-002"}')" >/dev/null
  api_write POST "/services" \
    "$(jq -n '{name:"flights-svc", url:"https://httpbin.konghq.com", tags:["module-05"]}')" >/dev/null
  SID=$(api_curl GET "/services/flights-svc" | jq -r '.id')
  api_write POST "/routes" \
    "$(jq -n --arg s "$SID" '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$s}, tags:["module-05"]}')" >/dev/null
  RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')
  api_write POST "/routes/$RID/plugins" \
    "$(jq -n '{name:"key-auth", config:{key_names:["X-API-Key"], hide_credentials:true}, tags:["module-05"]}')" >/dev/null
fi
ok "Baseline applied"

RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')
wait_for_route "${KONNECT_PROXY_URL}/flights/anything" 30 || true

# ──────────────────────────────────────────────────────────────────────────────
# Lab 05-A - request-transformer-advanced
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 05-A - Request Transformer"

step "1. Attach request-transformer-advanced with add/rename/remove/replace + template variables"
attach_rta() {
  api_write POST "/routes/$RID/plugins" "$(jq -n '{
    name: "request-transformer-advanced",
    tags: ["module-05"],
    config: {
      add: {
        headers: [
          "X-API-Version:v3",
          "X-Tenant-Type:travel",
          "X-Tenant-Id:$(consumer.custom_id)",
          "X-Calling-User:$(consumer.username)"
        ]
      },
      replace: {
        headers: ["X-Source:kong-gateway"]
      },
      remove: {
        querystring: ["debug","trace","_internal"],
        headers: ["X-Internal-Debug","X-Forwarded-Secret"]
      },
      rename: {
        querystring: ["page:offset","size:limit"]
      },
      append: {
        headers: ["Via:1.1 kong-gateway"]
      }
    }
  }')" >/dev/null
}
attach_rta
ok "request-transformer-advanced attached"
wait_for_route "${KONNECT_PROXY_URL}/flights/anything" 15 || true

step "2. Static header injection - expect X-API-Version: v3 + X-Tenant-Type: travel upstream"
BODY=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001')
V=$(echo "$BODY" | jq -r '.headers["X-Api-Version"] // "missing"')
T=$(echo "$BODY" | jq -r '.headers["X-Tenant-Type"] // "missing"')
[[ "$V" == "v3" && "$T" == "travel" ]] && ok "Static headers reached upstream (X-Api-Version=$V, X-Tenant-Type=$T)" || { err "Static injection failed: V=$V T=$T"; exit 1; }

step "3. Template variables - per-Consumer values resolved dynamically"
WEB=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
  | jq -r '.headers["X-Tenant-Id"]')
MOB=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: mobile-app-secret-key-002' \
  | jq -r '.headers["X-Tenant-Id"]')
if [[ "$WEB" == "web-001" && "$MOB" == "mobile-001" ]]; then
  ok "Templates resolved per-Consumer: web-app→$WEB, mobile-app→$MOB"
else
  err "Template resolution failed (got web=$WEB, mob=$MOB)"; exit 1
fi

step "4. rename querystring - ?page=2&size=20 → ?offset=2&limit=20"
ARGS=$(curl -s "${KONNECT_PROXY_URL}/flights/anything?page=2&size=20" -H 'X-API-Key: web-app-secret-key-001' \
  | jq -c '.args')
if [[ "$ARGS" == '{"limit":"20","offset":"2"}' ]]; then
  ok "rename worked: upstream saw $ARGS"
else
  warn "Expected {limit:'20',offset:'2'}, got: $ARGS"
fi

step "5. remove - ?debug=true&trace=full should be stripped"
ARGS2=$(curl -s "${KONNECT_PROXY_URL}/flights/anything?debug=true&trace=full&legit=ok" -H 'X-API-Key: web-app-secret-key-001' \
  | jq -c '.args')
if [[ "$ARGS2" == '{"legit":"ok"}' ]]; then
  ok "remove worked - upstream saw only $ARGS2"
else
  err "remove failed - upstream still sees: $ARGS2"; exit 1
fi

step "6. replace - client-supplied X-Source must be overwritten to kong-gateway"
SRC=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' -H 'X-Source: malicious-client' \
  | jq -r '.headers["X-Source"]')
if [[ "$SRC" == "kong-gateway" ]]; then
  ok "replace forced X-Source=kong-gateway (overrode client value)"
else
  err "replace failed - upstream saw X-Source=$SRC"; exit 1
fi

step "7. append Via header - both client value + Kong value present"
VIA=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' -H 'Via: 1.0 my-proxy' \
  | jq -r '.headers["Via"]')
if echo "$VIA" | grep -q "my-proxy" && echo "$VIA" | grep -q "kong-gateway"; then
  ok "append works - Via: $VIA"
else
  warn "Expected both 'my-proxy' and 'kong-gateway' in Via, got: $VIA"
fi

pause_verify "Konnect → flights-route → Plugins: request-transformer-advanced enabled. Inspect config."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 05-B - response-transformer-advanced
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 05-B - Response Transformer"

step "1. Attach response-transformer-advanced (add headers + json, remove fields, conditional on 2XX)"
attach_rtra() {
  api_write POST "/routes/$RID/plugins" "$(jq -n '{
    name: "response-transformer-advanced",
    tags: ["module-05"],
    config: {
      add: {
        if_status: ["2XX"],
        headers: ["X-Bootcamp-Module:05", "X-Powered-By:Kong"],
        json: ["_meta.version:v3", "_meta.served_by:kong"]
      },
      remove: {
        if_status: ["2XX"],
        json: ["headers","origin"]
      },
      replace: {
        if_status: ["2XX"],
        json: ["url:[REDACTED]"]
      }
    }
  }')" >/dev/null
}
attach_rtra
ok "response-transformer-advanced attached"
wait_for_route "${KONNECT_PROXY_URL}/flights/anything" 15 || true

step "2. Response headers - expect X-Bootcamp-Module: 05"
BCM=$(curl -sI "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-bootcamp-module/{print $2}' | tr -d '\r\n')
[[ "$BCM" == "05" ]] && ok "X-Bootcamp-Module: $BCM" || { err "Expected '05', got '$BCM'"; exit 1; }

step "3. Body - _meta.version should be added"
META=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
  | jq -r '._meta.version // "missing"')
[[ "$META" == "v3" ]] && ok "_meta.version=$META" || { err "Expected v3, got '$META'"; exit 1; }

step "4. Body - internal fields .headers and .origin should be stripped"
HAS_HEADERS=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
  | jq 'has("headers")')
HAS_ORIGIN=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
  | jq 'has("origin")')
if [[ "$HAS_HEADERS" == "false" && "$HAS_ORIGIN" == "false" ]]; then
  ok "Internal fields stripped (.headers and .origin both removed)"
else
  err "Strip failed - headers=$HAS_HEADERS origin=$HAS_ORIGIN"; exit 1
fi

step "5. replace - .url should be [REDACTED]"
URL=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
  | jq -r '.url')
[[ "$URL" == "[REDACTED]" ]] && ok "url replaced: $URL" || { err "Expected [REDACTED], got '$URL'"; exit 1; }

step "6. Conditional transform - 4xx should NOT get _meta (no API key)"
RESP=$(curl -s "${KONNECT_PROXY_URL}/flights/anything")
HAS_META=$(echo "$RESP" | jq 'has("_meta")' 2>/dev/null || echo "false")
if [[ "$HAS_META" == "false" ]]; then
  ok "_meta NOT added to 401 response (conditional by status worked)"
else
  warn "_meta unexpectedly present on 401 - check if_status config"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Cleanup - wipe everything tagged module-05"
printf 'Delete all M05 entities now? [Y/n]: '
read -r CLEAN
case "${CLEAN:-Y}" in
  n|N) warn "Skipping cleanup." ;;
  *) cleanup_everything; ok "Module 05 cleanup complete."; cleanup_generated_files ;;
esac

hdr "Module 05 verification complete ✓"
ok "Lab 05-A (request transformer with templates) and Lab 05-B (response transformer with conditional) exercised."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
