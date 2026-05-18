#!/usr/bin/env bash
# scripts/lib/common.sh - shared helpers for verify-module-NN.sh scripts.
#
# Source this file at the top of every module verification script:
#     SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
#     # shellcheck disable=SC1091
#     source "$SCRIPT_DIR/lib/common.sh"
#
# What this file provides:
#   • Colored output helpers       hdr / step / ok / warn / err / info / hr / pause_verify
#   • Env loading + prompts        load_env / save_env / prompt_var / require_cmd
#   • Konnect endpoints            $KONNECT_API_BASE (computed after collect_konnect_inputs)
#   • Admin API helpers            api_curl (read-only) / api_write (fails loudly on non-2xx)
#   • decK helpers                 deck_sync_stdin / deck_reset / deck_ping
#   • Entity helpers               wait_for_route / list_services / list_routes
#   • Common flows                 collect_konnect_inputs / pick_deploy_mode / pick_cfg_method
#                                  cleanup_everything

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

# ──────────────────────────────────────────────────────────────────────────────
# Env / prompts
# ──────────────────────────────────────────────────────────────────────────────
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

load_env() {
  # Caller sets SCRIPT_DIR; we resolve ENV_FILE from it.
  ENV_FILE="${SCRIPT_DIR}/.env"
  if [[ -f "$ENV_FILE" ]]; then
    info "Loading defaults from $ENV_FILE (existing env vars take precedence)"
    # shellcheck disable=SC1090
    set -a; source "$ENV_FILE"; set +a
  fi
}

save_env() {
  cat > "$ENV_FILE" <<EOF
# Auto-saved by verify-module-*.sh - safe to edit/delete
DEPLOY_MODE=${DEPLOY_MODE:-}
KONNECT_TOKEN=${KONNECT_TOKEN:-}
KONNECT_REGION=${KONNECT_REGION:-}
KONNECT_CP_ID=${KONNECT_CP_ID:-}
KONNECT_CP_NAME=${KONNECT_CP_NAME:-}
KONNECT_PROXY_URL=${KONNECT_PROXY_URL:-}
KONG_DP_CONTAINER=${KONG_DP_CONTAINER:-}
CFG_METHOD=${CFG_METHOD:-}
EOF
  chmod 600 "$ENV_FILE"
  ok "Saved values to $ENV_FILE (chmod 600)"
}

# ──────────────────────────────────────────────────────────────────────────────
# Prerequisites check
# ──────────────────────────────────────────────────────────────────────────────
# Print install hint for a missing tool. Caller passes the bare tool name.
_install_hint() {
  case "$1" in
    curl)    printf '  curl     %s\n' "macOS: pre-installed · Linux: 'apt install curl' / 'yum install curl'" ;;
    jq)      printf '  jq       %s\n' "macOS: 'brew install jq' · Linux: 'apt install jq' / 'yum install jq'" ;;
    openssl) printf '  openssl  %s\n' "macOS: pre-installed · Linux: 'apt install openssl' / 'yum install openssl'" ;;
    deck)    printf '  deck     %s\n' "macOS: 'brew install kong/deck/deck' · Linux: see https://docs.konghq.com/deck/" ;;
    docker)  printf '  docker   %s\n' "https://docs.docker.com/get-docker/ (need ≥ 4 GB allocated for hybrid mode)" ;;
    python3) printf '  python3  %s\n' "macOS: 'brew install python@3' · Linux: 'apt install python3'" ;;
    *)       printf '  %-8s %s\n' "$1" "(install hint not available)" ;;
  esac
}

# Print a short version string for a tool. Best-effort.
_tool_version() {
  case "$1" in
    curl)    curl --version 2>/dev/null    | head -1 | awk '{print $2}' ;;
    jq)      jq --version 2>/dev/null      | sed 's/^jq-//' ;;
    openssl) openssl version 2>/dev/null   | awk '{print $2}' ;;
    deck)    deck version 2>/dev/null      | awk '/^decK/{print $2}' ;;
    docker)  docker --version 2>/dev/null  | awk '{print $3}' | tr -d ',' ;;
    bash)    printf '%s' "$BASH_VERSION" ;;
    python3) python3 --version 2>/dev/null | awk '{print $2}' ;;
    *)       printf 'unknown' ;;
  esac
}

