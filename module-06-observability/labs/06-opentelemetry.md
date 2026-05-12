# Lab 06-C - OpenTelemetry Distributed Tracing

> **Goal:** Configure Kong to emit distributed traces via OpenTelemetry Protocol (OTLP) and visualise them in Jaeger or Grafana Tempo.

## Architecture

```
Client → Kong → Upstream
          ↓
    OTLP exporter
          ↓
  OTel Collector
          ↓
    Jaeger / Tempo
```

## Step 1 - Start the OTel Collector and Jaeger

Create `docker-compose.tracing.yml`:

```yaml
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    command: ["--config=/etc/otel-collector-config.yml"]
    volumes:
      - ./otel-collector-config.yml:/etc/otel-collector-config.yml
    ports:
      - "4317:4317"    # OTLP gRPC
      - "4318:4318"    # OTLP HTTP
      - "8888:8888"    # Prometheus metrics
    networks:
      - kong-net

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    environment:
      COLLECTOR_OTLP_ENABLED: "true"
    ports:
      - "16686:16686"   # Jaeger UI
      - "14250:14250"   # gRPC
    networks:
      - kong-net

networks:
  kong-net:
    external: true
```

Create `otel-collector-config.yml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  logging:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger, logging]
```

```bash
docker compose -f docker-compose.tracing.yml up -d
```

## Step 2 - Enable OpenTelemetry plugin

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "opentelemetry",
    "config": {
      "endpoint": "http://otel-collector:4318/v1/traces",
      "resource_attributes": {
        "service.name": "kong-gateway",
        "deployment.environment": "development",
        "service.version": "3.9"
      },
      "propagation_headers": ["w3c"],
      "sampling_rate": 1.0,
      "connect_timeout": 1000,
      "send_timeout": 5000,
      "read_timeout": 5000
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
plugins:
  - name: opentelemetry
    config:
      endpoint: "http://otel-collector:4318/v1/traces"
      resource_attributes:
        service.name: kong-gateway
        deployment.environment: development
      propagation_headers: [w3c]
      sampling_rate: 1.0
```

:::

## Step 3 - Generate traced traffic

```bash
# Make several requests with W3C traceparent headers
TRACE_ID=$(openssl rand -hex 16)
curl -s \
  -H "traceparent: 00-${TRACE_ID}-$(openssl rand -hex 8)-01" \
  -H "X-API-Key: web-app-key-abc123" \
  http://localhost:8000/api/flights | jq 'length'
```

## Step 4 - View traces in Jaeger

1. Open [http://localhost:16686](http://localhost:16686)
2. Select **Service**: `kong-gateway`
3. Click **Find Traces**
4. Click any trace to see the waterfall

You'll see spans for:
- Kong total time
- Plugin execution time (rewrite, access, header_filter phases)
- Upstream response time

## Step 5 - Propagate trace context to backend

Your Express backend should forward the `traceparent` header:

```javascript
// server/middleware/tracing.js
const { trace, context, propagation } = require('@opentelemetry/api');

module.exports = (req, res, next) => {
  // Extract trace context from Kong-forwarded headers
  const ctx = propagation.extract(context.active(), req.headers);
  const span = trace.getTracer('mytravel-api').startSpan(
    `${req.method} ${req.path}`,
    { attributes: { 'http.method': req.method, 'http.url': req.url } },
    ctx
  );

  res.on('finish', () => {
    span.setAttribute('http.status_code', res.statusCode);
    span.end();
  });

  next();
};
```

## Step 6 - Sampling strategies

```yaml
config:
  sampling_rate: 0.1    # Sample 10% of requests (production)
  # OR use header-based sampling:
  # Always sample if X-Debug-Trace: true
```

```bash
# Force trace on specific requests
curl -s \
  -H "X-API-Key: web-app-key-abc123" \
  -H "traceparent: 00-00000000000000000000000000000001-0000000000000001-01" \
  http://localhost:8000/api/flights | jq 'length'
```

## OTel Plugin Config Reference

| Config | Description |
|---|---|
| `endpoint` | OTLP HTTP endpoint URL |
| `resource_attributes` | Key-value pairs attached to all spans |
| `propagation_headers` | `w3c`, `b3`, `b3-single`, `datadog`, `jaeger` |
| `sampling_rate` | `0.0` to `1.0` (fraction of requests to trace) |
| `batch_span_count` | Max spans per batch |
| `batch_flush_delay` | Max wait before flushing batch (ms) |

---

*Next: [Module 07 - AI Gateway →](/module-07-ai-gateway/)*
