# Lab 04-D - CORS (Cross-Origin Resource Sharing)

> **Goal:** Configure the CORS plugin so browser-based frontends can call your Kong-proxied APIs from a different origin.

## Why CORS?

Browsers block cross-origin requests by default. When your frontend (`https://app.example.com`) calls an API on `http://localhost:8000`, the browser sends a **preflight OPTIONS request** first. Kong must respond with the correct `Access-Control-*` headers or the browser will block the request.

```
Browser → OPTIONS /api/flights (preflight) →
  Kong CORS plugin responds with Access-Control-* headers →
    Browser approves → actual GET /api/flights sent →
      Kong proxies to upstream
```

## Step 1 - Apply CORS to a route

::: code-group

```yaml [decK YAML]
routes:
  - name: flights-list
    plugins:
      - name: cors
        config:
          origins:
            - "https://app.example.com"
            - "http://localhost:3000"
          methods:
            - GET
            - POST
            - PUT
            - DELETE
            - OPTIONS
          headers:
            - Authorization
            - Content-Type
            - X-API-Key
          exposed_headers:
            - X-Request-Id
            - X-RateLimit-Remaining-Minute
          credentials: true
          max_age: 3600
          preflight_continue: false
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "cors",
    "config": {
      "origins": ["https://app.example.com", "http://localhost:3000"],
      "methods": ["GET","POST","PUT","DELETE","OPTIONS"],
      "headers": ["Authorization","Content-Type","X-API-Key"],
      "exposed_headers": ["X-Request-Id","X-RateLimit-Remaining-Minute"],
      "credentials": true,
      "max_age": 3600
    }
  }' | jq '{id, name}'
```

:::

## Step 2 - Test the preflight response

```bash
# Simulate browser preflight (OPTIONS request)
curl -si -X OPTIONS http://localhost:8000/api/flights \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization" \
  | grep -i "access-control"

# Expected headers:
# Access-Control-Allow-Origin: https://app.example.com
# Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
# Access-Control-Allow-Headers: Authorization, Content-Type, X-API-Key
# Access-Control-Allow-Credentials: true
# Access-Control-Max-Age: 3600
```

## Step 3 - Test with a cross-origin GET

```bash
# Actual request from allowed origin
curl -si http://localhost:8000/api/flights \
  -H "Origin: https://app.example.com" \
  | grep -i "access-control"

# Expected:
# Access-Control-Allow-Origin: https://app.example.com
# Access-Control-Allow-Credentials: true
# Access-Control-Expose-Headers: X-Request-Id, X-RateLimit-Remaining-Minute
```

## Step 4 - Test rejection from disallowed origin

```bash
curl -si -X OPTIONS http://localhost:8000/api/flights \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  | grep -i "access-control"

# Expected: no Access-Control-Allow-Origin header → browser blocks the request
```

## Common Pitfall: credentials + wildcard

::: warning
`credentials: true` is **incompatible** with `origins: ["*"]`. Always specify explicit origins when credentials are required.
:::

```yaml
# ❌ This will not work - browsers reject it
config:
  origins: ["*"]
  credentials: true

# ✅ Correct
config:
  origins: ["https://app.example.com"]
  credentials: true
```

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `origins` | `["*"]` | Allowed origins. Use explicit URLs with `credentials: true` |
| `methods` | all standard | Allowed HTTP methods in `Access-Control-Allow-Methods` |
| `headers` | `[]` | Allowed request headers (`Access-Control-Allow-Headers`) |
| `exposed_headers` | `[]` | Headers exposed to browser JS (`Access-Control-Expose-Headers`) |
| `credentials` | `false` | Allow cookies and auth headers |
| `max_age` | `null` | Preflight cache duration in seconds |
| `preflight_continue` | `false` | Forward OPTIONS preflight to upstream instead of responding directly |

---

*Previous: [Lab 04-C - ACL](./04-acl) · Next: [Lab 04-E - IP Restriction →](./04-ip-restriction)*
