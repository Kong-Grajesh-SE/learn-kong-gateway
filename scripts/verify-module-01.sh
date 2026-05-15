#!/usr/bin/env bash
# verify-module-01.sh — Verify Module 01 (Orientation) against a Konnect Serverless Gateway.
#
# Covers:
#   Lab 01-A  Verify gateway reachability (DP setup is N/A for serverless)
#   Lab 01-B  Create Service + Route, send proxied traffic, inspect headers, test status codes
#
# Module 01 has no plugins, so cleanup just removes the Service/Route (and httpbin-service routes)
# so Module 02 starts from an empty CP.

set -u
set -o pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Colors / output helpers
# ──────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; BLU=$'\033[34m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; CYN=""; RST=""
fi

hr()    { printf '%s\n' "────────────────────────────────────────────────────────────────────────────"; }
hdr()   {
  printf '\n%s%s%s' "$BOLD$BLU" "$1" "$RST"
  if [[ -n "${DEPLOY_MODE:-}" ]]; then
    printf '   %s[mode: %s]%s' "$DIM" "$DEPLOY_MODE" "$RST"
  fi
  printf '\n'
  hr
}
step()  { printf '\n%s▶ %s%s\n' "$BOLD$CYN" "$1" "$RST"; }
ok()    { printf '%s✓ %s%s\n' "$GRN" "$1" "$RST"; }
warn()  { printf '%s! %s%s\n' "$YLW" "$1" "$RST"; }
err()   { printf '%s✗ %s%s\n' "$RED" "$1" "$RST" >&2; }
info()  { printf '%s%s%s\n' "$DIM" "$1" "$RST"; }

pause_verify() {
  printf '\n%s%s%s\n' "$YLW$BOLD" "VERIFY IN KONNECT:" "$RST"
  printf '%s%s%s\n' "$YLW" "$1" "$RST"
  printf '%sPress Enter to continue, or Ctrl-C to abort.%s ' "$DIM" "$RST"
  read -r _ || true
}

prompt_var() {
  # prompt_var <var_name> <prompt_text> [default]
  local __var=$1 __prompt=$2 __default=${3-}
  local __current=${!__var-}
  if [[ -n "$__current" ]]; then return 0; fi
  local __input
  if [[ -n "$__default" ]]; then
    printf '%s [%s]: ' "$__prompt" "$__default"
  else
    printf '%s: ' "$__prompt"
  fi
  read -r __input || true
  if [[ -z "$__input" && -n "$__default" ]]; then __input=$__default; fi
  printf -v "$__var" '%s' "$__input"
  export "$__var"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command not found: $1"; exit 1; }
}

# ──────────────────────────────────────────────────────────────────────────────
# Load .env if present (prefer existing env vars, .env fills in missing ones)
# ──────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  info "Loading defaults from $ENV_FILE (existing env vars take precedence)"
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

hdr "Kong Bootcamp — Module 01 Verification (Konnect)"

# ──────────────────────────────────────────────────────────────────────────────
# Collect inputs
# ──────────────────────────────────────────────────────────────────────────────
require_cmd curl
require_cmd jq

# Deployment mode — chosen ONCE for the entire run.
#   serverless = Konnect-hosted DP (proxy URL *.kongcloud.dev)
#   hybrid     = Konnect CP + local Docker DP (proxy URL http://localhost:8000)
# Precedence: CLI arg ($1)  >  DEPLOY_MODE env var / .env  >  interactive prompt
CLI_MODE=${1-}
CLI_MODE_LC=$(printf '%s' "$CLI_MODE" | tr '[:upper:]' '[:lower:]')
case "$CLI_MODE_LC" in
  -h|--help)
    cat <<USAGE
Usage: $(basename "$0") [serverless|hybrid]

  serverless   Run all checks against a Konnect serverless gateway
  hybrid       Run all checks against a local Docker Data Plane + Konnect CP

If omitted, the script uses \$DEPLOY_MODE (from env or scripts/.env), or asks interactively.
The chosen mode applies to the ENTIRE script run — proxy URL, DP checks, portal-verify prompts.
USAGE
    exit 0 ;;
  serverless|hybrid) DEPLOY_MODE=$CLI_MODE_LC ;;
  "")  : ;;  # fall through to env / prompt
  *) err "Unknown mode '$CLI_MODE'. Use: serverless | hybrid (or --help)"; exit 1 ;;
esac