# check_prerequisites - print a status table and exit 1 if anything required is missing.
# Required tools depend on selected modes (which the caller may not have picked yet),
# so this function checks the "always required" core plus reports optional tools.
check_prerequisites() {
  hdr "Prerequisites"

  local required=( curl jq openssl bash )
  local optional=( deck docker python3 )
  local missing_req=() missing_opt=()

  step "Required tools"
  for t in "${required[@]}"; do
    if [[ "$t" == "bash" ]] || command -v "$t" >/dev/null 2>&1; then
      ok "  $t $(_tool_version "$t")"
    else
      err "  $t - NOT FOUND"
      missing_req+=("$t")
    fi
  done

  step "Optional tools (needed only if you pick certain modes)"
  for t in "${optional[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      ok "  $t $(_tool_version "$t")"
    else
      info "  $t - not found (only required if you choose its mode)"
      missing_opt+=("$t")
    fi
  done

  if (( ${#missing_req[@]} > 0 )); then
    echo
    err "Missing required tools - please install:"
    for t in "${missing_req[@]}"; do _install_hint "$t" >&2; done
    exit 1
  fi

  if (( ${#missing_opt[@]} > 0 )); then
    echo
    warn "Optional tools not installed:"
    for t in "${missing_opt[@]}"; do _install_hint "$t" >&2; done
    case " ${missing_opt[*]} " in
      *' deck '*)   info "  • Without deck   → you must pick CFG_METHOD=api when prompted." ;;
    esac
    case " ${missing_opt[*]} " in
      *' docker '*) info "  • Without docker → you cannot use DEPLOY_MODE=hybrid (serverless is fine)." ;;
    esac
  fi

  # Bash 4+ check (some scripts use associative arrays / ${var,,})
  local bash_major=${BASH_VERSION%%.*}
  if (( bash_major < 4 )); then
    warn "Bash $BASH_VERSION detected. macOS ships 3.2 by default - most scripts work, but if you hit a parse error, install bash 4+: 'brew install bash'."
  fi

  ok "Prerequisites check passed"
}

# check_kong_version - once Konnect is reachable, confirm the CP/DPs run Kong 3.14+.
# Safe to call after ping_konnect (uses KONNECT_API_BASE / KONNECT_TOKEN).
check_kong_version() {
  step "Kong Gateway version (require 3.14+)"

  # Konnect serverless: the runtime version isn't exposed directly per-CP;
  # Konnect manages it (always latest stable). Surface this and move on.
  if [[ "${DEPLOY_MODE:-}" == "serverless" ]]; then
    info "Serverless mode - Konnect manages the runtime. Konnect always tracks the current Kong release (3.14+)."
    ok "Assuming Kong Gateway 3.14+ (serverless, Konnect-managed)"
    return 0
  fi

  # Hybrid: check the registered Data Planes' reported versions.
  local versions_json
  versions_json=$(curl -sS -H "Authorization: Bearer $KONNECT_TOKEN" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/dataplanes" 2>/dev/null || echo '{}')

  local count
  count=$(echo "$versions_json" | jq -r '.data | length' 2>/dev/null || echo 0)
  if [[ "$count" == "0" ]]; then
    warn "No registered Data Planes found yet. If your DP just started, give it 30s and re-run."
    return 0
  fi

  local bad=0
  while IFS=$'\t' read -r host ver; do
    [[ -z "$ver" ]] && continue
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    if (( major > 3 )) || (( major == 3 && minor >= 14 )); then
      ok "  $host  → Kong $ver (OK, ≥ 3.14)"
    else
      err "  $host  → Kong $ver  (BELOW 3.14 - labs will fail)"
      bad=$((bad+1))
    fi
  done < <(echo "$versions_json" | jq -r '.data[]? | [(.hostname // "?"), (.version // "")] | @tsv')

  if (( bad > 0 )); then
    err "At least one DP is running Kong < 3.14. Update the docker image tag to 'kong/kong-gateway:3.14' and restart the DP."
    exit 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Deployment mode selection
# ──────────────────────────────────────────────────────────────────────────────
pick_deploy_mode() {
  # Accepts CLI arg via $1 (passed in by the caller). Falls back to env, then prompt.
  local cli_mode=${1-}
  local cli_mode_lc; cli_mode_lc=$(printf '%s' "$cli_mode" | tr '[:upper:]' '[:lower:]')

  case "$cli_mode_lc" in
    -h|--help)
      cat <<USAGE
Usage: $(basename "${BASH_SOURCE[1]:-script}") [serverless|hybrid]

  serverless   Run all checks against a Konnect serverless gateway
  hybrid       Run all checks against a local Docker Data Plane + Konnect CP

If omitted, the script uses \$DEPLOY_MODE (from env or scripts/.env), or asks interactively.
The chosen mode applies to the ENTIRE script run.
USAGE
      exit 0 ;;
    serverless|hybrid) DEPLOY_MODE=$cli_mode_lc ;;
    "")  : ;;
    *) err "Unknown mode '$cli_mode'. Use: serverless | hybrid (or --help)"; exit 1 ;;
  esac

  if [[ -z "${DEPLOY_MODE:-}" ]]; then
    echo
    echo "${BOLD}Deployment mode${RST} ${DIM}(applies to the entire script run)${RST}"
    echo "  1) serverless  - Konnect runs the Data Plane (proxy URL is *.kongcloud.dev)"
    echo "  2) hybrid      - Konnect CP + local Docker Data Plane (proxy URL is http://localhost:8000)"
    printf 'Choose [1/2]: '
    read -r mode_choice
    case "${mode_choice:-1}" in
      1) DEPLOY_MODE="serverless" ;;
      2) DEPLOY_MODE="hybrid"     ;;
      *) err "Invalid choice"; exit 1 ;;
    esac
  fi
  case "$DEPLOY_MODE" in
    serverless|hybrid) ok "Deployment mode (locked for this run): ${BOLD}${DEPLOY_MODE}${RST}" ;;
    *) err "DEPLOY_MODE must be 'serverless' or 'hybrid' (got '$DEPLOY_MODE')"; exit 1 ;;
  esac
  export DEPLOY_MODE
}

