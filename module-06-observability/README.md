# Module 06 - Observability

> **The scenario.** A user complains: "I just booked a flight and it failed silently - no error, no confirmation." You have nothing to investigate with. Your gateway has no logs, no metrics, no traces. You're guessing.
>
> In the next ~90 minutes you'll wire up the **three pillars of observability** - **logs**, **metrics**, **traces** - one plugin per pillar. After this module, the next "silent failure" report comes with a request ID you can trace end-to-end.

## What you'll have at the end

Three signal streams flowing out of your gateway:

```
                                ┌── http-log     → external HTTP endpoint (logs)
Kong Gateway ──── plugins ──────┼── prometheus   → /metrics endpoint (pulled by Prometheus)
                                └── opentelemetry → OTLP collector (Jaeger/Tempo/Honeycomb)
```

You'll be able to:
- See **every request** in your log receiver, with status, latency, and `X-Kong-Request-Id`.
- Query metrics like `rate(kong_http_requests_total{status=~"5.."}[1m])` in Prometheus.
- Open a trace in Jaeger and see exactly how long Kong vs upstream took.

## Who this module is for

You finished M01–M03 (M04 and M05 are helpful but not required for observability to work). Plugins from M03 are still useful - `correlation-id` headers will flow into both logs and traces.

## Three concepts you need today

| Concept | What it is | Why it matters |
|---|---|---|
| **The three pillars** | **Logs** = "what happened" (event records). **Metrics** = "how many, how fast" (aggregated numbers). **Traces** = "where the time went" (per-request waterfall). | Each pillar answers a different question. One isn't enough. |
| **Push vs pull** | Logs and traces **push** to a destination on each request. Metrics are **pulled** by a scraper (Prometheus). | Push = good for cloud egress / fan-out. Pull = better for high-volume rates because the scraper controls frequency. |
| **Cardinality** | The number of distinct label combinations a metric has. High-cardinality labels (per-Consumer, per-request-id) explode storage. | Never put `consumer_id` or `request_id` in Prometheus labels - use traces/logs for that. |

Plugin chain shape:

```
Client → Kong ──┬─ http-log:        POST every request log line to https://logs.example.com/in
                ├─ prometheus:      expose /metrics on the DP (for the scraper)
                └─ opentelemetry:   POST traces to https://otlp.example.com:4318
                     │
                     └─ Upstream
```

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 06-A | [HTTP Logging](./labs/06-http-logging) | ~25 min | Stream every request log line to a webhook receiver. Inspect what's in a Kong log entry. Mask sensitive fields. |
| 06-B | [Prometheus & Grafana](./labs/06-prometheus) | ~30 min | Enable the prometheus plugin, scrape `/metrics`, build the four golden-signal queries (RED metrics) |
| 06-C | [OpenTelemetry](./labs/06-opentelemetry) | ~35 min | Send traces via OTLP, view them in Jaeger, propagate `traceparent` to upstream |

## Exit ticket

1. A user reports their request `id=abc-123` failed. You have all three signals enabled. Which signal do you start with, and why?
2. You're told to "rate-limit per Consumer." The dev team also wants "Prometheus dashboards by Consumer." Why is one fine and the other a foot-gun?
3. Your upstream takes 200ms to respond on a slow request. Kong's `kong_kong_latency_ms` says it spent 4ms. Where did the other 196ms go, and which metric captures it?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| `http-log` POSTs aren't reaching your receiver | TLS issue - Kong sends real HTTPS requests. Check the cert. Or your receiver is rejecting bulk JSON arrays - switch `flush_timeout` / `queue_size`. |
| Prometheus `/metrics` returns 404 | On Konnect serverless the `/metrics` endpoint isn't exposed externally - metrics flow into Konnect Analytics instead. Hybrid DP exposes `/metrics` on port 8100 by default. |
| OpenTelemetry collector receives nothing | Header propagation off - make sure `header_type: w3c` matches what your collector expects. Also: confirm your collector accepts OTLP/HTTP (port 4318), not just OTLP/gRPC (4317). |
| Metrics labels keep growing | Default `kong_http_requests_total` labels are fine (service, route, code). If you added Consumer labels you've created a cardinality bomb - disable. |
| Traces in Jaeger show no upstream span | The plugin only traces Kong's own work unless your upstream **continues** the trace by reading `traceparent` and emitting child spans. Not Kong's job; upstream needs OpenTelemetry too. |

## What's next

**[Module 07 - Enterprise & Advanced](/module-07-enterprise/)** brings the harder plugins: JWT, HMAC, ACL with Consumer Groups, OIDC Auth Code Flow, Upstream OAuth (M2M), OPA policy-as-code, Datakit orchestration, RBAC. The signals you wire up today will be invaluable when something breaks in M07.

---

*Previous: [Module 05 - Transformations](/module-05-transformations/) · Next: [Module 07 - Enterprise & Advanced →](/module-07-enterprise/)*
