# Lab 06-B - Prometheus & Grafana

> **Goal.** In ~30 minutes you'll enable the `prometheus` plugin, learn what each metric means, and build the four **RED metrics** queries (Rate, Errors, Duration) you'll use forever after.

::: warning Serverless caveat
Konnect **serverless** gateways don't expose a public `/metrics` endpoint - instead the same metrics flow into Konnect Analytics. You can still complete this lab on serverless conceptually, but the scrape step requires either:
- A **hybrid** Docker DP (which exposes `/metrics` on port 8100), or
- The Konnect Prometheus federation endpoint (Enterprise feature, see Konnect → Settings → Monitoring).

The plugin config and PromQL queries are identical either way.
:::

---

## Step 1 - Enable the `prometheus` plugin (3 min)

Apply it **globally** so every Service contributes metrics:

```yaml [Top of kong.yaml]
plugins:
  - name: prometheus
    config:
      status_code_metrics: true
      latency_metrics:     true
      bandwidth_metrics:   true
      upstream_health_metrics: true
      per_consumer:        false        # ⚠ leave OFF to avoid cardinality bombs
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

Wait 15s. Konnect → **Plugins** → `prometheus` should show as a **global** plugin.

::: warning Why `per_consumer: false`?
Setting `per_consumer: true` adds a `consumer` label to every metric. If you have 1,000 Consumers × 5 routes × 4 status codes = 20,000 unique label combinations **per metric**. Multiply by 8 metrics = 160K time series. Prometheus storage costs explode. Reserve per-Consumer detail for **logs** and **traces** - not metrics.
:::

---

## Step 2 - Scrape `/metrics` (5 min)

### On a hybrid Docker DP

```bash
# Inside the DP container
docker exec kong-dp curl -s http://localhost:8100/metrics | head -40
```

### On Konnect serverless

The proxy doesn't expose `/metrics` publicly. Use **Konnect Analytics** (UI) or set up Konnect's Prometheus federation in `Settings → Monitoring`. Both surface the same metrics - they're just delivered to you rather than scraped by you.

Either way, you'll see hundreds of lines like:

```
# HELP kong_http_requests_total HTTP status codes per service/route
# TYPE kong_http_requests_total counter
kong_http_requests_total{service="flights-svc",route="flights-route",code="200"} 47
kong_http_requests_total{service="flights-svc",route="flights-route",code="401"} 12