# ──────────────────────────────────────────────────────────────────────────────
# Konnect inputs
# ──────────────────────────────────────────────────────────────────────────────
collect_konnect_inputs() {
  require_cmd curl
  require_cmd jq

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
  export KONNECT_PROXY_URL

  KONNECT_API_BASE="https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities"
  export KONNECT_API_BASE
}

# ──────────────────────────────────────────────────────────────────────────────
# Config method selection (decK vs Admin API)
# ──────────────────────────────────────────────────────────────────────────────
pick_cfg_method() {
  if [[ -z "${CFG_METHOD:-}" ]]; then
    hdr "Configuration method"
    echo "  1) decK (sync YAML to Konnect)"
    echo "  2) Konnect Admin API (curl)"
    printf 'Choose [1/2]: '
    read -r cfg_choice
    case "${cfg_choice:-1}" in
      1) CFG_METHOD="deck"  ;;
      2) CFG_METHOD="api"   ;;
      *) err "Invalid choice"; exit 1 ;;
    esac
  fi
  case "$CFG_METHOD" in
    deck) require_cmd deck ;;
    api)  : ;;
    *) err "CFG_METHOD must be 'deck' or 'api' (got '$CFG_METHOD')"; exit 1 ;;
  esac
  ok "Using ${BOLD}${CFG_METHOD}${RST}${GRN} for configuration${RST}"
  export CFG_METHOD
}

# ──────────────────────────────────────────────────────────────────────────────
# Konnect Admin API helpers
# ──────────────────────────────────────────────────────────────────────────────

