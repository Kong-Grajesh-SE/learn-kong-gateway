# Lab 07-D - Upstream OAuth (M2M Token Injection)

> **Goal.** In ~30 minutes you'll configure Kong to **fetch an OAuth2 client-credentials token from an IdP** and inject it as `Authorization: Bearer <token>` for every upstream request. Your internal services get a clean Bearer token without ever seeing client credentials.
>
> **Pattern.** This is the **machine-to-machine** counterpart to Lab 07-C's browser flow. Tokens are issued to *Kong* on behalf of the API, not to the client.

::: warning Enterprise plugin
`upstream-oauth` requires **Kong Gateway Enterprise** or **Konnect**. Min version: Kong Gateway 3.8 - but we're on 3.14, so you're good.
:::

::: tip OIDC vs Upstream OAuth - who is the token *for*?
- **OIDC (07-C)**: Token authenticates the **client** (a human user). Kong validates it; upstream typically reads `X-Authenticated-Userid`.
- **Upstream OAuth (this lab)**: Token authenticates **Kong itself** to a *downstream API* that requires OAuth. The client may not even know OAuth is happening.

A common architecture: client uses `key-auth` to Kong → Kong uses `upstream-oauth` to inject a Bearer token to the SaaS API behind it.
:::

## How Upstream OAuth Works

```
Client → Kong (any auth / no auth) →
  upstream-oauth plugin fetches token from IdP (client_credentials) →
    Token cached until expires_in →
      Injects "Authorization: Bearer <token>" into upstream request →
        Upstream API receives valid token
```

The client **never sees** the upstream token - Kong manages the full M2M OAuth flow transparently.

## Step 1 - Apply the plugin to a service

::: code-group

```yaml [decK YAML]
services:
  - name: partner-api
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
              - api.write
          client_auth_method: client_secret_basic
          cache:
            strategy: memory
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/services/partner-api/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "upstream-oauth",
    "config": {
      "oauth": {
        "token_endpoint": "https://idp.example.com/oauth/token",
        "grant_type": "client_credentials",
        "client_id": "kong-m2m-client",
        "client_secret": "kong-m2m-secret",
        "scopes": ["api.read"]
      },
      "client_auth_method": "client_secret_basic",
      "cache": { "strategy": "memory" }
    }
  }' | jq '{id, name}'
```

:::

## Step 2 - Verify token injection

```bash
# Make a request - Kong fetches token and injects it upstream
curl -si http://localhost:8000/api/partner-resource | head -5
# HTTP/1.1 200 OK  (upstream received valid Bearer token)

# Use httpbin to inspect what Kong forwarded
curl -s http://localhost:8000/anything | jq '.headers.Authorization'
# "Bearer eyJhbGciOi..."
```

## Step 3 - Test token caching

```bash
# Kong fetches a fresh token on first request (cache miss)
curl -si http://localhost:8000/api/partner-resource \
  | grep -i "x-upstream-oauth"

# Subsequent requests reuse the cached token - no IdP round-trip
# The token is refreshed automatically when expires_in lapses
```

## Step 4 - Use Redis for token cache (multi-node)

```yaml
config:
  oauth:
    token_endpoint: "https://idp.example.com/oauth/token"
    grant_type: client_credentials
    client_id: kong-m2m-client
    client_secret: kong-m2m-secret
  cache:
    strategy: redis
    redis:
      host: redis
      port: 6379
      timeout: 2000
```

## Step 5 - Kong Identity as the upstream IdP

Use Kong Konnect's built-in OIDC provider as the token issuer:

```yaml
config:
  oauth:
    token_endpoint: "https://us.api.konghq.com/konnect-oidc/<org-id>/protocol/openid-connect/token"
    grant_type: client_credentials
    client_id: "<konnect-app-client-id>"
    client_secret: "<konnect-app-client-secret>"
    scopes:
      - openid
      - konnect-oidc
  client_auth_method: client_secret_basic
  cache:
    strategy: memory
```

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `oauth.token_endpoint` | - | IdP token endpoint URL |
| `oauth.grant_type` | `client_credentials` | OAuth grant type |
| `oauth.client_id` | - | OAuth client ID registered at the IdP |
| `oauth.client_secret` | - | OAuth client secret |
| `oauth.scopes` | `[]` | OAuth scopes to request |
| `client_auth_method` | `client_secret_basic` | `client_secret_basic`, `client_secret_post`, `client_secret_jwt` |
| `cache.strategy` | `memory` | Token cache backend: `memory` or `redis` |
| `token_header_name` | `Authorization` | Request header used to inject the token upstream |
| `token_prefix` | `Bearer` | Prefix prepended to the token value |

---

*Previous: [Lab 07-B - RBAC & Teams](./07-rbac-teams) · Next: [Lab 07-D - OPA →](./07-opa)*
