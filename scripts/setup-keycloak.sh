#!/usr/bin/env bash
# setup-keycloak.sh — Start the bootcamp Keycloak instance and verify it's ready.
#
# What it does:
#   1. Starts (or restarts) the kc-bootcamp container via Docker Compose
#   2. Waits for Keycloak to finish importing the kong-bootcamp realm
#   3. Runs a quick smoke test against the discovery endpoint
#   4. Prints the connection details you need for Labs 07-C and 07-D
#
# Usage:
#   ./scripts/setup-keycloak.sh              # start Keycloak (default)
#   ./scripts/setup-keycloak.sh ngrok        # start Keycloak + open ngrok tunnel (Option B)
#   ./scripts/setup-keycloak.sh stop         # docker compose down (keep DB)
#   ./scripts/setup-keycloak.sh reset        # docker compose down -v (wipe DB)
#   ./scripts/setup-keycloak.sh cleanup      # stop + remove container, volumes & image
#   ./scripts/setup-keycloak.sh status       # show container health
#
# Options (env vars):
#   KC_PORT        Keycloak host port       (default: 8080)
#   KC_ADMIN       Keycloak admin username  (default: admin)
#   KC_PASS        Keycloak admin password  (default: admin)
#   NGROK_AUTHTOKEN  ngrok auth token — required only for the ngrok command
#                    (or pre-configured via: ngrok config add-authtoken <token>)

set -uo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'; GRN=$'\033[0;32m'; RED=$'\033[0;31m'; YEL=$'\033[0;33m'
CYN=$'\033[0;36m'; RST=$'\033[0m'
ok()   { printf "${GRN}✓${RST}  %s\n" "$*"; }
err()  { printf "${RED}✗${RST}  %s\n" "$*" >&2; }
warn() { printf "${YEL}!${RST}   %s\n" "$*"; }
info() { printf "${CYN}ℹ${RST}  %s\n" "$*"; }
hdr()  { printf "\n${BOLD}${CYN}%s${RST}\n%s\n" "$*" "$(printf '─%.0s' {1..76})"; }

# ── config ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KC_DIR="${SCRIPT_DIR}/../module-07-enterprise/keycloak"
KC_PORT="${KC_PORT:-8080}"
KC_ADMIN="${KC_ADMIN:-admin}"
KC_PASS="${KC_PASS:-admin}"
KC_REALM="kong-bootcamp"
KC_BASE="http://localhost:${KC_PORT}"
ISSUER="${KC_BASE}/realms/${KC_REALM}"

CMD="${1:-start}"

# ── helpers ──────────────────────────────────────────────────────────────────
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command not found: $1"; exit 1; }
}

wait_for_keycloak() {
  local timeout=120 interval=5 elapsed=0
  info "Waiting up to ${timeout}s for Keycloak realm import to complete…"
  while (( elapsed < timeout )); do
    if curl -sf "${ISSUER}/.well-known/openid-configuration" -o /dev/null 2>/dev/null; then
      ok "Keycloak is ready after ${elapsed}s"
      return 0
    fi
    printf '.'
    elapsed=$(( elapsed + interval ))
    sleep "$interval"
  done
  echo
  err "Keycloak did not become ready within ${timeout}s."
  err "Check logs: docker logs kc-bootcamp"
  return 1
}

# ── pre-flight ───────────────────────────────────────────────────────────────
require_cmd docker
require_cmd curl
require_cmd jq

if [[ ! -f "${KC_DIR}/docker-compose.yml" ]]; then
  err "docker-compose.yml not found at ${KC_DIR}"
  err "Run this script from the repo root, or check that module-07-enterprise/keycloak/ exists."
  exit 1
fi

# ── commands ─────────────────────────────────────────────────────────────────
case "$CMD" in

  stop)
    hdr "Stopping Keycloak"
    docker compose -f "${KC_DIR}/docker-compose.yml" down
    ok "kc-bootcamp stopped (DB preserved). Use 'reset' to wipe."
    exit 0
    ;;

  reset)
    hdr "Resetting Keycloak (stop + wipe embedded DB)"
    warn "This destroys all realm data. The realm will be re-imported from realm-export.json on next start."
    printf 'Continue? [y/N]: '
    read -r _ans
    case "${_ans}" in
      y|Y) ;;
      *)   info "Aborted."; exit 0 ;;
    esac
    docker compose -f "${KC_DIR}/docker-compose.yml" down -v
    ok "kc-bootcamp stopped and data volume removed."
    exit 0
    ;;

  status)
    hdr "Keycloak container status"
    docker compose -f "${KC_DIR}/docker-compose.yml" ps
    echo
    if curl -sf "${ISSUER}/.well-known/openid-configuration" -o /dev/null 2>/dev/null; then
      ok "Realm endpoint reachable: ${ISSUER}"
    else
      warn "Realm endpoint not reachable: ${ISSUER}"
    fi
    exit 0
    ;;

  cleanup)
    hdr "Cleanup — remove Keycloak container, volumes and image"
    warn "This will:"
    warn "  • Stop and remove the kc-bootcamp container"
    warn "  • Delete the embedded-DB volume (all realm data wiped)"
    warn "  • Remove the quay.io/keycloak/keycloak image from local Docker"
    printf 'Continue? [y/N]: '
    read -r _ans
    case "${_ans}" in
      y|Y) ;;
      *)   info "Aborted."; exit 0 ;;
    esac
    docker compose -f "${KC_DIR}/docker-compose.yml" down -v --rmi local 2>/dev/null || true
    # Also remove the image by full name in case --rmi local misses it
    KC_IMAGE=$(docker inspect kc-bootcamp --format '{{.Config.Image}}' 2>/dev/null || true)
    if [[ -n "$KC_IMAGE" ]]; then
      docker rmi "$KC_IMAGE" 2>/dev/null || true
    fi
    ok "kc-bootcamp container, data volume, and image removed."
    info "Re-run './scripts/setup-keycloak.sh' to start fresh."
    exit 0
    ;;

  ngrok)
    ;;  # fall through — ngrok command starts KC first, then opens tunnel

  start)
    ;;  # fall through to startup sequence below

  *)
    err "Unknown command: $CMD"
    err "Usage: $0 [start|ngrok|stop|reset|cleanup|status]"
    exit 1
    ;;