# _verbose_log - pretty-print HTTP call details to stderr when VERBOSE=1.
# Args: method, path, status, request_body, response_body
# (request/response bodies are passed-by-content, not by file path.)
_verbose_log() {
  [[ "${VERBOSE:-}" != "1" ]] && return 0
  local method=$1 path=$2 status=$3 req=${4-} resp=${5-}
  local status_color="$DIM"
  case "$status" in
    2*)        status_color="$GRN" ;;
    3*)        status_color="$CYN" ;;
    4*|5*|000) status_color="$RED" ;;
  esac
  printf '%s  ↪ %s %s%s  %s[HTTP %s]%s\n' \
    "$DIM" "$method" "$path" "$RST" "$status_color" "$status" "$RST" >&2
  if [[ -n "$req" ]]; then
    printf '%s    request:%s\n' "$DIM" "$RST" >&2
    # Try to pretty-print JSON; fall back to first 5 lines of raw text. Cap at 30 lines.
    { echo "$req" | jq -C . 2>/dev/null || echo "$req"; } | head -30 | sed 's/^/      /' >&2
  fi
  if [[ -n "$resp" ]]; then
    printf '%s    response:%s\n' "$DIM" "$RST" >&2
    { echo "$resp" | jq -C . 2>/dev/null || echo "$resp"; } | head -30 | sed 's/^/      /' >&2
  fi
}

api_curl() {
  # Read-only helper. Returns body on stdout; HTTP status NOT checked.
  # Always captures status+body so VERBOSE=1 can log them; never blocks on errors.
  # Usage: api_curl <METHOD> <PATH> [JSON_BODY]
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
  _verbose_log "$method" "$path" "$code" "$body" "$(cat "$tmp")"
  cat "$tmp"
  rm -f "$tmp"
}

wait_with_progress() {
  # wait_with_progress <seconds> [label]
  # Sleep with a visible countdown so the user knows the script is alive.
  local total=$1 label=${2-"Waiting"}
  local i
  for (( i = total; i > 0; i-- )); do
    printf '\r%s  %s %ds remaining…%s ' "$DIM" "$label" "$i" "$RST"
    sleep 1
  done
  printf '\r%s  %s done.                                    %s\n' "$DIM" "$label" "$RST"
}

resolve_id() {
  # resolve_id <plural-kind> <name>
  # Konnect Admin API requires UUIDs in path segments for PATCH/PUT/DELETE and
  # nested-resource POSTs. GET-by-name does work, so we round-trip name → uuid here.
  # Echoes the UUID on stdout. Returns non-zero if the entity isn't found.
  local kind=$1 name=$2
  local id
  id=$(api_curl GET "/$kind/$name" 2>/dev/null | jq -r '.id // empty')
  if [[ -z "$id" || "$id" == "null" ]]; then return 1; fi
  printf '%s' "$id"
}

