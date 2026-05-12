# Lab 03-D - HMAC Authentication

> **Goal:** Protect an API route with HMAC signature authentication. Clients sign each request with a username and shared secret; Kong validates the signature and clock skew before proxying.

## How HMAC Auth Works

```
Client builds signing string (date + @request-target + ...) →
  Signs with HMAC-SHA256 using shared secret →
    Sends Authorization header with username + algorithm + signature →
      Kong validates signature, clock skew, and consumer →
        ✅ Valid → request proxied
        ❌ Invalid → 401 Unauthorized
```

## Step 1 - Enable HMAC Auth on a route

::: code-group

```yaml [decK YAML]
routes:
  - name: flights-list
    plugins:
      - name: hmac-auth
        config:
          hide_credentials: true
          clock_skew: 300
          enforce_headers:
            - date
            - "@request-target"
          algorithms:
            - hmac-sha256
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hmac-auth",
    "config": {
      "hide_credentials": true,
      "clock_skew": 300,
      "enforce_headers": ["date", "@request-target"],
      "algorithms": ["hmac-sha256"]
    }
  }' | jq '{id, name, config}'
```

:::

## Step 2 - Create a consumer and HMAC credential

```bash
# Create consumer
curl -s -X POST http://localhost:8001/consumers \
  -H "Content-Type: application/json" \
  -d '{"username": "hmac-client"}' | jq '{id, username}'

# Attach HMAC credential
curl -s -X POST http://localhost:8001/consumers/hmac-client/hmac-auth \
  -H "Content-Type: application/json" \
  -d '{"username": "hmac-client", "secret": "my-shared-secret"}' | jq .
```

## Step 3 - Build and send a signed request

HMAC clients must include a properly signed `Authorization` header. Here is a helper script:

```bash
#!/bin/bash
# hmac-request.sh

USERNAME="hmac-client"
SECRET="my-shared-secret"
METHOD="GET"
PATH="/api/flights"
HOST="localhost:8000"
DATE=$(date -u "+%a, %d %b %Y %H:%M:%S GMT")

# Build signing string (newline-separated)
SIGNING_STRING="date: $DATE
@request-target: $METHOD $(echo $PATH | tr '[:upper:]' '[:lower:]')"

# Sign with HMAC-SHA256
SIGNATURE=$(echo -n "$SIGNING_STRING" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

# Send the request
curl -si \
  -H "Date: $DATE" \
  -H "Authorization: hmac username=\"$USERNAME\", algorithm=\"hmac-sha256\", headers=\"date @request-target\", signature=\"$SIGNATURE\"" \
  "http://$HOST$PATH"
```

```bash
chmod +x hmac-request.sh && ./hmac-request.sh
# Expected: HTTP/1.1 200 OK
```

## Step 4 - Verify rejection without valid signature

```bash
# No Authorization header → 401
curl -si http://localhost:8000/api/flights | head -5

# Wrong signature → 401
curl -si \
  -H "Date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
  -H "Authorization: hmac username=\"hmac-client\", algorithm=\"hmac-sha256\", headers=\"date @request-target\", signature=\"badsig\"" \
  http://localhost:8000/api/flights | head -5

# Stale date (beyond clock_skew) → 401
curl -si \
  -H "Date: Mon, 01 Jan 2024 00:00:00 GMT" \
  -H "Authorization: hmac username=\"hmac-client\", algorithm=\"hmac-sha256\", headers=\"date @request-target\", signature=\"anything\"" \
  http://localhost:8000/api/flights | head -5
```

## Authorization Header Format

```
Authorization: hmac username="<username>",
               algorithm="hmac-sha256",
               headers="date @request-target",
               signature="<base64-encoded-signature>"
```

The **signing string** is a newline-concatenation of the signed header values in the order declared in `headers`:

```
date: Mon, 12 May 2026 10:00:00 GMT
@request-target: get /api/flights
```

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `algorithms` | `["hmac-sha256"]` | Allowed: `hmac-sha224`, `hmac-sha256`, `hmac-sha384`, `hmac-sha512` |
| `clock_skew` | `300` | Max time drift in seconds between client and server |
| `enforce_headers` | `[]` | Headers the client **must** sign (e.g. `date`, `@request-target`) |
| `validate_request_body` | `false` | If `true`, validates a `Digest: SHA-256=<base64>` header against the body |
| `hide_credentials` | `false` | Strip the `Authorization` header before proxying upstream |
| `anonymous` | `null` | Fallback consumer if auth fails (multi-auth setups) |

---

*Previous: [Lab 03-C - OIDC / Keycloak](./03-oidc-keycloak) · Next: [Module 04 - Traffic Control →](/module-04-traffic-control/)*
