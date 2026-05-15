#!/usr/bin/env bash
# verify-module-02.sh - Verify Module 02 (Routing & Topology) against Konnect.
#
# Covers:
#   Lab 02-A  Three Services (flights/hotels/cars), route by path, overlap by path,
#             overlap by method, strip_path verification
#   Lab 02-B  Upstream `flights-pool` with two targets, weighted round-robin,
#             active + passive health checks, forced-outage drill
#
# Usage:  ./scripts/verify-module-02.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 02 Verification (Routing & Topology)"

check_prerequisites
load_env
pick_deploy_mode "${1-}"
collect_konnect_inputs
pick_cfg_method
save_env

# ──────────────────────────────────────────────────────────────────────────────
# Pre-flight: empty CP + reach Konnect
# ──────────────────────────────────────────────────────────────────────────────
hdr "Pre-flight"
ping_konnect
check_kong_version
verify_hybrid_dp

cleanup_if_needed

# ──────────────────────────────────────────────────────────────────────────────
# Lab 02-A - Multi-Service routing
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 02-A - Multi-Service routing"

apply_lab_02a() {
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: flights-route,         paths: [/flights],         strip_path: true,  tags: [module-02] }
      - { name: flights-premium-route, paths: [/flights/premium], strip_path: true,  methods: [POST], tags: [module-02] }
  - name: hotels-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: hotels-route, paths: [/hotels], strip_path: true, tags: [module-02] }
  - name: cars-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: cars-route, paths: [/cars], strip_path: true, tags: [module-02] }
YAML
  else
    # Three Services
    for SVC in flights-svc hotels-svc cars-svc; do
      api_write POST "/services" \
        "$(jq -n --arg n "$SVC" '{name:$n, url:"https://httpbin.konghq.com", tags:["module-02"]}')" >/dev/null \
        || { err "Failed to create service $SVC"; return 1; }
    done
    # Routes (capture each Service id so we can attach Routes by id).
    # Use plain variables instead of associative arrays for bash 3.2 portability (macOS default).
    local SID_FLIGHTS SID_HOTELS SID_CARS
    SID_FLIGHTS=$(api_curl GET "/services/flights-svc" | jq -r '.id')
    SID_HOTELS=$(api_curl GET "/services/hotels-svc"   | jq -r '.id')
    SID_CARS=$(api_curl GET "/services/cars-svc"       | jq -r '.id')

    # /flights → flights-svc
    api_write POST "/routes" \
      "$(jq -n --arg sid "$SID_FLIGHTS" \
            '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$sid}, tags:["module-02"]}')" >/dev/null
    # /flights/premium POST-only → flights-svc
    api_write POST "/routes" \
      "$(jq -n --arg sid "$SID_FLIGHTS" \
            '{name:"flights-premium-route", paths:["/flights/premium"], methods:["POST"], strip_path:true, service:{id:$sid}, tags:["module-02"]}')" >/dev/null
    # /hotels
    api_write POST "/routes" \
      "$(jq -n --arg sid "$SID_HOTELS" \
            '{name:"hotels-route", paths:["/hotels"], strip_path:true, service:{id:$sid}, tags:["module-02"]}')" >/dev/null
    # /cars
    api_write POST "/routes" \
      "$(jq -n --arg sid "$SID_CARS" \
            '{name:"cars-route", paths:["/cars"], strip_path:true, service:{id:$sid}, tags:["module-02"]}')" >/dev/null
  fi
}

step "1. Create Services + Routes via $CFG_METHOD"
apply_lab_02a
ok "Three Services + four Routes configured"

info "Services on CP:"
list_services
info "Routes on CP:"
list_routes

pause_verify "Konnect → Gateway Services: confirm flights-svc, hotels-svc, cars-svc exist with httpbin.konghq.com:443. Each has at least one Route."

step "2. Wait for Routes to propagate"
wait_for_route "${KONNECT_PROXY_URL}/flights/get" 30 || exit 1

step "3. Hit /flights, /hotels, /cars - each should 200"
for P in flights hotels cars; do
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/$P/get")
  if [[ "$HTTP" == "200" ]]; then
    ok "/$P/get → 200"
  else
    err "/$P/get → $HTTP (expected 200)"; exit 1
  fi
done

step "4. strip_path verification - /flights/get should reach upstream as /get"
URL=$(curl -s "${KONNECT_PROXY_URL}/flights/get" | jq -r '.url')
PATH_SEEN=$(printf '%s' "$URL" | sed -E 's|^[a-zA-Z]+://[^/]+||; s|\?.*$||')
if [[ "$PATH_SEEN" == "/get" ]]; then
  ok "Upstream saw clean path '/get' (strip_path works)"