api_write() {
  # Write helper that captures HTTP status and FAILS LOUDLY on non-2xx.
  # Honors VERBOSE=1 by also logging method/path/status + request/response bodies.
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
  _verbose_log "$method" "$path" "$code" "$body" "$(cat "$tmp")"
  if [[ "$code" == 2* ]]; then
    cat "$tmp"; rm -f "$tmp"; return 0
  fi
  err "Konnect Admin API $method $path → HTTP $code"
  if [[ -n "$body" ]]; then err "Request body: $body"; fi
  err "Response body:"
  sed 's/^/  /' "$tmp" >&2 || true
  rm -f "$tmp"
  return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# decK helpers
# ──────────────────────────────────────────────────────────────────────────────
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

deck_ping() {
  deck gateway ping --konnect-token "$KONNECT_TOKEN" \
    --konnect-control-plane-name "$KONNECT_CP_NAME"
}

# ──────────────────────────────────────────────────────────────────────────────
# Entity helpers
# ──────────────────────────────────────────────────────────────────────────────
wait_for_route() {
  # wait_for_route <url> [timeout_seconds]
  # Polls until the URL stops returning Kong's "no Route matched" 404.
  local url=$1 timeout=${2:-30} interval=3 elapsed=0 http
  info "Waiting up to ${timeout}s for route to propagate to the DP…"
  while (( elapsed < timeout )); do
    http=$(curl -sS -o /tmp/_verify_wait.txt -w '%{http_code}' "$url" || echo "000")
    if [[ "$http" != "404" ]] || ! grep -q "no Route matched" /tmp/_verify_wait.txt 2>/dev/null; then
      ok "Route is live after ${elapsed}s (HTTP $http)"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
    printf '.'
  done
  echo
  err "Route did not propagate within ${timeout}s. Last response (HTTP $http):"
  cat /tmp/_verify_wait.txt; echo
  return 1
}

wait_for_http_status() {
  # wait_for_http_status <url> <expected_code> [timeout_seconds] [extra_curl_args...]
  # Polls until the URL returns the expected HTTP status code.
  # Useful for confirming a plugin has propagated (e.g. wait for 401 after attaching key-auth).
  local url=$1 expected=$2 timeout=${3:-45} interval=3 elapsed=0 http
  shift 3 || shift $#
  info "Waiting up to ${timeout}s for HTTP ${expected} from the DP…"
  while (( elapsed < timeout )); do
    # -o /tmp/_verify_wait.txt keeps body out of stdout so $http stays clean.
    # 2>/dev/null suppresses curl's own error messages (connection refused, etc.)
    # On curl failure we fall back to "000" so the comparison never matches prematurely.
    http=$(curl -s -o /tmp/_verify_wait.txt -w '%{http_code}' "$@" "$url" 2>/dev/null) || http="000"
    if [[ "$http" == "$expected" ]]; then
      ok "Plugin active: HTTP ${expected} after ${elapsed}s"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
    printf '.'
  done
  echo
  err "Plugin did not become active within ${timeout}s. Expected HTTP ${expected}, last got HTTP ${http}."
  return 1
}

wait_for_body_jq() {
  # wait_for_body_jq <url> <jq_expr> [timeout_seconds] [extra_curl_args...]
  # Polls until a GET response body, parsed with jq, returns a non-empty/non-null value.
  # Useful for request-transforming plugins whose effect appears in httpbin's echoed headers
  # (the JSON body) rather than in HTTP response headers.
  local url=$1 jq_expr=$2 timeout=${3:-60} interval=3 elapsed=0 value
  shift 3 || shift $#
  info "Waiting up to ${timeout}s for '$jq_expr' in response body…"
  while (( elapsed < timeout )); do
    value=$(curl -s "$@" "$url" | jq -r "${jq_expr} // empty" 2>/dev/null)
    if [[ -n "$value" && "$value" != "null" ]]; then
      ok "Plugin active: body value present after ${elapsed}s"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
    printf '.'
  done
  echo
  err "'$jq_expr' not seen in response body within ${timeout}s - plugin may not have propagated."
  return 1
}

wait_for_response_header() {
  # Polls until the response contains the named header (lowercase match).
  # Extra curl args (e.g. -H 'X-API-Key: …') are forwarded to every poll request.
  # Useful for confirming header-injecting plugins have propagated (e.g. correlation-id,
  # rate-limiting, etc.), optionally scoped to a specific consumer via an API key.
  local url=$1 header=$2 timeout=${3:-45} interval=3 elapsed=0 value
  shift 3 || shift $#
  info "Waiting up to ${timeout}s for '${header}' header in response…"
  while (( elapsed < timeout )); do
    value=$(curl -sI "$@" "$url" | awk -F': ' -v h="${header}" 'tolower($1)==h{print $2}' | tr -d '\r\n')
    if [[ -n "$value" ]]; then
      ok "Plugin active: '${header}' present after ${elapsed}s"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
    printf '.'
  done
  echo
  err "Header '${header}' not seen within ${timeout}s - plugin may not have propagated."
  return 1
}

list_services() {
  api_curl GET "/services" \
    | jq -r '.data[]? | "  - " + .name + " → " + .protocol + "://" + .host + ":" + (.port|tostring)'
}

list_routes() {
  api_curl GET "/routes" \
    | jq -r '.data[]? | "  - " + .name + "  paths=" + (.paths|tostring) + "  strip_path=" + (.strip_path|tostring)'
}

list_consumers() {
  api_curl GET "/consumers" \
    | jq -r '.data[]? | "  - " + .username + (if .custom_id then "  custom_id=" + .custom_id else "" end)'
}

list_plugins_by_tag() {
  # list_plugins_by_tag <tag>
  api_curl GET "/plugins?tags=$1" \
    | jq -r '.data[]? | "  - " + .name + (if .route then "  (route)" elif .service then "  (service)" elif .consumer then "  (consumer)" else "  (global)" end)'
}

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup - inspect-then-confirm pattern
# ──────────────────────────────────────────────────────────────────────────────
inspect_cp_state() {
  # Returns a summary of what's currently in the CP. Prints nothing if empty.
  # Sets globals: CP_SERVICES_N, CP_ROUTES_N, CP_CONSUMERS_N, CP_PLUGINS_N, CP_UPSTREAMS_N, CP_CG_N
  CP_SERVICES_N=$(api_curl  GET "/services"        | jq -r '.data | length' 2>/dev/null || echo 0)
  CP_ROUTES_N=$(api_curl    GET "/routes"          | jq -r '.data | length' 2>/dev/null || echo 0)
  CP_CONSUMERS_N=$(api_curl GET "/consumers"       | jq -r '.data | length' 2>/dev/null || echo 0)
  CP_PLUGINS_N=$(api_curl   GET "/plugins"         | jq -r '.data | length' 2>/dev/null || echo 0)
  CP_UPSTREAMS_N=$(api_curl GET "/upstreams"       | jq -r '.data | length' 2>/dev/null || echo 0)
  CP_CG_N=$(api_curl        GET "/consumer_groups" | jq -r '.data | length' 2>/dev/null || echo 0)
}

cp_is_empty() {
  # Returns 0 (true) if the CP has no user-created entities.
  inspect_cp_state
  (( CP_SERVICES_N == 0 && CP_ROUTES_N == 0 && CP_CONSUMERS_N == 0 \
     && CP_PLUGINS_N == 0 && CP_UPSTREAMS_N == 0 && CP_CG_N == 0 ))
}

print_cp_state() {
  inspect_cp_state
  printf '  Services:        %s\n' "$CP_SERVICES_N"
  printf '  Routes:          %s\n' "$CP_ROUTES_N"
  printf '  Consumers:       %s\n' "$CP_CONSUMERS_N"
  printf '  Consumer Groups: %s\n' "$CP_CG_N"
  printf '  Upstreams:       %s\n' "$CP_UPSTREAMS_N"
  printf '  Plugins:         %s\n' "$CP_PLUGINS_N"
}

cleanup_if_needed() {
  # Inspect first. If empty, proceed silently. If not, show what's there and ask.
  step "Pre-flight: checking CP state"
  if cp_is_empty; then
    ok "Control Plane is already empty - no cleanup needed."
    return 0
  fi

  warn "Control Plane is not empty. Current contents:"
  print_cp_state
  echo
  warn "The module verification scripts assume a clean Control Plane."
  warn "Continuing without cleanup may cause spurious failures or leftover plugin chains."
  echo
  printf '%sWipe everything on the CP before proceeding? [Y/n/inspect]:%s ' "$BOLD$YLW" "$RST"
  read -r ans
  case "${ans:-Y}" in
    n|N)
      warn "Skipping cleanup - re-running with leftover state may produce confusing results."
      return 0
      ;;
    inspect|i|I)
      info "Detailed inventory:"
      echo
      info "Services:"        ; list_services        2>/dev/null || true
      info "Routes:"          ; list_routes          2>/dev/null || true
      info "Consumers:"       ; list_consumers       2>/dev/null || true
      info "Upstreams:"       ; api_curl GET "/upstreams" | jq -r '.data[]?.name' | sed 's/^/  - /' || true
      info "Consumer Groups:" ; api_curl GET "/consumer_groups" | jq -r '.data[]?.name' | sed 's/^/  - /' || true
      info "Plugins:"         ; api_curl GET "/plugins" | jq -r '.data[]? | "  - " + .name + (if .route then " (route)" elif .service then " (service)" elif .consumer then " (consumer)" elif .consumer_group then " (consumer-group)" else " (global)" end)' || true
      echo
      printf '%sNow - wipe everything? [Y/n]:%s ' "$BOLD$YLW" "$RST"
      read -r ans2
      case "${ans2:-Y}" in
        n|N) warn "Skipping cleanup."; return 0 ;;
      esac
      ;;
  esac

  step "Wiping CP…"
  cleanup_everything
}

