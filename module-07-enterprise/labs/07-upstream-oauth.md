# Lab 07-D - Upstream OAuth (M2M Token Injection)

> **Goal.** In ~30 minutes you'll configure Kong to **fetch an OAuth2 client-credentials token from Keycloak** and inject it as `Authorization: Bearer <token>` for every upstream request. Your upstream APIs get a clean Bearer token without ever seeing client credentials.
>
> **Pattern.** This is the **machine-to-machine** counterpart to Lab 07-C's browser flow. Tokens are issued to *Kong* on behalf of the API, not to the client.

::: warning Enterprise plugin
`upstream-oauth` requires **Kong Gateway Enterprise** or **Konnect**. Min version: Kong Gateway 3.8 - we're on 3.14, so you're good.
:::

::: tip OIDC vs Upstream OAuth - who is the token *for*?
- **OIDC (07-C)**: Token authenticates the **client** (a human user). Kong validates it; upstream reads `X-Authenticated-Userid`.
- **Upstream OAuth (this lab)**: Token authenticates **Kong itself** to the *upstream API*. The client may not know OAuth is happening.

Common pattern: client uses `key-auth` to Kong → Kong uses `upstream-oauth` to inject a Bearer token upstream.
:::

## How Upstream OAuth Works

```
Client → Kong (any auth / no auth)
  ↓
  upstream-oauth plugin: POST client_credentials to Keycloak
  ↓
  Token cached until expires_in lapses
  ↓
  Injects "Authorization: Bearer <token>" into upstream request
  ↓
Upstream API receives valid token
```

## Step 1 - Connect Kong to Keycloak

Same requirement as Lab 07-C: Kong's data plane must reach Keycloak's token endpoint. If you completed 07-C in this session, `$KEYCLOAK_BASE` and `$KONNECT_PROXY_URL` are already set - skip to Step 2.

::: details Option A - Hybrid mode (local Docker DP + local Keycloak)

```bash
# Start Keycloak (if not already running from 07-C)
cd module-07-enterprise/keycloak
docker compose up -d

# Verify M2M token endpoint works directly from your machine
curl -fsS -X POST \
  -d 'grant_type=client_credentials' \
  -d 'client_id=kong-m2m' \
  -d 'client_secret=kong-m2m-client-secret-replace-in-prod' \
  'http://localhost:8080/realms/kong-bootcamp/protocol/openid-connect/token' \
  | jq '{access_token: .access_token[:40], expires_in}'
# { "access_token": "eyJhbGciOiJSUzI1N...", "expires_in": 900 }

export KEYCLOAK_BASE="http://localhost:8080"
export KONNECT_PROXY_URL="http://localhost:8000"   # local DP port
```
:::

::: details Option B - Public URL via ngrok (Konnect serverless or any cloud DP)

```bash
# Start Keycloak (if not already running from 07-C)
cd module-07-enterprise/keycloak
docker compose up -d

# Expose Keycloak publicly
ngrok http 8080
# → Forwarding: https://abc123.ngrok.io → localhost:8080

export KEYCLOAK_BASE="https://abc123.ngrok.io"   # ← your ngrok URL

# Verify M2M token endpoint is reachable via the public URL
curl -fsS -X POST \
  -d 'grant_type=client_credentials' \
  -d 'client_id=kong-m2m' \
  -d 'client_secret=kong-m2m-client-secret-replace-in-prod' \
  "${KEYCLOAK_BASE}/realms/kong-bootcamp/protocol/openid-connect/token" \
  | jq '{access_token: .access_token[:40], expires_in}'
```
:::

## Step 2 - Attach `upstream-oauth` to `flights-route`

::: code-group

```yaml [decK YAML]
services:
  - name: flights-svc
    routes:
      - name: flights-route
        plugins:
          - name: upstream-oauth
            tags: [module-07]
            config:
              oauth:
                token_endpoint: "$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/token"
                grant_type: client_credentials
                client_id: kong-m2m
                client_secret: kong-m2m-client-secret-replace-in-prod
                scopes: []
              cache:
                strategy: memory
                default_ttl: 300
                eagerly_expire: 5
```

```bash [Konnect Admin API]
ROUTE_ID=$(curl -s \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/routes/flights-route" \
  | jq -r '.id')

curl -s -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/routes/${ROUTE_ID}/plugins" \
  -d "{
    \"name\": \"upstream-oauth\",
    \"tags\": [\"module-07\"],
    \"config\": {
      \"oauth\": {
        \"token_endpoint\": \"$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/token\",
        \"grant_type\": \"client_credentials\",
        \"client_id\": \"kong-m2m\",
        \"client_secret\": \"kong-m2m-client-secret-replace-in-prod\",
        \"scopes\": []
      },
      \"cache\": { \"strategy\": \"memory\", \"default_ttl\": 300, \"eagerly_expire\": 5 }
    }
  }" | jq '{id, name}'
```

:::

::: warning Serverless gateway + localhost Keycloak
If you have not completed Step 1 Option B, a `*.kongcloud.dev` serverless gateway **cannot reach** `localhost:8080`. Go back to Step 1 and expose Keycloak via ngrok (Option B) before continuing.
:::

## Step 3 - Verify token injection 🎯

```bash
# Kong fetches a token from Keycloak and injects it upstream - check what httpbin echoes back
curl -s $KONNECT_PROXY_URL/flights/anything \
  | jq '.headers.Authorization'
# "Bearer eyJhbGciOiJS..."
```

The client sent **no** Authorization header. Kong fetched the M2M token from Keycloak and injected it - transparently.

```bash
# Inspect first 60 chars of the injected token
curl -s $KONNECT_PROXY_URL/flights/anything \
  | jq -r '.headers.Authorization' | cut -c1-67
# Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6IC
```

## Step 4 - Token caching

Kong caches the token until `expires_in - eagerly_expire` seconds. Observe the round-trip latency drop on the second request:

```bash
# First request: Kong fetches a fresh token from Keycloak (adds ~50-200 ms)
time curl -s $KONNECT_PROXY_URL/flights/get | jq '.headers.Authorization | length'

# Subsequent requests: served from cache (no Keycloak round-trip)
time curl -s $KONNECT_PROXY_URL/flights/get | jq '.headers.Authorization | length'
```

## Step 5 - Use Redis for token cache (multi-node)

```yaml
config:
  oauth:
    token_endpoint: "$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/token"
    grant_type: client_credentials
    client_id: kong-m2m
    client_secret: kong-m2m-client-secret-replace-in-prod
  cache:
    strategy: redis
    redis:
      host: redis
      port: 6379
      timeout: 2000
```

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `oauth.token_endpoint` | - | IdP token endpoint URL |
| `oauth.grant_type` | `client_credentials` | OAuth grant type |
| `oauth.client_id` | - | OAuth client ID registered at the IdP |
| `oauth.client_secret` | - | OAuth client secret |
| `oauth.scopes` | `[]` | OAuth scopes to request |
| `cache.strategy` | `memory` | Token cache backend: `memory` or `redis` |
| `cache.default_ttl` | `300` | Seconds to cache the token |
| `cache.eagerly_expire` | `5` | Refresh token this many seconds before it expires |

---

We continue with the same `flights-svc` in 07-E. **Don't clean up yet.**

---

**Next:** [Lab 07-E - OPA Policy-as-Code →](./07-opa)

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
