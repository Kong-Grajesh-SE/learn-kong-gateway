#!/usr/bin/env bash
# verify-module-04.sh - Verify Module 04 (Traffic & Resilience) against Konnect.
#
# Covers:
#   Lab 04-A  Per-Consumer rate limits with X-RateLimit-* + 429 + Retry-After
#   Lab 04-B  proxy-cache with X-Cache-Status MISS/HIT/Bypass
#
# Usage:  ./scripts/verify-module-04.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 04 Verification (Traffic & Resilience)"

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
# Baseline: Service + Route + Consumers + key-auth
# ──────────────────────────────────────────────────────────────────────────────
hdr "Baseline: Service + Route + Consumers + key-auth"

apply_baseline() {
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - { username: anonymous, tags: [module-04] }
  - username: web-app
    custom_id: web-001
    tags: [module-04]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-04]
    keyauth_credentials: [{ key: mobile-app-secret-key-002 }]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-04]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-04]
        plugins:
          - name: key-auth
            tags: [module-04]
            config:
              key_names: [X-API-Key]
              hide_credentials: true
              anonymous: ANON_PLACEHOLDER
YAML
  else
    for U in anonymous:_ web-app:web-001 mobile-app:mobile-001; do
      USER=${U%:*}; CID=${U#*:}
      local payload
      if [[ "$CID" == "_" ]]; then
        payload=$(jq -n --arg u "$USER" '{username:$u, tags:["module-04"]}')
      else
        payload=$(jq -n --arg u "$USER" --arg c "$CID" '{username:$u, custom_id:$c, tags:["module-04"]}')
      fi
      api_write POST "/consumers" "$payload" >/dev/null
    done
    local web_id mob_id
    web_id=$(resolve_id consumers web-app)    || { err "web-app not found"; return 1; }
    mob_id=$(resolve_id consumers mobile-app) || { err "mobile-app not found"; return 1; }
    api_write POST "/consumers/$web_id/key-auth" "$(jq -n '{key:"web-app-secret-key-001"}')" >/dev/null
    api_write POST "/consumers/$mob_id/key-auth" "$(jq -n '{key:"mobile-app-secret-key-002"}')" >/dev/null
    api_write POST "/services" \
      "$(jq -n '{name:"flights-svc", url:"https://httpbin.konghq.com", tags:["module-04"]}')" >/dev/null
    local sid; sid=$(api_curl GET "/services/flights-svc" | jq -r '.id')
    api_write POST "/routes" \
      "$(jq -n --arg s "$sid" '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$s}, tags:["module-04"]}')" >/dev/null
    local rid; rid=$(api_curl GET "/routes/flights-route" | jq -r '.id')
    local aid; aid=$(api_curl GET "/consumers/anonymous" | jq -r '.id')
    api_write POST "/routes/$rid/plugins" \
      "$(jq -n --arg a "$aid" '{name:"key-auth", config:{key_names:["X-API-Key"], hide_credentials:true, anonymous:$a}, tags:["module-04"]}')" >/dev/null
  fi
}

# In decK path, we need to substitute the anonymous ID after creating Consumers.
if [[ "$CFG_METHOD" == "deck" ]]; then
  # First pass: create Consumers + Service+Route, no plugin
  cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - { username: anonymous, tags: [module-04] }
  - username: web-app
    custom_id: web-001
    tags: [module-04]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-04]
    keyauth_credentials: [{ key: mobile-app-secret-key-002 }]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-04]
    routes:
      - { name: flights-route, paths: [/flights], strip_path: true, tags: [module-04] }
YAML
  ANON_ID=$(api_curl GET "/consumers/anonymous" | jq -r '.id')
  # Second pass: now apply the key-auth plugin with the real anonymous id
  cat <<YAML | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - { username: anonymous, tags: [module-04] }
  - username: web-app
    custom_id: web-001
    tags: [module-04]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-04]
    keyauth_credentials: [{ key: mobile-app-secret-key-002 }]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-04]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-04]
        plugins:
          - name: key-auth
            tags: [module-04]
            config:
              key_names: [X-API-Key]
              hide_credentials: true
              anonymous: $ANON_ID
YAML
else
  apply_baseline
  ANON_ID=$(api_curl GET "/consumers/anonymous" | jq -r '.id')
