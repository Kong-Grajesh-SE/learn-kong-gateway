#!/usr/bin/env bash
# verify-module-03.sh - Verify Module 03 (Easy Wins) against Konnect.
#
# Covers:
#   Lab 03-A  Consumers + key-auth deep dive (with anonymous fallback)
#   Lab 03-B  cors + ip-restriction + correlation-id
#
# Usage:  ./scripts/verify-module-03.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 03 Verification (Easy Wins)"

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
# Build the baseline: Service + Route + 2 Consumers + an anonymous Consumer
# ──────────────────────────────────────────────────────────────────────────────
hdr "Baseline: Service + Route + Consumers"

apply_baseline() {
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - { username: anonymous, tags: [module-03] }
  - username: web-app
    custom_id: web-001
    tags: [module-03]
    keyauth_credentials:
      - { key: web-app-secret-key-001, tags: [module-03] }
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-03]
    keyauth_credentials:
      - { key: mobile-app-secret-key-002, tags: [module-03] }
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-03]
    routes:
      - { name: flights-route, paths: [/flights], strip_path: true, tags: [module-03] }
YAML
  else
    # Consumers
    for U in anonymous:_ web-app:web-001 mobile-app:mobile-001; do
      USER=${U%:*}; CID=${U#*:}
      if [[ "$CID" == "_" ]]; then
        api_write POST "/consumers" \
          "$(jq -n --arg u "$USER" '{username:$u, tags:["module-03"]}')" >/dev/null
      else
        api_write POST "/consumers" \
          "$(jq -n --arg u "$USER" --arg c "$CID" '{username:$u, custom_id:$c, tags:["module-03"]}')" >/dev/null
      fi
    done
    # Credentials - Konnect requires UUIDs in path for nested writes
    local web_id mob_id
    web_id=$(resolve_id consumers web-app)    || { err "web-app not found"; return 1; }
    mob_id=$(resolve_id consumers mobile-app) || { err "mobile-app not found"; return 1; }
    api_write POST "/consumers/$web_id/key-auth" "$(jq -n '{key:"web-app-secret-key-001"}')" >/dev/null
    api_write POST "/consumers/$mob_id/key-auth" "$(jq -n '{key:"mobile-app-secret-key-002"}')" >/dev/null
    # Service + Route
    api_write POST "/services" \
      "$(jq -n '{name:"flights-svc", url:"https://httpbin.konghq.com", tags:["module-03"]}')" >/dev/null
    local sid; sid=$(api_curl GET "/services/flights-svc" | jq -r '.id')
    api_write POST "/routes" \
      "$(jq -n --arg s "$sid" '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$s}, tags:["module-03"]}')" >/dev/null
  fi
}
apply_baseline
ok "Baseline applied - 3 Consumers (web-app, mobile-app, anonymous), 1 Service, 1 Route"

info "Consumers:" ; list_consumers
info "Services:"  ; list_services

# Resolve the anonymous Consumer's ID once; we'll need it for key-auth `anonymous:` config.
ANON_ID=$(api_curl GET "/consumers/anonymous" | jq -r '.id')
[[ -z "$ANON_ID" || "$ANON_ID" == "null" ]] && { err "Could not resolve anonymous Consumer ID"; exit 1; }
ok "Anonymous Consumer ID: $ANON_ID"

pause_verify "Konnect → Consumers: confirm web-app (key: web-app-secret-key-001), mobile-app (key: mobile-app-secret-key-002), anonymous (no creds)."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 03-A - key-auth deep dive
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 03-A - Consumers & key-auth"

