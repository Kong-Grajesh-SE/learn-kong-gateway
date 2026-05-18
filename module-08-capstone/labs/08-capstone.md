# Lab 08 - Capstone: Production Gateway

> **Goal.** In ~2.5–3 hours, build a single Kong gateway that satisfies the **15-step acceptance script** at the end. Eleven-plus plugins, three Consumer tiers, two auth methods, full observability. **No more step-by-step.** You'll get a brief, hints, and an acceptance test - *how* you implement it is up to you.

::: tip How to use this lab
Read **Stage 0** all the way through before you type anything. Sketch your `kong.yaml` on paper or in a scratch file. Then start executing.

You'll be tempted to copy/paste from earlier labs. **Don't, yet.** Sketch first. The plugin chain order matters - copying from M03 and M04 and M07 without thinking will produce a config that *almost* works.
:::

---

## Stage 0 - The brief, the constraints, the contract (15 min read)

### The brief

Your travel platform launches Monday. One backend (`httpbin.konghq.com` - pretend it's your real API). Three audiences:

- **Free users** - anonymous-ish web visitors. API key only. Read-only.
- **Partners** - third-party booking sites. JWT, signed by partner IdPs. Read + write to flights & bookings.
- **Internal services** - your own microservices. API key + must come from your office IP range. Full access including `/admin`.

### The contract (memorize)

| Tier | Auth | Rate limit | Allowed paths |
|---|---|---|---|
| free | `key-auth` API key | 10 req/min | `GET /v3/flights/*` only |
| partner | `jwt` HS256, `iss` claim → Consumer | 100 req/min | `/v3/flights/*` + `/v3/bookings/*` (GET, POST) |
| internal | `key-auth` API key + IP allowlist | 1000 req/min | All routes including `/v3/admin/*` |

### Cross-cutting

- All clients call `/v3/...`. Backend serves `/v2/...`. **Rewrite path** at the gateway.
- Clients send `{"flightId": "..."}`. Backend expects `{"id": "..."}`. **Rewrite body field** at the gateway.
- Backend responses include `_debug` and `internal_id` fields. **Strip them.**
- Browser at `https://app.mytravel.com` must work. CORS allowed.
- Every request gets ONE correlation ID, propagated to logs/metrics/traces.
- `GET /v3/flights/popular` is hit ~10x/sec. **Cache for 60s.**

### Decisions you need to make

1. **Scope of `cors`** - global or per-route? (Hint: think about preflight.)
2. **Scope of `prometheus`, `correlation-id`** - global or per-route?
3. **One `rate-limiting` plugin or three?** (Hint: per-Consumer-Group scope is your friend.)
4. **Plugin priority for `key-auth` vs `cors`** - what runs first on a preflight?
5. **Where does `proxy-cache` sit relative to `rate-limiting`?** Cached responses count against the limit. Is that what you want?

Sketch your plugin chain. Don't read on until you've drawn it.

---

## Stage 1 - Reset and bootstrap (10 min)

Empty your Konnect CP first:

```bash
echo '_format_version: "3.0"' | deck gateway sync - \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

Set up your env (if you haven't already):

```bash
export ANON_IP=$(curl -s https://httpbin.konghq.com/ip | jq -r '.origin')
echo "Your apparent IP (the one you'll allow-list for internal): $ANON_IP"
```

---

## Stage 2 - Topology and identity (30 min)

Build the baseline. **Reveal the YAML one section at a time** - sketch yours first, then check.

::: details Stage 2 hint - Services, Routes, Consumer Groups, Consumers
```yaml
_format_version: '3.0'

consumer_groups:
  - { name: free,     tags: [module-08] }
  - { name: partner,  tags: [module-08] }
  - { name: internal, tags: [module-08] }

consumers:
  - username: free-user
    custom_id: free-001
    groups: [free]
    keyauth_credentials:
      - { key: FREE-KEY-001 }
    tags: [module-08]

  - username: partner-issuer-a
    custom_id: partner-a-001
    groups: [partner]
    jwt_secrets:
      - { key: "partner-a", algorithm: HS256, secret: "partner-a-shared-secret-256-bit-do-not-leak" }
    tags: [module-08]

  - username: internal-svc
    custom_id: internal-001
    groups: [internal]
    keyauth_credentials:
      - { key: INTERNAL-KEY-001 }
    tags: [module-08]

services:
  - name: travel-svc
    url: https://httpbin.konghq.com
    tags: [module-08]
    routes:
      - { name: flights-route,  paths: [/v3/flights],  strip_path: true, tags: [module-08] }
      - { name: bookings-route, paths: [/v3/bookings], strip_path: true, tags: [module-08] }
      - { name: admin-route,    paths: [/v3/admin],    strip_path: true, tags: [module-08] }
      - { name: popular-route,  paths: [/v3/flights/popular], strip_path: true, methods: [GET], tags: [module-08] }
```
:::

Sync. Wait ~15s. **Smoke test** - should all return 200 (no plugins yet):

```bash
curl -sI $KONNECT_PROXY_URL/v3/flights/get   | head -1
curl -sI $KONNECT_PROXY_URL/v3/bookings/get  | head -1
curl -sI $KONNECT_PROXY_URL/v3/admin/get     | head -1
```

---

## Stage 3 - Auth + Authorization (40 min)

Each tier authenticates differently. **`acl` enforces the route allowlist per tier.**

::: details Stage 3 hint - auth + ACL configuration
**Flights and bookings (partner-accessible) use the JWT plugin OR key-auth.** Multiple auth plugins on one route compose with OR - Kong accepts any of them. Use `anonymous` fallback to allow keyless requests but mark them as the anonymous consumer (then ACL denies).

```yaml
plugins:
  # Auth - JWT first (partner tokens)
  - name: jwt
    route: flights-route
    config:
      key_claim_name: iss
      claims_to_verify: [exp]
      header_names: [Authorization]
      anonymous: <PASTE-FREE-OR-CREATE-ANON-CONSUMER-ID>   # ← gets you the OR pattern
  - name: key-auth
    route: flights-route
    config:
      key_names: [X-API-Key]
      hide_credentials: true
      anonymous: <PASTE-ANONYMOUS-CONSUMER-ID>

  # ACL - only allow these groups on flights
  - name: acl
    route: flights-route
    config:
      allow: [free, partner, internal]
      hide_groups_header: true

  # bookings-route - partner + internal only
  - name: jwt
    route: bookings-route
    config: { key_claim_name: iss, claims_to_verify: [exp] }
  - name: key-auth
    route: bookings-route
    config: { key_names: [X-API-Key], hide_credentials: true }
  - name: acl
    route: bookings-route
    config: { allow: [partner, internal], hide_groups_header: true }

  # admin-route - internal only
  - name: key-auth
    route: admin-route
    config: { key_names: [X-API-Key], hide_credentials: true }
  - name: acl
    route: admin-route
    config: { allow: [internal], hide_groups_header: true }
  - name: ip-restriction
    route: admin-route
    config:
      allow: [<YOUR-IP>/32]      # only your office IP can hit /admin
      status: 403
      message: "Internal-only endpoint"
```

You'll need to create an `anonymous` Consumer first (no credentials, just a username) and paste its ID into the `anonymous:` fields. That's how you allow keyless requests to land *somewhere* - then ACL denies anonymous from the route.
:::

Test each tier hits exactly the right routes:

```bash
# free-user → only flights (200), bookings + admin → 403
curl -s -o /dev/null -w '%{http_code} ' $KONNECT_PROXY_URL/v3/flights/get  -H 'X-API-Key: FREE-KEY-001'
curl -s -o /dev/null -w '%{http_code} ' $KONNECT_PROXY_URL/v3/bookings/get -H 'X-API-Key: FREE-KEY-001'
curl -s -o /dev/null -w '%{http_code}\n' $KONNECT_PROXY_URL/v3/admin/get   -H 'X-API-Key: FREE-KEY-001'
# expected: 200 403 403
```

---

## Stage 4 - Per-tier rate limits (20 min)

Three `rate-limiting` plugin instances, each scoped to a Consumer Group:

::: details Stage 4 hint
```yaml
- { name: rate-limiting, consumer_group: free,     config: { minute: 10,   policy: local, limit_by: consumer } }
- { name: rate-limiting, consumer_group: partner,  config: { minute: 100,  policy: local, limit_by: consumer } }
- { name: rate-limiting, consumer_group: internal, config: { minute: 1000, policy: local, limit_by: consumer } }
```
:::

Verify each tier reports the right limit in `X-RateLimit-Limit-Minute`.

---

## Stage 5 - Edge security & shape (30 min)

Now the cross-cutting stuff: CORS, transformers, cache, correlation.

::: details Stage 5 hint
```yaml
# Global plugins (no route: / service: / consumer: scope means GLOBAL)
- name: cors
  config:
    origins: [https://app.mytravel.com, http://localhost:3000]
    methods: [GET, POST, PUT, DELETE, OPTIONS]
    headers: [Content-Type, X-API-Key, Authorization]
    credentials: true
    max_age: 3600
- name: correlation-id
  config: { header_name: X-Correlation-ID, generator: uuid#counter, echo_downstream: true }

# Route-scoped - rewrite v3 → v2 for the upstream
- name: request-transformer-advanced
  route: flights-route
  config:
    replace:
      uri: "/get"          # demo: httpbin doesn't have /v2 paths; we pretend
    add:
      headers: ["X-API-Version:v3"]
    rename:
      body: ["flightId:id"]

- name: response-transformer-advanced
  service: travel-svc       # apply to all routes of this Service
  config:
    remove:
      json: ["_debug", "internal_id", "headers", "origin"]
    add:
      json: ["_meta.version:v3"]
      headers: ["X-Bootcamp-Module:08"]
    if_status: ["2XX"]

# Cache the hot endpoint
- name: proxy-cache
  route: popular-route
  config:
    response_code: [200]
    request_method: [GET, HEAD]
    content_type: [application/json]
    cache_ttl: 60
    strategy: memory
    cache_control: false
```
:::

---

## Stage 6 - Observability (25 min)

Three global plugins. None of them should be route-scoped - you want visibility into *everything*.

::: details Stage 6 hint
```yaml
# Global plugins
- name: prometheus
  config:
    status_code_metrics: true
    latency_metrics:     true
    bandwidth_metrics:   true
    upstream_health_metrics: true
    per_consumer:        false    # ⚠ never true at this scale

- name: http-log
  config:
    http_endpoint: <PASTE-WEBHOOK-SITE-URL>
    method: POST
    flush_timeout: 2
    queue_size: 100
    content_type: application/json
    custom_fields_by_lua:
      "request.headers.authorization": "return '[REDACTED]'"
      "request.headers.x-api-key":     "return '[REDACTED]'"

- name: opentelemetry
  config:
    endpoint: <PASTE-OTLP-COLLECTOR-URL>
    headers: { "x-honeycomb-team": "<api-key>" }
    resource_attributes: { "service.name": "kong-bootcamp-capstone" }
    sampling_rate: 1.0
    header_type: w3c
```
:::

Once observability is wired up, send 20 requests, then check:
- webhook.site shows ~20 log entries with `[REDACTED]` keys.
- Konnect Analytics (or your Prometheus) shows `kong_http_requests_total` ticking.
- Your OTLP collector (Jaeger / Honeycomb) shows traces.

---

## Stage 7 - The 15-step Acceptance Test (20 min) 🎯

This is the moment of truth. **All 15 should pass.** Each tests a different piece of your work.

```bash
#!/usr/bin/env bash
# Save as: acceptance.sh
# Edit URLs and tokens up top. Then run: bash acceptance.sh

set -u
PROXY=${KONNECT_PROXY_URL?Set KONNECT_PROXY_URL}
FREE_KEY=FREE-KEY-001
INT_KEY=INTERNAL-KEY-001
# Mint a partner JWT at jwt.io with iss=partner-a, secret=partner-a-shared-secret-256-bit-do-not-leak
PARTNER_TOKEN=${PARTNER_TOKEN?Set PARTNER_TOKEN with a freshly-minted JWT}

PASS=0; FAIL=0
check() {
  local name=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then PASS=$((PASS+1)); echo "  ✓ $name (got $actual)"
  else FAIL=$((FAIL+1)); echo "  ✗ $name (expected $expected, got $actual)"; fi
}

# 1. Free user reaches /flights (200)
check "1.  free → /flights"     "200" "$(curl -s -o /dev/null -w '%{http_code}' $PROXY/v3/flights/get -H "X-API-Key: $FREE_KEY")"
# 2. Free user blocked from /bookings (403)
check "2.  free → /bookings"    "403" "$(curl -s -o /dev/null -w '%{http_code}' $PROXY/v3/bookings/get -H "X-API-Key: $FREE_KEY")"
# 3. Free user blocked from /admin (403)
check "3.  free → /admin"       "403" "$(curl -s -o /dev/null -w '%{http_code}' $PROXY/v3/admin/get -H "X-API-Key: $FREE_KEY")"
# 4. Partner (JWT) reaches /flights (200)
check "4.  partner → /flights"  "200" "$(curl -s -o /dev/null -w '%{http_code}' $PROXY/v3/flights/get -H "Authorization: Bearer $PARTNER_TOKEN")"
# 5. Partner (JWT) reaches /bookings (200)
check "5.  partner → /bookings" "200" "$(curl -s -o /dev/null -w '%{http_code}' $PROXY/v3/bookings/get -H "Authorization: Bearer $PARTNER_TOKEN")"
# 6. Internal reaches /admin (200)
check "6.  internal → /admin"   "200" "$(curl -s -o /dev/null -w '%{http_code}' $PROXY/v3/admin/get -H "X-API-Key: $INT_KEY")"
# 7. Internal from wrong IP blocked from /admin
# (can't simulate without proxying - manual check: from another IP it should be 403)
echo "  ~ 7.  internal → /admin from non-office IP: MANUAL CHECK (use a different network)"
# 8. CORS preflight succeeds for app.mytravel.com
ALLOW=$(curl -s -i -X OPTIONS $PROXY/v3/flights/get \
  -H 'Origin: https://app.mytravel.com' \
  -H 'Access-Control-Request-Method: GET' \
  | awk '/^access-control-allow-origin:/{print $2}' | tr -d '\r\n')
check "8.  CORS preflight"      "https://app.mytravel.com" "$ALLOW"
# 9. Rate-limit header reports free=10
LIMIT=$(curl -sI $PROXY/v3/flights/get -H "X-API-Key: $FREE_KEY" | awk -F': ' '/^x-ratelimit-limit-minute/{print $2}' | tr -d '\r\n')
check "9.  free RL limit = 10"  "10"  "$LIMIT"
# 10. Rate-limit header reports internal=1000
LIMIT_INT=$(curl -sI $PROXY/v3/flights/get -H "X-API-Key: $INT_KEY" | awk -F': ' '/^x-ratelimit-limit-minute/{print $2}' | tr -d '\r\n')
check "10. internal RL limit = 1000" "1000" "$LIMIT_INT"
# 11. Correlation-ID header present in response
CORR=$(curl -sI $PROXY/v3/flights/get -H "X-API-Key: $FREE_KEY" | awk '/^x-correlation-id:/{print $2}' | tr -d '\r\n')
[[ -n "$CORR" ]] && check "11. Correlation-ID present" "yes" "yes" || check "11. Correlation-ID present" "yes" "no"
# 12. Response body strips _debug and internal_id
BODY=$(curl -s $PROXY/v3/flights/get -H "X-API-Key: $FREE_KEY")
HAS_DEBUG=$(echo "$BODY" | jq 'has("_debug")')
check "12. _debug stripped"      "false" "$HAS_DEBUG"
# 13. Response body has _meta.version=v3 (flat key with literal dot)
META_VER=$(echo "$BODY" | jq -r '.["_meta.version"] // "absent"')
check "13. _meta.version = v3"   "v3"    "$META_VER"
# 14. Hot endpoint cached (X-Cache-Status: Hit on second request)
curl -s -o /dev/null $PROXY/v3/flights/popular -H "X-API-Key: $INT_KEY" # warm
STATUS=$(curl -sI $PROXY/v3/flights/popular -H "X-API-Key: $INT_KEY" | awk -F': ' '/^x-cache-status/{print $2}' | tr -d '\r\n')
check "14. proxy-cache Hit"      "Hit"   "$STATUS"
# 15. No API key leaks to upstream (httpbin echoes request - verify it's stripped)
HAS_KEY=$(curl -s $PROXY/v3/flights/get -H "X-API-Key: $FREE_KEY" | jq -r '.headers["X-Api-Key"] // "absent"')
check "15. API key hidden from upstream" "absent" "$HAS_KEY"

echo
echo "── Result: $PASS passed, $FAIL failed ──"
exit $FAIL
```

**Don't peek at the answers below until you've tried.** Iterate. Fix one failing step at a time.

---

## Reflection (5 min)

Once you hit 15/15, take five minutes to write down:

1. **Which design decision did you get wrong first?** Plugin scope? Plugin order? Auth scheme?
2. **Which acceptance step taught you the most?** Was there a "oh, *that's* why" moment?
3. **What would you do differently** if a real partner asked you to add a fourth tier next week? (Hint: thinking through this is more valuable than re-doing the lab.)

---

## Cleanup

```bash
echo '_format_version: "3.0"' | deck gateway sync - \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

---

## You completed the bootcamp

If you got 15/15 - congratulations. You can design and operate Kong gateways now.

**What to do next:**
- Specialist bootcamps (AI Gateway, Agentic AI & MCP, Dev Portal, APIOps) for deeper niches.
- Take the verify-script approach in your own team's repo - automated acceptance tests for every PR that touches gateway config.
- The Capstone YAML you just wrote is a reasonable starting point for a real `kong.yaml` in production. Strip the lab tags, add your real upstreams and IdP URLs, and you have something to deploy.

Thanks for working through the bootcamp.

---

*Previous: [Module 07 - Enterprise & Advanced](/module-07-enterprise/) · Home: [Bootcamp index](/)*

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
