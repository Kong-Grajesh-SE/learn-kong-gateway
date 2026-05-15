# Lab 07-A - Advanced Auth: JWT + HMAC

> **Goal.** In ~45 minutes you'll set up two **stateless** auth plugins: `jwt` (any JWS-signed token) and `hmac-auth` (signed request bodies + headers, replay-protected). You'll mint tokens / signatures locally and watch Kong validate them at the edge.

::: tip Stateless = Kong stores no credential metadata per request
Both plugins validate a signature using a shared secret on the Consumer. There's no per-request DB lookup, no token cache to invalidate. **Scales horizontally for free.** That's their key advantage over `key-auth`.
:::

---

## Part 1 - JWT (Bearer tokens, ~20 min)

### Step 1.1 - Baseline + a Consumer (3 min)

```yaml [kong.yaml]
_format_version: '3.0'

consumers:
  - username: partner-api-client
    custom_id: partner-001
    tags: [module-07]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-07]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

### Step 1.2 - Attach `jwt` plugin to the Route (3 min)

```yaml [Append plugin to flights-route]
plugins:
  - name: jwt
    config:
      key_claim_name: iss                  # the JWT claim that identifies the Consumer
      claims_to_verify: [exp]              # also verify the token isn't expired
      run_on_preflight: false              # skip on CORS preflight (OPTIONS)
      uri_param_names: []                  # tokens MUST come from the header
      cookie_names:    []
      header_names: [Authorization]
```

Sync.

::: info `key_claim_name` and how Kong knows the Consumer
JWT contains a claim - by convention `iss` (issuer). The plugin reads that claim from the incoming token, then looks up the Consumer that has a `jwt_secrets[].key` matching it. That's how Kong maps a token to a Consumer.
:::

### Step 1.3 - Create a JWT secret for the Consumer (3 min)

```yaml [Append to the Consumer]
consumers:
  - username: partner-api-client
    custom_id: partner-001
    jwt_secrets:
      - key:      "partner-issuer"        # matches the `iss` in the token
        algorithm: HS256
        secret:    "super-secret-256-bit-key-do-not-leak"
```

Sync.

### Step 1.4 - Mint a token, then call (5 min) 🎯

Easiest local way to create a JWT: use [jwt.io](https://jwt.io) in your browser.

1. Open [jwt.io](https://jwt.io).
2. Set algorithm to **HS256**.
3. Payload:
   ```json
   {
     "iss": "partner-issuer",
     "exp": 9999999999,
     "sub": "partner-api-client"
   }
   ```
4. In "Verify signature": enter `super-secret-256-bit-key-do-not-leak`.
5. Copy the encoded token from the left panel.

```bash
export TOKEN="<paste-encoded-token-here>"
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.headers | {"X-Consumer-Username", "X-Credential-Identifier", "Authorization"}'
```

Expected:
```json
{
  "X-Consumer-Username": "partner-api-client",
  "X-Credential-Identifier": "partner-issuer",
  "Authorization": "Bearer eyJ..."
}
```

🎯 Kong validated the token, identified the Consumer via `iss`, and forwarded the request. (The `Authorization` header is still present - by default JWT doesn't strip it, unlike `key-auth`'s `hide_credentials`.)

### Step 1.5 - Test failure modes (3 min) 🧪

```bash
# No token
curl -i $KONNECT_PROXY_URL/flights/anything | head -3
# HTTP/2 401  {"message":"Unauthorized"}

# Wrong signature (change one character in the token)
BAD_TOKEN="${TOKEN:0:-5}XXXXX"
curl -i $KONNECT_PROXY_URL/flights/anything -H "Authorization: Bearer $BAD_TOKEN" | head -3
# HTTP/2 401  {"message":"Invalid signature"}

# Expired token (mint one with exp: 1000000000 - way in the past)
# Then call:
curl -i $KONNECT_PROXY_URL/flights/anything -H "Authorization: Bearer $EXPIRED" | head -3
# HTTP/2 401  {"message":"Token expired"}
```

::: tip JWT signing algorithms
- **HS256** - symmetric, one shared secret. Simple. Used in this lab.
- **RS256 / ES256** - asymmetric, your IdP signs with a private key, Kong verifies with the public key. Production default.

For RS256, the Consumer's `jwt_secrets[].rsa_public_key` holds the public PEM and Kong validates against it.
:::

---

## Part 2 - HMAC (Signed requests, ~20 min)

HMAC-auth is different from JWT: the client doesn't carry a token. Instead, **every request is individually signed** using a shared secret. The signature covers headers (and optionally body) so any tampering is detected.

### Step 2.1 - Add HMAC credentials to a Consumer (3 min)

```yaml [Add hmac_auth Consumer + credentials]
consumers:
  - username: data-feed-client
    custom_id: feed-001
    hmacauth_credentials:
      - username:  "feed-001"
        secret:    "feed-shared-secret-do-not-leak-256-bit"