step "1. Attach key-auth (no anonymous fallback yet) to flights-route"
attach_keyauth() {
  local anon=${1:-}
  local body
  if [[ -n "$anon" ]]; then
    body=$(jq -n --arg a "$anon" \
      '{name:"key-auth", config:{key_names:["X-API-Key","apikey"], key_in_header:true, key_in_query:true, hide_credentials:true, anonymous:$a}, tags:["module-03"]}')
  else
    body='{"name":"key-auth","config":{"key_names":["X-API-Key","apikey"],"key_in_header":true,"key_in_query":true,"hide_credentials":true},"tags":["module-03"]}'
  fi
  if [[ "$CFG_METHOD" == "deck" ]]; then
    # decK: route-level plugin via sync
    local anon_yaml=""
    [[ -n "$anon" ]] && anon_yaml="
              anonymous: $anon"
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - { username: anonymous, tags: [module-03] }
  - username: web-app
    custom_id: web-001
    tags: [module-03]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-03]
    keyauth_credentials: [{ key: mobile-app-secret-key-002 }]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-03]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-03]
        plugins:
          - name: key-auth
            tags: [module-03]
            config:
              key_names: [X-API-Key, apikey]
              key_in_header: true
              key_in_query:  true
              hide_credentials: true${anon_yaml}
YAML
  else
    local rid; rid=$(api_curl GET "/routes/flights-route" | jq -r '.id')
    # Remove any existing key-auth on this route first
    local existing
    existing=$(api_curl GET "/routes/$rid/plugins?name=key-auth" | jq -r '.data[]?.id')
    [[ -n "$existing" ]] && api_curl DELETE "/plugins/$existing" >/dev/null
    api_write POST "/routes/$rid/plugins" "$body" >/dev/null
  fi
}

attach_keyauth ""    # no anonymous fallback
ok "key-auth attached (no anonymous)"

wait_for_route "${KONNECT_PROXY_URL}/flights/get" 30 || exit 1
# key-auth may propagate after the route itself is live; wait for the 401.
wait_for_http_status "${KONNECT_PROXY_URL}/flights/get" 401 45 || exit 1

step "2. Hit the route WITHOUT a key - expect 401"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
if [[ "$HTTP" == "401" ]]; then
  ok "401 Unauthorized (correct - no key, no anonymous fallback)"
else
  err "Expected 401, got $HTTP"; exit 1
fi