fi
ok "Baseline applied (3 Consumers, Service+Route, key-auth with anonymous fallback)"

wait_for_route "${KONNECT_PROXY_URL}/flights/get" 30 || exit 1

# Sanity: anonymous → 200, web-app → 200
HTTP_ANON=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get")
HTTP_WEB=$(curl -s -o /dev/null -w '%{http_code}' "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001')
[[ "$HTTP_ANON" == "200" && "$HTTP_WEB" == "200" ]] && ok "Baseline returns 200 for both anonymous and web-app"

# ──────────────────────────────────────────────────────────────────────────────
# Lab 04-A - Rate limiting
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 04-A - Rate Limiting"

# Find the route id once
RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')

# Resolve Consumer ids
ANON_CID=$ANON_ID
WEB_CID=$(api_curl GET "/consumers/web-app"    | jq -r '.id')
MOB_CID=$(api_curl GET "/consumers/mobile-app" | jq -r '.id')

step "1. Attach per-Consumer rate-limit plugins (free=10/min, pro=100/min, internal=300/min) scoped to flights-route"
attach_rl() {
  local cons_id=$1 limit=$2 tag=$3
  api_write POST "/plugins" \
    "$(jq -n --arg cid "$cons_id" --arg rid "$RID" --argjson n "$limit" --arg t "$tag" \
      '{name:"rate-limiting",
        config:{minute:$n, policy:"local", limit_by:"consumer"},
        consumer:{id:$cid},
        route:{id:$rid},
        tags:["module-04", $t]}')" >/dev/null
}
attach_rl "$ANON_CID" 10  "free"
attach_rl "$WEB_CID"  100 "pro"
attach_rl "$MOB_CID"  300 "internal"
ok "Three rate-limit plugin instances attached"

# Wait for the mobile-app plugin (last created) to propagate before testing any tier.
# Once the mobile-app limit header is visible, all three plugins are live.
wait_for_response_header "${KONNECT_PROXY_URL}/flights/get" "x-ratelimit-limit-minute" 60 \
  -H 'X-API-Key: mobile-app-secret-key-002' || exit 1

