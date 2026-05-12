# Lab 06-A - HTTP Logging

> **Goal:** Stream Kong access logs to an HTTP endpoint in real-time. We'll use a simple Node.js log receiver and the http-log plugin.

## Step 1 - Create a log receiver

Create `log-receiver.js`:

```javascript
// log-receiver.js - simple HTTP endpoint that prints Kong logs
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/kong-logs') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const log = JSON.parse(body);
        const { request, response, latencies, service, consumer } = log;
        console.log(JSON.stringify({
          time: new Date(log.started_at).toISOString(),
          method: request?.method,
          path: request?.uri,
          status: response?.status,
          latency_ms: latencies?.request,
          kong_ms: latencies?.kong,
          proxy_ms: latencies?.proxy,
          service: service?.name,
          consumer: consumer?.username ?? 'anonymous',
        }, null, 2));
      } catch (e) {
        console.error('Parse error:', e.message);
      }
      res.writeHead(200);
      res.end('OK');
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(4000, () => {
  console.log('Log receiver listening on :4000/kong-logs');
});
```

```bash
node log-receiver.js
```

## Step 2 - Enable HTTP Log plugin

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "http-log",
    "config": {
      "http_endpoint": "http://host.docker.internal:4000/kong-logs",
      "method": "POST",
      "content_type": "application/json",
      "timeout": 10000,
      "keepalive": 60000,
      "flush_timeout": 2,
      "retry_count": 10
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
plugins:
  - name: http-log
    config:
      http_endpoint: "http://host.docker.internal:4000/kong-logs"
      method: POST
      content_type: application/json
      timeout: 10000
      keepalive: 60000
      flush_timeout: 2
      retry_count: 10
```

:::

## Step 3 - Generate traffic and watch logs

```bash
# Terminal 1 - Log receiver running
node log-receiver.js

# Terminal 2 - Generate traffic
for i in {1..5}; do
  curl -s -H "X-API-Key: web-app-key-abc123" \
    http://localhost:8000/api/flights > /dev/null
  sleep 0.5
done
```

You should see structured log entries in the receiver:

```json
{
  "time": "2026-05-12T10:30:00.000Z",
  "method": "GET",
  "path": "/api/flights",
  "status": 200,
  "latency_ms": 18,
  "kong_ms": 4,
  "proxy_ms": 14,
  "service": "mytravel-com-api",
  "consumer": "travel-web-app"
}
```

## Step 4 - Add custom Lua fields

Enrich logs with custom fields using Lua:

```bash
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "http-log",
    "config": {
      "http_endpoint": "http://host.docker.internal:4000/kong-logs",
      "method": "POST",
      "custom_fields_by_lua": {
        "correlation_id": "return kong.request.get_header(\"Kong-Request-ID\")",
        "consumer_group": "return (kong.client.get_consumer_groups() or {})[1] and (kong.client.get_consumer_groups() or {})[1].name or \"none\"",
        "route_id": "return kong.router.get_route().id"
      }
    }
  }' | jq '{id, name}'
```

## Step 5 - Log only errors

Apply the plugin at route level and filter to 4xx/5xx only:

```bash
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "http-log",
    "config": {
      "http_endpoint": "http://host.docker.internal:4000/kong-logs",
      "method": "POST",
      "custom_fields_by_lua": {
        "error_only": "if kong.response.get_status() < 400 then return ngx.exit(0) end return \"true\""
      }
    }
  }' | jq '{id, name}'
```

## Log Fields Reference

| Field | Description |
|---|---|
| `request.method` | HTTP method |
| `request.uri` | Request path + query |
| `request.size` | Request body size in bytes |
| `response.status` | HTTP status code |
| `response.size` | Response body size |
| `latencies.request` | Total end-to-end latency (ms) |
| `latencies.kong` | Time in Kong plugins (ms) |
| `latencies.proxy` | Time waiting for upstream (ms) |
| `service.name` | Kong service name |
| `route.name` | Kong route name |
| `consumer.username` | Authenticated consumer |

---

*Next: [Lab 06-B - Prometheus →](./06-prometheus)*