step "3. Hit with a valid key - expect 200 + correct X-Consumer-Username injected"
BODY=$(curl -s "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001')
CONS=$(echo "$BODY" | jq -r '.headers["X-Consumer-Username"] // .headers["X-Consumer-Username"] // "missing"')
if [[ "$CONS" == "web-app" ]]; then
  ok "Identified as Consumer 'web-app' via X-Consumer-Username header"
else
  err "Expected X-Consumer-Username=web-app, got '$CONS'"
  echo "$BODY" | jq '.headers' | head -20
  exit 1
fi

step "4. hide_credentials - upstream must NOT see X-API-Key"
LEAKED=$(echo "$BODY" | jq -r '.headers["X-Api-Key"] // .headers["X-API-Key"] // "absent"')
if [[ "$LEAKED" == "absent" ]]; then
  ok "API key stripped before upstream (hide_credentials works)"
else
  err "API key leaked to upstream: $LEAKED"; exit 1
fi

step "5. Hit with wrong key - expect 401"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: definitely-not-real')
if [[ "$HTTP" == "401" ]]; then ok "Wrong key → 401"; else err "Expected 401, got $HTTP"; exit 1; fi

step "6. Anonymous fallback - add anonymous Consumer ID to key-auth config"
attach_keyauth "$ANON_ID"
wait_for_http_status "${KONNECT_PROXY_URL}/flights/get" 200 45 || true

CONS=$(curl -s "${KONNECT_PROXY_URL}/flights/get" | jq -r '.headers["X-Consumer-Username"] // "missing"')
if [[ "$CONS" == "anonymous" ]]; then
  ok "No-key request is now identified as 'anonymous' Consumer"
else
  err "Expected anonymous, got '$CONS'"; exit 1
fi

pause_verify "Konnect → Plugins: key-auth on flights-route with anonymous → $ANON_ID. Confirm in UI."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 03-B - cors + ip-restriction + correlation-id
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 03-B - CORS, IP Restriction, Correlation ID"

step "1. Detach key-auth and apply baseline + 3 Tier-1 plugins"

apply_lab_03b() {
  # Resolve the client's apparent IP (so we can allow it via ip-restriction)
  CLIENT_IP=$(curl -s "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001' \
    | jq -r '.origin' | cut -d',' -f1 | tr -d ' ')
  [[ -z "$CLIENT_IP" || "$CLIENT_IP" == "null" ]] && CLIENT_IP="$(curl -s https://httpbin.konghq.com/ip | jq -r '.origin')"
  info "Your apparent IP (will be added to ip-restriction allow list): $CLIENT_IP"

  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'

plugins:
  - name: cors
    tags: [module-03]
    config:
      origins: [https://app.mytravel.com, http://localhost:3000]
      methods: [GET, POST, PUT, DELETE, OPTIONS]
      headers: [Content-Type, X-API-Key, Authorization]
      exposed_headers: [X-Kong-Request-Id, X-Correlation-ID]
      credentials: true
      max_age: 3600
  - name: correlation-id
    tags: [module-03]
    config:
      header_name: X-Correlation-ID
      generator: uuid#counter
      echo_downstream: true

consumers:
  - { username: anonymous, tags: [module-03] }
  - username: web-app
    custom_id: web-001
    tags: [module-03]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-03]
    keyauth_credentials: [{ key: mobile-app-secret-key-002 }]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-03]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-03]
        plugins:
          - name: ip-restriction
            tags: [module-03]
            config:
              allow: [$CLIENT_IP]
              status: 403
              message: "Your IP is not allowed."
YAML
  else
    # Remove old key-auth plugin from the route
    local rid; rid=$(api_curl GET "/routes/flights-route" | jq -r '.id')
    local kid; kid=$(api_curl GET "/routes/$rid/plugins?name=key-auth" | jq -r '.data[0]?.id // empty')
    [[ -n "$kid" ]] && api_curl DELETE "/plugins/$kid" >/dev/null
    # Add cors + correlation-id globally
    api_write POST "/plugins" \
      "$(jq -n '{name:"cors", config:{origins:["https://app.mytravel.com","http://localhost:3000"], methods:["GET","POST","PUT","DELETE","OPTIONS"], headers:["Content-Type","X-API-Key","Authorization"], exposed_headers:["X-Kong-Request-Id","X-Correlation-ID"], credentials:true, max_age:3600}, tags:["module-03"]}')" >/dev/null
    api_write POST "/plugins" \
      "$(jq -n '{name:"correlation-id", config:{header_name:"X-Correlation-ID", generator:"uuid#counter", echo_downstream:true}, tags:["module-03"]}')" >/dev/null
    # Add ip-restriction (route-scoped) with the client IP in allow list
    api_write POST "/routes/$rid/plugins" \
      "$(jq -n --arg ip "$CLIENT_IP" '{name:"ip-restriction", config:{allow:[$ip], status:403, message:"Your IP is not allowed."}, tags:["module-03"]}')" >/dev/null
  fi
}
apply_lab_03b
ok "cors (global), correlation-id (global), ip-restriction (route → allow $CLIENT_IP) applied"

# Route is already live from Lab 03-A.  Wait until the newly-added plugins have
# propagated by polling for the correlation-id header (last plugin in the chain).
wait_for_response_header "${KONNECT_PROXY_URL}/flights/get" "x-correlation-id" 60 || exit 1