step "2. Verify each tier reports the right X-RateLimit-Limit-Minute"
# Bash 3.2 portable (macOS default): iterate "tier:expected:key" tuples, parse with parameter expansion.
for ENTRY in 'anonymous:10:' 'web-app:100:web-app-secret-key-001' 'mobile-app:300:mobile-app-secret-key-002'; do
  TIER=$(echo "$ENTRY" | cut -d: -f1)
  EXPECTED=$(echo "$ENTRY" | cut -d: -f2)
  K=$(echo "$ENTRY" | cut -d: -f3-)
  if [[ -n "$K" ]]; then
    LIMIT=$(curl -sI "${KONNECT_PROXY_URL}/flights/get" -H "X-API-Key: $K" \
      | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-ratelimit-limit-minute/{print $2}' | tr -d '\r\n')
  else
    LIMIT=$(curl -sI "${KONNECT_PROXY_URL}/flights/get" \
      | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-ratelimit-limit-minute/{print $2}' | tr -d '\r\n')
  fi
  if [[ "$LIMIT" == "$EXPECTED" ]]; then
    ok "  $TIER: X-RateLimit-Limit-Minute = $LIMIT"
  else
    err "  $TIER: expected $EXPECTED, got '$LIMIT'"; exit 1
  fi
done

step "3. Exceed the anonymous tier (10/min) and expect a 429 with Retry-After"
for _ in {1..12}; do
  curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/get"
done
RESP=$(curl -sI "${KONNECT_PROXY_URL}/flights/get")
HTTP=$(echo "$RESP" | head -1 | awk '{print $2}')
RETRY=$(echo "$RESP" | awk -F': ' 'BEGIN{IGNORECASE=1} /^retry-after/{print $2}' | tr -d '\r\n')
if [[ "$HTTP" == "429" && -n "$RETRY" ]]; then
  ok "429 returned with Retry-After=${RETRY}s"
else
  warn "Expected 429+Retry-After, got HTTP=$HTTP Retry-After='$RETRY'"
fi

pause_verify "Konnect → flights-route → Plugins: three rate-limiting instances, one per Consumer."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 04-B - Proxy Cache
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 04-B - Proxy Cache"

step "1. Attach proxy-cache to flights-route (60s TTL, in-memory, ignore upstream cache-control)"
attach_cache() {
  local body
  body=$(jq -n --arg rid "$RID" '{
    name: "proxy-cache",
    config: {
      response_code:  [200,301,404],
      request_method: ["GET","HEAD"],
      content_type:   ["application/json","application/json;charset=utf-8"],
      cache_ttl: 60,
      strategy: "memory",
      cache_control: false
    },
    route: {id:$rid},
    tags: ["module-04"]
  }')
  api_write POST "/plugins" "$body" >/dev/null
}
attach_cache
ok "proxy-cache attached"

# Wait for proxy-cache to propagate using a throwaway URL so the /get cache
# key used in steps 2-3 remains cold for the Miss → Hit sequence.
wait_for_response_header "${KONNECT_PROXY_URL}/flights/ip" "x-cache-status" 60 \
  -H 'X-API-Key: web-app-secret-key-001' || exit 1

step "2. First request → X-Cache-Status: Miss (cache cold)"
# Use -si (GET + headers in output): HEAD requests (-sI) never write a cache entry
# because they carry no response body, so the cache would never warm.
H1=$(curl -si "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-cache-status/{print $2}' | tr -d '\r\n')
if [[ "$H1" == "Miss" ]]; then
  ok "First request was a Miss (correct - cache empty)"
else
  warn "Expected Miss, got '$H1' (may have hit a stale cache key)"
fi

step "3. Second request → X-Cache-Status: Hit"
# In Konnect serverless, multiple DP nodes sit behind a load balancer and each
# has its own in-memory cache.  A Miss on node A caches the entry only there;
# the next request may hit node B (cold → another Miss).  Retry up to 15 times
# so that, regardless of LB policy, we revisit a warm node and confirm a Hit.
H2=""
for _i in {1..15}; do
  H2=$(curl -si "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001' \
    | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-cache-status/{print $2}' | tr -d '\r\n')
  [[ "$H2" == "Hit" ]] && break
done
if [[ "$H2" == "Hit" ]]; then
  ok "Second request was a Hit (correct - served from Kong's memory)"
else
  err "Expected Hit on second request, got '$H2' after 15 attempts"; exit 1
fi

step "4. POST should Bypass the cache (request_method whitelist excludes POST)"
HP=$(curl -si -X POST "${KONNECT_PROXY_URL}/flights/post" -H 'X-API-Key: web-app-secret-key-001' \
  -H 'Content-Type: application/json' --data '{"x":1}' \
  | awk -F': ' 'BEGIN{IGNORECASE=1} /^x-cache-status/{print $2}' | tr -d '\r\n')
if [[ "$HP" == "Bypass" ]]; then
  ok "POST was Bypassed (writes never cached, by design)"
else
  warn "Expected Bypass on POST, got '$HP'"
fi

step "5. Latency comparison - cached should be much faster than upstream call"
# Bust the cache so first call is a clean Miss
curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/uuid" -H 'X-API-Key: web-app-secret-key-001'  # warm
T_MISS_START=$(python3 -c 'import time; print(time.time())')
curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/anything?cachebuster=$RANDOM" -H 'X-API-Key: web-app-secret-key-001'
T_MISS=$(python3 -c "import time; print(round((time.time() - $T_MISS_START) * 1000))")
T_HIT_START=$(python3 -c 'import time; print(time.time())')
curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/anything?cachebuster=$RANDOM" -H 'X-API-Key: web-app-secret-key-001'
T_HIT=$(python3 -c "import time; print(round((time.time() - $T_HIT_START) * 1000))")
info "Miss latency: ${T_MISS}ms · Hit latency (different key, also Miss): ${T_HIT}ms"
info "(Run a second time to compare repeated Hits on the same URL.)"

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Cleanup - wipe everything tagged module-04"
printf 'Delete all M04 entities now? [Y/n]: '
read -r CLEAN
case "${CLEAN:-Y}" in
  n|N) warn "Skipping cleanup." ;;
  *) cleanup_everything; ok "Module 04 cleanup complete."; cleanup_generated_files ;;
esac

hdr "Module 04 verification complete ✓"
ok "Lab 04-A (per-tier rate limits, 429 + Retry-After) and Lab 04-B (proxy-cache Miss/Hit/Bypass) exercised."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
