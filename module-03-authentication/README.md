# Module 03 - Authentication Plugins

> Kong's plugin-based auth model lets you protect APIs with multiple strategies without changing your backend code. Auth plugins validate credentials and, on success, inject consumer identity into request headers.

## Overview

| | |
|---|---|
| **Duration** | ~2 hours |
| **Level** | Intermediate |
| **Stack** | Kong Gateway, Keycloak, curl |
| **Outcome** | APIs protected with Key Auth, JWT, and OIDC via Keycloak |

## Learning Objectives

- Understand Kong's authentication plugin model
- Implement Key Authentication for simple API key protection
- Implement JWT authentication for stateless token validation
- Configure OIDC with Keycloak for enterprise SSO

## How Kong Auth Works

```
Request arrives → Auth Plugin runs →
  ✅ Credentials valid → Consumer identified → Request forwarded
  ❌ No credentials   → 401 Unauthorized
  ❌ Bad credentials  → 401 / 403 Forbidden
```

After a successful auth check, Kong injects headers that your backend can use:

| Header | Value |
|---|---|
| `X-Consumer-ID` | Kong consumer UUID |
| `X-Consumer-Username` | Consumer username |
| `X-Consumer-Custom-ID` | Consumer's custom_id |
| `X-Credential-Identifier` | The API key / JWT kid used |

## Authentication Plugins Overview

| Plugin | Protocol | Use Case |
|---|---|---|
| **key-auth** | API key in header/query | Simple API access control |
| **jwt** | JWT in `Authorization: Bearer` | Stateless token validation |
| **openid-connect** | OIDC auth code / client credentials | Enterprise SSO via IdP |
| **oauth2** | OAuth 2.0 flows | Third-party app authorization |
| **basic-auth** | HTTP Basic Auth | Legacy integrations |
| **hmac-auth** | HMAC signature | High-security M2M |
| **ldap-auth** | LDAP bind | Corporate directory auth |
| **mtls-auth** | Client TLS certificates | Zero-trust environments |

## Plugin Scope

Auth plugins can be applied at three scopes:

| Scope | Effect | Config |
|---|---|---|
| **Global** | All services and routes | `POST /plugins` |
| **Service** | All routes on a service | `POST /services/{id}/plugins` |
| **Route** | Specific route only | `POST /routes/{id}/plugins` |

## Labs

| Lab | Topic |
|---|---|
| [03-A: Key Authentication](/module-03-authentication/labs/03-key-auth) | Protect flights API with API keys, create consumer credentials |
| [03-B: JWT Auth](/module-03-authentication/labs/03-jwt-auth) | Sign and validate JWTs, manage secrets via decK |
| [03-C: OIDC / Keycloak](/module-03-authentication/labs/03-oidc-keycloak) | Full OIDC auth code flow with Keycloak, session cookies |

## Key Concepts

### Anonymous Access

You can configure an `anonymous` consumer as a fallback - requests without credentials get the anonymous consumer identity but can still pass through:

```yaml
plugins:
  - name: key-auth
    config:
      anonymous: <anonymous-consumer-id>
      key_in_header: true
```

### Multiple Auth Methods

Kong can run multiple auth plugins simultaneously and use logic plugins like `request-termination` or `acl` to combine them:

```
key-auth OR jwt → consumer identified → acl check → forward
```

## Plugin Quick Reference

> Condensed configs for every plugin used in this module. See the [full Plugin Reference](/plugin-reference) for all parameters, template variables, and advanced examples.

### key-auth

```yaml
plugins:
  - name: key-auth
    config:
      key_names: [X-API-Key, apikey]   # header or query param names
      key_in_header: true
      key_in_query: true
      hide_credentials: true            # strip key before upstream
```

**Create a consumer key:**
```bash
curl -X POST http://localhost:8001/consumers/{consumer}/key-auth \
  -d '{"key": "my-secret-api-key"}'
```