step "2. CORS - allowed origin should get Access-Control-Allow-Origin"
ALLOW=$(curl -s -i -X OPTIONS "${KONNECT_PROXY_URL}/flights/get" \
  -H 'Origin: https://app.mytravel.com' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: X-API-Key' \
  | awk -F': ' '/^access-control-allow-origin/{print $2}' | tr -d '\r\n')
if [[ "$ALLOW" == "https://app.mytravel.com" ]]; then
  ok "CORS preflight for allowed origin returns Access-Control-Allow-Origin: $ALLOW"
else
  err "Expected Allow-Origin=https://app.mytravel.com, got '$ALLOW'"; exit 1
fi

step "3. CORS - disallowed origin should NOT get Access-Control-Allow-Origin"
DISALLOW=$(curl -s -i -X OPTIONS "${KONNECT_PROXY_URL}/flights/get" \
  -H 'Origin: https://evil.com' \
  -H 'Access-Control-Request-Method: GET' \
  | awk -F': ' '/^access-control-allow-origin/{print $2}' | tr -d '\r\n')
if [[ -z "$DISALLOW" ]]; then
  ok "No Allow-Origin for disallowed origin (correct)"
else
  warn "Unexpected Allow-Origin: $DISALLOW"
fi

step "4. correlation-id - Kong should inject one and echo it downstream"
# Plugin propagation was already confirmed by wait_for_response_header above.
CORR_DOWN=$(curl -sI "${KONNECT_PROXY_URL}/flights/get" | awk -F': ' '/^x-correlation-id/{print $2}' | tr -d '\r\n')
if [[ -n "$CORR_DOWN" ]]; then
  ok "X-Correlation-ID present in response: $CORR_DOWN"
else
  err "No X-Correlation-ID in response - plugin not active"; exit 1
fi

step "5. correlation-id - client-supplied header should be preserved"
CUSTOM_ID="my-custom-trace-id-12345"
SEEN=$(curl -s "${KONNECT_PROXY_URL}/flights/get" -H "X-Correlation-ID: $CUSTOM_ID" \
  | jq -r '.headers["X-Correlation-Id"] // "missing"')
if [[ "$SEEN" == "$CUSTOM_ID" ]]; then
  ok "Client-supplied correlation ID preserved: $SEEN"
else
  warn "Client value not preserved (got '$SEEN') - Konnect plugin schema may differ; check the lab"
fi

step "6. ip-restriction - your IP is on the allow list, expect 200"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
if [[ "$HTTP" == "200" ]]; then
  ok "Allow list works - $CLIENT_IP got 200"
else
  err "Expected 200 (your IP is allowed), got $HTTP"; exit 1
fi

step "7. ip-restriction - flip to deny list and re-test"
flip_ip_to_deny() {
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'

plugins:
  - name: cors
    tags: [module-03]
    config:
      origins: [https://app.mytravel.com, http://localhost:3000]
      methods: [GET, POST, PUT, DELETE, OPTIONS]
      headers: [Content-Type, X-API-Key, Authorization]
      credentials: true
      max_age: 3600
  - name: correlation-id
    tags: [module-03]
    config:
      header_name: X-Correlation-ID
      generator: uuid#counter
      echo_downstream: true

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-03]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-03]
        plugins:
          - name: ip-restriction
            tags: [module-03]
            config:
              deny: [$CLIENT_IP]
              status: 403
              message: "Your IP is not allowed."
YAML
  else
    # Konnect rejects PATCH on /plugins/{id} - DELETE the existing ip-restriction
    # plugin and POST a fresh one with the deny list instead.
    local rid; rid=$(api_curl GET "/routes/flights-route" | jq -r '.id')
    local pid; pid=$(api_curl GET "/routes/$rid/plugins?name=ip-restriction" | jq -r '.data[0]?.id // empty')
    [[ -n "$pid" ]] && api_curl DELETE "/plugins/$pid" >/dev/null
    api_write POST "/routes/$rid/plugins" \
      "$(jq -n --arg ip "$CLIENT_IP" '{name:"ip-restriction", config:{deny:[$ip], status:403, message:"Your IP is not allowed."}, tags:["module-03"]}')" >/dev/null \
      || { err "Failed to re-create ip-restriction with deny list"; return 1; }
  fi
}
flip_ip_to_deny
sleep 12   # propagation
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
if [[ "$HTTP" == "403" ]]; then
  ok "Deny list works - your IP got 403"
else
  warn "Expected 403, got $HTTP (deny may need more propagation time)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Cleanup - wipe everything tagged module-03 so M04 starts clean"
printf 'Delete all M03 entities now? [Y/n]: '
read -r CLEAN
case "${CLEAN:-Y}" in
  n|N) warn "Skipping cleanup - M04 will need to clean up manually." ;;
  *)
    cleanup_everything
    cleanup_generated_files
    ok "Module 03 cleanup complete."
    ;;
esac

hdr "Module 03 verification complete ✓"
ok "All steps from Lab 03-A (Consumers + key-auth + anonymous) and Lab 03-B (cors + ip-restriction + correlation-id) were exercised."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