cleanup_generated_files() {
  # Remove any files the scripts dropped during a run.
  # NOTE: scripts/.env is preserved by default (it caches your credentials for re-runs).
  # Pass --purge to also delete .env.
  local purge=${1-}
  local removed=()
  # Temp files used by lib helpers and per-module scripts
  for f in /tmp/_verify_wait.txt /tmp/_verify_ping.json /tmp/_verify_outage.txt \
           /tmp/m01_proxy.txt /tmp/m01_ka.json; do
    if [[ -e "$f" ]]; then rm -f "$f" && removed+=("$f"); fi
  done
  # Per-module generated artifacts in scripts/
  for f in "$SCRIPT_DIR"/*-config-dump.yaml "$SCRIPT_DIR"/*.bak; do
    if [[ -e "$f" ]]; then rm -f "$f" && removed+=("$f"); fi
  done
  # Optional: purge cached env
  if [[ "$purge" == "--purge" && -e "$ENV_FILE" ]]; then
    rm -f "$ENV_FILE" && removed+=("$ENV_FILE (cached inputs)")
  fi
  if (( ${#removed[@]} > 0 )); then
    ok "Removed generated files:"
    printf '  - %s\n' "${removed[@]}"
  else
    info "No generated files to remove."
  fi
}

reset_cfg_method_in_env() {
  # Set CFG_METHOD= (null) in the saved .env so the NEXT script run re-prompts
  # the user to pick decK vs Admin API. The CURRENT shell's CFG_METHOD stays
  # intact so the rest of the in-flight script continues fine.
  if [[ -f "$ENV_FILE" ]]; then
    if grep -q '^CFG_METHOD=' "$ENV_FILE"; then
      # Portable sed -i (works on both GNU and BSD/macOS sed)
      sed -i.bak 's/^CFG_METHOD=.*/CFG_METHOD=/' "$ENV_FILE" && rm -f "$ENV_FILE.bak"
      info "Cleared cached CFG_METHOD in $ENV_FILE - next run will re-ask 'decK vs Admin API'."
    fi
  fi
}