esac

# ── start sequence ────────────────────────────────────────────────────────────
hdr "Starting Keycloak for Module 07 labs"
info "Compose file: ${KC_DIR}/docker-compose.yml"
info "Realm:        ${KC_REALM}  |  Port: ${KC_PORT}"

# Check if already running and healthy
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^kc-bootcamp$'; then
  if curl -sf "${ISSUER}/.well-known/openid-configuration" -o /dev/null 2>/dev/null; then
    ok "kc-bootcamp is already running and healthy — nothing to do."
    echo
  else
    info "Container is running but realm not yet ready. Waiting…"
    wait_for_keycloak || exit 1
  fi
else
  docker compose -f "${KC_DIR}/docker-compose.yml" up -d || {
    err "docker compose up failed. Is Docker running?"
    exit 1
  }
  echo
  wait_for_keycloak || exit 1
fi

# ── smoke tests ──────────────────────────────────────────────────────────────
hdr "Smoke tests"

# 1. Discovery endpoint
DISCOVERY=$(curl -sf "${ISSUER}/.well-known/openid-configuration" 2>/dev/null) || {
  err "Could not fetch OIDC discovery document from ${ISSUER}"
  exit 1
}
ISSUER_CLAIM=$(printf '%s' "$DISCOVERY" | jq -r '.issuer // empty')
if [[ "$ISSUER_CLAIM" == "$ISSUER" ]]; then
  ok "OIDC discovery OK  (issuer: ${ISSUER_CLAIM})"
else
  warn "Issuer mismatch: expected '${ISSUER}', got '${ISSUER_CLAIM}'"
fi

# 2. Token endpoint reachable
TOKEN_EP=$(printf '%s' "$DISCOVERY" | jq -r '.token_endpoint // empty')
AUTH_EP=$(printf '%s' "$DISCOVERY" | jq -r '.authorization_endpoint // empty')
JWKS_URI=$(printf '%s' "$DISCOVERY" | jq -r '.jwks_uri // empty')
ok "Token endpoint:         ${TOKEN_EP}"
ok "Authorization endpoint: ${AUTH_EP}"
ok "JWKS URI:               ${JWKS_URI}"

