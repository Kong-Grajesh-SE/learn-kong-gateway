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
| **Redirect URIs allowed** | `http://localhost:8000/*`, `http://localhost:8080/*`, `https://*.kongcloud.dev/*`, `https://*.us.serverless.gateways.konggateway.com/*` |

---

## Quick start

Use the helper script from the repo root - it starts the container, waits for the realm import, and runs smoke tests:

```bash
./scripts/setup-keycloak.sh          # start + verify
./scripts/setup-keycloak.sh status   # check health any time
./scripts/setup-keycloak.sh stop     # stop (keeps DB)
./scripts/setup-keycloak.sh reset    # stop + wipe DB (re-imports realm on next start)
./scripts/setup-keycloak.sh cleanup  # stop + wipe DB + remove image
```

Or start manually:

```bash
cd module-07-enterprise/keycloak
docker compose up -d

# Wait ~30s for first-start realm import
docker logs -f kc-bootcamp 2>&1 | grep -m1 'Imported realm'
# Expected: ... Imported realm kong-bootcamp from file ...

# Confirm the realm is live
curl -s http://localhost:8080/realms/kong-bootcamp/.well-known/openid-configuration | jq '.issuer'
# Expected: "http://localhost:8080/realms/kong-bootcamp"
```

Open the admin console at <http://localhost:8080> (admin / admin) and switch the realm dropdown (top-left) to **`kong-bootcamp`**.

---

## Deployment modes

### Option A - Hybrid Docker DP (local Kong data plane)

The Kong DP container runs on the same Docker host as Keycloak. Use `host.docker.internal` so the DP container can reach Keycloak on the host:

| Setting | Value |
|---|---|
| `KEYCLOAK_BASE` | `http://localhost:8080` |
| Issuer for Kong plugin | `http://host.docker.internal:8080/realms/kong-bootcamp` |
| Kong proxy URL | `http://localhost:8000` |

```bash
export KEYCLOAK_BASE=http://localhost:8080
./scripts/verify-module-07.sh   # choose Option A when prompted
```

### Option B - Konnect serverless + ngrok tunnel

A Konnect serverless gateway runs in Konnect's cloud and **cannot reach `localhost`**. Expose Keycloak over the internet with ngrok so the Konnect DP can call the token and JWKS endpoints.

#### Recommended: use the helper script

The `setup-keycloak.sh ngrok` command starts Keycloak (if not already running), opens the tunnel, and automatically sets Keycloak's `frontendUrl` to the public HTTPS URL — ensuring the `iss` claim in every token matches the issuer Kong's OIDC plugin validates against:

```bash
./scripts/setup-keycloak.sh ngrok
# Prints: export KEYCLOAK_BASE=https://xxxxx.ngrok-free.app
```

Copy the printed `export` and skip to step 5. The manual steps below are for reference.

#### 1. Install ngrok

```bash
# macOS
brew install ngrok
ngrok config add-authtoken <YOUR_NGROK_AUTHTOKEN>   # free account at https://ngrok.com
```

#### 2. Start Keycloak

```bash
./scripts/setup-keycloak.sh   # or docker compose up -d in module-07-enterprise/keycloak/
```

#### 3. Open the ngrok tunnel

```bash
ngrok http 8080
```

ngrok prints a forwarding URL, e.g.:

```
Forwarding   https://abc123.ngrok-free.app -> http://localhost:8080
```

Copy that HTTPS URL - it is your `KEYCLOAK_BASE` for this session.

#### 4. Update Keycloak's frontend URL

Keycloak embeds its own URL in tokens (`iss` claim) and in the discovery document. When Kong validates a token, the `iss` must match the `issuer` in the plugin config. Tell Keycloak to use the public ngrok URL as its frontend:

```bash
NGROK_URL=https://abc123.ngrok-free.app   # replace with your URL

curl -s -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(
    curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
      -d 'grant_type=password&client_id=admin-cli&username=admin&password=admin' \
      | jq -r '.access_token')" \
  "http://localhost:8080/admin/realms/kong-bootcamp" \
  -d "{\"attributes\":{\"frontendUrl\":\"${NGROK_URL}\"}}"
```

Verify the issuer now reflects the ngrok URL:

```bash
curl -s "${NGROK_URL}/realms/kong-bootcamp/.well-known/openid-configuration" | jq '.issuer'
# Expected: "https://abc123.ngrok-free.app/realms/kong-bootcamp"
```

#### 5. Run the verify script

```bash
export KEYCLOAK_BASE=$NGROK_URL
./scripts/verify-module-07.sh   # choose Option B when prompted, paste $NGROK_URL
```

::: warning ngrok URL changes every restart
The free ngrok plan assigns a new URL each time you run `ngrok http 8080`. You must repeat step 4 (update frontend URL) and re-export `KEYCLOAK_BASE` after every restart. A paid ngrok plan with a static domain avoids this.
:::

::: tip Redirect URIs are pre-approved
`realm-export.json` pre-approves `https://*.kongcloud.dev/*` and `https://*.us.serverless.gateways.konggateway.com/*` as valid redirect URIs, covering both Konnect proxy URL patterns without any manual Keycloak admin UI changes.
:::

---

## Endpoints you'll need

```bash
# Replace KEYCLOAK_BASE with your actual URL (localhost or ngrok)
KEYCLOAK_BASE=http://localhost:8080
ISSUER="${KEYCLOAK_BASE}/realms/kong-bootcamp"

curl -s "${ISSUER}/.well-known/openid-configuration" \
  | jq '{authorization_endpoint, token_endpoint, jwks_uri, end_session_endpoint}'
```

