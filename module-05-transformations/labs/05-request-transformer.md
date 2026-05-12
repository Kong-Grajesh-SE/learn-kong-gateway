# Lab 05-A - Request Transformer

> **Goal:** Use the Request Transformer plugin to inject headers, strip sensitive fields, and add versioning metadata on the bookings endpoint.

## Step 1 - Add headers to requests

Inject an audit header so your backend knows the request came through Kong:

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "headers": [
          "X-Kong-Proxied:true",
          "X-API-Version:v2",
          "X-Request-Source:gateway"
        ],
        "querystring": [],
        "body": []
      },
      "remove": {
        "headers": ["X-Internal-Debug"],
        "querystring": ["debug"],
        "body": []
      },
      "replace": {
        "headers": [],
        "querystring": [],
        "body": []
      }
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
routes:
  - name: bookings-create
    plugins:
      - name: request-transformer
        config:
          add:
            headers:
              - "X-Kong-Proxied:true"
              - "X-API-Version:v2"
              - "X-Request-Source:gateway"
          remove:
            headers:
              - X-Internal-Debug
            querystring:
              - debug
```

:::

## Step 2 - Verify headers reach the backend

```bash
# Check that Kong adds the headers to upstream requests
curl -s -X POST http://localhost:8000/demo/post \
  -H "Content-Type: application/json" \
  -H "X-Internal-Debug: secret" \
  -d '{"flight": "AA123"}' | jq '.headers | {
    kong_proxied: ."X-Kong-Proxied",
    api_version: ."X-Api-Version",
    debug_removed: ."X-Internal-Debug"
  }'

# X-Internal-Debug should be absent
# X-Kong-Proxied should be "true"
```

## Step 3 - Rename a query parameter

Translate external API parameter names to internal ones:

```bash
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "rename": {
        "querystring": ["page:offset", "size:limit"]
      }
    }
  }' | jq '{id, name}'

# Now external clients use ?page=1&size=10
# Backend receives ?offset=1&limit=10
curl -s "http://localhost:8000/api/flights?page=1&size=5" | jq 'length'
```

## Step 4 - Body transformation on POST

Inject a booking source and strip a client-internal field:

```bash
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "body": ["booking_source:kong-gateway", "api_version:v2"]
      },
      "remove": {
        "body": ["client_debug_info", "internal_trace_id"]
      }
    }
  }' | jq '{id, name}'

# Test
curl -s -X POST http://localhost:8000/demo/post \
  -H "Content-Type: application/json" \
  -d '{
    "flight_id": "AA123",
    "seats": 2,
    "client_debug_info": "should be removed",
    "internal_trace_id": "abc-123"
  }' | jq '.json'
```

## Step 5 - request-transformer-advanced (Enterprise)

The advanced version supports templates and conditional logic:

```yaml
plugins:
  - name: request-transformer-advanced
    config:
      add:
        headers:
          - "X-Consumer-Username:$(consumer.username)"
          - "X-Request-Time:$(date.timestamp)"
      replace:
        body:
          - "processed_by:kong-enterprise"
      dots_in_keys: true
      allow: {}
```

> **Template variables:** `$(consumer.username)`, `$(consumer.id)`, `$(route.id)`, `$(service.name)`, `$(date.timestamp)`

## Request Transformer Config Reference

```yaml
config:
  # Keys must not already exist (idempotent add)
  add:
    headers: ["key:value"]
    querystring: ["key:value"]
    body: ["key:value"]

  # Keys are removed if they exist
  remove:
    headers: ["key"]
    querystring: ["key"]
    body: ["key"]

  # Keys are overwritten if they exist
  replace:
    headers: ["key:value"]
    querystring: ["key:value"]
    body: ["key:value"]

  # Always add (even if key exists - creates multi-value)
  append:
    headers: ["key:value"]
    querystring: ["key:value"]
    body: ["key:value"]
```

---

*Next: [Lab 05-B - Response Transformer →](./05-response-transformer)*