if [[ -z "${DEPLOY_MODE:-}" ]]; then
  echo
  echo "${BOLD}Deployment mode${RST} ${DIM}(applies to the entire script run)${RST}"
  echo "  1) serverless  — Konnect runs the Data Plane (proxy URL is *.kongcloud.dev)"
  echo "  2) hybrid      — Konnect CP + local Docker Data Plane (proxy URL is http://localhost:8000)"
  printf 'Choose [1/2]: '
  read -r MODE_CHOICE
  case "${MODE_CHOICE:-1}" in
    1) DEPLOY_MODE="serverless" ;;
    2) DEPLOY_MODE="hybrid"     ;;
    *) err "Invalid choice"; exit 1 ;;
  esac
fi
case "$DEPLOY_MODE" in
  serverless|hybrid) ok "Deployment mode (locked for this run): ${BOLD}${DEPLOY_MODE}${RST}" ;;
  *) err "DEPLOY_MODE must be 'serverless' or 'hybrid' (got '$DEPLOY_MODE')"; exit 1 ;;
esac

prompt_var KONNECT_TOKEN "Konnect Personal Access Token (kpat_…)"
[[ -z "${KONNECT_TOKEN:-}" ]] && { err "KONNECT_TOKEN is required."; exit 1; }

prompt_var KONNECT_REGION "Konnect region (us | eu | au)" "us"
prompt_var KONNECT_CP_ID  "Konnect Control Plane ID (UUID from the CP URL)"
[[ -z "${KONNECT_CP_ID:-}" ]] && { err "KONNECT_CP_ID is required."; exit 1; }

prompt_var KONNECT_CP_NAME "Konnect Control Plane NAME (used by decK)" "bootcamp-cp"

if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  prompt_var KONNECT_PROXY_URL "Local Data Plane PROXY URL" "http://localhost:8000"
  prompt_var KONG_DP_CONTAINER "Docker container name for the local DP" "kong-dp"
else
  prompt_var KONNECT_PROXY_URL "Serverless gateway PROXY URL (e.g. https://xxxx.kongcloud.dev)"
fi
[[ -z "${KONNECT_PROXY_URL:-}" ]] && { err "KONNECT_PROXY_URL is required."; exit 1; }
KONNECT_PROXY_URL=${KONNECT_PROXY_URL%/}  # strip trailing slash

KONNECT_API_BASE="https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities"

# Persist for re-runs
cat > "$ENV_FILE" <<EOF
# Auto-saved by verify-module-01.sh — safe to edit/delete
DEPLOY_MODE=$DEPLOY_MODE
KONNECT_TOKEN=$KONNECT_TOKEN
KONNECT_REGION=$KONNECT_REGION
KONNECT_CP_ID=$KONNECT_CP_ID
KONNECT_CP_NAME=$KONNECT_CP_NAME
KONNECT_PROXY_URL=$KONNECT_PROXY_URL
KONG_DP_CONTAINER=${KONG_DP_CONTAINER:-}
EOF
chmod 600 "$ENV_FILE"
ok "Saved values to $ENV_FILE (chmod 600)"

# ──────────────────────────────────────────────────────────────────────────────
# Pick configuration method
# ──────────────────────────────────────────────────────────────────────────────
hdr "Configuration method"
echo "  1) decK (sync YAML to Konnect)"
echo "  2) Konnect Admin API (curl)"
printf 'Choose [1/2]: '
read -r CFG_CHOICE
case "${CFG_CHOICE:-1}" in
  1) CFG_METHOD="deck";  require_cmd deck ;;
  2) CFG_METHOD="api"  ;;
  *) err "Invalid choice"; exit 1 ;;
esac
ok "Using ${BOLD}${CFG_METHOD}${RST}${GRN} for configuration${RST}"

# ──────────────────────────────────────────────────────────────────────────────
# Helpers — both backends expose the same verbs
# ──────────────────────────────────────────────────────────────────────────────
api_curl() {
  # Read-only GET helper. Returns body on stdout; HTTP status NOT checked.
  local method=$1 path=$2 body=${3-}
  local args=( -sS -X "$method"
               -H "Authorization: Bearer $KONNECT_TOKEN"
               -H "Accept: application/json" )
  if [[ -n "$body" ]]; then
    args+=( -H "Content-Type: application/json" --data "$body" )
  fi
  curl "${args[@]}" "${KONNECT_API_BASE}${path}"
}

