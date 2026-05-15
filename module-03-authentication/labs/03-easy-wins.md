# Lab 03-B — CORS, IP Restriction, Correlation ID

> **Goal.** In ~45 minutes you'll add three more Tier-1 plugins back-to-back. Each is a single config block. You'll **enable, test the failure mode each one prevents**, and move on.

Picking up from Lab 03-A. Same `flights-svc` and `flights-route` are in place, no plugins on the route (you dropped `key-auth` at the end of 03-A).

---

## Part 1 — CORS (~15 min)

### What problem it solves

You're building a browser frontend at `https://app.mytravel.com`. The frontend calls your Kong gateway. The browser refuses the request because the gateway didn't say "yes, callers from app.mytravel.com are allowed". That's **CORS** (Cross-Origin Resource Sharing) — a browser-enforced security rule.

Servers opt-in by setting `Access-Control-Allow-*` response headers. The `cors` plugin sets those for you on every response.

### Step 1.1 — See the failure first (3 min)

Pretend you're a browser making a CORS preflight check from `https://app.mytravel.com`:

```bash
curl -s -i -X OPTIONS $KONNECT_PROXY_URL/flights/get \
  -H 'Origin: https://app.mytravel.com' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: X-API-Key' \
  | grep -iE '^(HTTP|access-control)'
```

You'll see `HTTP/2 404` and **no `Access-Control-Allow-*` headers**. A real browser would block the actual request that follows. (You can't reproduce that block from curl because curl ignores CORS.)

### Step 1.2 — Enable the `cors` plugin globally (5 min)

Global plugins live at the top of `kong.yaml`, **not** inside a Service:

```yaml [Append to kong.yaml]
_format_version: '3.0'

plugins:
  - name: cors
    config:
      origins:
        - https://app.mytravel.com
        - http://localhost:3000          # local dev frontend
      methods: [GET, POST, PUT, DELETE, OPTIONS]
      headers: [Content-Type, X-API-Key, Authorization]
      exposed_headers: [X-Kong-Request-Id, X-Correlation-ID]
      credentials: true
      max_age: 3600

consumers:
  # … (your two consumers from Lab 03-A)

services:
  # … (flights-svc from Lab 03-A)
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

Wait ~15s.

### Step 1.3 — Verify (3 min)

```bash
curl -s -i -X OPTIONS $KONNECT_PROXY_URL/flights/get \
  -H 'Origin: https://app.mytravel.com' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: X-API-Key' \
  | grep -iE '^(HTTP|access-control)'
```

Expected (abbreviated):
```
HTTP/2 204
access-control-allow-origin: https://app.mytravel.com
access-control-allow-methods: GET, POST, PUT, DELETE, OPTIONS
access-control-allow-headers: Content-Type, X-API-Key, Authorization
access-control-max-age: 3600
access-control-allow-credentials: true
```

🎯 Browser would now permit the real request.

Try with a disallowed origin — `https://evil.com`:

```bash
curl -s -i -X OPTIONS $KONNECT_PROXY_URL/flights/get \
  -H 'Origin: https://evil.com' \
  -H 'Access-Control-Request-Method: GET' \
  | grep -iE '^(HTTP|access-control-allow-origin)'
```

No `Access-Control-Allow-Origin` is returned → browser would block.

::: warning `origins: ["*"]` is the wrong default
`*` allows any origin. Fine for genuinely public read APIs, **wrong** the moment you need credentials (`credentials: true` + `origins: ["*"]` is invalid per the CORS spec — browsers reject it). Always enumerate origins explicitly.
:::

**✅ Checkpoint.** Allowed origin returns `Access-Control-Allow-Origin`. Disallowed origin doesn't.

---

## Part 2 — IP Restriction (~12 min)

### What problem it solves

You spotted a scraper at `203.0.113.42` hammering `/flights`. You want to block it — or alternatively, restrict access to a known list of office IPs.

### Step 2.1 — Find your current IP (2 min)

We need a known-good IP to test with. Kong sees the IP that hits the gateway:

```bash
curl -s $KONNECT_PROXY_URL/flights/get | jq -r '.origin'
# Example: 203.0.113.42
```

