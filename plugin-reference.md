---
title: Plugin Reference
description: Quick-reference for every Kong plugin covered in the API Gateway Bootcamp - config tables, code snippets, and links to labs.
---

# 🧩 Plugin Reference

Quick-reference for all Kong plugins used across this bootcamp.
Click any plugin name to jump to the full lab.

| Plugin | Category | Lab |
|---|---|---|
| [key-auth](#key-auth) | Authentication | [Lab 03-A](/module-03-authentication/labs/03-key-auth) |
| [hmac-auth](#hmac-auth) | Authentication | [Lab 07-A](/module-07-enterprise/labs/07-advanced-auth) |
| [jwt](#jwt-auth) | Authentication | [Lab 07-A](/module-07-enterprise/labs/07-advanced-auth) |
| [openid-connect (Keycloak)](#openid-connect-with-keycloak) | Authentication | [Lab 07-C](/module-07-enterprise/labs/07-oidc-auth-code) |
| [openid-connect (Kong Identity)](#openid-connect-with-kong-identity) | Authentication | [Lab 07-A](/module-07-enterprise/labs/07-oidc-auth-code) |
| [upstream-oauth](#upstream-oauth) | Authentication | [Lab 07-C](/module-07-enterprise/labs/07-upstream-oauth) |
| [acl](#acl) | Authorization | [Lab 07-B](/module-07-enterprise/labs/07-consumer-groups-acl) |
| [cors](#cors) | Security | [Lab 03-B](/module-03-authentication/labs/03-easy-wins) |
| [ip-restriction](#ip-restriction) | Security | [Lab 03-B](/module-03-authentication/labs/03-easy-wins) |
| [opa](#opa) | Security | [Lab 07-D](/module-07-enterprise/labs/07-opa) |
| [rate-limiting-advanced](#rate-limiting-advanced) | Traffic Control | [Lab 04-A](/module-04-traffic-control/labs/04-rate-limiting) |
| [proxy-cache](#proxy-cache) | Traffic Control | [Lab 04-F](/module-04-traffic-control/labs/04-proxy-cache) |
| [proxy-cache-advanced](#proxy-cache-advanced) | Traffic Control | [Lab 04-F](/module-04-traffic-control/labs/04-proxy-cache) |
| [datakit](#datakit) | Traffic Control | [Lab 07-E](/module-07-enterprise/labs/07-datakit) |
| [request-transformer-advanced](#request-transformer-advanced) | Transformation | [Lab 05-A](/module-05-transformations/labs/05-request-transformer) |
| [response-transformer-advanced](#response-transformer-advanced) | Transformation | [Lab 05-B](/module-05-transformations/labs/05-response-transformer) |
| [correlation-id](#correlation-id) | Transformation | [Lab 03-B](/module-03-authentication/labs/03-easy-wins) |
| [opentelemetry](#opentelemetry) | Observability | [Lab 06-C](/module-06-observability/labs/06-opentelemetry) |
| [prometheus](#prometheus) | Observability | [Lab 06-B](/module-06-observability/labs/06-prometheus) |
| [http-log](#http-log) | Observability | [Lab 06-A](/module-06-observability/labs/06-http-logging) |

---

## key-auth

> Protects routes with API key authentication. Keys can be passed via header or query parameter.

**Module:** [03 - Authentication](/module-03-authentication/) · **Lab:** [03-A](/module-03-authentication/labs/03-key-auth)

### Quick Config

::: code-group

```yaml [decK YAML]
plugins:
  - name: key-auth
    config:
      key_names: [X-API-Key, apikey]
      key_in_header: true
      key_in_query: true
      key_in_body: false
      hide_credentials: true
```

```bash [Admin API]
curl -X POST http://localhost:8001/routes/{route}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "key-auth",
    "config": {
      "key_names": ["X-API-Key", "apikey"],
      "hide_credentials": true
    }
  }'
```

:::

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `key_names` | `["apikey"]` | Header / query param names to check |
| `key_in_header` | `true` | Accept key in request headers |
| `key_in_query` | `true` | Accept key in query string |
| `key_in_body` | `false` | Accept key in request body |
| `hide_credentials` | `false` | Strip key before forwarding to upstream |
| `anonymous` | `null` | Fallback consumer if unauthenticated (for multi-auth) |
| `run_on_preflight` | `true` | Check auth on OPTIONS requests |

### Create a Consumer Key

```bash
curl -X POST http://localhost:8001/consumers/my-consumer/key-auth \
  -H "Content-Type: application/json" \
  -d '{"key": "my-secret-api-key"}'
```

---

## jwt-auth

> Validates JSON Web Tokens. Kong verifies the signature using the consumer's registered secret or RSA public key.

**Module:** [07 - Enterprise & Advanced](/module-07-enterprise/) · **Lab:** [07-A Advanced Auth (JWT + HMAC)](/module-07-enterprise/labs/07-advanced-auth)

### Quick Config

```yaml
plugins:
  - name: jwt
    config:
      key_claim_name: iss
      claims_to_verify: [exp]
      header_names: [Authorization]
      secret_is_base64: false
```

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `key_claim_name` | `iss` | JWT claim that identifies the consumer credential |
| `claims_to_verify` | `["exp"]` | Claims to validate (`exp`, `nbf`) |
| `header_names` | `["Authorization"]` | Headers to look for the JWT |
| `cookie_names` | `[]` | Cookie names to check for JWT |
| `uri_param_names` | `["jwt"]` | Query params to check for JWT |
| `secret_is_base64` | `false` | Whether the consumer secret is base64-encoded |
| `anonymous` | `null` | Fallback consumer for unauthenticated requests |

---

## hmac-auth

> Protects routes using HMAC signature authentication. Clients sign each request with a username and HMAC secret; Kong validates the signature and clock skew before proxying.

Min version: Kong Gateway 1.0 | [Plugin Hub](https://developer.konghq.com/plugins/hmac-auth/)

**Module:** [07 - Enterprise & Advanced](/module-07-enterprise/) · **Lab:** [07-A Advanced Auth (JWT + HMAC)](/module-07-enterprise/labs/07-advanced-auth)

### Quick Config

::: code-group

```yaml [decK YAML]
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
        - hmac-sha512
      validate_request_body: false
```

```bash [Admin API]
curl -X POST http://localhost:8001/routes/{route}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hmac-auth",
    "config": {
      "hide_credentials": true,
      "clock_skew": 300,
      "algorithms": ["hmac-sha256"]
    }
  }'
```

:::

### Create Consumer Credential

```bash
curl -X POST http://localhost:8001/consumers/my-consumer/hmac-auth \
  -H "Content-Type: application/json" \
  -d '{"username": "my-consumer", "secret": "my-shared-secret"}'
```

### Request Signing Format

Clients must send an `Authorization` header:

```
Authorization: hmac username="<username>", algorithm="hmac-sha256", headers="date @request-target", signature="<base64-signature>"
```

The signature is a base64-encoded HMAC of the signing string - a newline-concatenation of the signed header values. Recommended headers to sign: `date`, `@request-target`, `host`.

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `algorithms` | `["hmac-sha256"]` | Allowed algorithms: `hmac-sha224`, `hmac-sha256`, `hmac-sha384`, `hmac-sha512` |
| `clock_skew` | `300` | Max allowed time drift in seconds between client and server |
| `enforce_headers` | `[]` | Headers the client *must* include in the signature |
| `validate_request_body` | `false` | If `true`, validates a `Digest: SHA-256=<base64>` header against the request body |
| `hide_credentials` | `false` | Strip the `Authorization` header before proxying to upstream |
| `anonymous` | `null` | Fallback consumer if authentication fails (multi-auth setups) |

---

## openid-connect with Keycloak

> Full browser-based SSO using OIDC Authorization Code Flow. Kong acts as the OIDC Relying Party; Keycloak is the IdP. Tokens never reach the browser - all exchange is server-side.

**Module:** [07 - Enterprise & Advanced](/module-07-enterprise/) · **Lab:** [07-C OIDC Authorization Code Flow](/module-07-enterprise/labs/07-oidc-auth-code)

### Quick Config

```yaml
plugins:
  - name: openid-connect
    config:
      issuer: "http://keycloak:8080/realms/workshop"
      client_id:
        - kong-demo
      client_secret:
        - kong-demo-secret
      scopes:
        - openid
        - profile
        - email
      auth_methods:
        - authorization_code
        - session
      response_mode: form_post
      redirect_uri:
        - http://localhost:8000/api/users/profile
      login_action: redirect
      logout_path: /logout
      session_secret: "change-this-to-a-32-char-secret!!"
```

### Configuration Reference

| Parameter | Description |
|---|---|
| `issuer` | IdP OIDC discovery URL (base, without `/.well-known/...`) |
| `client_id` | Kong's registered client ID at the IdP |
| `client_secret` | Kong's registered client secret |
| `auth_methods` | Allowed flows: `authorization_code`, `client_credentials`, `session`, `bearer` |
| `response_mode` | How auth code is returned: `query` or `form_post` (prefer `form_post`) |
| `scopes` | OIDC scopes to request from the IdP |
| `session_secret` | AES key for session cookie encryption (min 32 chars) |
| `session_rolling_timeout` | Inactivity timeout in seconds (default: `3600`) |
| `session_absolute_timeout` | Hard max session duration (default: `86400`) |
| `login_action` | What to do when unauthenticated: `redirect` (browser) or `deny` (API) |
| `logout_path` | Path that triggers RP-initiated logout |
| `logout_revoke` | Revoke tokens at IdP on logout |
| `userinfo_headers_claims` | Claims from userinfo to inject as headers |
| `upstream_headers_names` | Header names for the injected claims |

---

## openid-connect with Kong Identity

> Configure the OIDC plugin using **Kong Konnect Identity** (Kong's built-in IdP) as the issuer - no external Keycloak required for service-to-service or admin API protection.

**Module:** [07 - OIDC & RBAC](/module-07-enterprise/) · **Lab:** [07-A](/module-07-enterprise/labs/07-oidc-auth-code)

Kong Identity is Kong Konnect's native OIDC/OAuth2 provider. It issues tokens for machine-to-machine authentication and can be used to protect APIs without deploying a separate IdP.

### Get your Kong Identity issuer URL

In Konnect: **Settings → Identity** → copy the Issuer URL. It looks like:

```
https://<region>.api.konghq.com/konnect-oidc/<org-id>
```

### Quick Config

```yaml
plugins:
  - name: openid-connect
    config:
      issuer: "https://us.api.konghq.com/konnect-oidc/<your-org-id>"
      client_id:
        - <konnect-app-client-id>
      client_secret:
        - <konnect-app-client-secret>
      auth_methods:
        - client_credentials
        - bearer
      scopes:
        - openid
        - konnect-oidc
      bearer_token_param_type:
        - header
      login_action: deny
```

### Client Credentials flow (M2M)

```bash
# 1. Get a token from Kong Identity
TOKEN=$(curl -s -X POST \
  "https://us.api.konghq.com/konnect-oidc/<org-id>/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=<your-client-id>" \
  -d "client_secret=<your-client-secret>" \
  | jq -r '.access_token')

# 2. Call the API with the Bearer token
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/protected-resource
```

### Kong Identity vs External IdP

| | Kong Identity | Keycloak / External IdP |
|---|---|---|
| **Setup** | Zero-config in Konnect | Deploy & configure separately |
| **Use case** | M2M, service accounts | Browser SSO, social login |
| **Token issuer** | `*.api.konghq.com` | Your IdP host |
| **PKCE** | Supported | Supported |
| **User management** | Konnect portal teams | IdP user store |

---

## upstream-oauth

> **Enterprise.** Allows Kong Gateway to obtain an OAuth 2.0 access token from a configured IdP and inject it into upstream requests - enables machine-to-machine auth without exposing credentials to the client.

::: tip Kong Gateway Enterprise required
`upstream-oauth` requires Kong Gateway Enterprise or Konnect. Min version: Kong Gateway 3.8. [Plugin Hub](https://developer.konghq.com/plugins/upstream-oauth/)
:::

**Module:** [07 - Enterprise](/module-07-enterprise/) · **Lab:** [07-C](/module-07-enterprise/labs/07-upstream-oauth)

### How It Works

```
Client → Kong Gateway → [fetch/cache token from IdP] → Upstream API (Bearer token injected)
```

Kong caches the access token until its `expires_in`. Subsequent requests reuse the cached token without contacting the IdP again.

### Quick Config

::: code-group

```yaml [Client Secret (M2M)]
plugins:
  - name: upstream-oauth
    config:
      oauth:
        token_endpoint: "https://idp.example.com/oauth/token"
        grant_type: client_credentials
        client_id: kong-m2m-client
        client_secret: kong-m2m-secret
        scopes:
          - api.read
      client_auth_method: client_secret_basic
      cache:
        strategy: memory
```

```yaml [Redis cache]
plugins:
  - name: upstream-oauth
    config:
      oauth:
        token_endpoint: "https://idp.example.com/oauth/token"
        grant_type: client_credentials
        client_id: kong-m2m-client
        client_secret: kong-m2m-secret
      client_auth_method: client_secret_post
      cache:
        strategy: redis
        redis:
          host: redis
          port: 6379
```

:::

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `oauth.token_endpoint` | - | IdP token endpoint URL |
| `oauth.grant_type` | `client_credentials` | OAuth grant type |
| `oauth.client_id` | - | OAuth client ID registered at the IdP |
| `oauth.client_secret` | - | OAuth client secret |
| `oauth.scopes` | `[]` | OAuth scopes to request |
| `client_auth_method` | `client_secret_basic` | Auth method: `client_secret_basic`, `client_secret_post`, `client_secret_jwt` |
| `cache.strategy` | `memory` | Token cache backend: `memory` or `redis` |
| `token_header_name` | `Authorization` | Request header used to inject the token upstream |
| `token_prefix` | `Bearer ` | Prefix prepended to the token value |

---

## acl

> Group-based access control. Consumers belong to groups; routes allow or deny by group. Must be combined with an authentication plugin (key-auth, jwt, or oidc).

**Module:** [07 - Enterprise & Advanced](/module-07-enterprise/) · **Lab:** [07-B Consumer Groups & ACL](/module-07-enterprise/labs/07-consumer-groups-acl)

### Quick Config

::: code-group

```yaml [decK YAML - allowlist]
plugins:
  - name: acl
    config:
      allow:
        - premium-tier
        - admin-tier
      hide_groups_header: true
```

```yaml [decK YAML - denylist]
plugins:
  - name: acl
    config:
      deny:
        - blocked-users
      hide_groups_header: true
```

:::

### Assign consumer to group

```bash
# Create a consumer group
curl -X PUT http://localhost:8001/consumer_groups/premium-tier \
  -d '{"name":"premium-tier"}'

# Add a consumer to the group
curl -X POST http://localhost:8001/consumer_groups/premium-tier/consumers \
  -H "Content-Type: application/json" \
  -d '{"consumer": "travel-web-app"}'
```

### Configuration Reference

| Parameter | Description |
|---|---|
| `allow` | List of group names that **are permitted** |
| `deny` | List of group names that **are blocked** |
| `hide_groups_header` | Don't send `X-Consumer-Groups` to upstream |

::: warning
Specify either `allow` **or** `deny`, not both.
:::

---

## cors

> Adds Cross-Origin Resource Sharing (CORS) response headers so browsers can make cross-origin requests to your APIs. Configure allowed origins, methods, headers, and credentials policy.

Min version: Kong Gateway 1.0 | [Plugin Hub](https://developer.konghq.com/plugins/cors/)

**Module:** [03 - Easy Wins](/module-03-authentication/) · **Lab:** [03-B CORS, IP, Correlation](/module-03-authentication/labs/03-easy-wins)

### Quick Config

::: code-group

```yaml [Specific origins]
plugins:
  - name: cors
    config:
      origins:
        - "https://app.example.com"
        - "https://admin.example.com"
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
        - X-RateLimit-Remaining
      credentials: true
      max_age: 3600
      preflight_continue: false
```

```yaml [Wildcard (open APIs)]
plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:
        - GET
        - POST
      headers:
        - Authorization
        - Content-Type
      credentials: false
      max_age: 600
```

:::

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `origins` | `["*"]` | Allowed origins (list of URLs, or `*` for any) |
| `methods` | `["GET","HEAD","PUT","PATCH","POST","DELETE"]` | Allowed HTTP methods |
| `headers` | `[]` | Allowed request headers (`Access-Control-Allow-Headers`) |
| `exposed_headers` | `[]` | Headers exposed to browser JS (`Access-Control-Expose-Headers`) |
| `credentials` | `false` | Allow cookies/auth headers. Cannot be combined with `origins: ["*"]` |
| `max_age` | `null` | Preflight cache duration in seconds (`Access-Control-Max-Age`) |
| `preflight_continue` | `false` | Forward `OPTIONS` preflight requests to upstream instead of responding immediately |

::: warning
`credentials: true` is incompatible with `origins: ["*"]`. Use explicit origin URLs when credentials are required.
:::

::: tip
Use the CORS plugin only on Routes matching on **paths or methods** - not Host-only routes. Browsers cannot send a custom `Host` header during preflight.
:::

---

## ip-restriction

> Restricts access to a Service or Route by allowing or blocking client IP addresses. Supports single IPs, multiple IPs, and CIDR notation for IPv4 and IPv6.

Min version: Kong Gateway 1.0 | [Plugin Hub](https://developer.konghq.com/plugins/ip-restriction/)

**Module:** [03 - Easy Wins](/module-03-authentication/) · **Lab:** [03-B CORS, IP, Correlation](/module-03-authentication/labs/03-easy-wins)

### Quick Config

::: code-group

```yaml [Allowlist]
plugins:
  - name: ip-restriction
    config:
      allow:
        - 10.0.0.0/8          # internal network
        - 192.168.1.100        # trusted IP
      status: 403
      message: "Your IP address is not permitted."
```

```yaml [Denylist]
plugins:
  - name: ip-restriction
    config:
      deny:
        - 203.0.113.42         # known bad actor
        - 198.51.100.0/24      # blocked range
      status: 403
```

:::

### IP Address Detection

Kong reads the client IP from `X-Real-IP` by default. For deployments behind a load balancer, update `kong.conf`:

```ini
real_ip_header = X-Forwarded-For
trusted_ips    = 10.0.0.0/8, 172.16.0.0/12
```

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `allow` | `[]` | Allowlist of IPs/CIDRs - all other IPs are blocked |
| `deny` | `[]` | Denylist of IPs/CIDRs - all other IPs are allowed |
| `status` | `403` | HTTP status code returned when access is denied |
| `message` | `"Your IP address is not allowed"` | Error message body when denied |

::: tip
Combine `allow` and `deny` to, for example, permit an entire CIDR range but block specific IPs within it.
:::

---

## opa

> **Enterprise.** Integrates with [Open Policy Agent (OPA)](https://www.openpolicyagent.org/) for policy-based authorization. Kong forwards request context to OPA; the request is allowed or rejected based on the Rego policy evaluation result.

::: tip Kong Gateway Enterprise required
`opa` requires Kong Gateway Enterprise or Konnect. Min version: Kong Gateway 2.4. [Plugin Hub](https://developer.konghq.com/plugins/opa/)
:::

**Module:** [07 - Enterprise](/module-07-enterprise/) · **Lab:** [07-D](/module-07-enterprise/labs/07-opa)

### How It Works

```
Client → Kong → OPA (Rego policy eval) → allow/deny → Upstream
```

Kong sends a JSON payload containing the request's headers, path, method, consumer, and service data to OPA's REST API. OPA evaluates the policy and returns a boolean or a structured response with custom headers and status code.

### Quick Config

```yaml
plugins:
  - name: opa
    config:
      opa_host: opa
      opa_port: 8181
      opa_path: /v1/data/myapp/authz/allow
      include_consumer_in_opa_input: true
      include_service_in_opa_input: true
      include_route_in_opa_input: false
      ssl_verify: true
```

### OPA Input Structure

Kong sends the following JSON to OPA:

```json
{
  "input": {
    "request": {
      "http": {
        "method": "GET",
        "path": "/api/flights",
        "host": "api.example.com",
        "headers": { "authorization": "Bearer ..." },
        "querystring": { "page": "1" }
      }
    },
    "client_ip": "10.0.0.5",
    "consumer": { "id": "...", "username": "alice" },
    "service": { "name": "flights-service" }
  }
}
```

### Example Rego Policy

```go
package myapp.authz

default allow = false

allow {
  input.request.http.method == "GET"
  input.consumer.username != ""
}
```

### OPA Response Formats

**Boolean (simple):**
```json
{ "result": true }
```

**Object (custom headers / status code):**
```json
{
  "result": {
    "allow": false,
    "status": 403,
    "message": "Access denied by policy",
    "headers": { "X-Policy-Denied": "true" }
  }
}
```

### Configuration Reference

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

## proxy-cache-advanced

> Enterprise response caching plugin. Caches upstream responses in memory or Redis and serves them directly from Kong - reduces upstream load and improves latency.

::: tip Kong Gateway Enterprise required
`proxy-cache-advanced` is an Enterprise plugin. The open-source edition includes `proxy-cache` (memory-only, no Redis, no cache bypass controls).
:::

**Module:** [04 - Traffic Control](/module-04-traffic-control/) · **Lab:** [04-F](/module-04-traffic-control/labs/04-proxy-cache)

### Quick Config

::: code-group

```yaml [Memory (dev / demo)]
plugins:
  - name: proxy-cache-advanced
    config:
      strategy: memory
      memory:
        dictionary_name: kong_db_cache
      response_code:
        - 200
        - 301
      request_method:
        - GET
        - HEAD
      content_type:
        - application/json
        - text/plain
      cache_ttl: 300        # 5 minutes
      cache_control: false  # ignore Cache-Control headers
      ignore_uri_case: false
```

```yaml [Redis (production)]
plugins:
  - name: proxy-cache-advanced
    config:
      strategy: redis
      redis:
        host: redis
        port: 6379
        timeout: 2000
        password: ""          # set if Redis auth is enabled
        database: 0
        cluster_addresses: [] # for Redis Cluster
        sentinel_master: ""   # for Redis Sentinel
      response_code:
        - 200
      request_method:
        - GET
        - HEAD
      content_type:
        - application/json
      cache_ttl: 600          # 10 minutes
      cache_control: true     # respect Cache-Control: no-cache headers
```

:::

### Admin API

```bash
# Apply to a route
curl -X POST http://localhost:8001/routes/{route}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "proxy-cache-advanced",
    "config": {
      "strategy": "memory",
      "response_code": [200],
      "request_method": ["GET"],
      "cache_ttl": 300
    }
  }'

# Check cache status via response headers
curl -si http://localhost:8000/api/flights | grep -i "X-Cache"
# X-Cache-Status: Miss  (first request - cached)
# X-Cache-Status: Hit   (subsequent requests - served from cache)

# Purge cache for a specific resource
curl -X DELETE http://localhost:8001/proxy-cache-advanced/{cache-key}
```

### Cache Response Headers

| Header | Values | Meaning |
|---|---|---|
| `X-Cache-Status` | `Miss` | First request, response cached |
| `X-Cache-Status` | `Hit` | Served from cache |
| `X-Cache-Status` | `Bypass` | Request bypassed cache (POST, or Cache-Control: no-cache) |
| `X-Cache-Status` | `Refresh` | Cache entry expired, upstream called |
| `X-Cache-Key` | hash string | Cache lookup key |
| `Age` | seconds | How long this entry has been cached |

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `strategy` | `memory` | Storage backend: `memory` or `redis` |
| `cache_ttl` | `300` | Cache entry lifetime in seconds |
| `response_code` | `[200, 301, 404]` | HTTP status codes to cache |
| `request_method` | `[GET, HEAD]` | HTTP methods to cache |
| `content_type` | `[text/plain, application/json]` | Content-Type headers to cache |
| `cache_control` | `false` | Honour `Cache-Control: no-cache` / `no-store` |
| `ignore_uri_case` | `false` | Treat `/Flights` and `/flights` as the same key |
| `vary_headers` | `[]` | Additional headers that form part of the cache key |
| `memory.dictionary_name` | `kong_db_cache` | Shared memory zone name |
| `redis.host` | - | Redis server hostname |
| `redis.port` | `6379` | Redis server port |
| `redis.timeout` | `2000` | Redis connection timeout (ms) |

### Cache Key

The default cache key is a hash of:

```
method + host + uri + query_string
```

Add `vary_headers` to scope the cache per-consumer or per-API-version:

```yaml
config:
  vary_headers:
    - Authorization    # different cache per bearer token
    - X-API-Version    # different cache per version header
```

---

## proxy-cache

> Reverse proxy caching using in-memory storage (free tier). Caches upstream responses and serves them directly from Kong to reduce upstream load and improve latency. For Redis/cluster support and advanced controls, see [proxy-cache-advanced](#proxy-cache-advanced).

Min version: Kong Gateway 1.2 | [Plugin Hub](https://developer.konghq.com/plugins/proxy-cache/)

**Module:** [04 - Traffic Control](/module-04-traffic-control/) · **Lab:** [04-F](/module-04-traffic-control/labs/04-proxy-cache)

### Quick Config

```yaml
plugins:
  - name: proxy-cache
    config:
      strategy: memory
      memory:
        dictionary_name: kong_db_cache
      response_code:
        - 200
        - 301
      request_method:
        - GET
        - HEAD
      content_type:
        - application/json
        - text/plain
      cache_ttl: 300
      cache_control: false
```

### Admin API

```bash
# Apply to a route
curl -X POST http://localhost:8001/routes/{route}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "proxy-cache",
    "config": {
      "strategy": "memory",
      "response_code": [200],
      "request_method": ["GET"],
      "cache_ttl": 300
    }
  }'

# Check cache status from response headers
curl -si http://localhost:8000/api/resource | grep X-Cache
# X-Cache-Status: Miss   (first request - cached now)
# X-Cache-Status: Hit    (subsequent requests from cache)
```

### Cache Response Headers

| Header | Value | Meaning |
|---|---|---|
| `X-Cache-Status` | `Miss` | Not in cache; response stored now |
| `X-Cache-Status` | `Hit` | Served from cache |
| `X-Cache-Status` | `Bypass` | Request not cacheable (e.g. POST method) |
| `X-Cache-Status` | `Refresh` | Cache expired; upstream called again |
| `X-Cache-Key` | hash | Cache lookup key for this request |

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `strategy` | `memory` | Storage backend (`memory` only - use `proxy-cache-advanced` for Redis) |
| `cache_ttl` | `300` | Entry lifetime in seconds |
| `response_code` | `[200, 301, 404]` | HTTP response codes to cache |
| `request_method` | `[GET, HEAD]` | HTTP methods to cache |
| `content_type` | `[text/plain, application/json]` | Content-Types to cache |
| `cache_control` | `false` | Respect `Cache-Control: no-cache` / `no-store` headers |
| `memory.dictionary_name` | `kong_db_cache` | Shared memory zone name |
| `vary_query_params` | `[]` | Query parameters included in the cache key |
| `vary_headers` | `[]` | Request headers included in the cache key |

---

## request-transformer-advanced

> Modify inbound requests - add, remove, replace, rename, or append headers, query parameters, and body fields. The **advanced** (Enterprise) variant adds Lua templating and conditional logic.

**Module:** [05 - Transformations](/module-05-transformations/) · **Lab:** [05-A](/module-05-transformations/labs/05-request-transformer)

### Quick Config

```yaml
plugins:
  - name: request-transformer-advanced
    config:
      add:
        headers:
          - "X-Kong-Proxied:true"
          - "X-Consumer-Username:$(consumer.username)"   # template variable
          - "X-Request-Time:$(date.timestamp)"
        querystring: []
        body: []
      remove:
        headers:
          - X-Internal-Debug
          - X-Forwarded-Secret
        querystring:
          - debug
          - trace
      replace:
        headers:
          - "X-API-Version:v3"
      rename:
        querystring:
          - "page:offset"      # external ?page= → upstream ?offset=
          - "size:limit"       # external ?size= → upstream ?limit=
      dots_in_keys: false
      allow:
        body: []               # allowlist body fields (blocks everything else)
```

### Template Variables

| Variable | Value |
|---|---|
| `$(consumer.id)` | Authenticated consumer UUID |
| `$(consumer.username)` | Authenticated consumer username |
| `$(consumer.custom_id)` | Consumer custom identifier |
| `$(route.id)` | Route UUID |
| `$(service.id)` | Service UUID |
| `$(service.name)` | Service name |
| `$(date.timestamp)` | Unix epoch timestamp |

### Configuration Reference

| Operation | Behaviour |
|---|---|
| `add` | Add field if it does **not** already exist |
| `append` | Add field even if it exists (creates multi-value) |
| `remove` | Delete field if it exists |
| `replace` | Overwrite field if it exists; no-op if absent |
| `rename` | Rename field key (value unchanged) |
| `allow` | Allowlist - fields not listed are **stripped** |

---

## response-transformer-advanced

> Modify outbound responses - add, remove, replace headers and JSON body fields. The **advanced** variant supports JSON path operations on nested objects and Lua transformation functions.

**Module:** [05 - Transformations](/module-05-transformations/) · **Lab:** [05-B](/module-05-transformations/labs/05-response-transformer)

### Quick Config

```yaml
plugins:
  - name: response-transformer-advanced
    config:
      add:
        headers:
          - "X-Powered-By:Kong Gateway"
        json:
          - "metadata.gateway:\"kong\""
          - "api_version:\"v2\""
        json_types:
          - string
          - string
      remove:
        headers:
          - X-Served-By
          - Via
          - Server
        json:
          - data.internal_cost
          - data.provider_id
      replace:
        json:
          - "status:\"processed\""
        json_types:
          - string
      rename:
        headers:
          - "X-Legacy-Id:X-Canonical-Id"
      allow:
        json: []               # allowlist - strips all other JSON fields
```

### JSON Path Operations (Advanced)

```yaml
config:
  transform:
    functions:
      - |
        local body = require("cjson").decode(kong.response.get_raw_body())
        body.served_at = ngx.now()
        body.node_id = kong.node.get_id()
        kong.response.set_raw_body(require("cjson").encode(body))
```

### Configuration Reference

| Parameter | Description |
|---|---|
| `add.json` | Add JSON key:value if absent (flat or nested path) |
| `add.json_types` | Type for each added JSON value (`string`, `boolean`, `number`) |
| `remove.json` | Remove JSON field by key or dotted path |
| `replace.json` | Overwrite JSON field if it exists |
| `allow.json` | Allowlist - all other JSON fields are stripped from the response |
| `transform.functions` | Lua snippets for arbitrary body manipulation |

---

## correlation-id

> Injects a unique ID into every request (and optionally the response) for end-to-end tracing across Kong logs, upstream services, and external systems.

Min version: Kong Gateway 1.0 | [Plugin Hub](https://developer.konghq.com/plugins/correlation-id/)

**Module:** [03 - Easy Wins](/module-03-authentication/) · **Lab:** [03-B CORS, IP, Correlation](/module-03-authentication/labs/03-easy-wins)

### Quick Config

::: code-group

```yaml [decK YAML]
plugins:
  - name: correlation-id
    config:
      header_name: Kong-Request-ID
      generator: uuid#counter
      echo_downstream: true
```

```bash [Admin API]
curl -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "correlation-id",
    "config": {
      "header_name": "Kong-Request-ID",
      "generator": "uuid#counter",
      "echo_downstream": true
    }
  }'
```

:::

### Generator Options

| Generator | Format | Example |
|---|---|---|
| `uuid` | Standard UUID v4 | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| `uuid#counter` | UUID + request counter | `a1b2c3d4-...#42` |
| `tracker` | Jaeger-compatible | `0123456789abcdef:0123456789abcdef:0` |

### Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `header_name` | `Kong-Request-ID` | Header injected into the request (and response if `echo_downstream` is true) |
| `generator` | `uuid#counter` | ID generation format: `uuid`, `uuid#counter`, or `tracker` |
| `echo_downstream` | `false` | Return the correlation ID in the response headers |

---

## rate-limiting-advanced

> Consumer-aware rate limiting with sliding window support, Redis clustering, and namespace isolation.

**Module:** [04 - Traffic Control](/module-04-traffic-control/) · **Lab:** [04-A](/module-04-traffic-control/labs/04-rate-limiting)

### Quick Config

```yaml
plugins:
  - name: rate-limiting-advanced
    config:
      limit:
        - 60      # 60 requests per minute
        - 1000    # 1000 requests per hour
      window_size:
        - 60
        - 3600
      window_type: sliding   # sliding | fixed
      identifier: consumer   # consumer | ip | credential | header | path
      sync_rate: 10          # sync local counters to Redis every 10 seconds
      namespace: api-gateway-bootcamp
      retry_after_jitter_max: 0
      hide_client_headers: false
```

---

## opentelemetry

> Export distributed traces via OTLP to any OpenTelemetry-compatible backend (Jaeger, Grafana Tempo, Zipkin, Datadog).

**Module:** [06 - Observability](/module-06-observability/) · **Lab:** [06-C](/module-06-observability/labs/06-opentelemetry)

### Quick Config

```yaml
plugins:
  - name: opentelemetry
    config:
      endpoint: "http://otel-collector:4318/v1/traces"
      resource_attributes:
        service.name: kong-gateway
        deployment.environment: bootcamp
      propagation:
        default_format: w3c
        extract:
          - w3c
          - b3
        inject:
          - w3c
      batch_span_processor:
        max_export_batch_size: 200
        scheduled_delay: 5000
```

---

## prometheus

> Expose Kong gateway metrics in Prometheus format at `/metrics` on the status port (`:8100`).

**Module:** [06 - Observability](/module-06-observability/) · **Lab:** [06-B](/module-06-observability/labs/06-prometheus)

### Quick Config

```yaml
plugins:
  - name: prometheus
    config:
      status_code_metrics: true
      latency_metrics: true
      bandwidth_metrics: true
      upstream_health_metrics: true
      per_consumer: true
```

---

## http-log

> Stream structured access logs to any HTTP endpoint as POST requests.

**Module:** [06 - Observability](/module-06-observability/) · **Lab:** [06-A](/module-06-observability/labs/06-http-logging)

### Quick Config

```yaml
plugins:
  - name: http-log
    config:
      http_endpoint: "http://log-receiver:3000/logs"
      method: POST
      content_type: application/json
      timeout: 10000
      keepalive: 60000
      flush_timeout: 2
      queue_size: 1
```

---

## datakit

> **Enterprise.** Node-based API workflow engine. Orchestrate third-party API calls, transform data with jq, decode/sign/verify JWTs, and conditionally modify requests and responses - all within a single Kong plugin.

::: tip Kong Gateway Enterprise required
`datakit` requires Kong Gateway Enterprise or Konnect. Min version: Kong Gateway 3.11. [Plugin Hub](https://developer.konghq.com/plugins/datakit/)
:::

**Module:** [07 - Enterprise](/module-07-enterprise/) · **Lab:** [07-E](/module-07-enterprise/labs/07-datakit)

### Use Cases

| Pattern | Description |
|---|---|
| Third-party auth injection | Fetch an internal auth token and inject it as a request header before proxying |
| Request multiplexing | Call multiple upstream APIs in parallel and merge responses into one |
| Dynamic header manipulation | Add, remove, or transform request/response headers using jq |
| JWT sign / verify | Decode an incoming JWT, validate claims, and sign a new JWT for upstream |
| XML ↔ JSON conversion | Transform XML requests to JSON for REST upstreams (and JSON responses back to XML) |
| Conditional cache | Serve cached responses on hit; fetch and store on miss using `branch` + `cache` nodes |
| Vault secret injection | Pull secrets from HashiCorp Vault and use them as auth headers |

### Core Concepts

A Datakit config is a **directed acyclic graph (DAG) of nodes**. Each node consumes inputs and produces outputs. Nodes are connected by referencing the source node's `name`:

```yaml
- name: FETCH_TOKEN
  type: call
  url: https://idp.example.com/oauth/token
  method: POST

- name: INJECT_HEADER
  type: jq
  input: FETCH_TOKEN.body           # connects FETCH_TOKEN.body → this node
  jq: '{ "Authorization": ("Bearer " + .access_token) }'
  output: service_request.headers   # result sets upstream request headers
```

### Node Types

| Node | Type | Purpose |
|---|---|---|
| Call | `call` | Make an external HTTP request (async/parallel by default) |
| jq | `jq` | Transform data using a [jq](https://jqlang.org/) expression |
| Static | `static` | Provide hardcoded input values |
| Property | `property` | Get or set Kong context properties (`kong.ctx.shared.*`, consumer, route, etc.) |
| Exit | `exit` | Return a response to the client immediately, bypassing upstream |
| Branch | `branch` | Conditional execution: `then`/`else` lists based on a boolean input |
| Cache | `cache` | Store or fetch data from memory or Redis |
| JWT Decode | `jwt_decode` | Decode a JWT without signature verification |
| JWT Sign | `jwt_sign` | Create and sign a new JWT (HS256/RS256/ES256) |
| JWT Verify | `jwt_verify` | Verify a JWT's signature and claims (JWKS/JWK/PEM/HMAC) |
| XML→JSON | `xml_to_json` | Parse an XML string into JSON |
| JSON→XML | `json_to_xml` | Serialize JSON into an XML string |

### Implicit Nodes (Always Available)

| Node | Inputs | Outputs |
|---|---|---|
| `request` | - | `body`, `headers`, `query`, `method`, `path`, `scheme` |
| `service_request` | `body`, `headers`, `query` | - |
| `service_response` | - | `body`, `headers`, `status` |
| `response` | `body`, `headers` | - |

### Quick Config - Third-party Auth Injection

```yaml
plugins:
  - name: datakit
    config:
      nodes:
        - name: TOKEN_BODY
          type: static
          values:
            grant_type: client_credentials
            client_id: my-client
            client_secret: my-secret

        - name: FETCH_TOKEN
          type: call
          url: https://idp.example.com/oauth/token
          method: POST
          input: TOKEN_BODY

        - name: AUTH_HEADER
          type: jq
          input: FETCH_TOKEN.body
          jq: '{ "Authorization": ("Bearer " + .access_token) }'
          output: service_request.headers
```

### Configuration Reference

| Parameter | Description |
|---|---|
| `nodes` | Array of node definitions forming the workflow DAG |
| `nodes[].name` | Unique node name used in I/O references |
| `nodes[].type` | Node type: `call`, `jq`, `static`, `property`, `exit`, `branch`, `cache`, `jwt_decode`, `jwt_sign`, `jwt_verify`, `xml_to_json`, `json_to_xml` |
| `nodes[].input` | Single input connection (`{node}` or `{node}.{field}`) |
| `nodes[].inputs` | Named input connections map |
| `nodes[].output` | Single output connection |
| `nodes[].outputs` | Named output connections map |
| `resources.cache` | Cache resource config for `cache` nodes (`strategy`: `memory` or `redis`) |
| `resources.vault` | Vault secret references used in nodes |
| `debug` | Enable detailed error output in responses (**dev/test only - never in production**) |

---

*[← Back to Home](/)*

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