api_write() {
  # Write helper that captures HTTP status and FAILS LOUDLY on non-2xx.
  # api_write <METHOD> <PATH> [JSON_BODY]   → prints response body on stdout, returns 0/1
  local method=$1 path=$2 body=${3-}
  local tmp; tmp=$(mktemp)
  local args=( -sS -o "$tmp" -w '%{http_code}'
               -X "$method"
               -H "Authorization: Bearer $KONNECT_TOKEN"
               -H "Accept: application/json" )
  if [[ -n "$body" ]]; then
    args+=( -H "Content-Type: application/json" --data "$body" )
  fi
  local code
  code=$(curl "${args[@]}" "${KONNECT_API_BASE}${path}" || echo "000")
  if [[ "$code" == 2* ]]; then
    cat "$tmp"; rm -f "$tmp"; return 0
  fi
  err "Konnect Admin API $method $path → HTTP $code"
  if [[ -n "$body" ]]; then
    err "Request body: $body"
  fi
  err "Response body:"
  sed 's/^/  /' "$tmp" >&2 || true
  rm -f "$tmp"
  return 1
}

deck_sync_stdin() {
  # Pipe a YAML doc on stdin
  deck gateway sync - \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-control-plane-name "$KONNECT_CP_NAME"
}

deck_reset() {
  printf 'y\n' | deck gateway reset \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-control-plane-name "$KONNECT_CP_NAME" >/dev/null 2>&1 || true
}

create_service_and_route() {
  local svc_name=$1 svc_url=$2 route_name=$3 route_path=$4
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin
_format_version: '3.0'
services:
  - name: $svc_name
    url: $svc_url
    tags: [bootcamp, module-01]
    routes:
      - name: $route_name
        paths:
          - $route_path
        strip_path: true
        tags: [bootcamp, module-01]
YAML
  else
    # Upsert Service: PUT /services/{name} is upsert-by-name on Kong 3.x / Konnect.
    local svc_body route_body svc_id
    svc_body=$(jq -n --arg url "$svc_url" --arg name "$svc_name" \
                 '{name:$name, url:$url, tags:["bootcamp","module-01"]}')
    api_write PUT "/services/$svc_name" "$svc_body" >/dev/null \
      || { err "Failed to create/update service '$svc_name'"; return 1; }

    # Verify and get the service ID so the route reference is unambiguous.
    svc_id=$(api_curl GET "/services/$svc_name" | jq -r '.id // empty')
    if [[ -z "$svc_id" ]]; then
      err "Service '$svc_name' missing after PUT — Konnect did not persist it."; return 1
    fi
    ok "Service '$svc_name' present (id=$svc_id)"

    route_body=$(jq -n --arg name "$route_name" --arg path "$route_path" --arg svc_id "$svc_id" \
                   '{name:$name, paths:[$path], strip_path:true, service:{id:$svc_id}, tags:["bootcamp","module-01"]}')
    api_write PUT "/routes/$route_name" "$route_body" >/dev/null \
      || { err "Failed to create/update route '$route_name'"; return 1; }

    local route_id
    route_id=$(api_curl GET "/routes/$route_name" | jq -r '.id // empty')
    if [[ -z "$route_id" ]]; then
      err "Route '$route_name' missing after PUT — Konnect did not persist it."; return 1
    fi
    ok "Route '$route_name' present (id=$route_id)"
  fi
}

delete_service_and_route() {
  local svc_name=$1 route_name=$2
  if [[ "$CFG_METHOD" == "deck" ]]; then
    cat <<YAML | deck_sync_stdin
_format_version: '3.0'
services: []
routes: []
YAML
  else
    api_curl DELETE "/routes/$route_name"   >/dev/null || true
    api_curl DELETE "/services/$svc_name"   >/dev/null || true
  fi
}

wait_for_route() {
  # wait_for_route <url> [timeout_seconds]
  # Polls until the URL stops returning Kong's "no Route matched" 404 (i.e. route propagated).
  local url=$1 timeout=${2:-30} interval=3 elapsed=0 http body
  info "Waiting up to ${timeout}s for route to propagate to the DP (serverless polls every ~10s)…"
  while (( elapsed < timeout )); do
    body=$(curl -sS -o /tmp/m01_wait.txt -w '%{http_code}' "$url" || echo "000")
    http=$body
    if [[ "$http" != "404" ]] || ! grep -q "no Route matched" /tmp/m01_wait.txt 2>/dev/null; then
      ok "Route is live after ${elapsed}s (HTTP $http)"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
    printf '.'
  done
  echo
  err "Route did not propagate within ${timeout}s. Last response (HTTP $http):"
  cat /tmp/m01_wait.txt; echo
  return 1
}

