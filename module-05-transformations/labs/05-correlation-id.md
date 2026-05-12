# Lab 05-C - Correlation ID

> **Goal:** Implement end-to-end request tracing by injecting a unique correlation ID into every request.

## Why Correlation IDs?

When a user reports "my booking failed at 14:32", you need to find that exact request across:
- Kong proxy logs
- Express backend logs
- Database query logs
- External API call logs

A **correlation ID** ties all these log lines together.

## Step 1 - Enable the Correlation ID plugin globally

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "correlation-id",
    "config": {
      "header_name": "Kong-Request-ID",
      "generator": "uuid#counter",
      "echo_downstream": true
    }
  }' | jq '{id, name, config}'
```

```yaml [decK YAML]
plugins:
  - name: correlation-id
    config:
      header_name: Kong-Request-ID
      generator: uuid#counter
      echo_downstream: true
```

:::

## Step 2 - Observe the correlation ID

```bash
# The ID appears in the response header
curl -si http://localhost:8000/api/flights | grep "Kong-Request-ID"
# Kong-Request-ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890#1

# Make multiple requests - counter increments
for i in {1..3}; do
  curl -si http://localhost:8000/api/flights | grep "Kong-Request-ID"
done
```

## Step 3 - Pass a custom correlation ID

Clients can provide their own ID for end-to-end tracing:

```bash
curl -si -H "Kong-Request-ID: my-custom-trace-id-12345" \
  http://localhost:8000/api/flights | grep "Kong-Request-ID"

# If echo_downstream: true, your ID is preserved and echoed back
```

## Step 4 - Correlate logs

Kong's proxy access log includes the correlation ID. View it:

```bash
# Follow proxy logs
docker compose logs -f kong | grep "Kong-Request-ID"

# Or use the Kong Admin API log endpoint (if enabled)
curl -s http://localhost:8001/logs | jq '.[]  | select(.request.headers["kong-request-id"] != null)'
```

## Step 5 - Use in Express backend

Update your backend to log the correlation ID:

```javascript
// server/index.js - add this middleware
app.use((req, res, next) => {
  const correlationId = req.headers['kong-request-id'];
  if (correlationId) {
    req.correlationId = correlationId;
    res.setHeader('Kong-Request-ID', correlationId);  // pass through
    console.log(`[${correlationId}] ${req.method} ${req.path}`);
  }
  next();
});
```

## Generator Options

| Generator | Format | Example |
|---|---|---|
| `uuid` | Standard UUID v4 | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| `uuid#counter` | UUID + request counter | `a1b2c3d4-...#42` |
| `tracker` | Jaeger-compatible | `0123456789abcdef:0123456789abcdef:0` |

## Step 6 - Combine with logging plugin

The correlation ID becomes powerful when paired with HTTP logging:

```bash
# Apply HTTP log plugin to stream logs with correlation IDs
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "http-log",
    "config": {
      "http_endpoint": "http://host.docker.internal:3001/logs",
      "method": "POST",
      "timeout": 10000,
      "keepalive": 60000,
      "flush_timeout": 2,
      "retry_count": 10,
      "custom_fields_by_lua": {
        "correlation_id": "return kong.request.get_header(\"Kong-Request-ID\")"
      }
    }
  }' | jq '{id, name}'
```

## Summary

| Plugin | Header | Value |
|---|---|---|
| `correlation-id` | `Kong-Request-ID` | UUID or UUID#counter |
| `request-transformer` | Any custom | Static value |
| Both combined | `Kong-Request-ID` + custom | Full trace context |

---

*Next: [Module 06 - Observability →](/module-06-observability/)*
