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

## Resources

- [Key Auth plugin](https://developer.konghq.com/plugins/key-authentication/)
- [JWT plugin](https://developer.konghq.com/plugins/jwt/)
- [OpenID Connect plugin](https://developer.konghq.com/plugins/openid-connect/)
- [Kong authentication overview](https://developer.konghq.com/gateway/authentication/)

---

*Previous: [Module 02](/module-02-core-gateway/) · Next: [Module 04 - Traffic Control →](/module-04-traffic-control/)*
