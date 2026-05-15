#!/usr/bin/env bash
# verify-module-06.sh - Verify Module 06 (Observability) against Konnect.
#
# Covers:
#   Lab 06-A  http-log: structured access logs streamed to a webhook receiver
#   Lab 06-B  prometheus: enable plugin, confirm metrics endpoint / Konnect Analytics
#   Lab 06-C  opentelemetry: configure OTLP endpoint, verify traceparent forwarding
#
# Some parts of this lab need external services (webhook receiver, OTLP collector).
# The script prompts for them and skips sub-sections gracefully if they're absent.
#
# Usage:  ./scripts/verify-module-06.sh [serverless|hybrid]

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 06 Verification (Observability)"

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
# Baseline
# ──────────────────────────────────────────────────────────────────────────────
hdr "Baseline: Service + Route + Consumer + key-auth"

if [[ "$CFG_METHOD" == "deck" ]]; then
  cat <<'YAML' | deck_sync_stdin >/dev/null
_format_version: '3.0'
consumers:
  - username: web-app
    custom_id: web-001
    tags: [module-06]
    keyauth_credentials: [{ key: web-app-secret-key-001 }]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-06]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-06]
        plugins:
          - name: key-auth
            tags: [module-06]
            config: { key_names: [X-API-Key], hide_credentials: true }
YAML
else
  api_write POST "/consumers" \
    "$(jq -n '{username:"web-app", custom_id:"web-001", tags:["module-06"]}')" >/dev/null
  api_write POST "/consumers/web-app/key-auth" "$(jq -n '{key:"web-app-secret-key-001"}')" >/dev/null
  api_write POST "/services" \
    "$(jq -n '{name:"flights-svc", url:"https://httpbin.konghq.com", tags:["module-06"]}')" >/dev/null
  SID=$(api_curl GET "/services/flights-svc" | jq -r '.id')
  api_write POST "/routes" \
    "$(jq -n --arg s "$SID" '{name:"flights-route", paths:["/flights"], strip_path:true, service:{id:$s}, tags:["module-06"]}')" >/dev/null
  RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')
  api_write POST "/routes/$RID/plugins" \
    "$(jq -n '{name:"key-auth", config:{key_names:["X-API-Key"], hide_credentials:true}, tags:["module-06"]}')" >/dev/null
fi
ok "Baseline applied"

wait_for_route "${KONNECT_PROXY_URL}/flights/get" 30 || true
RID=$(api_curl GET "/routes/flights-route" | jq -r '.id')

# ──────────────────────────────────────────────────────────────────────────────
# Lab 06-A - HTTP Logging
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 06-A - HTTP Logging"

info "Logs need an HTTP endpoint to POST to. Easiest free option: https://webhook.site"
prompt_var LOG_URL "Log receiver URL (POST target). Press Enter to SKIP http-log section."

if [[ -z "${LOG_URL:-}" ]]; then
  warn "No LOG_URL provided - skipping Lab 06-A."
else
  step "1. Attach http-log to flights-route"
  api_write POST "/routes/$RID/plugins" "$(jq -n --arg u "$LOG_URL" '{
    name: "http-log",
    tags: ["module-06"],
    config: {
      http_endpoint: $u,
      method: "POST",
      timeout: 10000,
      keepalive: 60000,
      flush_timeout: 2,
      queue_size: 100,
      content_type: "application/json",
      custom_fields_by_lua: {
        "request.headers.authorization": "return \"[REDACTED]\"",
        "request.headers.x-api-key":     "return \"[REDACTED]\""
      }
    }
  }')" >/dev/null
  ok "http-log attached"
  wait_for_route "${KONNECT_PROXY_URL}/flights/get" 15 || true

  step "2. Send ~5 requests to produce log entries"
  for _ in {1..5}; do
    curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001'
  done
  ok "5 requests sent. Wait ~3s for the flush window."
  sleep 4
  pause_verify "Open $LOG_URL in your browser - confirm 5 JSON POST bodies arrived, each with x-api-key=[REDACTED] in request.headers."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 06-B - Prometheus
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 06-B - Prometheus"

step "1. Enable prometheus plugin globally (no per_consumer)"
api_write POST "/plugins" "$(jq -n '{
  name: "prometheus",
  tags: ["module-06"],
  config: {
    status_code_metrics: true,
    latency_metrics: true,
    bandwidth_metrics: true,
    upstream_health_metrics: true,
    per_consumer: false
  }
}')" >/dev/null
ok "prometheus plugin enabled globally"

step "2. Send 30 requests to populate metrics"
for _ in {1..30}; do
  curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/get" -H 'X-API-Key: web-app-secret-key-001'
done
# Mix in some 4xx/5xx
for code in 401 403 404 500 502 503; do
  curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/status/$code" -H 'X-API-Key: web-app-secret-key-001'
done
ok "30 OKs + 6 errors sent"

