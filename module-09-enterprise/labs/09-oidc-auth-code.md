# Lab 09-A - OIDC Authorization Code Flow

> **Goal:** Implement the full OIDC Authorization Code flow end-to-end. Browser-based login via Keycloak, server-side token exchange, and session management.

## Flow Recap

```
1. Browser  → GET http://localhost:8000/api/users/profile
2. Kong     → No session → 302 redirect → Keycloak login page
3. User     → Authenticates at Keycloak (:8080)
4. Keycloak → POST auth code → Kong callback (form_post)
5. Kong     → Exchange code for tokens (server-side, inside Docker)
6. Kong     → Store session, set encrypted session cookie
7. Kong     → Redirect browser to original URL
8. Browser  → GET /api/users/profile with session cookie
9. Kong     → Validate session → call Keycloak userinfo
10. Kong    → Inject X-Userinfo header → Express backend
11. Express → Return user profile data
```

## Step 1 - Prerequisites

```bash
# Start Keycloak with the workshop realm
cd get-started-guide
npm run keycloak:setup

# Connect Kong to Keycloak's Docker network
KONG_ID=$(docker ps --filter "name=kong" --format "{{.ID}}" | head -1)
docker network connect keycloak_default $KONG_ID

# Test internal connectivity
docker exec $KONG_ID wget -qO- \
  http://kong-workshop-keycloak:8080/realms/workshop/.well-known/openid-configuration \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['issuer'])"
```

## Step 2 - Apply OIDC plugin

```bash
curl -s -X POST http://localhost:8001/routes/users-profile/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "openid-connect",
    "config": {
      "issuer": "http://kong-workshop-keycloak:8080/realms/workshop",
      "client_id": ["kong-demo"],
      "client_secret": ["kong-demo-secret"],
      "scopes": ["openid", "profile", "email"],
      "auth_methods": ["authorization_code", "session"],
      "response_mode": "form_post",
      "redirect_uri": ["http://localhost:8000/api/users/profile"],
      "login_action": "redirect",
      "logout_path": "/logout",
      "logout_revoke": true,
      "logout_revoke_access_token": true,
      "session_secret": "change-this-in-prod-32-chars-min!",
      "session_rolling_timeout": 1800,
      "session_absolute_timeout": 86400,
      "leeway": 5,
      "userinfo_headers_claims": ["email", "name", "preferred_username"],
      "upstream_headers_claims": ["email", "name"],
      "upstream_headers_names": ["X-User-Email", "X-User-Name"]
    }
  }' | jq '{id, name}'
```

## Step 3 - Test the browser flow

```bash
# Without session → should redirect to Keycloak
curl -siL http://localhost:8000/api/users/profile | grep -E "HTTP|Location"
```

In a browser:
1. Open [http://localhost:8000/api/users/profile](http://localhost:8000/api/users/profile)
2. Redirected to Keycloak → log in as `demo` / `demo123`
3. After login → redirected back to profile endpoint
4. Profile data returned with user's info

## Step 4 - Inspect the session cookie

Open browser DevTools → Application → Cookies → `localhost`:

```
Name:     session
Value:    <encrypted JWT session>
HttpOnly: ✅ (no JS access)
Secure:   production only
SameSite: Lax
```

## Step 5 - Decode the userinfo header

The `X-Userinfo` header contains a base64-encoded JSON claims object:

```bash
# Using the cookie from browser DevTools
curl -s -H "Cookie: session=<your-cookie>" \
  http://localhost:8000/api/users/profile | jq '.'

# Decode the X-Userinfo header (if using httpbin)
curl -s -H "Cookie: session=<your-cookie>" \
  http://localhost:8000/demo/headers | \
  jq -r '.headers["X-Userinfo"]' | \
  base64 -d 2>/dev/null | python3 -m json.tool
```

## Step 6 - Logout

```bash
# Trigger logout (clears session + revokes token at Keycloak)
curl -si http://localhost:8000/logout | grep -E "HTTP|Location"
# 302 → Keycloak RP-initiated logout
```

## Step 7 - OIDC Config reference

| Config | Value | Description |
|---|---|---|
| `issuer` | Keycloak realm URL | OIDC discovery endpoint base |
| `auth_methods` | `authorization_code`, `session` | Allowed flow types |
| `response_mode` | `form_post` | How auth code is returned (more secure than `query`) |
| `session_secret` | 32+ char string | AES key for session cookie encryption |
| `session_rolling_timeout` | `1800` (30 min) | Inactivity timeout |
| `session_absolute_timeout` | `86400` (24h) | Max session duration regardless of activity |
| `logout_revoke` | `true` | Revoke refresh token at IdP on logout |
| `leeway` | `5` | Clock skew tolerance (seconds) |

## Keycloak Test Users

| Username | Password | Role | Use Case |
|---|---|---|---|
| `demo` | `demo123` | Standard user | Normal user flow |
| `admin` | `admin123` | Admin | RBAC / admin features |

---

*Next: [Lab 09-B - Developer Portal →](./09-dev-portal)*
