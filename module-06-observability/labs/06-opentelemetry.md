# Lab 06-C - OpenTelemetry

> **Goal.** In ~35 minutes you'll attach the `opentelemetry` plugin to your gateway, send traces to an OTLP collector (Jaeger), and observe how Kong's spans connect to your upstream's spans - when you have an upstream that emits them.

OpenTelemetry (OTel) is the open standard for distributed traces. Kong's plugin emits **spans** (work units with start/end timestamps) and propagates **trace context** via the `traceparent` header so downstream services can continue the trace.

---

## Step 1 - Get an OTLP collector (5 min)

You need somewhere to send traces. Three options:

### Option A - Local Jaeger (hybrid Docker setup)

A ready-to-run stack lives in [`module-06-observability/jaeger/`](../jaeger/). It runs an **OpenTelemetry Collector** in front of **Jaeger all-in-one** so the Collector handles batching and back-pressure, and you can fan out to a cloud backend later without touching Kong's plugin config.

```bash
cd module-06-observability/jaeger
docker compose up -d
open http://localhost:16686     # Jaeger UI
```

Set `OTLP_ENDPOINT=http://host.docker.internal:4318/v1/traces` - the DP container reaches ports published on your host via this DNS name.

See [jaeger/README.md](../jaeger/README.md) for ports, verification commands, and how to add a cloud exporter.

### Option B - Free cloud OTLP collector (serverless setup)