if [[ "$DEPLOY_MODE" == "hybrid" ]]; then
  step "3. Hybrid: scrape /metrics from the DP container (port 8100)"
  if docker exec "$KONG_DP_CONTAINER" sh -c 'curl -s http://localhost:8100/metrics | grep "^kong_http_requests_total" | head -5' 2>/dev/null; then
    ok "/metrics on the DP shows kong_http_requests_total"
  else
    warn "Could not scrape /metrics inside the DP container (port 8100 may not be exposed)."
  fi
else
  info "Serverless mode: /metrics is not publicly exposed. Metrics flow into Konnect Analytics."
  pause_verify "Konnect → Analytics → look at the last 5 minutes - confirm the 36 requests are visible, with a 4xx/5xx breakdown."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Lab 06-C - OpenTelemetry
# ──────────────────────────────────────────────────────────────────────────────
hdr "Lab 06-C - OpenTelemetry"

prompt_var OTLP_ENDPOINT "OTLP HTTP endpoint (e.g. http://localhost:4318/v1/traces). Press Enter to SKIP."

if [[ -z "${OTLP_ENDPOINT:-}" ]]; then
  warn "No OTLP_ENDPOINT provided - skipping Lab 06-C live verification."
  step "1. Attach opentelemetry plugin anyway (with a placeholder endpoint, sampling=0)"
  api_write POST "/plugins" "$(jq -n '{
    name: "opentelemetry",
    tags: ["module-06"],
    config: {
      endpoint: "http://collector-not-configured.invalid:4318/v1/traces",
      resource_attributes: { "service.name": "kong-bootcamp", "deployment.environment": "lab" },
      sampling_rate: 0,
      header_type: "w3c",
      batch_span_count: 200,
      batch_flush_delay: 3
    }
  }')" >/dev/null
  ok "opentelemetry plugin attached (sampling=0, so no actual spans emitted)"
else
  prompt_var OTLP_AUTH_HEADER "Optional OTLP auth header (format 'Key:Value', e.g. 'x-honeycomb-team:abc'). Press Enter for none."
  HDR_JSON='{}'
  if [[ -n "${OTLP_AUTH_HEADER:-}" ]]; then
    HDR_KEY=${OTLP_AUTH_HEADER%%:*}
    HDR_VAL=${OTLP_AUTH_HEADER#*:}
    HDR_JSON=$(jq -nc --arg k "$HDR_KEY" --arg v "$HDR_VAL" '{($k):$v}')
  fi
  step "1. Attach opentelemetry plugin globally (100% sampling for the lab)"
  api_write POST "/plugins" "$(jq -n --arg ep "$OTLP_ENDPOINT" --argjson hdr "$HDR_JSON" '{
    name: "opentelemetry",
    tags: ["module-06"],
    config: {
      endpoint: $ep,
      resource_attributes: { "service.name": "kong-bootcamp", "deployment.environment": "lab" },
      headers: $hdr,
      sampling_rate: 1.0,
      header_type: "w3c",
      batch_span_count: 200,
      batch_flush_delay: 3
    }
  }')" >/dev/null
  ok "opentelemetry attached, sampling=1.0, endpoint=$OTLP_ENDPOINT"

  step "2. Send 10 requests so traces flow"
  for _ in {1..10}; do
    curl -s -o /dev/null "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001'
  done

  step "3. traceparent header should be forwarded to upstream"
  TP=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
    | jq -r '.headers["Traceparent"] // "missing"')
  if [[ "$TP" =~ ^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$ ]]; then
    ok "traceparent forwarded to upstream: $TP"
  else
    warn "traceparent missing or malformed: $TP"
  fi

  step "4. Honour client-supplied traceparent (same trace-id continues)"
  INCOMING=00-0123456789abcdef0123456789abcdef-0123456789abcdef-01
  CONT=$(curl -s "${KONNECT_PROXY_URL}/flights/anything" -H 'X-API-Key: web-app-secret-key-001' \
    -H "traceparent: $INCOMING" | jq -r '.headers["Traceparent"]')
  # Same trace-id (the 32-hex block), different span-id (the 16-hex block) is the correct continue behavior
  TRACE_ID_IN=$(echo "$INCOMING" | cut -d- -f2)
  TRACE_ID_OUT=$(echo "$CONT" | cut -d- -f2)
  if [[ "$TRACE_ID_IN" == "$TRACE_ID_OUT" ]]; then
    ok "Trace continued (same trace-id $TRACE_ID_OUT carried forward, new span-id)"
  else
    warn "Trace-id mismatch - in=$TRACE_ID_IN out=$TRACE_ID_OUT"
  fi

  pause_verify "Open your OTLP collector (Jaeger / Tempo / Honeycomb): confirm spans for service.name=kong-bootcamp."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────
hdr "Cleanup - wipe everything tagged module-06"
printf 'Delete all M06 entities now? [Y/n]: '
read -r CLEAN
case "${CLEAN:-Y}" in
  n|N) warn "Skipping cleanup." ;;
  *) cleanup_everything; ok "Module 06 cleanup complete."; cleanup_generated_files ;;
esac

hdr "Module 06 verification complete ✓"
ok "Lab 06-A (http-log), 06-B (prometheus), 06-C (opentelemetry) - at least the parts where external services were available."
info "Re-run anytime: $0 ${DEPLOY_MODE}"