| Endpoint | Path |
|---|---|
| Authorization | `$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/auth` |
| Token | `$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/token` |
| JWKS | `$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/certs` |
| End session | `$KEYCLOAK_BASE/realms/kong-bootcamp/protocol/openid-connect/logout` |

---

## Test the M2M client (Lab 07-D)

Before wiring `upstream-oauth` into Kong, confirm Keycloak issues tokens correctly:

```bash
KEYCLOAK_BASE=http://localhost:8080   # or your ngrok URL

TOKEN=$(curl -s -X POST \
  -d 'grant_type=client_credentials' \
  -d 'client_id=kong-m2m' \
  -d 'client_secret=kong-m2m-client-secret-replace-in-prod' \
  "${KEYCLOAK_BASE}/realms/kong-bootcamp/protocol/openid-connect/token" \
  | jq -r '.access_token')

echo "Token (first 60 chars): ${TOKEN:0:60}…"

# Inspect the claims
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{iss, sub, azp, exp}'
```

## Test the Auth Code client (Lab 07-C) - password grant shortcut

The Auth Code flow requires a browser. For a quick smoke test, use the password grant (only enabled in this dev realm):

```bash
KEYCLOAK_BASE=http://localhost:8080   # or your ngrok URL

TOKEN=$(curl -s -X POST \
  -d 'grant_type=password' \
  -d 'client_id=kong' \
  -d 'client_secret=kong-bootcamp-client-secret-replace-in-prod' \
  -d 'username=alice' \
  -d 'password=alice-password' \
  -d 'scope=openid profile email' \
  "${KEYCLOAK_BASE}/realms/kong-bootcamp/protocol/openid-connect/token" \
  | jq -r '.access_token')

echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{preferred_username, email, realm_access}'
```

---

## Testing via browser (full OIDC Authorization Code flow)

The password grant above is a non-interactive shortcut. To exercise the real browser login experience — Keycloak login page → credential entry → redirect back to Kong — use one of the two options below.

### Option A — Quick test: inject token via ModHeader

No Kong plugin changes required.

1. Install the [ModHeader](https://modheader.com) browser extension (Chrome / Firefox)
2. Open any tab, press **F12 → Console**, and run:
   ```js
   const r = await fetch("https://YOUR-NGROK.ngrok-free.app/realms/kong-bootcamp/protocol/openid-connect/token", {
     method: "POST",
     headers: {
       "Content-Type": "application/x-www-form-urlencoded",
       "ngrok-skip-browser-warning": "true"   // bypasses ngrok free-tier interstitial on POST
     },
     body: new URLSearchParams({
       grant_type: "password",
       client_id: "kong",
       client_secret: "kong-bootcamp-client-secret-replace-in-prod",
       username: "alice",
       password: "alice-password"
     })
   });
   const { access_token } = await r.json();
   console.log(access_token);
   ```
   Replace `YOUR-NGROK` with your actual ngrok subdomain. For hybrid/localhost mode use `localhost:8080` and remove the bypass header.

3. In ModHeader, add request header: `Authorization: Bearer <paste-token>`
4. Navigate to your Kong proxy URL — expect a **200** response with the httpbin JSON body

### Option B — Full login page: authorization code flow

Requires a one-time plugin config change in the Konnect portal.

1. Update the `openid-connect` plugin on `flights-route`:

   | Config field | Verify script value | Browser login value |
   |---|---|---|
   | `login_action` | `response` | `redirect` |
   | `auth_methods` | `password, bearer, client_credentials` | `authorization_code, bearer, session` |

2. Navigate to your Kong proxy URL in the browser
3. Kong detects no session → redirects to the Keycloak login page
4. Log in as **`alice`** / **`alice-password`**
5. Keycloak redirects back to Kong → Kong exchanges the auth code → sets a session cookie → returns the **200** httpbin response

> **Before re-running the verify script**, revert `login_action` to `response` and `auth_methods` to `["password", "bearer", "client_credentials"]`. The automated tests use the password-grant flow and will fail against a redirect-only config.

---

## Wiring into Kong (preview - full details in Lab 07-C)

**Option A (hybrid DP)** - use `host.docker.internal` so the DP container can reach Keycloak:

```yaml
plugins:
  - name: openid-connect
    route: flights-route
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

**Option B (serverless + ngrok)** - use the public ngrok URL:

```yaml
plugins:
  - name: openid-connect
    route: flights-route
    config:
      issuer: https://abc123.ngrok-free.app/realms/kong-bootcamp   # your ngrok URL
      client_id: [kong]
      client_secret: [kong-bootcamp-client-secret-replace-in-prod]
      auth_methods: [authorization_code, bearer, session]
      scopes: [openid, profile, email]
      redirect_uri: [https://xxxx.kongcloud.dev/auth/callback]      # your Konnect proxy URL
      login_action: redirect
      logout_path: /logout
```

---

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
./scripts/setup-keycloak.sh reset   # wipes DB, re-imports on next start
./scripts/setup-keycloak.sh        # starts fresh
```

Or manually:

```bash
docker compose down -v   # drops embedded DB
docker compose up -d
```

## Cleanup

```bash
./scripts/setup-keycloak.sh stop     # stop container, keep DB
./scripts/setup-keycloak.sh reset    # stop + wipe DB
./scripts/setup-keycloak.sh cleanup  # stop + wipe DB + remove image
```

::: warning Secrets are test-only
`kong-bootcamp-client-secret-replace-in-prod` and the test user passwords are checked into the repo for ease of setup. **Never** copy these into a real environment - rotate before any production use.
:::

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

