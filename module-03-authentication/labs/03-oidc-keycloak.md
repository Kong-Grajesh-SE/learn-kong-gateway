# Lab 03-C - OIDC Authentication with Keycloak

> **Goal:** Configure Kong as an OIDC relying party using Keycloak as the identity provider. Implement the Authorization Code Flow for browser-based user login.

## Architecture

```
Browser → Kong (:8000/api/users/profile)
              ↓
     Kong OpenID Connect plugin
     (no valid session)
              ↓
     302 redirect → Keycloak (:8080)
              ↓
     User logs in
              ↓
     Keycloak POST-back auth code to Kong
              ↓
     Kong exchanges code for tokens (server-side)
              ↓
     Kong sets session cookie
              ↓
     Kong injects x-userinfo header → Express backend
```

**Key principle:** The browser never sees a token. All token exchange is server-side inside the Docker network.

## Step 1 - Start Keycloak

```bash
cd get-started-guide
npm run keycloak:setup
```

This starts Keycloak and imports the `workshop` realm with pre-configured clients:

| Username | Password | Role |
|---|---|---|
| `demo` | `demo123` | Standard user |
| `admin` | `admin123` | Admin user |

Admin console: [http://localhost:8080/admin](http://localhost:8080/admin) (admin / admin)

## Step 2 - Verify the OIDC discovery endpoint

```bash
curl -s http://localhost:8080/realms/workshop/.well-known/openid-configuration | \
  jq '{issuer, authorization_endpoint, token_endpoint, userinfo_endpoint}'
```

## Step 3 - Connect Kong to the Keycloak network

Keycloak and Kong must be on the same Docker network for server-side token exchange:

```bash
# Find your Kong container ID
KONG_ID=$(docker ps --filter "name=kong" --format "{{.ID}}" | head -1)

# Connect Kong to Keycloak's network
docker network connect keycloak_default $KONG_ID

# Verify connectivity
docker exec $KONG_ID wget -qO- \
  http://kong-workshop-keycloak:8080/realms/workshop/.well-known/openid-configuration \
  | python3 -m json.tool | grep '"issuer"'
```

## Step 4 - Configure the OpenID Connect plugin

Apply the plugin to the `/api/users/profile` route:

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/users-profile/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "openid-connect",
    "config": {
      "issuer": "http://localhost:8080/realms/workshop",
      "client_id": ["kong-demo"],
      "client_secret": ["kong-demo-secret"],
      "scopes": ["openid", "profile", "email"],
      "auth_methods": ["authorization_code", "session"],
      "response_mode": "form_post",
      "redirect_uri": ["http://localhost:8000/api/users/profile"],
      "login_action": "redirect",
      "logout_path": "/logout",
      "session_secret": "change-this-to-a-32-char-secret!!"
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
routes:
  - name: users-profile
    paths: [~/api/users/profile$]
    methods: [GET]
    plugins:
      - name: openid-connect
        config:
          issuer: "http://localhost:8080/realms/workshop"
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

:::

## Step 5 - Test the auth code flow

```bash
# Without session - should redirect to Keycloak
curl -si http://localhost:8000/api/users/profile | grep -E "HTTP|Location"
# HTTP/1.1 302 Found
# Location: http://localhost:8080/realms/workshop/protocol/openid-connect/auth?...
```

In a browser:
1. Open [http://localhost:8000/api/users/profile](http://localhost:8000/api/users/profile)
2. You'll be redirected to Keycloak login
3. Log in as `demo` / `demo123`
4. Kong receives the auth code, exchanges it for tokens, sets a session cookie
5. You're redirected back with the profile data

## Step 6 - Inspect the userinfo header

After login, Kong injects the `x-userinfo` header into upstream requests:

```bash
# Using the session cookie (from browser DevTools)
curl -s -H "Cookie: session=<your-session-cookie>" \
  http://localhost:8000/demo/headers | \
  jq '.headers["X-Userinfo"]' | \
  python3 -c "import sys,base64,json; d=sys.stdin.read().strip().strip('\"'); \
    print(json.dumps(json.loads(base64.b64decode(d + '==').decode()), indent=2))"
```

## Step 7 - Machine-to-Machine with Client Credentials

For service-to-service calls (no browser):

```bash
# Get an M2M token from Keycloak
M2M_TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/workshop/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=kong-demo" \
  -d "client_secret=kong-demo-secret" \
  | jq -r '.access_token')

# Configure plugin to also accept client_credentials flow
# Then call with Bearer token
curl -s -H "Authorization: Bearer $M2M_TOKEN" \
  http://localhost:8000/api/users/profile | jq '.'
```

## OIDC Plugin Configuration Reference

| Config | Description |
|---|---|
| `issuer` | IdP OIDC discovery URL |
| `client_id` | Kong's registered client ID |
| `client_secret` | Kong's registered client secret |
| `auth_methods` | Allowed flows: `authorization_code`, `client_credentials`, `session` |
| `response_mode` | How auth code is sent back: `query`, `form_post` |
| `session_secret` | Cookie encryption key (min 32 chars) |
| `redirect_uri` | Callback URL (must match Keycloak client config) |
| `scopes` | OIDC scopes to request |
| `login_action` | What to do when unauthenticated: `redirect`, `deny` |

## Challenge

Configure a **second Keycloak client** `mobile-client` with PKCE (no client secret) and configure a second Kong route `/api/mobile/profile` that uses it. Test with `curl` using the PKCE flow.

---

*Next: [Module 04 - Traffic Control →](/module-04-traffic-control/)*
