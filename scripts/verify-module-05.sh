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
snapshot_deck_dump "module-05" "pre-apply"

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
  web_id=$(resolve_id consumers web-app)    || { err "web-app not found"; exit 1; }
  mob_id=$(resolve_id consumers mobile-app) || { err "mobile-app not found"; exit 1; }
  api_write POST "/consumers/$web_id/key-auth" "$(jq -n '{key:"web-app-secret-key-001"}')" >/dev/null
  api_write POST "/consumers/$mob_id/key-auth" "$(jq -n '{key:"mobile-app-secret-key-002"}')" >/dev/null
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
# Wait for the route AND key-auth credentials to fully propagate.
# wait_for_route stops at the first non-404 (a 401 from key-auth), which means
# consumer credentials may still be in-flight.  We need a 200 with a valid key
# before attaching plugins that probe the authenticated response body.
wait_for_http_status "${KONNECT_PROXY_URL}/flights/anything" 200 90 \
  -H 'X-API-Key: web-app-secret-key-001' || exit 1

# ──────────────────────────────────────────────────────────────────────────────
# Lab 05-A - request-transformer-advanced
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 05-A - Request Transformer"
snapshot_deck_dump "module-05" "lab-05a-pre"

step "1. Attach request-transformer-advanced with add/rename/remove/replace + template variables"
attach_rta() {
  # Template variables reference Kong's injected consumer headers (set by key-auth,
  # which runs at priority 1003 before request-transformer-advanced at 801).
  # Valid namespace: $(headers["..."]) - NOT $(consumer.custom_id) which is unsupported.
  api_write POST "/routes/$RID/plugins" "$(jq -n \
    --arg tid 'X-Tenant-Id:$(headers["x-consumer-custom-id"])' \
    --arg usr 'X-Calling-User:$(headers["x-consumer-username"])' \
    '{
      name: "request-transformer-advanced",
      tags: ["module-05"],
      config: {
        add: {
          headers: [
            "X-API-Version:v3",
            "X-Tenant-Type:travel",
            $tid,
            $usr
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
          headers: ["X-Kong-Via:1.1 kong-gateway"]
        }
      }
    }')" >/dev/null
}
attach_rta
ok "request-transformer-advanced attached"
# request-transformer-advanced injects headers into the upstream REQUEST, not the HTTP
# response - httpbin echoes them in its JSON body.  Poll the body, not response headers.
wait_for_body_jq "${KONNECT_PROXY_URL}/flights/anything" '.headers["X-Api-Version"]' 60 \
  -H 'X-API-Key: web-app-secret-key-001' || exit 1

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
OFFSET=$(echo "$ARGS" | jq -r '.offset // empty')
LIMIT=$(echo  "$ARGS" | jq -r '.limit  // empty')
if [[ "$OFFSET" == "2" && "$LIMIT" == "20" ]]; then
  ok "rename worked: page→offset=$OFFSET, size→limit=$LIMIT"
else
  warn "rename: expected page→offset=2, size→limit=20, got: $ARGS"
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

step "7. append X-Kong-Via header - both client value + appended Kong value present"
# Via is consumed/stripped by Kong's reverse-proxy TCP layer (hop-by-hop semantics).
# Use a custom X-Kong-Via header so it travels end-to-end to the upstream echo.
VIA=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' -H 'X-Kong-Via: 1.0 my-proxy' \
  | jq -r '.headers["X-Kong-Via"]')
if echo "$VIA" | grep -q "my-proxy" && echo "$VIA" | grep -q "kong-gateway"; then
  ok "append works - X-Kong-Via: $VIA"
else
  warn "Expected both 'my-proxy' and 'kong-gateway' in X-Kong-Via, got: $VIA"
fi

pause_verify "Konnect → flights-route → Plugins: request-transformer-advanced enabled. Inspect config."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 05-B - response-transformer-advanced
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 05-B - Response Transformer"
snapshot_deck_dump "module-05" "lab-05b-pre"

step "1. Attach response-transformer-advanced (add headers + json, remove fields, conditional on 2XX)"
attach_rtra() {
  # if_status: Kong requires exact codes ("200") or numeric ranges ("200-299").
  # "2XX" wildcard notation is NOT supported and returns HTTP 400.
  # dots_in_keys: false so "top.sub" in json paths navigates nested objects
  # (default true treats the dot as a literal key-name character).
  api_write POST "/routes/$RID/plugins" "$(jq -n '{
    name: "response-transformer-advanced",
    tags: ["module-05"],
    config: {
      dots_in_keys: false,
      add: {
        if_status: ["200-299"],
        headers: ["X-Bootcamp-Module:05", "X-Powered-By:Kong"],
        json: ["_meta.version:v3", "_meta.served_by:kong"]
      },
      remove: {
        if_status: ["200-299"],
        json: ["headers","origin"]
      },
      replace: {
        if_status: ["200-299"],
        json: ["url:[REDACTED]"]
      }
    }
  }')" >/dev/null
}
attach_rtra || { err "response-transformer-advanced failed to attach"; exit 1; }
ok "response-transformer-advanced attached"
# Wait for the plugin to propagate: poll until the injected X-Bootcamp-Module header appears.
wait_for_response_header "${KONNECT_PROXY_URL}/flights/anything" "x-bootcamp-module" 60 \
  -H 'X-API-Key: web-app-secret-key-001' || exit 1

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
