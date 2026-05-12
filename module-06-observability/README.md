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

## Plugin Quick Reference

> Condensed configs for every plugin used in this module. See the [full Plugin Reference](/plugin-reference) for all parameters.

### http-log

```yaml
plugins:
  - name: http-log
    config:
      http_endpoint: "http://log-receiver:3000/logs"
      method: POST
      content_type: application/json
      timeout: 10000
      keepalive: 60000
      flush_timeout: 2
      queue_size: 1
```

| Parameter | Default | Description |
|---|---|---|
| `http_endpoint` | - | URL to POST log entries to |
| `method` | `POST` | HTTP method for log delivery |
| `content_type` | `application/json` | Payload content type |
| `timeout` | `10000` | Send timeout in milliseconds |
| `flush_timeout` | `2` | Max seconds to wait before flushing a partial batch |
| `queue_size` | `1` | Number of log entries to batch per request |
| `custom_fields_by_lua` | `{}` | Lua expressions to add custom fields to the log entry |

**Lab:** [06-A: HTTP Logging](/module-06-observability/labs/06-http-logging)

---

### prometheus

```yaml
plugins:
  - name: prometheus
    config:
      status_code_metrics: true
      latency_metrics: true
      bandwidth_metrics: true
      upstream_health_metrics: true
      per_consumer: true
```

**Scrape endpoint:** `http://localhost:8100/metrics` (status port)

| Parameter | Default | Description |
|---|---|---|
| `status_code_metrics` | `false` | Expose per-status-code request counters |
| `latency_metrics` | `false` | Expose request, upstream, and Kong latency histograms |
| `bandwidth_metrics` | `false` | Expose bytes in/out counters |
| `upstream_health_metrics` | `false` | Expose upstream target health gauges |
| `per_consumer` | `false` | Break down metrics by consumer label |

**Lab:** [06-B: Prometheus](/module-06-observability/labs/06-prometheus)

---

### opentelemetry

```yaml
plugins:
  - name: opentelemetry
    config:
      endpoint: "http://otel-collector:4318/v1/traces"
      resource_attributes:
        service.name: kong-gateway
        deployment.environment: bootcamp
      propagation:
        default_format: w3c
        extract: [w3c, b3]
        inject: [w3c]
      batch_span_processor:
        max_export_batch_size: 200
        scheduled_delay: 5000
```

| Parameter | Description |
|---|---|
| `endpoint` | OTLP/HTTP collector URL (`/v1/traces`) |
| `resource_attributes` | Static key-value tags added to every span |
| `propagation.default_format` | Trace context format: `w3c` (recommended), `b3`, `datadog` |
| `propagation.extract` | Formats to read from incoming requests |
| `propagation.inject` | Formats to inject into upstream requests |
| `batch_span_processor.max_export_batch_size` | Max spans per export batch |
| `batch_span_processor.scheduled_delay` | Flush interval in milliseconds |

**Lab:** [06-C: OpenTelemetry](/module-06-observability/labs/06-opentelemetry)

---

## Resources

- [HTTP Log plugin](https://developer.konghq.com/plugins/http-log/)
- [Prometheus plugin](https://developer.konghq.com/plugins/prometheus/)
- [OpenTelemetry plugin](https://developer.konghq.com/plugins/opentelemetry/)
- [Kong analytics overview](https://developer.konghq.com/gateway/analytics/)
- [Full Plugin Reference →](/plugin-reference)

---

*Previous: [Module 05](/module-05-transformations/) · Next: [Module 07 - OIDC & RBAC →](/module-07-enterprise/)*