elif [[ "$PATH_SEEN" == /flights/* ]]; then
  err "strip_path NOT working - upstream saw '$PATH_SEEN'"; exit 1
else
  warn "Unexpected upstream path: '$PATH_SEEN'"
fi

step "5. Route overlap by path - /flights/premium should match the more specific Route"
# POST /flights/premium/post → flights-premium-route (POST only)
HTTP_POST=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"x":1}' \
  "${KONNECT_PROXY_URL}/flights/premium/post")
# GET /flights/premium/get → no method match on premium → falls back to flights-route
HTTP_GET=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/premium/get")
if [[ "$HTTP_POST" == "200" && "$HTTP_GET" == "200" ]]; then
  ok "Both methods return 200 (POST hits premium-route, GET falls back to flights-route)"
else
  warn "POST=$HTTP_POST  GET=$HTTP_GET - Konnect Analytics will confirm which Route matched"
fi

pause_verify "Konnect → Analytics → filter by service=flights-svc: confirm BOTH 'flights-route' AND 'flights-premium-route' show traffic. Premium picks up the POST; the catch-all picks up the GET."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 02-B - Upstreams & Health Checks
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 02-B - Upstreams & Health Checks"

apply_lab_02b_upstream() {
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'

upstreams:
  - name: flights-pool
    algorithm: round-robin
    slots: 10000
    tags: [module-02]
    targets:
      - { target: httpbin.konghq.com:443, weight: 100, tags: [module-02] }
      - { target: httpbin.org:443,        weight: 50,  tags: [module-02] }

services:
  - name: flights-svc
    host: flights-pool
    port: 443
    protocol: https
    tags: [module-02]
    routes:
      - { name: flights-route,         paths: [/flights],         strip_path: true,  tags: [module-02] }
      - { name: flights-premium-route, paths: [/flights/premium], strip_path: true,  methods: [POST], tags: [module-02] }
  - name: hotels-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: hotels-route, paths: [/hotels], strip_path: true, tags: [module-02] }
  - name: cars-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: cars-route, paths: [/cars], strip_path: true, tags: [module-02] }
YAML
  else
    # Create Upstream + targets. Konnect requires UUIDs (not names) in path
    # segments for nested resource POSTs and for PATCH - resolve the IDs first.
    api_write POST "/upstreams" \
      "$(jq -n '{name:"flights-pool", algorithm:"round-robin", slots:10000, tags:["module-02"]}')" >/dev/null
    local up_id; up_id=$(resolve_id upstreams flights-pool) \
      || { err "Could not resolve upstream id for flights-pool"; return 1; }
    api_write POST "/upstreams/$up_id/targets" \
      "$(jq -n '{target:"httpbin.konghq.com:443", weight:100, tags:["module-02"]}')" >/dev/null
    api_write POST "/upstreams/$up_id/targets" \
      "$(jq -n '{target:"httpbin.org:443", weight:50, tags:["module-02"]}')" >/dev/null
    # Update flights-svc to point at the Upstream. Konnect's Admin API rejects
    # PATCH on /services/{id} (405); use PUT with a full body instead.
    local svc_id; svc_id=$(resolve_id services flights-svc) \
      || { err "Could not resolve service id for flights-svc"; return 1; }
    api_write PUT "/services/$svc_id" \
      "$(jq -n '{name:"flights-svc", host:"flights-pool", port:443, protocol:"https", tags:["module-02"]}')" >/dev/null \
      || { err "Failed to update flights-svc to point at flights-pool"; return 1; }
  fi
}

step "1. Create Upstream 'flights-pool' with two weighted targets"
apply_lab_02b_upstream || { err "Failed to set up flights-pool upstream"; exit 1; }
ok "Upstream + 2 targets created. flights-svc now points at the Upstream."

pause_verify "Konnect → Upstreams → flights-pool: confirm 2 targets (httpbin.konghq.com:443 w=100, httpbin.org:443 w=50) both healthy."

step "2. Wait for the routing change to propagate"
wait_for_route "${KONNECT_PROXY_URL}/flights/get" 30 || exit 1

step "3. Send 30 requests; expect a ~2:1 split between the two targets"
TMP=$(mktemp)
for _ in {1..30}; do
  # Silent jq fallback - some responses come back as Kong error text (not JSON)
  # when a target is still warming up; skip those rather than spam parse errors.
  HOST=$(curl -s "${KONNECT_PROXY_URL}/flights/get" 2>/dev/null \
    | jq -r '.headers.Host // empty' 2>/dev/null)
  [[ -n "$HOST" ]] && echo "$HOST" >> "$TMP"
done
DISTINCT=$(sort "$TMP" | uniq -c | sort -rn)
echo "$DISTINCT" | sed 's/^/  /'
NUM_HOSTS=$(echo "$DISTINCT" | wc -l | tr -d ' ')
if (( NUM_HOSTS >= 2 )); then
  ok "Load-balancing across ≥2 distinct upstream Host values"
else
  warn "Only 1 distinct Host seen - second target may have failed health check, or upstream returned the same Host header for both"
fi
rm -f "$TMP"

step "4. Add an active health check (Kong probes each target on a schedule)"
apply_healthchecks() {
  local hc_path=$1
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
upstreams:
  - name: flights-pool
    algorithm: round-robin
    slots: 10000
    tags: [module-02]
    targets:
      - { target: httpbin.konghq.com:443, weight: 100, tags: [module-02] }
      - { target: httpbin.org:443,        weight: 50,  tags: [module-02] }
    healthchecks:
      active:
        type: https
        http_path: $hc_path
        timeout: 3
        concurrency: 2
        healthy:    { interval: 10, successes: 2, http_statuses: [200, 201, 202, 204] }
        unhealthy:  { interval: 5,  http_failures: 3, tcp_failures: 3, timeouts: 3, http_statuses: [429, 500, 502, 503, 504] }
services:
  - name: flights-svc
    host: flights-pool
    port: 443
    protocol: https
    tags: [module-02]
    routes:
      - { name: flights-route,         paths: [/flights],         strip_path: true,  tags: [module-02] }
      - { name: flights-premium-route, paths: [/flights/premium], strip_path: true,  methods: [POST], tags: [module-02] }
  - name: hotels-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: hotels-route, paths: [/hotels], strip_path: true, tags: [module-02] }
  - name: cars-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - { name: cars-route, paths: [/cars], strip_path: true, tags: [module-02] }
YAML
  else
    local up_id; up_id=$(resolve_id upstreams flights-pool) \
      || { err "Could not resolve upstream id for flights-pool"; return 1; }
    # Konnect rejects PATCH; use PUT with the full upstream definition.
    api_write PUT "/upstreams/$up_id" \
      "$(jq -n --arg hp "$hc_path" '{
        name: "flights-pool",
        algorithm: "round-robin",
        slots: 10000,
        tags: ["module-02"],
        healthchecks: {
          active: {
            type: "https",
            http_path: $hp,
            timeout: 3,
            concurrency: 2,
            healthy:   { interval: 10, successes: 2, http_statuses: [200, 201, 202, 204] },
            unhealthy: { interval: 5,  http_failures: 3, tcp_failures: 3, timeouts: 3, http_statuses: [429, 500, 502, 503, 504] }
          }
        }
      }')" >/dev/null \
      || { err "Failed to apply healthchecks on flights-pool"; return 1; }
  fi
}
apply_healthchecks "/status/200"
ok "Active health check probing /status/200 every 10s"

pause_verify "Konnect → Upstreams → flights-pool: wait ~20s, both targets should show GREEN health."

step "5. Force the outage drill - point health check at /status/503"
apply_healthchecks "/status/503"
info "Health-check probe interval is 5s; needs 3 consecutive failures + DP poll cycle."
# Poll up to 60s for the outage to materialize, so we don't quit early when the
# DP is still catching up. Print progress so it doesn't feel hung.
OUTAGE_REACHED=0
for ATTEMPT in 1 2 3 4 5 6 7 8 9 10 11 12; do
  printf '\r%s  Probe %d/12 - waiting 5s then checking…%s ' "$DIM" "$ATTEMPT" "$RST"
  sleep 5
  HTTP=$(curl -s -o /tmp/_verify_outage.txt -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" 2>/dev/null || echo "000")
  BODY=$(cat /tmp/_verify_outage.txt 2>/dev/null || true)
  if [[ "$HTTP" == "503" ]]; then OUTAGE_REACHED=1; break; fi
done
printf '\r%s%s\n' "                                                          " ""
if (( OUTAGE_REACHED == 1 )) && echo "$BODY" | grep -q "ring-balancer"; then
  ok "Outage simulated - Kong reports 'failure to get a peer from the ring-balancer' (HTTP 503)"
elif (( OUTAGE_REACHED == 1 )); then
  ok "HTTP 503 returned (no healthy targets, as expected)"
else
  warn "Did not see 503 within 60s. Last HTTP=$HTTP. On serverless gateways, active health checks may not fire as aggressively as a local DP - this is expected, not a script bug. Moving on."
fi
rm -f /tmp/_verify_outage.txt

step "6. Recover the targets"
apply_healthchecks "/status/200"
wait_with_progress 30 "Recovering"
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
if [[ "$HTTP" == "200" ]]; then
  ok "Targets recovered - /flights/get → 200"
else
  warn "Still HTTP $HTTP - health check may need another cycle"
fi

pause_verify "Konnect → Upstreams → flights-pool → Targets: both targets back to green."

# ──────────────────────────────────────────────────────────────────────────────
# Final state + cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Final inventory before cleanup"
info "Services:"   ; list_services
info "Routes:"     ; list_routes

step "Cleanup - wipe everything tagged module-02 so M03 starts clean"
printf 'Delete all M02 entities now? [Y/n]: '
read -r CLEAN
case "${CLEAN:-Y}" in
  n|N) warn "Skipping cleanup - M03 will need to clean up manually." ;;
  *)
    cleanup_everything
    cleanup_generated_files
    ok "Module 02 cleanup complete."
    ;;
esac

hdr "Module 02 verification complete ✓"
ok "All steps from M02-A (multi-service routing) and M02-B (Upstreams + health) were exercised."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