| Parameter | Default | Description |
|---|---|---|
| `key_names` | `["apikey"]` | Header / query param names to check |
| `hide_credentials` | `false` | Strip key before proxying |
| `key_in_body` | `false` | Accept key in request body |
| `anonymous` | `null` | Fallback consumer for unauthenticated requests |

**Lab:** [03-A: Key Authentication](/module-03-authentication/labs/03-key-auth)

---

### hmac-auth

```yaml
plugins:
  - name: hmac-auth
    config:
      hide_credentials: true
      clock_skew: 300
      enforce_headers: [date, "@request-target"]
      algorithms: [hmac-sha256]
```

**Create a consumer HMAC credential:**
```bash
curl -X POST http://localhost:8001/consumers/{consumer}/hmac-auth \
  -d '{"username": "my-consumer", "secret": "my-shared-secret"}'
```

**Authorization header format clients must send:**
```
Authorization: hmac username="<username>", algorithm="hmac-sha256", headers="date @request-target", signature="<base64>"
```

| Parameter | Default | Description |
|---|---|---|
| `algorithms` | `["hmac-sha256"]` | Allowed: `hmac-sha256`, `hmac-sha384`, `hmac-sha512` |
| `clock_skew` | `300` | Max time drift in seconds |
| `enforce_headers` | `[]` | Headers client *must* include in signature |
| `validate_request_body` | `false` | Validate `Digest` header against body hash |

---

### jwt

```yaml
plugins:
  - name: jwt
    config:
      key_claim_name: iss
      claims_to_verify: [exp]
      header_names: [Authorization]
      secret_is_base64: false
```

**Create a consumer JWT credential:**
```bash
curl -X POST http://localhost:8001/consumers/{consumer}/jwt \
  -H "Content-Type: application/json" \
  -d '{"algorithm": "HS256", "key": "my-key-id", "secret": "my-jwt-secret"}'
```

| Parameter | Default | Description |
|---|---|---|
| `key_claim_name` | `iss` | JWT claim identifying the consumer credential |
| `claims_to_verify` | `["exp"]` | Claims to validate (`exp`, `nbf`) |
| `header_names` | `["Authorization"]` | Headers to look for the JWT |
| `uri_param_names` | `["jwt"]` | Query params to check for JWT |
| `secret_is_base64` | `false` | Whether the consumer secret is base64-encoded |

**Lab:** [03-B: JWT Auth](/module-03-authentication/labs/03-jwt-auth)

---

### openid-connect (Keycloak)

```yaml
plugins:
  - name: openid-connect
    config:
      issuer: "http://keycloak:8080/realms/workshop"
      client_id: [kong-demo]
      client_secret: [kong-demo-secret]
      auth_methods: [authorization_code, session]
      scopes: [openid, profile, email]
      response_mode: form_post
      login_action: redirect
      logout_path: /logout
      session_secret: "change-this-to-a-32-char-secret!!"
```

| Parameter | Description |
|---|---|
| `issuer` | IdP OIDC discovery base URL |
| `auth_methods` | `authorization_code`, `client_credentials`, `session`, `bearer` |
| `session_secret` | AES key for session cookie (min 32 chars) |
| `login_action` | `redirect` for browsers, `deny` for APIs |
| `logout_revoke` | Revoke tokens at IdP on logout |

**Lab:** [03-C: OIDC / Keycloak](/module-03-authentication/labs/03-oidc-keycloak)

---

## Resources

- [Key Auth plugin](https://developer.konghq.com/plugins/key-authentication/)
- [HMAC Auth plugin](https://developer.konghq.com/plugins/hmac-auth/)
- [JWT plugin](https://developer.konghq.com/plugins/jwt/)
- [OpenID Connect plugin](https://developer.konghq.com/plugins/openid-connect/)
- [Kong authentication overview](https://developer.konghq.com/gateway/authentication/)
- [Full Plugin Reference →](/plugin-reference)

---

*Previous: [Module 02](/module-02-core-gateway/) · Next: [Module 04 - Traffic Control →](/module-04-traffic-control/)*