list_services() {
  # Read-only, identical for both methods — uses Konnect Admin API.
  api_curl GET "/services" \
    | jq -r '.data[]? | "  - " + .name + " → " + .protocol + "://" + .host + ":" + (.port|tostring)'
}

list_routes() {
  api_curl GET "/routes" \
    | jq -r '.data[]? | "  - " + .name + "  paths=" + (.paths|tostring) + "  strip_path=" + (.strip_path|tostring)'
}

# ──────────────────────────────────────────────────────────────────────────────
# Lab 01-A — Verify gateway reachability
# ──────────────────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  hdr "Lab 01-A — Verify hybrid Data Plane (local Docker)"
else
  hdr "Lab 01-A — Verify serverless gateway reachability"
  info "(DP container setup from the lab does not apply — Konnect runs the DP for you.)"
fi

step "1. Ping Konnect Admin API"
PING_HTTP=$(curl -sS -o /tmp/m01_ping.json -w '%{http_code}' \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}")
if [[ "$PING_HTTP" == "200" ]]; then
  CP_NAME_FROM_API=$(jq -r '.name // "?"' /tmp/m01_ping.json)
  ok "Konnect API reachable. CP: $CP_NAME_FROM_API ($KONNECT_CP_ID)"
else
  err "Konnect API returned HTTP $PING_HTTP. Body:"
  cat /tmp/m01_ping.json; exit 1
fi

if [[ "$CFG_METHOD" == "deck" ]]; then
  step "2. decK auth check"
  if deck gateway ping --konnect-token "$KONNECT_TOKEN" \
       --konnect-control-plane-name "$KONNECT_CP_NAME"; then
    ok "decK can reach the CP"
  else
    err "decK ping failed — check CP NAME / token"; exit 1
  fi
fi