# HELP kong_kong_latency_ms Latency added by Kong (plugins + routing), per service/route
# TYPE kong_kong_latency_ms histogram
kong_kong_latency_ms_bucket{service="flights-svc",route="flights-route",le="1"} 3
kong_kong_latency_ms_bucket{service="flights-svc",route="flights-route",le="5"} 18
...
kong_kong_latency_ms_sum{service="flights-svc",route="flights-route"} 187
kong_kong_latency_ms_count{service="flights-svc",route="flights-route"} 59
```

---

## Step 3 - The metrics that matter (5 min - read)

Out of dozens of metrics Kong exposes, you'll mostly use these:

| Metric | Type | What it tells you |
|---|---|---|
| `kong_http_requests_total` | Counter | Number of requests, by service/route/status |
| `kong_request_latency_ms` | Histogram | Total request latency (client perspective) |
| `kong_kong_latency_ms` | Histogram | Time Kong itself spent (plugin chain, routing) |
| `kong_upstream_latency_ms` | Histogram | Time spent waiting for the upstream |
| `kong_bandwidth_bytes` | Counter | Bytes in/out by direction & service |
| `kong_datastore_reachable` | Gauge | Is the Kong DB/CP reachable? `1` = yes, `0` = no |
| `kong_upstream_target_health` | Gauge | Health-check status of each Upstream target |

::: tip Three latencies, again
- `kong_request_latency_ms` - what the **client** saw.
- `kong_kong_latency_ms` - what **Kong** added (plugins, balancer).
- `kong_upstream_latency_ms` - what the **upstream** took.

`request ≈ kong + upstream`. When the SLO alarm fires, your first PromQL question is: "Is `upstream_latency` spiking, or `kong_latency`?"
:::

---

## Step 4 - Build the four RED queries (10 min) 🎯

RED = **R**ate / **E**rrors / **D**uration. Every API needs these four queries set up before anything else.

Paste each into Konnect Analytics' **PromQL** input (or a local Grafana panel), one at a time:

### Q1: Request rate per second, per route

```js
sum by (service, route) (
  rate(kong_http_requests_total[1m])
)
```

### Q2: Error rate (% of requests returning 4xx or 5xx)

```js
100
* sum by (service, route) (rate(kong_http_requests_total{code=~"4..|5.."}[1m]))
/ sum by (service, route) (rate(kong_http_requests_total[1m]))
```

### Q3: p95 upstream latency

```js
histogram_quantile(0.95,
  sum by (service, route, le) (rate(kong_upstream_latency_ms_bucket[5m]))
)
```

### Q4: p95 Kong latency (your plugin chain's cost)

```js
histogram_quantile(0.95,
  sum by (service, route, le) (rate(kong_kong_latency_ms_bucket[5m]))
)
```

::: tip From queries to alerts
- **Page** when Q2 > 1% for >5 minutes (real users seeing errors).
- **Warn** when Q3 > your SLO (upstream getting slow).
- **Investigate** when Q4 starts climbing (plugin chain getting expensive - usually a new plugin).
- **Ignore** Q1 unless it crosses your capacity threshold.
:::

---

## Step 5 - Generate some metric movement (3 min)

Pump traffic so the dashboards have something to show:

```bash
for i in {1..50}; do
  curl -s -o /dev/null \
    -H 'X-API-Key: web-app-secret-key-001' \
    "$KONNECT_PROXY_URL/flights/anything"
done

# Mix in some 4xx and 5xx
for code in 401 403 404 500 502 503; do
  curl -s -o /dev/null \
    -H 'X-API-Key: web-app-secret-key-001' \
    "$KONNECT_PROXY_URL/flights/status/$code"
done
```

Re-run your queries. You should see real rate, real errors, real latency percentiles.

---

## Step 6 - What to instrument vs what to NOT (4 min - read)

The temptation when you have metrics is to track everything. Resist.

| Do | Don't |
|---|---|
| ✅ Track rate, errors, duration per **service** and **route** | ❌ Track per **Consumer** (high cardinality, use logs for that) |
| ✅ Use **histograms** for latency, **counters** for counts | ❌ Use a gauge that you set to "the last latency" (useless after 1s) |
| ✅ Aggregate before storing - store p50, p95, p99 | ❌ Store raw event durations as labels |
| ✅ Set **SLO-based alerts** on Q2/Q3 | ❌ Alert on raw thresholds (`> 200ms`) - alert on **error budget burn rate** |
| ✅ Keep label cardinality < ~1000 per metric | ❌ Add a `user_id` or `request_id` label "just in case" |

::: warning The cardinality bomb story
A team added a `user_id` label to a counter "for debugging." With 100K active users × 6 routes × 8 status codes ≈ 4.8M unique time series. Prometheus OOMed at 3 AM. Recovery took 14 hours and cost the on-call engineer their week. Use **logs and traces** for per-user analysis; metrics are for *aggregate* behaviour.
:::

---

## Recap

- `prometheus` plugin enabled globally, default labels keep cardinality bounded.
- The four RED queries answer most "is it broken?" questions.
- The three latencies (`request`, `kong`, `upstream`) separate gateway problems from upstream problems.
- High-cardinality labels are the enemy. Per-Consumer detail belongs in logs/traces.

---

## Cleanup

**Don't clean up yet.** Lab 06-C reuses the Service + Route. Cleanup at the end of 06-C.

---

**Next:** [Lab 06-C - OpenTelemetry →](./06-opentelemetry)