cleanup_everything() {
  # Empties the CP. Both decK and Admin API paths supported.
  if [[ "$CFG_METHOD" == "deck" ]]; then
    echo '_format_version: "3.0"' | deck_sync_stdin >/dev/null
    ok "decK reset complete (CP is empty)."
  else
    # Delete plugins → routes → consumers → upstreams → services (order matters for FKs)
    for kind in plugins routes consumers upstreams services; do
      local ids
      ids=$(api_curl GET "/$kind" | jq -r '.data[]?.id' 2>/dev/null || true)
      if [[ -n "$ids" ]]; then
        while IFS= read -r id; do
          [[ -z "$id" ]] && continue
          curl -sS -X DELETE -H "Authorization: Bearer $KONNECT_TOKEN" \
            "${KONNECT_API_BASE}/$kind/$id" >/dev/null || true
        done <<< "$ids"
      fi
    done
    ok "Admin API delete sweep complete."
  fi
  # Whenever we wipe the CP, also clear the cached config-method so the next
  # script run lets the user choose deck vs api fresh.
  reset_cfg_method_in_env
}

# ──────────────────────────────────────────────────────────────────────────────
# Hybrid DP verification (used by every module that supports hybrid)
# ──────────────────────────────────────────────────────────────────────────────
verify_hybrid_dp() {
  [[ "$DEPLOY_MODE" != "hybrid" ]] && return 0
  step "Hybrid: verify Docker DP container '$KONG_DP_CONTAINER'"
  require_cmd docker
  if ! docker ps --format '{{.Names}}' | grep -qx "$KONG_DP_CONTAINER"; then
    err "Container '$KONG_DP_CONTAINER' is not running."
    exit 1
  fi
  ok "Container '$KONG_DP_CONTAINER' is running"
  if docker exec "$KONG_DP_CONTAINER" kong health >/dev/null 2>&1; then
    ok "kong health → green"
  else
    err "kong health failed inside $KONG_DP_CONTAINER."; exit 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Konnect API reachability check
# ──────────────────────────────────────────────────────────────────────────────
ping_konnect() {
  step "Ping Konnect Admin API"
  local http
  http=$(curl -sS -o /tmp/_verify_ping.json -w '%{http_code}' \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}")
  if [[ "$http" == "200" ]]; then
    local cp_name; cp_name=$(jq -r '.name // "?"' /tmp/_verify_ping.json)
    ok "Konnect API reachable. CP: $cp_name ($KONNECT_CP_ID)"
  else
    err "Konnect API returned HTTP $http. Body:"
    cat /tmp/_verify_ping.json; exit 1
  fi
}
