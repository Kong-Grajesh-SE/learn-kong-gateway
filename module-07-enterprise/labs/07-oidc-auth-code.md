# Lab 07-C - OIDC Authorization Code Flow

> **Goal.** In ~45 minutes you'll implement the full OIDC Auth Code flow end-to-end: browser-based login via Keycloak, server-side token exchange, and Bearer-token validation. The result is **enterprise SSO** for any API behind Kong.
>
> **Pre-reqs.** The `module-07-enterprise/keycloak/` docker-compose running locally. See the `README.md` in that folder.

::: warning Auth Code = browser flow, not API flow
This is for **human users in browsers**. For machine-to-machine OAuth, use **Upstream OAuth** (07-D) instead. Confusing them is the #1 OIDC setup mistake.
:::

## Flow Recap

```
1. Browser   → GET $KONNECT_PROXY_URL/flights/anything
2. Kong      → No session / no token → 302 redirect → Keycloak login page
3. User      → Authenticates at Keycloak (:8080)
4. Keycloak  → Issues access_token (+ refresh + id tokens)
5. Client    → Sends Bearer <access_token> to Kong
6. Kong      → Validates token against Keycloak discovery endpoint
7. Kong      → Injects X-Authenticated-Userid, X-Credential-Identifier upstream
8. Upstream  → Receives request with identity headers
```

## Step 1 - Connect Kong to Keycloak

Konnect's **serverless** data plane runs in Kong's cloud and cannot reach `localhost`. Choose the option that matches your setup, then continue with Step 2 using the resulting `$KEYCLOAK_BASE` value.

::: details Option A — Hybrid mode (local Docker DP + local Keycloak) · *recommended for bootcamp*

**When to use:** You started a local Kong data plane with `DEPLOY_MODE=hybrid` (the Docker Compose in the module-01 lab).

```bash
# 1. Start Keycloak
cd module-07-enterprise/keycloak
docker compose up -d

# 2. Verify the realm is loaded (from your machine)
curl -s http://localhost:8080/realms/kong-bootcamp/.well-known/openid-configuration \
  | jq '.issuer'
# "http://localhost:8080/realms/kong-bootcamp"

# 3. Set environment variables for the rest of this lab
export KEYCLOAK_BASE="http://localhost:8080"
export KONNECT_PROXY_URL="http://localhost:8000"   # local DP port
```

The OIDC plugin `issuer` will be `http://localhost:8080/realms/kong-bootcamp`.  
The local Kong DP container can reach Keycloak because both run on the same Docker host.
:::

::: details Option B — Public URL via ngrok (Konnect serverless or any cloud DP)

**When to use:** Your proxy URL is a `*.kongcloud.dev` serverless gateway, or any Kong DP that is not on the same machine as Keycloak.

```bash
# 1. Start Keycloak
cd module-07-enterprise/keycloak
docker compose up -d

# 2. Expose Keycloak publicly
ngrok http 8080
# → Forwarding: https://abc123.ngrok.io → localhost:8080
#   Copy the https URL — you'll use it as KEYCLOAK_BASE.

# 3. Verify the realm is reachable via the public URL
KEYCLOAK_BASE="https://abc123.ngrok.io"   # ← replace with YOUR ngrok URL
curl -s "${KEYCLOAK_BASE}/realms/kong-bootcamp/.well-known/openid-configuration" \
  | jq '.authorization_endpoint'
# "https://abc123.ngrok.io/realms/kong-bootcamp/protocol/openid-connect/auth"

# 4. Export for the rest of this lab
export KEYCLOAK_BASE
```

> **Note:** The `issuer` in Keycloak's discovery doc may still say `localhost:8080` — this is cosmetic.  
> Kong uses the `issuer` value you supply, not the one Keycloak advertises.
:::

**Pre-configured clients in the `kong-bootcamp` realm:**

| Client ID | Secret | Use |
|---|---|---|
| `kong` | `kong-bootcamp-client-secret-replace-in-prod` | OIDC Bearer validation (this lab) |
| `kong-m2m` | `kong-m2m-client-secret-replace-in-prod` | Client Credentials — Lab 07-D |

**Test users:**

| Username | Password | Role |
|---|---|---|
| `alice` | `alice-password` | user |
| `bob` | `bob-password` | admin |

## Step 2 - Attach `openid-connect` plugin to `flights-route`

::: code-group

