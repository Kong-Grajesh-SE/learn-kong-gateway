# Lab 06-A - HTTP Logging

> **Goal.** In ~25 minutes you'll attach `http-log` to `flights-route`, ship every request log line to a free public webhook receiver, and inspect the structure of a Kong log entry - including the latency breakdown that makes "Kong vs upstream" obvious.

::: tip Picking up from M03+
Start from the M03 baseline (Service + Route + Consumers + key-auth). Optional plugins from M04/M05 don't matter for observability.
:::

---

## Step 1 - Get a free log receiver (3 min)

We need an HTTP endpoint Kong can POST to. Use [**webhook.site**](https://webhook.site) - it gives you a one-time URL that captures every request.

1. Open [webhook.site](https://webhook.site) in your browser.
2. The page auto-creates a URL like `https://webhook.site/abc-123-xyz`. Copy it.

```bash
export LOG_URL=https://webhook.site/<your-unique-id>
```

::: info Production alternatives
For real production: Datadog, Splunk, Logstash, Loki, or your own HTTPS endpoint. Anything that accepts POSTed JSON works. `webhook.site` is just for this lab.
:::

---

## Step 2 - Rebuild the baseline + attach `http-log` (5 min)

```yaml [kong.yaml]
_format_version: '3.0'

consumers:
  - username: web-app
    custom_id: web-001
    keyauth_credentials:
      - key: web-app-secret-key-001
    tags: [module-06]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-06]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        plugins:
          - name: key-auth
            config: { key_names: [X-API-Key], hide_credentials: true }
          - name: http-log
            config:
              http_endpoint: <PASTE-YOUR-LOG-URL>
              method: POST
              timeout: 10000              # ms
              keepalive: 60000            # ms - reuse TCP
              flush_timeout: 2            # seconds - batch logs every 2s
              queue_size: 100             # buffer up to 100 entries before forced flush
              content_type: application/json
```

Replace `<PASTE-YOUR-LOG-URL>` and sync:

```bash
sed -i.bak "s|<PASTE-YOUR-LOG-URL>|$LOG_URL|" kong.yaml
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

Wait 15s.

---

## Step 3 - Make some traffic (3 min)

```bash
for i in {1..5}; do
  curl -s -o /dev/null \
    -H 'X-API-Key: web-app-secret-key-001' \
    $KONNECT_PROXY_URL/flights/get
done

# And a couple of failures
curl -s -o /dev/null $KONNECT_PROXY_URL/flights/status/500   # 401 - no key
curl -s -o /dev/null $KONNECT_PROXY_URL/flights/status/404 \
  -H 'X-API-Key: web-app-secret-key-001'                     # 404 from upstream
```

Now refresh webhook.site. You should see ~7 POSTs land within a few seconds (the flush window is 2s).

**✅ Checkpoint.** Webhook.site shows POSTs from Kong with JSON bodies.

---

## Step 4 - Anatomy of a Kong log entry (5 min - read)

Click any entry on webhook.site. The body is a JSON object Kong fills in:

```json
{
  "request": {
    "method": "GET",
    "uri": "/flights/get",
    "url": "https://<gateway>/flights/get",
    "size": 0,
    "querystring": {},
    "headers": {
      "host": "<gateway>",
      "user-agent": "curl/7.84.0",
      "x-api-key": "REDACTED"
    },
    "tls": { ... }
  },
  "response": {
    "status": 200,
    "size": 1234,
    "headers": { ... }
  },
  "latencies": {
    "request": 218,        ← TOTAL time, ms (client perspective)
    "kong":    4,          ← time spent inside Kong (plugins + routing)
    "proxy":  214          ← time waiting for upstream
  },
  "route":    { "name": "flights-route", "id": "<uuid>" },
  "service":  { "name": "flights-svc",   "id": "<uuid>" },
  "consumer": { "username": "web-app",   "id": "<uuid>" },
  "client_ip": "203.0.113.42",
  "started_at": 1748700000123
}
```

::: info The three latency numbers
- **`latencies.request`** - total time from request start to response end.
- **`latencies.kong`** - time spent inside Kong (plugins, routing, balancing).
- **`latencies.proxy`** - time spent waiting for the upstream.

`request ≈ kong + proxy`. If `kong` is high, it's *your* config or plugins. If `proxy` is high, it's the upstream. **This single distinction saves hours of misattributed debugging.**
:::

**✅ Checkpoint.** You can identify which log entries are 200s vs 401s vs 404s, and you can read the latency split for any one.

---

## Step 5 - Mask sensitive headers/fields (5 min) 🧪

Right now `request.headers.x-api-key` shows up in the log. Even if it's "REDACTED" for `key-auth`'s hide_credentials, **other** sensitive headers won't be. Let's strip them explicitly.

```yaml [Update http-log plugin]
- name: http-log
  config:
    http_endpoint: <your-url>
    method: POST
    timeout: 10000
    keepalive: 60000
    flush_timeout: 2
    queue_size: 100
    content_type: application/json
    # ── Strip sensitive headers before logging ──
    custom_fields_by_lua:
      # Use Lua to redact fields. Runs once per log entry.
      "request.headers.authorization": "return '[REDACTED]'"
      "request.headers.cookie":        "return '[REDACTED]'"
      "request.headers.x-api-key":     "return '[REDACTED]'"
```

::: warning Always redact at the log layer
Even when `key-auth` hides credentials from the upstream, **logging plugins read the original request** - so the key still ends up in the log unless you redact. Same for cookies, Bearer tokens, internal-only headers.

If you don't trust yourself to enumerate every sensitive header, log to an **allowlist** instead: drop everything by default, log only the headers you explicitly want.
:::

Sync. Send a few more requests. New log entries should show `"x-api-key": "[REDACTED]"`.

---

## Step 6 - What if the receiver is down? (4 min - read)

Kong's `http-log` plugin queues log entries in memory before flushing. If the receiver is unreachable:

| Setting | Behaviour |
|---|---|
| `queue_size` | Max entries in memory before forced flush. Default 1. Increase for high traffic. |
| `flush_timeout` | Seconds between flushes (regardless of queue size). |
| `retry_count` | How many times Kong retries a failed POST. After exhausting retries, the batch is **dropped**. |
| `keepalive` | Reuse a TCP connection across batches for efficiency. |

**Logs are best-effort.** Critical events (audit logs, compliance) should also be written to an upstream you control - not just streamed to a single endpoint that might be down.

For production: use a queue (Kafka, SQS) between Kong and your log store. Kong → queue is local-network-fast. Queue → store handles backpressure.

---

## Step 7 - Stop logging when you're done (1 min)

http-log POSTs are real traffic - webhook.site has rate limits. Remove the plugin before the next lab:

```yaml
- name: flights-route
  paths: [/flights]
  strip_path: true
  plugins:
    - name: key-auth
      config: { … }
    # http-log removed
```

Sync.

---

## Recap

You now know:
- `http-log` POSTs structured JSON for **every request** to any HTTPS endpoint.
- The `latencies` block in a Kong log separates **gateway time** from **upstream time** - your first triage question becomes "Kong or backend?"
- Sensitive headers must be redacted at the **log layer**, not just at the upstream layer.
- Log delivery is best-effort by default. Production = log → queue → store.

---

## Cleanup

**Don't clean up yet.** Lab 06-B and 06-C re-use the Service + Route. Full M06 cleanup at the end of 06-C.

---

**Next:** [Lab 06-B - Prometheus & Grafana →](./06-prometheus)