# Hybrid-only: check the local Docker DP is up and connected to Konnect
if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  step "Hybrid: verify Docker DP container '$KONG_DP_CONTAINER'"
  require_cmd docker
  if ! docker ps --format '{{.Names}}' | grep -qx "$KONG_DP_CONTAINER"; then
    err "Container '$KONG_DP_CONTAINER' is not running. Start it with 'docker compose up -d' from your kong-bootcamp dir (see labs/01-install-verify.md)."
    exit 1
  fi
  ok "Container '$KONG_DP_CONTAINER' is running"

  step "Hybrid: 'kong health' inside the DP"
  if docker exec "$KONG_DP_CONTAINER" kong health >/dev/null 2>&1; then
    ok "kong health → green"
  else
    err "kong health failed inside $KONG_DP_CONTAINER. Check 'docker logs $KONG_DP_CONTAINER'."; exit 1
  fi

  step "Hybrid: confirm DP→CP cluster connection in logs"
  if docker logs --tail 500 "$KONG_DP_CONTAINER" 2>&1 | grep -q "\[clustering\].*[Dd]ata plane connected"; then
    ok "DP is connected to the Konnect control plane"
  else
    warn "Could not find 'Data plane connected' in recent logs. The DP may still be starting — check 'docker logs -f $KONG_DP_CONTAINER'."
  fi

  step "Hybrid: confirm CP sees this DP as a registered node"
  NODES_JSON=$(curl -sS -H "Authorization: Bearer $KONNECT_TOKEN" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/dataplanes" || true)
  CONNECTED=$(echo "$NODES_JSON" | jq -r '[.data[]? | select(.connected==true)] | length' 2>/dev/null || echo "0")
  if [[ "$CONNECTED" -ge 1 ]]; then
    ok "$CONNECTED data plane node(s) connected to CP per Konnect"
    echo "$NODES_JSON" | jq -r '.data[]? | "  • " + (.hostname // "?") + "  version=" + (.version // "?") + "  connected=" + (.connected|tostring)'
  else
    warn "Konnect reports 0 connected nodes (DP may still be handshaking). Re-run if needed."
  fi
fi

step "Proxy reachability — expect 404 'no Route matched' (no routes yet)"
PROXY_BODY=$(curl -sS -o /tmp/m01_proxy.txt -w '%{http_code}' "$KONNECT_PROXY_URL/" || true)
if grep -q "no Route matched" /tmp/m01_proxy.txt 2>/dev/null; then
  ok "Proxy reachable (HTTP $PROXY_BODY, default Kong response)"
else
  warn "Proxy responded with HTTP $PROXY_BODY:"
  cat /tmp/m01_proxy.txt; echo
  warn "If you already have routes on this CP, run this script after cleanup, or use a fresh CP."
fi

if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  pause_verify "Konnect → Gateway Manager → '$KONNECT_CP_NAME' → Data Plane Nodes. Confirm your local DP appears with a green 'Connected' indicator."
else
  pause_verify "Konnect → Gateway Manager → '$KONNECT_CP_NAME' → Overview. Confirm the CP is healthy and your serverless DP is running."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 01-B — Service, Route, traffic
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 01-B — First API call through Kong"

SVC_NAME="httpbin-service"
ROUTE_NAME="httpbin-route"
ROUTE_PATH="/demo"
UPSTREAM_URL="https://httpbin.konghq.com"

step "0. Sanity-check upstream directly (before Kong is in the path)"
# From lab 01-B: `curl -s https://httpbin.konghq.com/get | jq '{url, origin}'`
UP_RESP=$(curl -sS -w '\n__HTTP__%{http_code}' "$UPSTREAM_URL/get")
UP_HTTP=$(printf '%s' "$UP_RESP" | sed -n 's/.*__HTTP__//p')
UP_BODY=$(printf '%s' "$UP_RESP" | sed 's/__HTTP__.*//')
if [[ "$UP_HTTP" == "200" ]]; then
  ok "Upstream $UPSTREAM_URL is reachable (HTTP 200)"
  echo "$UP_BODY" | jq '{url, origin}'
else
  err "Upstream returned HTTP $UP_HTTP — cannot verify Kong end-to-end. Aborting."
  exit 1
fi

step "1. Create Service + Route via $CFG_METHOD"
create_service_and_route "$SVC_NAME" "$UPSTREAM_URL" "$ROUTE_NAME" "$ROUTE_PATH"
ok "Configured: $SVC_NAME → $UPSTREAM_URL, route $ROUTE_NAME on $ROUTE_PATH"

info "Services on this CP (per Konnect Admin API):"
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
  err "  • Wrong PROXY URL ($KONNECT_PROXY_URL) — does this CP own that proxy?"
  err "  • Wrong CP — decK/API hit a different CP than the proxy URL"
  err "  • Serverless DP suspended (free tier) — re-deploy from Konnect"
  exit 1
fi

step "2. GET ${KONNECT_PROXY_URL}${ROUTE_PATH}/get — basic proxied request"
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

# Required for any deployment mode: a request-id + a forwarded host record.
REQUIRED=( "X-Kong-Request-Id" "X-Forwarded-Host" )
# Optional, mode-dependent — Konnect's edge proxy strips X-Forwarded-For/Port/Proto
# before reaching the upstream, while a self-hosted DP forwards them as-is.
if [[ "$DEPLOY_MODE" == "serverless" ]]; then
  EXPECTED_EXTRA=( "X-Forwarded-Path" "X-Forwarded-Prefix" )
  EXPECTED_ABSENT=( "X-Forwarded-For" "X-Forwarded-Port" "X-Forwarded-Proto" )
else
  EXPECTED_EXTRA=( "X-Forwarded-For" "X-Forwarded-Port" "X-Forwarded-Proto" )
  EXPECTED_ABSENT=()
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
if [[ "$DEPLOY_MODE" == "serverless" ]]; then
  info "Note: Konnect's edge proxy strips X-Forwarded-For/Port/Proto before the upstream — expected in serverless."
fi

step "4. POST ${ROUTE_PATH}/post — verify body forwarding"
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

step "6. strip_path verification — /demo is removed before upstream sees it"
# Note: httpbin.konghq.com reconstructs .url from X-Forwarded-Host, so the host
# portion will be the proxy host (serverless edge or localhost), NOT httpbin's.
# The reliable strip_path indicator is the PATH component — it must be /get, not /demo/get.
URL_SEEN_BY_UPSTREAM=$(curl -sS "${KONNECT_PROXY_URL}${ROUTE_PATH}/get" | jq -r '.url')
PATH_SEEN=$(printf '%s' "$URL_SEEN_BY_UPSTREAM" | sed -E 's|^[a-zA-Z]+://[^/]+||; s|\?.*$||')
if [[ "$PATH_SEEN" == "/get" ]]; then
  ok "strip_path works — upstream saw path '$PATH_SEEN' (full url: $URL_SEEN_BY_UPSTREAM)"
elif [[ "$PATH_SEEN" == /demo/* ]]; then
  err "strip_path NOT working — upstream still sees '/demo' prefix: $PATH_SEEN"
  err "Full url: $URL_SEEN_BY_UPSTREAM"; exit 1
else
  warn "Unexpected upstream path: '$PATH_SEEN' (full url: $URL_SEEN_BY_UPSTREAM)"
fi

pause_verify "Konnect → Analytics (or your CP Overview): confirm you see request activity for '$SVC_NAME'. The traffic counter may take ~1 minute to update."

# ──────────────────────────────────────────────────────────────────────────────
# Lab 01-B Step 6 — Optional kong-air service (hybrid only; serverless cannot
# reach host.docker.internal:3001).
# ──────────────────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  printf '\nOptional: also configure the "kong-air" service from lab Step 6? It expects a backend on http://host.docker.internal:3001 [y/N]: '
  read -r KA_CHOICE
  if [[ "${KA_CHOICE:-N}" =~ ^[Yy]$ ]]; then
    step "kong-air: create service + route"
    create_service_and_route "kong-air" "http://host.docker.internal:3001" "kong-air-route" "/kong-air"
    if wait_for_route "${KONNECT_PROXY_URL}/kong-air/api/flights" 30; then
      KA_HTTP=$(curl -sS -o /tmp/m01_ka.json -w '%{http_code}' "${KONNECT_PROXY_URL}/kong-air/api/flights")
      if [[ "$KA_HTTP" == "200" ]]; then
        ok "kong-air upstream reachable through Kong (HTTP 200)"
        jq '.[0] // empty' /tmp/m01_ka.json 2>/dev/null || head -c 300 /tmp/m01_ka.json
      else
        warn "kong-air route is live but upstream returned HTTP $KA_HTTP (is kong-air running locally on :3001?)"
      fi
    else
      warn "kong-air route never went live — skipping."
    fi
  else
    info "Skipping kong-air."
  fi
else
  info "Skipping Lab 01-B Step 6 (kong-air) — serverless DP cannot reach a backend on your laptop."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 01-B Step 7 — Export current Konnect config (deck dump / API listing)
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 01-B Step 7 — Export current configuration"
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
hdr "Cleanup — remove Module 01 entities before Module 02"
info "Module 01 has no plugins to disable. We delete the Service + Route so Module 02 starts clean."

printf 'Delete %s and %s now? [Y/n]: ' "$SVC_NAME" "$ROUTE_NAME"
read -r CLEAN_CHOICE
case "${CLEAN_CHOICE:-Y}" in
  n|N)
    warn "Skipping cleanup. You will need to delete '$SVC_NAME' and '$ROUTE_NAME' manually before Module 02." ;;
  *)
    # decK mode wipes everything via `services: []` / `routes: []`; API mode deletes by name.
    if [[ "$CFG_METHOD" == "deck" ]]; then
      delete_service_and_route "$SVC_NAME" "$ROUTE_NAME"
    else
      api_curl DELETE "/routes/$ROUTE_NAME"      >/dev/null || true
      api_curl DELETE "/routes/kong-air-route"   >/dev/null || true
      api_curl DELETE "/services/$SVC_NAME"      >/dev/null || true
      api_curl DELETE "/services/kong-air"       >/dev/null || true
    fi
    sleep 1
    REMAINING=$(api_curl GET "/services" | jq -r '[.data[]? | select(.name=="'"$SVC_NAME"'" or .name=="kong-air")] | length')
    if [[ "$REMAINING" == "0" ]]; then
      ok "Cleanup complete — Module 01 services removed."
    else
      warn "Some services still present (count=$REMAINING). Delete manually in Konnect if needed."
    fi
    ;;
esac

pause_verify "Konnect → Gateway Services: confirm '$SVC_NAME' is gone (or accept whatever you chose to keep). You're ready for Module 02."

hdr "Module 01 verification complete ✓"
ok "All steps from labs/01-install-verify.md and labs/01-first-api-call.md were exercised against your serverless gateway."
echo
info "Re-run anytime: $0"
info "Inputs cached in:  $ENV_FILE"