```yaml [decK YAML]
services:
  - name: flights-svc
    routes:
      - name: flights-route
        plugins:
          - name: openid-connect
            tags: [module-07]
            config:
              issuer: "$KEYCLOAK_BASE/realms/kong-bootcamp"
              client_id: ["kong"]
              client_secret: ["kong-bootcamp-client-secret-replace-in-prod"]
              auth_methods:
                - password           # Resource Owner Password Grant (for curl testing)
                - bearer             # Validate Bearer tokens
                - client_credentials # M2M (optional)
              scopes: ["openid", "profile", "email"]
              login_action: deny     # Return 401, don't redirect (API mode)
              bearer_token_param_type: ["header"]
```

```bash [Konnect Admin API]
# Resolve the route ID first
ROUTE_ID=$(curl -s \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/routes/flights-route" \
  | jq -r '.id')

curl -s -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/routes/${ROUTE_ID}/plugins" \
  -d "{
    \"name\": \"openid-connect\",
    \"tags\": [\"module-07\"],
    \"config\": {
      \"issuer\": \"$KEYCLOAK_BASE/realms/kong-bootcamp\",
      \"client_id\": [\"kong\"],
      \"client_secret\": [\"kong-bootcamp-client-secret-replace-in-prod\"],
      \"auth_methods\": [\"password\", \"bearer\", \"client_credentials\"],
      \"scopes\": [\"openid\", \"profile\", \"email\"],
      \"login_action\": \"deny\",
      \"bearer_token_param_type\": [\"header\"]
    }
  }" | jq '{id, name}'
```

:::

::: warning Serverless gateway + localhost Keycloak
If you have not completed Step 1 Option B, a `*.kongcloud.dev` serverless gateway **cannot reach** `localhost:8080`. Go back and either switch to hybrid mode (Option A) or expose Keycloak via ngrok (Option B) before continuing.
:::

## Step 3 - Get a token via password grant 🎯

```bash
# Use the KEYCLOAK_BASE you set in Step 1
CLIENT_SECRET="kong-bootcamp-client-secret-replace-in-prod"

TOKEN=$(curl -fsS -X POST \
  -d 'grant_type=password' \
  -d 'client_id=kong' \
  -d "client_secret=$CLIENT_SECRET" \
  -d 'username=alice' \
  -d 'password=alice-password' \
  -d 'scope=openid profile email' \
  "${KEYCLOAK_BASE}/realms/kong-bootcamp/protocol/openid-connect/token" | jq -r '.access_token')

echo "Token length: ${#TOKEN} chars"
```

## Step 4 - Call the route with the Bearer token 🎯

```bash
curl -si $KONNECT_PROXY_URL/flights/anything \
  -H "Authorization: Bearer $TOKEN" \
  | head -3
# HTTP/2 200

# Inspect upstream-injected identity headers
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.headers | with_entries(select(.key | test("X-"; "i")))'
```

Expected headers injected by `openid-connect`:

```json
{
  "X-Authenticated-Userid": "alice",
  "X-Credential-Identifier": "<sub claim UUID>"
}
```

## Step 5 - Test failure modes 🧪

```bash
# No token → 401 (login_action: deny)
curl -si $KONNECT_PROXY_URL/flights/get | head -3
# HTTP/2 401

# Expired / tampered token
curl -si $KONNECT_PROXY_URL/flights/get \
  -H "Authorization: Bearer BAD_TOKEN_HERE" | head -3
# HTTP/2 401
```

## Step 6 - OIDC Config Reference

| Config | Value | Description |
|---|---|---|
| `issuer` | Keycloak realm URL | OIDC discovery endpoint base |
| `auth_methods` | `bearer`, `password`, `authorization_code` | Allowed flow types |
| `login_action` | `deny` (API) / `redirect` (browser) | What to do when unauthenticated |
| `client_id` | `kong` | OAuth client registered in Keycloak |
| `client_secret` | realm client secret | Must match Keycloak client config |
| `scopes` | `openid profile email` | Claims to request |
| `bearer_token_param_type` | `header` | Where to look for Bearer token |

::: tip Konnect-native IdP (no Keycloak needed)
For production, use [Kong Identity](https://docs.konghq.com/konnect/reference/auth/konnect-oauth-server/) — Konnect's built-in OIDC provider. Replace the `issuer` with your Konnect org's OIDC endpoint.
:::

---

We continue with the same `flights-svc` in 07-D. **Don't clean up yet.**

---

**Next:** [Lab 07-D - Upstream OAuth (M2M) →](./07-upstream-oauth)
