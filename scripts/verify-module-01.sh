#!/usr/bin/env bash
# verify-module-01.sh - Verify Module 01 (Your First Gateway) against Konnect.
#
# Covers:
#   Lab 01 (Quick Start)            Konnect reachability, Service + Route, proxied traffic,
#                                   Kong-added headers, status passthrough, strip_path drill,
#                                   deck dump
#   Lab 01-hybrid-docker-setup      Hybrid-mode DP health + connection check (when DEPLOY_MODE=hybrid)
#
# Usage:  ./scripts/verify-module-01.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 01 Verification (Your First Gateway)"

check_prerequisites
load_env
pick_deploy_mode "${1-}"
collect_konnect_inputs
pick_cfg_method
save_env

# ──────────────────────────────────────────────────────────────────────────────
# Module-specific helpers
# ──────────────────────────────────────────────────────────────────────────────
SVC_NAME="httpbin-service"
ROUTE_NAME="httpbin-route"
ROUTE_PATH="/demo"
UPSTREAM_URL="https://httpbin.konghq.com"

m01_create_service_and_route() {
  local svc_name=$1 svc_url=$2 route_name=$3 route_path=$4
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
services:
  - name: $svc_name
    url: $svc_url
    tags: [module-01, bootcamp]
    routes:
      - name: $route_name
        paths: [$route_path]
        strip_path: true
        tags: [module-01, bootcamp]
YAML
  else
    # Konnect Admin API: PUT requires a UUID in the path, so we POST to create and
    # GET to resolve the auto-assigned id. If the entity already exists, GET still
    # returns its id, so the flow is idempotent.
    local sid
    sid=$(api_curl GET "/services/$svc_name" 2>/dev/null | jq -r '.id // empty')
    if [[ -z "$sid" ]]; then
      api_write POST "/services" \
        "$(jq -n --arg n "$svc_name" --arg u "$svc_url" \
              '{name:$n, url:$u, tags:["module-01","bootcamp"]}')" >/dev/null \
        || { err "Failed to create service $svc_name"; return 1; }
      sid=$(api_curl GET "/services/$svc_name" | jq -r '.id // empty')
    else
      info "Service '$svc_name' already exists (id=$sid) - skipping create"
    fi
    [[ -z "$sid" ]] && { err "Service $svc_name not found after POST"; return 1; }
    ok "Service '$svc_name' (id=$sid)"

    local rid
    rid=$(api_curl GET "/routes/$route_name" 2>/dev/null | jq -r '.id // empty')
    if [[ -z "$rid" ]]; then
      api_write POST "/routes" \
        "$(jq -n --arg n "$route_name" --arg p "$route_path" --arg sid "$sid" \
              '{name:$n, paths:[$p], strip_path:true, service:{id:$sid}, tags:["module-01","bootcamp"]}')" >/dev/null \
        || { err "Failed to create route $route_name"; return 1; }
      rid=$(api_curl GET "/routes/$route_name" | jq -r '.id // empty')
    else
      info "Route '$route_name' already exists (id=$rid) - skipping create"
    fi
    [[ -z "$rid" ]] && { err "Route $route_name not found after POST"; return 1; }
    ok "Route '$route_name' on $route_path (strip_path=true)"
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Pre-flight
# ──────────────────────────────────────────────────────────────────────────────
hdr "Pre-flight"
ping_konnect
check_kong_version

if [[ "$CFG_METHOD" == "deck" ]]; then
  step "decK auth check"
  if deck_ping; then ok "decK can reach the CP"; else err "decK ping failed - check CP NAME / token"; exit 1; fi
fi

verify_hybrid_dp
cleanup_if_needed
snapshot_deck_dump "module-01" "pre-apply"

step "Proxy reachability - expect 404 'no Route matched' (no routes yet)"
PROXY_BODY_HTTP=$(curl -sS -o /tmp/m01_proxy.txt -w '%{http_code}' "$KONNECT_PROXY_URL/" || true)
if grep -q "no Route matched" /tmp/m01_proxy.txt 2>/dev/null; then
  ok "Proxy reachable (HTTP $PROXY_BODY_HTTP, default Kong response)"
else
  warn "Proxy responded with HTTP $PROXY_BODY_HTTP:"
  cat /tmp/m01_proxy.txt; echo
  warn "If you already have routes on this CP, the cleanup gate should have caught it. Investigate before continuing."
fi
rm -f /tmp/m01_proxy.txt

if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  pause_verify "Konnect → Gateway Manager → '$KONNECT_CP_NAME' → Data Plane Nodes. Confirm your local DP appears with a green 'Connected' indicator."
else
  pause_verify "Konnect → Gateway Manager → '$KONNECT_CP_NAME' → Overview. Confirm the CP is healthy and your serverless DP is running."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 01-B - First API call through Kong
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 01 - First API call through Kong"
snapshot_deck_dump "module-01" "lab-01-pre"

step "0. Sanity-check upstream directly (before Kong is in the path)"
UP_RESP=$(curl -sS -w '\n__HTTP__%{http_code}' "$UPSTREAM_URL/get")
UP_HTTP=$(printf '%s' "$UP_RESP" | sed -n 's/.*__HTTP__//p')
UP_BODY=$(printf '%s' "$UP_RESP" | sed 's/__HTTP__.*//')
if [[ "$UP_HTTP" == "200" ]]; then
  ok "Upstream $UPSTREAM_URL is reachable (HTTP 200)"
  echo "$UP_BODY" | jq '{url, origin}'
else
  err "Upstream returned HTTP $UP_HTTP - cannot verify Kong end-to-end. Aborting."; exit 1
fi

step "1. Create Service + Route via $CFG_METHOD"
m01_create_service_and_route "$SVC_NAME" "$UPSTREAM_URL" "$ROUTE_NAME" "$ROUTE_PATH"

info "Services on this CP:"
list_services
info "Routes on this CP:"
list_routes

pause_verify "Konnect → Gateway Services: confirm '$SVC_NAME' exists with host=httpbin.konghq.com, port=443. Click into it → Routes tab: confirm '$ROUTE_NAME' on path '$ROUTE_PATH' (strip_path=true)."

step "1b. Wait for the route to be live on the DP"
PROP_TIMEOUT=30
if [[ "$DEPLOY_MODE" == "serverless" ]]; then
  info "Serverless DPs poll Konnect every ~10s. Allowing up to ${PROP_TIMEOUT}s."
else
  info "Local hybrid DP usually picks up config in <15s. Allowing up to ${PROP_TIMEOUT}s."
fi
if ! wait_for_route "${KONNECT_PROXY_URL}${ROUTE_PATH}/get" "$PROP_TIMEOUT"; then
  err "Route never went live. Possible causes:"
  err "  • Wrong PROXY URL ($KONNECT_PROXY_URL) - does this CP own that proxy?"
  err "  • Wrong CP - decK/API hit a different CP than the proxy URL"
  err "  • Serverless DP suspended (free tier) - re-deploy from Konnect"
  exit 1
fi

step "2. GET ${KONNECT_PROXY_URL}${ROUTE_PATH}/get - basic proxied request"
RESP=$(curl -sS -w '\n__HTTP__%{http_code}' "${KONNECT_PROXY_URL}${ROUTE_PATH}/get")
HTTP=$(printf '%s' "$RESP" | sed -n 's/.*__HTTP__//p')
BODY=$(printf '%s' "$RESP" | sed 's/__HTTP__.*//')
if [[ "$HTTP" == "200" ]]; then
  ok "HTTP 200 from proxy"
  echo "$BODY" | jq '{url, origin, host:.headers.Host, kong_request_id:.headers["X-Kong-Request-Id"]}'
else
  err "Expected 200, got $HTTP"; echo "$BODY"; exit 1
fi

step "3. Confirm Kong-added forwarding headers"
FWD_HEADERS=$(echo "$BODY" | jq -r '
  .headers | to_entries
  | map(select(.key | test("^(X-Forwarded|X-Kong)"; "i")))
  | from_entries')
echo "$FWD_HEADERS" | jq .

# Required in any mode: a request ID + a forwarded host record
REQUIRED=( "X-Kong-Request-Id" "X-Forwarded-Host" )
# Mode-dependent: Konnect's edge proxy strips X-Forwarded-For/Port/Proto in serverless;
# a self-hosted DP forwards them as-is.
if [[ "$DEPLOY_MODE" == "serverless" ]]; then
  EXPECTED_EXTRA=( "X-Forwarded-Path" "X-Forwarded-Prefix" )
else
  EXPECTED_EXTRA=( "X-Forwarded-For" "X-Forwarded-Port" "X-Forwarded-Proto" )
fi

MISSING_REQUIRED=()
for h in "${REQUIRED[@]}"; do
  echo "$FWD_HEADERS" | jq -e --arg h "$h" 'has($h)' >/dev/null || MISSING_REQUIRED+=("$h")
done
MISSING_EXTRA=()
for h in "${EXPECTED_EXTRA[@]}"; do
  echo "$FWD_HEADERS" | jq -e --arg h "$h" 'has($h)' >/dev/null || MISSING_EXTRA+=("$h")
done

if (( ${#MISSING_REQUIRED[@]} == 0 )); then
  ok "Required headers present: ${REQUIRED[*]}"
else
  err "Missing REQUIRED headers: ${MISSING_REQUIRED[*]}"; exit 1
fi
if (( ${#MISSING_EXTRA[@]} == 0 )); then
  ok "Mode-specific headers present (${DEPLOY_MODE}): ${EXPECTED_EXTRA[*]}"
else
  warn "Missing ${DEPLOY_MODE}-specific headers: ${MISSING_EXTRA[*]} (Kong/Konnect version may differ)"
fi
[[ "$DEPLOY_MODE" == "serverless" ]] && info "Note: Konnect's edge proxy strips X-Forwarded-For/Port/Proto before the upstream - expected in serverless."

step "4. POST ${ROUTE_PATH}/post - verify body forwarding"
POST_BODY='{"booking":"NYC-LON","seats":2}'
POST_RESP=$(curl -sS -X POST "${KONNECT_PROXY_URL}${ROUTE_PATH}/post" \
  -H "Content-Type: application/json" -d "$POST_BODY")
ECHOED=$(echo "$POST_RESP" | jq -c '.json')
if [[ "$ECHOED" == "$POST_BODY" || "$ECHOED" == '{"booking":"NYC-LON","seats":2}' ]]; then
  ok "Upstream echoed body correctly: $ECHOED"
else
  err "Body mismatch. Sent: $POST_BODY | Got: $ECHOED"; exit 1
fi

step "5. Status code passthrough (404, 503) and latency (delay/1)"
for code in 404 503; do
  GOT=$(curl -sS -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}${ROUTE_PATH}/status/$code")
  if [[ "$GOT" == "$code" ]]; then
    ok "/status/$code → $GOT"
  else
    err "/status/$code expected $code, got $GOT"; exit 1
  fi
done
T_START=$(date +%s)
curl -sS -o /dev/null "${KONNECT_PROXY_URL}${ROUTE_PATH}/delay/1"
T_END=$(date +%s)
ELAPSED=$((T_END - T_START))
if (( ELAPSED >= 1 )); then
  ok "/delay/1 took ${ELAPSED}s (≥1s, as expected)"
else
  warn "/delay/1 returned in ${ELAPSED}s (unexpectedly fast)"
fi

step "6. strip_path verification - /demo is removed before upstream sees it"
# httpbin.konghq.com reconstructs .url from X-Forwarded-Host, so the host portion
# is the proxy host (serverless edge or localhost), NOT httpbin's. The reliable
# strip_path indicator is the PATH component - it must be /get, not /demo/get.
URL_SEEN_BY_UPSTREAM=$(curl -sS "${KONNECT_PROXY_URL}${ROUTE_PATH}/get" | jq -r '.url')
PATH_SEEN=$(printf '%s' "$URL_SEEN_BY_UPSTREAM" | sed -E 's|^[a-zA-Z]+://[^/]+||; s|\?.*$||')
if [[ "$PATH_SEEN" == "/get" ]]; then
  ok "strip_path works - upstream saw path '$PATH_SEEN' (full url: $URL_SEEN_BY_UPSTREAM)"
elif [[ "$PATH_SEEN" == /demo/* ]]; then
  err "strip_path NOT working - upstream still sees '/demo' prefix: $PATH_SEEN"
  err "Full url: $URL_SEEN_BY_UPSTREAM"; exit 1
else
  warn "Unexpected upstream path: '$PATH_SEEN' (full url: $URL_SEEN_BY_UPSTREAM)"
fi

pause_verify "Konnect → Analytics (or your CP Overview): confirm you see request activity for '$SVC_NAME'. The traffic counter may take ~1 minute to update."

# ──────────────────────────────────────────────────────────────────────────────
# Optional: second service using an alternative public httpbin backend
# Works in both serverless and hybrid modes (no local backend required)
# ──────────────────────────────────────────────────────────────────────────────
printf '\nOptional: create a second service with an alternative httpbin backend? [Y/n]: '
read -r EXTRA_CHOICE
if [[ "${EXTRA_CHOICE:-Y}" =~ ^[Yy]$ ]]; then
  # Pick a random alternative backend to demonstrate multiple upstreams
  EXTRA_BACKENDS=("https://httpbin.org" "https://httpbun.com")
  EXTRA_URL="${EXTRA_BACKENDS[$((RANDOM % ${#EXTRA_BACKENDS[@]}))]}"
  EXTRA_SVC="httpbin-extra"
  EXTRA_ROUTE="httpbin-extra-route"
  EXTRA_PATH="/extra"

  step "Create second service '$EXTRA_SVC' → $EXTRA_URL"
  m01_create_service_and_route "$EXTRA_SVC" "$EXTRA_URL" "$EXTRA_ROUTE" "$EXTRA_PATH"

  if wait_for_route "${KONNECT_PROXY_URL}${EXTRA_PATH}/get" 30; then
    EXTRA_HTTP=$(curl -sS -o /tmp/m01_extra.json -w '%{http_code}' "${KONNECT_PROXY_URL}${EXTRA_PATH}/get")
    if [[ "$EXTRA_HTTP" == "200" ]]; then
      ok "$EXTRA_SVC upstream reachable through Kong (HTTP $EXTRA_HTTP)"
      jq '{url, origin}' /tmp/m01_extra.json 2>/dev/null || head -c 300 /tmp/m01_extra.json
    else
      warn "$EXTRA_SVC route is live but upstream returned HTTP $EXTRA_HTTP"
    fi
    rm -f /tmp/m01_extra.json
  else
    warn "$EXTRA_SVC route never went live - skipping."
  fi
else
  info "Skipping extra httpbin service."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 01-B Step 7 - Export current Konnect config
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 01-B Step 7 - Export current configuration"
DUMP_FILE="$SCRIPT_DIR/module-01-config-dump.yaml"
if [[ "$CFG_METHOD" == "deck" ]]; then
  if deck gateway dump \
       --konnect-token "$KONNECT_TOKEN" \
       --konnect-control-plane-name "$KONNECT_CP_NAME" \
       --output-file "$DUMP_FILE" >/dev/null 2>&1; then
    ok "decK dump saved to $DUMP_FILE"
    head -40 "$DUMP_FILE" || true
  else
    warn "deck gateway dump failed (continuing)."
  fi
else
  info "Listing services + routes via Admin API (equivalent of 'deck gateway dump'):"
  list_services
  list_routes
fi

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Cleanup - remove Module 01 entities before Module 02"
info "Module 01 has no plugins. We delete the Service + Route so Module 02 starts clean."

printf 'Delete %s and %s now? [Y/n]: ' "$SVC_NAME" "$ROUTE_NAME"
read -r CLEAN_CHOICE
case "${CLEAN_CHOICE:-Y}" in
  n|N) warn "Skipping cleanup. You will need to delete '$SVC_NAME' and '$ROUTE_NAME' manually before Module 02." ;;
  *)
    cleanup_everything
    sleep 1
    REMAINING=$(api_curl GET "/services" | jq -r '[.data[]? | select(.name=="'"$SVC_NAME"'" or .name=="httpbin-extra")] | length')
    if [[ "$REMAINING" == "0" ]]; then
      ok "Cleanup complete - '$SVC_NAME' removed."
    else
      warn "Some services still present (count=$REMAINING). Delete manually in Konnect if needed."
    fi
    cleanup_generated_files
    ;;
esac

hdr "Module 01 verification complete ✓"
ok "All steps from Lab 01 (Quick Start) were exercised against your ${DEPLOY_MODE} gateway."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
info "Inputs cached in:  $SCRIPT_DIR/.env"
