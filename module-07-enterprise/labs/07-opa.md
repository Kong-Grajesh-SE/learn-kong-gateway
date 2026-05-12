# Lab 07-D - OPA (Open Policy Agent)

> **Goal:** Integrate Open Policy Agent with Kong for policy-based authorization. Write a Rego policy, run OPA, configure the plugin, and test allow/deny decisions.

::: warning Enterprise
`opa` requires **Kong Gateway Enterprise** or **Konnect**. Min version: Kong Gateway 2.4.
:::

## How OPA Works with Kong

```
Request arrives at Kong →
  opa plugin forwards request context as JSON to OPA →
    OPA evaluates Rego policy →
      { "result": true }  → Kong proxies request
      { "result": false } → Kong returns 403 Forbidden
```

Kong sends the full request context (method, path, headers, query, consumer, service) to OPA's REST API. Your Rego policy decides allow/deny.

## Step 1 - Start OPA

```bash
# Run OPA as a sidecar (Docker Compose)
docker run -d --name opa \
  --network kong-net \
  -p 8181:8181 \
  openpolicyagent/opa:latest \
  run --server --addr :8181

# Verify OPA is running
curl -s http://localhost:8181/v1/health | jq .
# { "status": "ok" }
```

## Step 2 - Write a Rego policy

Create `policy.rego`:

```go
package myapp.authz

default allow = false

# Allow authenticated GET requests
allow {
  input.request.http.method == "GET"
  input.consumer.username != ""
}

# Allow admin consumers full access
allow {
  input.consumer.username == "travel-mobile-app"
}

# Block requests without a consumer (unauthenticated)
allow {
  input.consumer != null
  input.request.http.method == "GET"
}
```

## Step 3 - Load the policy into OPA

```bash
# Push policy to OPA via REST API
curl -s -X PUT http://localhost:8181/v1/policies/myapp \
  -H "Content-Type: text/plain" \
  --data-binary @policy.rego

# Verify policy loaded
curl -s http://localhost:8181/v1/policies | jq '.result[].id'
# "myapp"
```

## Step 4 - Apply the OPA plugin to a route

::: code-group

```yaml [decK YAML]
routes:
  - name: flights-list
    plugins:
      - name: opa
        config:
          opa_host: opa
          opa_port: 8181
          opa_path: /v1/data/myapp/authz/allow
          include_consumer_in_opa_input: true
          include_service_in_opa_input: true
          include_route_in_opa_input: false
          ssl_verify: false
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "opa",
    "config": {
      "opa_host": "opa",
      "opa_port": 8181,
      "opa_path": "/v1/data/myapp/authz/allow",
      "include_consumer_in_opa_input": true,
      "include_service_in_opa_input": true,
      "ssl_verify": false
    }
  }' | jq '{id, name}'
```

:::

## Step 5 - Test allow and deny

```bash
# Authenticated consumer (key-auth must also be enabled) → allowed
curl -si http://localhost:8000/api/flights \
  -H "X-API-Key: my-secret-api-key" | head -3
# HTTP/1.1 200 OK

# No credentials → denied
curl -si http://localhost:8000/api/flights | head -3
# HTTP/1.1 403 Forbidden
```

## Step 6 - Inspect the OPA input payload

```bash
# Test what Kong will send to OPA (manual simulation)
curl -s -X POST http://localhost:8181/v1/data/myapp/authz/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "request": {
        "http": {
          "method": "GET",
          "path": "/api/flights",
          "headers": {}
        }
      },
      "client_ip": "10.0.0.1",
      "consumer": { "username": "travel-web-app" },
      "service": { "name": "kong-air" }
    }
  }' | jq .
# { "result": true }
```

## OPA Input Structure

Kong sends the following JSON to OPA on every request:

```json
{
  "input": {
    "request": {
      "http": {
        "method": "GET",
        "path": "/api/flights",
        "host": "localhost:8000",
        "headers": { "authorization": "Bearer ..." },
        "querystring": { "page": "1" }
      }
    },
    "client_ip": "10.0.0.5",
    "consumer": { "id": "...", "username": "travel-web-app" },
    "service": { "name": "kong-air" }
  }
}
```

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `opa_host` | `localhost` | OPA server hostname |
| `opa_port` | `8181` | OPA server port |
| `opa_path` | - | OPA data/rule API path (e.g. `/v1/data/myapp/authz/allow`) |
| `https` | `false` | Use HTTPS to connect to OPA |
| `ssl_verify` | `true` | Verify OPA server TLS certificate |
| `include_consumer_in_opa_input` | `false` | Include authenticated Consumer data in OPA payload |
| `include_service_in_opa_input` | `false` | Include Kong Service object in OPA payload |
| `include_route_in_opa_input` | `false` | Include Kong Route object in OPA payload |
| `include_uri_captures_in_opa_input` | `false` | Include regex capture groups from the Route path |

---

*Previous: [Lab 07-C - Upstream OAuth](./07-upstream-oauth) · Next: [Lab 07-E - Datakit →](./07-datakit)*