# 3. M2M client credentials grant (Lab 07-D)
M2M_RESPONSE=$(curl -sf -X POST \
  -d 'grant_type=client_credentials' \
  -d 'client_id=kong-m2m' \
  -d 'client_secret=kong-m2m-client-secret-replace-in-prod' \
  "${TOKEN_EP}" 2>/dev/null) || true

if printf '%s' "$M2M_RESPONSE" | jq -e '.access_token' >/dev/null 2>&1; then
  ok "M2M client (kong-m2m) → token issued successfully"
else
  warn "M2M client grant failed — check realm-export.json import"
fi

# 4. Password grant for alice (Lab 07-C smoke test)
ALICE_RESPONSE=$(curl -sf -X POST \
  -d 'grant_type=password' \
  -d 'client_id=kong' \
  -d 'client_secret=kong-bootcamp-client-secret-replace-in-prod' \
  -d 'username=alice' \
  -d 'password=alice-password' \
  "${TOKEN_EP}" 2>/dev/null) || true

if printf '%s' "$ALICE_RESPONSE" | jq -e '.access_token' >/dev/null 2>&1; then
  ALICE_USER=$(printf '%s' "$ALICE_RESPONSE" | jq -r '.access_token' \
    | cut -d. -f2 \
    | { base64 -d 2>/dev/null || base64 -D 2>/dev/null; } \
    | jq -r '.preferred_username // "unknown"' 2>/dev/null || echo "unknown")
  ok "User alice (kong client) → token issued  (preferred_username: ${ALICE_USER})"
else
  warn "Password grant for alice failed — check realm-export.json import"
fi

# ── connection summary ────────────────────────────────────────────────────────
print_summary() {
  local public_url="${1:-}"
  hdr "Connection details for Labs 07-C and 07-D"

  cat <<INFO

  ${BOLD}Keycloak admin console${RST}
    URL:    http://localhost:${KC_PORT}
    Realm:  ${KC_REALM}
    Login:  ${KC_ADMIN} / ${KC_PASS}

  ${BOLD}Clients${RST}
    Lab 07-C (OIDC Auth Code)   id: kong
                                secret: kong-bootcamp-client-secret-replace-in-prod
    Lab 07-D (Upstream OAuth)   id: kong-m2m
                                secret: kong-m2m-client-secret-replace-in-prod

  ${BOLD}Test users${RST}
    alice      / alice-password   (role: user)
    bob-admin  / bob-password     (role: admin)

INFO

  if [[ -n "$public_url" ]]; then
    cat <<INFO
  ${BOLD}ngrok public URL (Option B — Konnect serverless)${RST}
    Issuer for Kong plugin:  ${public_url}/realms/${KC_REALM}
    export KEYCLOAK_BASE=${public_url}

  ${BOLD}Option A (hybrid DP) issuer${RST}
    Issuer for Kong plugin:  http://host.docker.internal:${KC_PORT}/realms/${KC_REALM}
    export KEYCLOAK_BASE=http://localhost:${KC_PORT}

INFO
  else
    cat <<INFO
  ${BOLD}Issuer for Kong plugin config${RST}
    Option A (hybrid DP):    http://host.docker.internal:${KC_PORT}/realms/${KC_REALM}
    Option B (serverless):   run '$0 ngrok' to get a public URL

  ${BOLD}Export KEYCLOAK_BASE to use with verify-module-07.sh${RST}
    export KEYCLOAK_BASE=http://localhost:${KC_PORT}

INFO
  fi
}