Save it:

```bash
MY_IP=$(curl -s $KONNECT_PROXY_URL/flights/get | jq -r '.origin' | cut -d',' -f1)
echo "My IP as Kong sees it: $MY_IP"
```

### Step 2.2 — Attach `ip-restriction` to the Route, allow only your IP (3 min)

```yaml [Append plugin to flights-route]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        plugins:
          - name: ip-restriction
            config:
              allow:
                - <paste-your-IP-here>     # only this IP can reach the route
              status: 403
              message: "Your IP is not allowed."
```

Sync. Wait 15s. Re-run:

```bash
curl -s -o /dev/null -w '%{http_code}\n' $KONNECT_PROXY_URL/flights/get
# 200
```

Still works — your IP is on the list.

### Step 2.3 — Flip to deny and lock yourself out (5 min) 🧪

Now flip allow → deny:

```yaml
- name: ip-restriction
  config:
    deny:
      - <your-IP>
    status: 403
    message: "Your IP is not allowed."
```

Sync. Wait 15s. Re-run:

```bash
curl -i $KONNECT_PROXY_URL/flights/get | head -3
# HTTP/2 403
# {"message":"Your IP is not allowed."}
```

🚫 You just locked yourself out. (Recoverable — you can still call the Konnect Admin API to undo it.)

::: tip Allow vs deny — which to use
- **`allow:`** = "ONLY these can in." Safer when you know exactly who's calling (B2B APIs, internal services). Risky if you forget your own IP.
- **`deny:`** = "Everyone except these." Better for blocking known bad actors. Risk: you have to maintain the list as attackers change IPs.

Real production: combine `ip-restriction` (broad strokes) with `rate-limiting` (per-Consumer caps, Module 05) and `bot-detection`.
:::

### Step 2.4 — Unlock yourself (2 min)

Remove the plugin:

```yaml [Drop the ip-restriction plugin]
- name: flights-route
  paths: [/flights]
  strip_path: true
  # plugins: removed
```

Sync. Wait 15s. Verify:

```bash
curl -s -o /dev/null -w '%{http_code}\n' $KONNECT_PROXY_URL/flights/get
# 200
```

**✅ Checkpoint.** Allow → 200. Deny → 403 with your custom message. Removing the plugin restores access.

---

## Part 3 — Correlation ID (~12 min)

### What problem it solves

When a request fails halfway through a microservice chain, you need a single ID that joins:
- Kong's access log,
- your upstream's log,
- your downstream service's log.

`correlation-id` generates that ID at the gateway and forwards it to every upstream as a request header.

### Step 3.1 — Enable globally (3 min)

```yaml [Update the plugins block at the top of kong.yaml]
plugins:
  - name: cors
    config:
      # … (keep what you have)
  - name: correlation-id
    config:
      header_name: X-Correlation-ID
      generator: uuid#counter        # UUID + monotonic counter — fast & unique
      echo_downstream: true          # also include the ID in the RESPONSE to the client
```

Sync. Wait 15s.

### Step 3.2 — Verify upstream sees it (3 min)

```bash
curl -s $KONNECT_PROXY_URL/flights/get \
  | jq -r '.headers["X-Correlation-Id"] // .headers["X-Correlation-ID"]'
# Example: 1bdfdb3e9b15a99c0001#1
```

🎯 Kong generated an ID and forwarded it to httpbin. httpbin echoed back the headers it received — so we can see Kong's correlation ID landed.

```bash
# Check the response header too (echo_downstream: true)
curl -s -i $KONNECT_PROXY_URL/flights/get \
  | grep -i 'x-correlation-id'
```

Expected:
```
x-correlation-id: <same id as above>
```

### Step 3.3 — Honour client-supplied IDs (3 min)

Distributed tracing systems often send their own correlation ID. Should Kong overwrite it or pass it through?

Try it: send a request with your own correlation ID:

```bash
curl -s $KONNECT_PROXY_URL/flights/get \
  -H 'X-Correlation-ID: my-custom-trace-id-12345' \
  | jq -r '.headers["X-Correlation-Id"]'
```

