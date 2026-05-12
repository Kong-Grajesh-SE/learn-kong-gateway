# Lab 05-B - Response Transformer

> **Goal:** Modify API responses to inject a demo header, strip internal fields, and add metadata.

## Step 1 - Inject a response header

Add a header to all responses from the bookings route:

```bash
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "response-transformer",
    "config": {
      "add": {
        "headers": ["X-Powered-By:Kong Gateway", "demo:injected-by-kong"],
        "json": [],
        "json_types": []
      },
      "remove": {
        "headers": ["X-Served-By", "Via"],
        "json": ["internal_id", "debug_info"]
      }
    }
  }' | jq '{id, name}'
```

## Step 2 - Verify response headers

```bash
curl -si -X POST http://localhost:8000/api/bookings \
  -H "Content-Type: application/json" \
  -d '{"flight_id": "AA123", "seats": 2}' | \
  grep -E "demo|X-Powered|X-Served"

# Expected:
# demo: injected-by-kong
# X-Powered-By: Kong Gateway
# (X-Served-By should be absent)
```

## Step 3 - Transform response JSON body

Add metadata to all flight list responses:

```bash
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "response-transformer",
    "config": {
      "add": {
        "json": ["api_version:\"v2\"", "powered_by:\"Kong Gateway\""],
        "json_types": ["string", "string"]
      }
    }
  }' | jq '{id, name}'

# Test
curl -s http://localhost:8000/api/flights | jq '. | if type == "array" then {count: length} else . end'
```

::: tip Note
`response-transformer` works on **flat JSON objects** in the body. For nested JSON manipulation, use `response-transformer-advanced`.
:::

## Step 4 - response-transformer-advanced (Enterprise)

The advanced plugin supports JSON path operations on nested objects:

```yaml
plugins:
  - name: response-transformer-advanced
    config:
      add:
        json:
          - "metadata.gateway:\"kong\""
          - "metadata.version:\"3.9\""
        json_types:
          - string
          - string
      remove:
        json:
          - "data.internal_cost"
          - "data.provider_id"
      replace:
        json:
          - "status:\"processed\""
        json_types:
          - string
      transform:
        functions:
          - |
            local body = require("cjson").decode(kong.response.get_raw_body())
            body.timestamp = ngx.now()
            kong.response.set_raw_body(require("cjson").encode(body))
```

## Step 5 - Chain request + response transformers

A common pattern: inject a request ID on ingress, echo it back in the response:

```bash
# Step A: Request transformer adds X-Request-ID
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {"headers": ["X-Booking-Source:kong-gateway"]}
    }
  }'

# Step B: Response transformer echoes it back
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "response-transformer",
    "config": {
      "add": {
        "headers": ["X-Booking-Source:kong-gateway"],
        "json": ["processed_by:\"kong\""],
        "json_types": ["string"]
      }
    }
  }'

# Test
curl -si -X POST http://localhost:8000/api/bookings \
  -H "Content-Type: application/json" \
  -d '{"flight_id": "AA123"}' | grep -E "X-Booking|processed_by"
```

## Response Transformer Config Reference

```yaml
config:
  add:
    headers: ["key:value"]   # Add header if absent
    json: ["key:value"]      # Add JSON field if absent
    json_types: ["string"]   # Type for each json value

  append:
    headers: ["key:value"]   # Add header (allows duplicates)

  remove:
    headers: ["key"]         # Remove header
    json: ["key"]            # Remove JSON body field

  replace:
    headers: ["key:value"]   # Replace header value
    json: ["key:value"]      # Replace JSON field value
    json_types: ["string"]
```

---

*Next: [Lab 05-C - Correlation ID →](./05-correlation-id)*