# ── ngrok tunnel (Option B) ──────────────────────────────────────────────────
if [[ "$CMD" == "ngrok" ]]; then
  require_cmd ngrok

  hdr "Opening ngrok tunnel for Konnect serverless (Option B)"

  # ── 1. ensure keycloak is up ──────────────────────────────────────────────
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^kc-bootcamp$'; then
    info "kc-bootcamp is not running — starting it first…"
    docker compose -f "${KC_DIR}/docker-compose.yml" up -d || {
      err "docker compose up failed. Is Docker running?"
      exit 1
    }
    wait_for_keycloak || exit 1
  elif ! curl -sf "${ISSUER}/.well-known/openid-configuration" -o /dev/null 2>/dev/null; then
    info "Container running but realm not ready. Waiting…"
    wait_for_keycloak || exit 1
  else
    ok "kc-bootcamp already running and healthy."
  fi

  # ── 2. configure authtoken if provided via env ────────────────────────────
  if [[ -n "${NGROK_AUTHTOKEN:-}" ]]; then
    info "Configuring ngrok authtoken from NGROK_AUTHTOKEN env var…"
    ngrok config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null
  fi

  # ── 3. start ngrok in background ─────────────────────────────────────────
  info "Starting ngrok tunnel on port ${KC_PORT}…"
  # Kill any existing ngrok on this port to avoid conflicts
  pkill -f "ngrok http ${KC_PORT}" 2>/dev/null || true
  ngrok http "${KC_PORT}" --log=stdout > /tmp/ngrok-kc.log 2>&1 &
  NGROK_PID=$!
  info "ngrok PID: ${NGROK_PID}  (logs: /tmp/ngrok-kc.log)"

  # ── 4. wait for ngrok API to return a public URL ──────────────────────────
  NGROK_URL=""
  _ng_timeout=30 _ng_elapsed=0
  info "Waiting for ngrok to assign a public URL…"
  while (( _ng_elapsed < _ng_timeout )); do
    NGROK_URL=$(curl -sf http://localhost:4040/api/tunnels 2>/dev/null \
      | jq -r '[.tunnels[] | select(.proto=="https")] | first | .public_url // empty' 2>/dev/null || true)
    if [[ -n "$NGROK_URL" ]]; then
      ok "ngrok tunnel active: ${NGROK_URL}"
      break
    fi
    printf '.'
    _ng_elapsed=$(( _ng_elapsed + 2 ))
    sleep 2
  done
  echo

  if [[ -z "$NGROK_URL" ]]; then
    err "ngrok did not produce a public URL within ${_ng_timeout}s."
    err "Check /tmp/ngrok-kc.log and ensure your authtoken is configured:"
    err "  ngrok config add-authtoken <YOUR_TOKEN>   # https://ngrok.com"
    kill "$NGROK_PID" 2>/dev/null || true
    exit 1
  fi

  # ── 5. update Keycloak frontendUrl so 'iss' in tokens matches the ngrok URL
  info "Updating Keycloak frontendUrl to ${NGROK_URL}…"
  ADMIN_TOKEN=$(curl -sf -X POST \
    -d "grant_type=password&client_id=admin-cli&username=${KC_ADMIN}&password=${KC_PASS}" \
    "http://localhost:${KC_PORT}/realms/master/protocol/openid-connect/token" \
    | jq -r '.access_token // empty') || true

  if [[ -z "$ADMIN_TOKEN" ]]; then
    warn "Could not obtain Keycloak admin token — frontendUrl NOT updated."
    warn "Kong's issuer validation may fail. Update manually in the admin UI:"
    warn "  Realm Settings → General → Frontend URL → ${NGROK_URL}"
  else
    _patch_http=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "http://localhost:${KC_PORT}/admin/realms/${KC_REALM}" \
      -d "{\"attributes\":{\"frontendUrl\":\"${NGROK_URL}\"}}")
    if [[ "$_patch_http" == "204" ]]; then
      ok "frontendUrl updated (HTTP 204)"
    else
      warn "PATCH returned HTTP ${_patch_http} — frontendUrl may not be set."
    fi
  fi

  # ── 6. verify issuer in discovery doc now shows the ngrok URL ─────────────
  _disc_issuer=$(curl -sf "${NGROK_URL}/realms/${KC_REALM}/.well-known/openid-configuration" \
    2>/dev/null | jq -r '.issuer // empty' || true)
  if [[ "$_disc_issuer" == "${NGROK_URL}/realms/${KC_REALM}" ]]; then
    ok "Discovery issuer matches ngrok URL ✓"
  else
    warn "Discovery issuer: '${_disc_issuer}' (expected '${NGROK_URL}/realms/${KC_REALM}')"
    warn "Keycloak may still be propagating the frontendUrl change — wait a moment and re-check."
  fi

  print_summary "$NGROK_URL"
  ok "ngrok setup complete. Tunnel PID=${NGROK_PID} — kill it with: kill ${NGROK_PID}"
  info "Tail tunnel logs: tail -f /tmp/ngrok-kc.log"
  exit 0
fi

print_summary
ok "Keycloak setup complete. Run './scripts/setup-keycloak.sh ngrok' for a public URL (Konnect serverless)."
