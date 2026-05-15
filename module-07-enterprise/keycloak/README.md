# Keycloak setup for Module 07-C (OIDC) and 07-D (Upstream OAuth)

> A preconfigured local Keycloak instance so you can run [Lab 07-C](../labs/07-oidc-auth-code) and [Lab 07-D](../labs/07-upstream-oauth) without spending an hour wiring up the IdP. Two users, two clients, one realm - all imported on first start.

## What's in the box

| File | Purpose |
|---|---|
| `docker-compose.yml` | Single Keycloak container, dev mode, port 8080 |
| `realm-export.json` | Preconfigured `kong-bootcamp` realm - imported automatically on first start |
| `README.md` | You are here |

## What's preconfigured in the realm

| Item | Value |
|---|---|
| **Realm** | `kong-bootcamp` |
| **Realm roles** | `user`, `admin` |
| **Groups** | `/travel-users` (→ `user`), `/platform-engineers` (→ `admin`) |
| **User 1** | `alice` / `alice-password` (role: user) |
| **User 2** | `bob-admin` / `bob-password` (role: admin) |
| **Client (Auth Code, Lab 07-C)** | `kong` / secret: `kong-bootcamp-client-secret-replace-in-prod` |
| **Client (M2M, Lab 07-D)** | `kong-m2m` / secret: `kong-m2m-client-secret-replace-in-prod` |
| **Redirect URIs allowed** | `http://localhost:8000/*`, `http://localhost:8080/*`, `https://*.kongcloud.dev/*` |

## Quick start

```bash
cd module-07-enterprise/keycloak
docker compose up -d

# Wait ~30s for first-start realm import
docker logs -f kc-bootcamp 2>&1 | grep -m1 'Imported realm'
# Look for: ... Imported realm kong-bootcamp from file ...

# Confirm it's running
curl -s http://localhost:8080/realms/kong-bootcamp/.well-known/openid-configuration | jq '.issuer'
# Expected: "http://localhost:8080/realms/kong-bootcamp"
```

Open the admin console at <http://localhost:8080> (admin / admin) and switch the realm dropdown (top-left) to **`kong-bootcamp`**.

## Endpoints you'll need

```bash
# OIDC discovery - Kong's openid-connect plugin reads this
ISSUER=http://localhost:8080/realms/kong-bootcamp
curl -s $ISSUER/.well-known/openid-configuration | jq '{authorization_endpoint, token_endpoint, jwks_uri, end_session_endpoint}'
```

Typical values:
- `authorization_endpoint`: `http://localhost:8080/realms/kong-bootcamp/protocol/openid-connect/auth`
- `token_endpoint`:         `http://localhost:8080/realms/kong-bootcamp/protocol/openid-connect/token`
- `jwks_uri`:               `http://localhost:8080/realms/kong-bootcamp/protocol/openid-connect/certs`

## Test the M2M client (Lab 07-D)

Before wiring `upstream-oauth` into Kong, confirm Keycloak issues tokens correctly:

```bash
TOKEN=$(curl -s -X POST \
  -d 'grant_type=client_credentials' \
  -d 'client_id=kong-m2m' \
  -d 'client_secret=kong-m2m-client-secret-replace-in-prod' \
  http://localhost:8080/realms/kong-bootcamp/protocol/openid-connect/token \
  | jq -r '.access_token')

echo "Token (first 60 chars): ${TOKEN:0:60}…"

# Inspect the claims
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{iss, sub, azp, exp}'
```

## Test the Auth Code client (Lab 07-C) - direct grant shortcut

The Auth Code flow needs a browser. For a quick smoke test, use the password grant (only enabled for testing):

```bash
TOKEN=$(curl -s -X POST \
  -d 'grant_type=password' \
  -d 'client_id=kong' \
  -d 'client_secret=kong-bootcamp-client-secret-replace-in-prod' \
  -d 'username=alice' \
  -d 'password=alice-password' \
  -d 'scope=openid profile email' \
  http://localhost:8080/realms/kong-bootcamp/protocol/openid-connect/token \
  | jq -r '.access_token')

echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{preferred_username, email, realm_access}'
```

## Wiring into Kong (preview - full details in Lab 07-C)

```yaml
plugins:
  - name: openid-connect
    route: protected-route
    config:
      issuer: http://host.docker.internal:8080/realms/kong-bootcamp
      client_id: [kong]
      client_secret: [kong-bootcamp-client-secret-replace-in-prod]
      auth_methods: [authorization_code, bearer, session]
      scopes: [openid, profile, email]
      redirect_uri: [http://localhost:8000/auth/callback]
      login_action: redirect
      logout_path: /logout
```

::: tip Konnect serverless caveat
A Konnect serverless gateway lives in Konnect's cloud - it can't reach `localhost:8080` on your laptop. For serverless OIDC, expose Keycloak with `ngrok http 8080` (or use Konnect Identity instead). For the hybrid Docker DP, `http://host.docker.internal:8080` works from inside the DP container.
:::

## Production-style setup (optional)

The default uses Keycloak's in-memory H2 store - fine for the lab, **wiped on every `docker compose down -v`**. For a persistent dev setup with Postgres:

```yaml
# Add to docker-compose.yml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak
    volumes:
      - kc-pg-data:/var/lib/postgresql/data

  keycloak:
    # ... existing config ...
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak
    depends_on:
      - postgres

volumes:
  kc-pg-data:
```

## Re-importing the realm

Realm import only runs **on first start** when the realm doesn't yet exist. To re-apply:

```bash
docker compose down -v       # ← the -v drops the embedded DB
docker compose up -d
```

Or, while the container runs, use the admin UI: **Realm settings → Action → Partial import** and upload `realm-export.json`.

## Cleanup

```bash
docker compose down -v       # stops + drops embedded DB
```

::: warning Secrets are test-only
`kong-bootcamp-client-secret-replace-in-prod` and the test user passwords are checked into the repo for ease of setup. **Never** copy these into a real environment - rotate before any production use.
:::