Expected: `my-custom-trace-id-12345`

By default, `correlation-id` **preserves** an existing header. To force overwrite (rare — only when you don't trust the client), set:

```yaml
- name: correlation-id
  config:
    header_name: X-Correlation-ID
    generator: uuid#counter
    echo_downstream: true
    # (default) preserves an existing header value. Add this to force overwrite:
    # generator_override: true   # ← in newer Kong versions; check the plugin schema
```

::: tip Generators
- `uuid` — full UUID v4 per request (most random, fine in most cases).
- `uuid#counter` — UUID *prefix* + monotonic counter. Slightly faster, useful for log sorting.
- `tracker` — sequential integer per worker. Avoid in production — collisions across DPs.
:::

**✅ Checkpoint.** Without a client-supplied header, Kong generates an ID. With one, Kong preserves it. The same ID appears in both the request to upstream and the response to client.

### Step 3.4 — Why this matters before you have logging (3 min — read)

You don't have a logging plugin yet (that's M07). So what use is a correlation ID?

Three real uses *today*:
1. **Konnect Analytics** — every request entry shows the correlation ID. You can filter by it.
2. **Customer support** — when someone reports "my booking failed", they can give you the correlation ID from the response header and you can pull the exact trace.
3. **Your upstream's logs** — if your upstream logs the request header `X-Correlation-ID`, you've already joined Kong and upstream logs on one ID without any additional infrastructure.

---

## Recap

You added three more plugins, each solving a real, immediate problem:

```
                     CORS — let app.mytravel.com call us
                     IP-Restriction — block scrapers / restrict to office IPs
                     Correlation-ID — one ID per request, end to end

Client ─▶ Kong Gateway ─▶ Service ─▶ Upstream
              │
              ├─ correlation-id (global)  ← injects X-Correlation-ID
              ├─ cors (global)            ← sets Access-Control-* on responses
              └─ ip-restriction (route)   ← allow/deny by client IP
```

**Plugin scope reminder:**
- `cors` and `correlation-id` are **global** — apply to every request through the gateway.
- `ip-restriction` is **route-scoped** — only applies to `flights-route`.
- More-specific scopes override more-general ones (same precedence as M02 routes).

---

## Exit ticket — answers

1. **How does the upstream know which Consumer made the request?** After `key-auth` succeeds, Kong injects `X-Consumer-Username`, `X-Consumer-Id`, `X-Consumer-Custom-Id`, and `X-Credential-Identifier`. The upstream reads these — it doesn't validate the API key itself.
2. **`cors` global vs route-scoped.** Route-scoped wins. Plugin scope precedence: **Consumer > Route > Service > Global**. When you have both, only the route-scoped instance runs for that route.
3. **`correlation-id` matters before logging because** (a) Konnect Analytics surfaces it, (b) clients can include it in support tickets to give you a unique trace point, (c) any upstream already logging request headers gets free log-correlation.

---

## Cleanup — full M03 wipe

::: code-group

```bash [decK — empty the CP]
echo '_format_version: "3.0"' | deck gateway sync - \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

```bash [Admin API — delete by name]
for ENT in routes/flights-route services/flights-svc \
           consumers/web-app consumers/mobile-app consumers/anonymous \
           plugins; do
  if [ "$ENT" = "plugins" ]; then
    # delete all plugins tagged module-03
    curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
      "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/plugins?tags=module-03" \
      | jq -r '.data[]?.id' \
      | xargs -I {} curl -s -X DELETE -H "Authorization: Bearer $KONNECT_TOKEN" \
          "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/plugins/{}"
  else
    curl -s -X DELETE -H "Authorization: Bearer $KONNECT_TOKEN" \
      "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/$ENT" \
      && echo "deleted $ENT"
  fi
done
```

:::

::: tip Why also delete the Consumers?
M04 (Identity & ACL) will re-create them with **consumer groups** attached. Starting fresh avoids accidental state carry-over.
:::

---

**Next:** Module 04 — Identity & ACL (coming soon). You'll group your Consumers into tiers (free/paid/internal), enforce access with `acl`, and meet two more auth plugins: `jwt` and `hmac-auth`.