Sign up at one of these and copy your OTLP endpoint + auth header:
- [Honeycomb](https://www.honeycomb.io) (free tier)
- [Grafana Cloud Traces](https://grafana.com/products/cloud) (free tier, Tempo backend)
- [Datadog](https://www.datadoghq.com) (trial)

Set:
```bash
export OTLP_ENDPOINT=https://api.honeycomb.io/v1/traces
export OTLP_HEADER_KEY='x-honeycomb-team:<your-api-key>'
```

### Option C - Skip the visualization, focus on emission

If you just want to verify Kong emits OTLP, point at a webhook receiver and inspect the binary payload. Less educational but the simplest.

---

## Step 2 - Attach the `opentelemetry` plugin (5 min)

```yaml [Append to flights-route plugins, or set globally]
plugins:
  # ... your existing ones
  - name: opentelemetry
    config:
      endpoint: <PASTE-YOUR-OTLP-ENDPOINT>
      resource_attributes:
        service.name: "kong-bootcamp-flights"
        deployment.environment: "lab"
      headers:
        x-honeycomb-team: "<api-key-if-needed>"        # or omit for local Jaeger
      sampling_rate: 1.0                              # 100% for the lab
      header_type: w3c                                # standard traceparent header
      batch_span_count: 200
      batch_flush_delay: 3                            # seconds
      connect_timeout_ms: 1000
      send_timeout_ms:    5000
```

Replace placeholders. Sync. Wait 15s.

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

::: tip Sampling rate
`sampling_rate: 1.0` = 100% - fine for the lab. In production, **head-based sampling at 1-10%** is typical for high-volume routes. Some traces (errors, slow requests) should always be kept - set up tail-based sampling at the collector for that.
:::

---

## Step 3 - Generate traffic and inspect a trace (5 min) 🎯

```bash
for i in {1..10}; do
  curl -s -o /dev/null \
    -H 'X-API-Key: web-app-secret-key-001' \
    "$KONNECT_PROXY_URL/flights/anything"
done
```

Open your collector UI (Jaeger at `http://localhost:16686` or your cloud UI).

Search for service: `kong-bootcamp-flights`. Click any trace. You'll see something like:

```
─── kong: GET /flights/anything   total=218ms
        ├── kong: access phase     ms (auth, rate-limit, transformers)
        ├── kong: balancer phase   ms (target selection)
        ├── kong: proxy → upstream     ms ← spans the upstream call
        └── kong: header_filter / body_filter  ms (response transformers)
```

🎯 Every Kong phase is a span. You can see exactly which plugin step took how long.

**✅ Checkpoint.** You see traces in your collector. Each trace has Kong-phase spans with sensible durations.

---

## Step 4 - Propagate to the upstream (5 min - read, then test)

Look at what Kong forwarded to httpbin:

```bash
curl -s "$KONNECT_PROXY_URL/flights/anything" \
  -H 'X-API-Key: web-app-secret-key-001' \
  | jq '.headers | {"Traceparent", "Tracestate"}'
```

Expected:
```json
{
  "Traceparent": "00-<trace-id-32-hex>-<span-id-16-hex>-01",
  "Tracestate": ""
}
```

🎯 `traceparent` is the **W3C trace context standard**. Your upstream - if it's instrumented with OTel - would:
1. Read `traceparent` from the incoming request.
2. Create a **child span** with that trace ID.
3. Emit its own span(s) to the same collector.

The result is a **single trace** spanning Kong → upstream → downstream services. Visible as one waterfall.

::: info Kong can't fix unobservable upstreams
If your upstream doesn't speak OTel, the trace stops at Kong's "proxy" span. You'll still see how long the upstream took (the duration of that span), but not what it did internally. **The full distributed-tracing value comes when every service emits spans.**
:::

---

## Step 5 - Honour client trace context (5 min) 🧪

A real client (or another upstream service) sends you a request with its own `traceparent`. Kong should **continue** that trace, not start a new one.

Try it:

```bash
# Make up a trace ID to simulate an incoming traced request
INCOMING_TRACE=00-0123456789abcdef0123456789abcdef-0123456789abcdef-01

curl -s "$KONNECT_PROXY_URL/flights/anything" \
  -H 'X-API-Key: web-app-secret-key-001' \
  -H "traceparent: $INCOMING_TRACE" \
  | jq '.headers["Traceparent"]'
```

Expected: a `traceparent` with the **same trace-id** as your input (the first hex blob), but a **different span-id** (Kong created a child span).

In your collector, search for trace ID `0123456789abcdef0123456789abcdef` - you'll find the trace, and Kong's spans will appear as a child of the (imaginary) caller's parent.

🎯 This is how you trace requests **across organizational boundaries** - your customer's traceparent flows into your gateway, and from there into your own services.

---

## Step 6 - What about traces and rate limiting / cache? (3 min - read)

Plugin spans appear in the trace in order. If your request hits the cache plugin and gets a cached response:

```
─── kong: GET /flights/anything  total=11ms
        ├── kong: access phase   3ms
        ├── kong: proxy-cache    1ms      ← HIT, upstream never called
        ├── (no upstream span)
        └── kong: header_filter  1ms
```

If the request gets rate-limited (429):

```
─── kong: GET /flights/anything  total=6ms
        ├── kong: access phase   5ms      ← rate-limiting decided to block here
        └── (no upstream span)
```

**You can see the decision in the waterfall.** Tracing makes plugin behaviour visible at the request level - invaluable for "why did this one request behave differently?" debugging.

---

## Step 7 - Sampling and cost (3 min - read)

OTLP traffic costs money in cloud collectors. Strategies:

| Sampling type | When |
|---|---|
| **Head-based** at Kong (e.g. `sampling_rate: 0.05` = 5%) | High-volume routes. Cheap. Loses error / slow traces unless you also do… |
| **Tail-based** at the collector | Keep all traces with errors or `>p99 latency`, drop the rest. More expensive collector setup. |
| **Probabilistic + always-on for errors** | Honeycomb / Grafana support this via collector rules - best of both worlds. |

For the bootcamp, `1.0` is fine. For production, start at `0.1` and tune.

---

## Recap

- `opentelemetry` plugin emits **spans for every Kong phase** of every request.
- `traceparent` header propagation lets your upstream **continue** the trace - required for end-to-end distributed tracing.
- Traces capture **per-request behaviour** in a way metrics and logs can't (you see the waterfall, not just totals).
- Sampling rate matters at production volume; default 1.0 here is for visibility.

---

## Exit ticket - answers

1. **User reports request `id=abc-123` failed.** Start with **logs** - log entries are searchable by `X-Kong-Request-Id` and contain the full request context including consumer, status, latencies. Logs → trace ID (if logged) → distributed trace. Don't start with metrics - they're aggregates; one user's failure is invisible there.
2. **Rate-limit per Consumer = fine. Prometheus per Consumer = footgun.** Rate-limiting uses Consumer ID as a counter key in Redis/local memory - bounded. Prometheus per-Consumer creates a unique time series **per Consumer**, multiplied by every other label combination - unbounded. Use logs/traces for per-Consumer detail; metrics for aggregates.
3. **Upstream 200ms total, Kong says 4ms - where did 196ms go?** `kong_upstream_latency_ms`. The 4ms is `kong_kong_latency_ms` (Kong's own plugin chain). The full request latency = kong + upstream. When the SLO alarm fires, look at upstream latency *first* - that's usually where the time is.

---

## Cleanup - full M06 wipe

```bash
echo '_format_version: "3.0"' | deck gateway sync - \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

Also bring down your local Jaeger if you started one:

```bash
docker compose -f docker-compose.jaeger.yml down
```

---

**Next:** [Module 07 - Enterprise & Advanced →](/module-07-enterprise/) - the hardest plugins: JWT, HMAC, ACL with Consumer Groups, OIDC Auth Code Flow, Upstream OAuth (M2M), OPA policy-as-code, Datakit orchestration, RBAC for Kong Manager.

