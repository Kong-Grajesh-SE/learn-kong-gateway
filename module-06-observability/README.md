# Module 06 - Observability

> You can't manage what you can't measure. Kong's observability plugins give you real-time visibility into API traffic - logs, metrics, and distributed traces.

## Overview

| | |
|---|---|
| **Duration** | ~90 minutes |
| **Level** | Intermediate–Advanced |
| **Stack** | Kong Gateway, Prometheus, Grafana, OpenTelemetry |
| **Outcome** | Full observability stack: logs to HTTP endpoint, metrics in Grafana, traces in OTLP |

## Learning Objectives

- Stream API gateway logs to external endpoints
- Expose Prometheus metrics for Grafana dashboards
- Send distributed traces via OpenTelemetry

## Observability Plugins

| Plugin | Type | Use Case |
|---|---|---|
| **http-log** | Log | POST access logs to any HTTP endpoint |
| **file-log** | Log | Write logs to a file |
| **tcp-log** | Log | Stream logs over TCP (Logstash, Fluentd) |
| **udp-log** | Log | Stream logs over UDP (syslog) |
| **prometheus** | Metrics | Expose `/metrics` in Prometheus format |
| **statsd** | Metrics | Send metrics to StatsD/DogStatsD |
| **datadog** | Metrics | Send metrics to Datadog |
| **opentelemetry** | Traces | Send traces via OTLP (Jaeger, Tempo, Grafana) |
| **zipkin** | Traces | Send traces in Zipkin format |

## What Kong Logs

Every proxied request generates a structured log entry:

```json
{
  "request": {
    "method": "GET",
    "uri": "/api/flights",
    "size": 0,
    "headers": { "host": "localhost:8000", "x-api-key": "[REDACTED]" }
  },
  "response": {
    "status": 200,
    "size": 1024,
    "headers": { "content-type": "application/json" }
  },
  "latencies": {
    "proxy": 12,
    "kong": 3,
    "request": 15
  },
  "route": { "name": "flights-list" },
  "service": { "name": "mytravel-com-api" },
  "consumer": { "username": "travel-web-app" },
  "authenticated_entity": { "key": "[REDACTED]" },
  "started_at": 1748700000000
}
```

## Prometheus Metrics

Kong exposes rich metrics at `/metrics` when the Prometheus plugin is enabled:

| Metric | Type | Description |
|---|---|---|
| `kong_http_requests_total` | Counter | Total requests by service, route, status |
| `kong_request_latency_ms` | Histogram | End-to-end request latency |
| `kong_upstream_latency_ms` | Histogram | Time waiting for upstream |
| `kong_kong_latency_ms` | Histogram | Time spent in Kong plugins |
| `kong_bandwidth_bytes` | Counter | Bytes in/out by service |
| `kong_datastore_reachable` | Gauge | Is the database reachable |

## Labs

| Lab | Topic |
|---|---|
| [06-A: HTTP Logging](/module-06-observability/labs/06-http-logging) | Stream access logs to an HTTP endpoint |
| [06-B: Prometheus](/module-06-observability/labs/06-prometheus) | Expose metrics, configure Grafana dashboard |
| [06-C: OpenTelemetry](/module-06-observability/labs/06-opentelemetry) | Send distributed traces to a collector |

## Resources

- [HTTP Log plugin](https://developer.konghq.com/plugins/http-log/)
- [Prometheus plugin](https://developer.konghq.com/plugins/prometheus/)
- [OpenTelemetry plugin](https://developer.konghq.com/plugins/opentelemetry/)
- [Kong analytics overview](https://developer.konghq.com/gateway/analytics/)

---

*Previous: [Module 05](/module-05-transformations/) · Next: [Module 07 - AI Gateway →](/module-07-ai-gateway/)*