```

Sync.

### Step 2.2 - Attach `hmac-auth` to a Route (3 min)

We'll re-purpose `flights-route` - but first remove the `jwt` plugin so we test HMAC cleanly:

```yaml [Replace jwt with hmac-auth on flights-route]
- name: flights-route
  paths: [/flights]
  strip_path: true
  plugins:
    - name: hmac-auth
      config:
        clock_skew: 300                    # seconds of allowed clock skew
        enforce_headers: [date, request-line, content-md5]   # ← these must be signed
        algorithms: [hmac-sha256]
        validate_request_body: true        # require body hash match
        hide_credentials: true
```

Sync.

### Step 2.3 - Build a signed request (8 min) 🎯

Signing manually is fiddly - let's do it. Here's the algorithm:

1. Compute `md5sum` of the request body → base64 encode → that's `Content-MD5`.
2. Build the "signing string": `date: <now>\nrequest-line: POST /flights/post HTTP/2\ncontent-md5: <md5>`.
3. HMAC-SHA256 that string with the shared secret → base64 → that's the `signature`.
4. Send `Authorization: hmac username="feed-001",algorithm="hmac-sha256",headers="date request-line content-md5",signature="<base64>"`.

```bash
BODY='{"feed":"prices","timestamp":1748700000}'
SECRET='feed-shared-secret-do-not-leak-256-bit'
USERNAME='feed-001'

DATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
CONTENT_MD5=$(printf '%s' "$BODY" | openssl dgst -md5 -binary | base64)
REQUEST_LINE="POST /flights/post HTTP/2"

SIGNING_STRING=$(printf 'date: %s\nrequest-line: %s\ncontent-md5: %s' \
  "$DATE" "$REQUEST_LINE" "$CONTENT_MD5")

SIGNATURE=$(printf '%s' "$SIGNING_STRING" \
  | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

curl -i -X POST "$KONNECT_PROXY_URL/flights/post" \
  -H "Date: $DATE" \
  -H "Content-MD5: $CONTENT_MD5" \
  -H "Authorization: hmac username=\"$USERNAME\",algorithm=\"hmac-sha256\",headers=\"date request-line content-md5\",signature=\"$SIGNATURE\"" \
  -H "Content-Type: application/json" \
  -d "$BODY"
```

Expected: HTTP 200 + httpbin echoes back your body.

🎯 Kong:
1. Read the `Authorization: hmac …` header.
2. Computed the expected signature for the request as Kong received it.
3. Compared. If equal → forward. If not → 401.

### Step 2.4 - Why HMAC is for high-security (3 min - read)

| Property | HMAC | JWT | key-auth |
|---|---|---|---|
| **Anyone replay an old request?** | ❌ Date check + clock skew window | ⚠ Until token expires | ✓ Yes, key is reusable |
| **Anyone modify the body?** | ❌ MD5 hash signed | ✓ JWT is a header, doesn't sign body | ✓ Yes |
| **Credential travels on every request?** | ❌ Only signature does, secret stays local | ✓ Token does | ✓ Key does |
| **Operational complexity** | High (clients must sign) | Medium | Low |

Use HMAC when the data is sensitive enough to merit the client-side complexity (financial feeds, healthcare, government).

### Step 2.5 - Failure modes (3 min) 🧪

```bash
# Replay the same request 6+ minutes later (clock skew exceeded)
sleep 360
# … re-run the same curl - should now return 401 "HMAC clock skew exceeded"

# Tamper with the body - change one character
curl -i -X POST "$KONNECT_PROXY_URL/flights/post" \
  -H "Date: $DATE" -H "Content-MD5: $CONTENT_MD5" \
  -H "Authorization: hmac ..."  \
  -d '{"feed":"TAMPERED","timestamp":1748700000}'
# → 401 "HMAC signature does not match"
```

---

## Recap - when to use which auth plugin

| Plugin | Use when |
|---|---|
| `key-auth` (M03) | Internal APIs, mobile apps, simple to bootstrap |
| `jwt` | Stateless tokens issued by your service; no Kong-side credential ops on every request |
| `hmac-auth` | High-security M2M; signed body + replay protection |
| `openid-connect` (07-C) | Browser SSO with your corporate IdP |
| `upstream-oauth` (07-D) | Kong injects an OAuth token for the *upstream*, not for the client |
| `oauth2` | Kong itself acts as an OAuth2 server (rarely needed when IdP exists) |

---

## Cleanup

We continue with the Service in 07-B (Consumer Groups + ACL). **Don't clean up yet.**

---

**Next:** [Lab 07-B - Consumer Groups & ACL →](./07-consumer-groups-acl)
