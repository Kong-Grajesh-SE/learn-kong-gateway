# Lab 03-A - Key Authentication

> **Goal:** Protect the kong-air flights API with API key authentication. Create consumer credentials and test access control with both curl and Insomnia.

## Step 1 - Enable Key Auth on a Route

We'll protect `GET /api/flights` with Key Auth:

::: code-group

```yaml [decK YAML - Konnect]
# Update kong-air.yaml - add plugin to flights-list route
routes:
  - name: flights-list
    paths: [~/api/flights$]
    methods: [GET]
    plugins:
      - name: key-auth
        config:
          key_names: [X-API-Key, apikey]
          key_in_header: true
          key_in_query: true
          key_in_body: false
          hide_credentials: true
```

```bash [Sync to Konnect]
deck gateway sync kong-air.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

:::

## Step 2 - Verify the route is protected

::: code-group

```bash [curl - Terminal]
# Without a key - should return 401
curl -si http://localhost:8000/api/flights | head -5
# Expected:
# HTTP/1.1 401 Unauthorized
# {"message":"No API key found in request"}
```

```text [Insomnia - GUI]
1. New Request → GET
2. URL: http://localhost:8000/api/flights
3. Click Send (no auth headers)
4. Verify: Status 401, body {"message":"No API key found in request"}
```

:::
```

## Step 3 - Create consumer credentials

```bash
# Generate an API key for travel-web-app
curl -s -X POST http://localhost:8001/consumers/travel-web-app/key-auth \
  -H "Content-Type: application/json" \
  -d '{"key": "web-app-key-abc123"}' | jq '.'

# Generate an API key for travel-mobile-app
curl -s -X POST http://localhost:8001/consumers/travel-mobile-app/key-auth \
  -H "Content-Type: application/json" \
  -d '{"key": "mobile-app-key-def456"}' | jq '.'

# Generate auto-generated key for dev-tester
curl -s -X POST http://localhost:8001/consumers/dev-tester/key-auth | \
  jq '{key, consumer}'
```

## Step 4 - Access with API keys

```bash
# Using X-API-Key header
curl -s -H "X-API-Key: web-app-key-abc123" \
  http://localhost:8000/api/flights | jq 'length'

# Using apikey header
curl -s -H "apikey: mobile-app-key-def456" \
  http://localhost:8000/api/flights | jq 'length'

# Using query parameter
curl -s "http://localhost:8000/api/flights?apikey=web-app-key-abc123" | jq 'length'
```

## Step 5 - hide_credentials verification

With `hide_credentials: true`, the API key is stripped before forwarding to the backend:

```bash
# The backend will not see the apikey header/query
curl -s -H "X-API-Key: web-app-key-abc123" \
  http://localhost:8000/demo/headers | jq '.headers | with_entries(select(.key | test("(?i)api|key")))'
# Should be empty - key was stripped
```

## Step 6 - Consumer context in headers

```bash
# Check what Kong injects for the consumer
curl -s -H "X-API-Key: web-app-key-abc123" \
  http://localhost:8000/demo/headers | jq '.headers | {
    consumer_id: ."X-Consumer-Id",
    consumer_username: ."X-Consumer-Username",
    credential_identifier: ."X-Credential-Identifier"
  }'
```

## Step 7 - decK YAML with credentials

::: warning
API key values in decK YAML are stored as plaintext. Use environment variables or a secrets manager in production.
:::

```yaml
_format_version: '3.0'

consumers:
  - username: travel-web-app
    keyauth_credentials:
      - key: web-app-key-abc123
        tags: [production]

  - username: travel-mobile-app
    keyauth_credentials:
      - key: mobile-app-key-def456
        tags: [production]
```

## Step 8 - List and rotate credentials

```bash
# List all keys for a consumer
curl -s http://localhost:8001/consumers/travel-web-app/key-auth | \
  jq '.data[] | {id, key, created_at}'

# Delete an old key (rotation)
OLD_KEY_ID="<paste id here>"
curl -s -X DELETE \
  "http://localhost:8001/consumers/travel-web-app/key-auth/$OLD_KEY_ID"

# Create new key
curl -s -X POST http://localhost:8001/consumers/travel-web-app/key-auth \
  -H "Content-Type: application/json" \
  -d '{"key": "web-app-key-new-789"}' | jq '{key}'
```

## Key Auth Configuration Reference

| Config | Default | Description |
|---|---|---|
| `key_names` | `["apikey"]` | Header / query param names to check |
| `key_in_header` | `true` | Accept key in request headers |
| `key_in_query` | `true` | Accept key in query string |
| `key_in_body` | `false` | Accept key in request body |
| `hide_credentials` | `false` | Strip key before forwarding |
| `anonymous` | `null` | Fallback consumer ID if unauthenticated |
| `run_on_preflight` | `true` | Check auth on OPTIONS requests |

## Challenge

1. Create a new route `/api/flights/premium` that requires both Key Auth **and** an ACL group check - only consumers in the `premium-tier` group should have access.
2. Test that `travel-web-app` (in premium-tier) succeeds but `dev-tester` gets a 403.

---

*Next: [Lab 03-B - JWT Auth →](./03-jwt-auth)*
