# Module 07 - OIDC & RBAC

> Enterprise-grade identity and access control: OIDC Authorization Code Flow for browser-based SSO, and Role-Based Access Control in Kong Manager for team isolation.

## Overview

| | |
|---|---|
| **Duration** | ~2.5 hours |
| **Level** | Advanced |
| **Stack** | Kong Gateway Enterprise, Keycloak, Kong Konnect |
| **Outcome** | Production-ready gateway with SSO and team-based access control |

## Learning Objectives

- Configure OIDC Authorization Code Flow end-to-end
- Set up RBAC workspaces and teams in Kong Manager
- Isolate consumers by team namespace

## Enterprise Feature Highlights

| Feature | Description |
|---|---|
| **OIDC / OpenID Connect** | Enterprise SSO with any OIDC-compliant IdP |
| **RBAC** | Role-based access control for Kong Manager |
| **Kong Konnect** | Managed control plane + analytics dashboard |
| **Audit Logs** | Full audit trail of all admin operations |

## Labs

| Lab | Topic |
|---|---|
| [07-A: OIDC Auth Code Flow](/module-07-enterprise/labs/07-oidc-auth-code) | Full browser-based SSO with Keycloak |
| [07-B: RBAC & Teams](/module-07-enterprise/labs/07-rbac-teams) | Kong Manager RBAC, consumer groups, team isolation |
| [Developer Portal Bootcamp ↗](https://kong-grajesh-se.github.io/learn-kong-dev-portal/) | Publish APIs, manage teams, customise portal |
| [APIOps Bootcamp ↗](https://kong-grajesh-se.github.io/learn-kong-apiops-bootcamp/) | GitHub Actions pipeline with quality gates |

## Plugin Quick Reference

> Condensed configs for every Enterprise plugin used in this module. See the [full Plugin Reference](/plugin-reference) for all parameters.

### openid-connect (Kong Identity)

Kong Identity is Konnect's built-in OIDC/OAuth2 IdP - zero external infrastructure required for M2M auth.

**Get your issuer URL:** Konnect → Settings → Identity → copy Issuer URL.

```yaml
plugins:
  - name: openid-connect
    config:
      issuer: "https://us.api.konghq.com/konnect-oidc/<your-org-id>"
      client_id: [<konnect-app-client-id>]
      client_secret: [<konnect-app-client-secret>]
      auth_methods: [client_credentials, bearer]
      scopes: [openid, konnect-oidc]
      login_action: deny
      bearer_token_param_type: [header]
```

**Get a token and call the API:**
```bash
TOKEN=$(curl -s -X POST \
  "https://us.api.konghq.com/konnect-oidc/<org-id>/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=<your-client-id>" \
  -d "client_secret=<your-client-secret>" \
  | jq -r '.access_token')

curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/protected
```

**Lab:** [07-A: OIDC Auth Code Flow](/module-07-enterprise/labs/07-oidc-auth-code)

---

### upstream-oauth

Allows Kong to fetch an OAuth 2.0 access token from an IdP and inject it into upstream requests - without exposing credentials to clients.

```yaml
plugins:
  - name: upstream-oauth
    config:
      oauth:
        token_endpoint: "https://idp.example.com/oauth/token"
        grant_type: client_credentials
        client_id: kong-m2m-client
        client_secret: kong-m2m-secret
        scopes: [api.read]
      client_auth_method: client_secret_basic
      cache:
        strategy: memory
```

| Parameter | Default | Description |
|---|---|---|
| `oauth.token_endpoint` | - | IdP token URL |
| `oauth.grant_type` | `client_credentials` | OAuth grant type |
| `client_auth_method` | `client_secret_basic` | `client_secret_basic`, `client_secret_post`, `client_secret_jwt` |
| `cache.strategy` | `memory` | Token cache: `memory` or `redis` |
| `token_header_name` | `Authorization` | Header name used to inject the token upstream |

---

### opa

Integrates with Open Policy Agent for policy-based authorization. Kong forwards request context; OPA evaluates Rego policy and returns allow/deny.

```yaml
plugins:
  - name: opa
    config:
      opa_host: opa
      opa_port: 8181
      opa_path: /v1/data/myapp/authz/allow
      include_consumer_in_opa_input: true
      include_service_in_opa_input: true
```

**Example Rego policy:**
```go
package myapp.authz

default allow = false

allow {
  input.request.http.method == "GET"
  input.consumer.username != ""
}
```

| Parameter | Default | Description |
|---|---|---|
| `opa_host` | `localhost` | OPA server hostname |
| `opa_port` | `8181` | OPA server port |
| `opa_path` | - | OPA data/rule API path |
| `include_consumer_in_opa_input` | `false` | Include Consumer in OPA payload |
| `include_service_in_opa_input` | `false` | Include Service in OPA payload |

---

### datakit

Node-based API workflow engine. Orchestrate third-party API calls, JWT operations, data transforms, and conditional logic in a single plugin.

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

        - name: INJECT_AUTH
          type: jq
          input: FETCH_TOKEN.body
          jq: '{ "Authorization": ("Bearer " + .access_token) }'
          output: service_request.headers
```

| Node Type | Purpose |
|---|---|
| `call` | Make an external HTTP request (runs async/parallel) |
| `jq` | Transform data with a jq expression |
| `static` | Provide hardcoded input values |
| `property` | Get/set Kong context (`kong.ctx.shared.*`, consumer, route) |
| `exit` | Return a response to the client, bypassing upstream |
| `branch` | Conditional execution based on a boolean input |
| `cache` | Store or fetch data from memory or Redis |
| `jwt_decode` / `jwt_sign` / `jwt_verify` | JWT operations |

**Lab:** Explore patterns at the [Datakit examples →](https://developer.konghq.com/plugins/datakit/examples/)

---

## Resources

- [Kong OIDC Plugin docs](https://developer.konghq.com/plugins/openid-connect/)
- [Upstream OAuth plugin](https://developer.konghq.com/plugins/upstream-oauth/)
- [OPA plugin](https://developer.konghq.com/plugins/opa/)
- [Datakit plugin](https://developer.konghq.com/plugins/datakit/)
- [Kong RBAC](https://developer.konghq.com/gateway/kong-manager/rbac/)
- [Kong Konnect](https://cloud.konghq.com/)
- [Full Plugin Reference →](/plugin-reference)

---

*Previous: [Module 06 - Observability](/module-06-observability/) · You've completed the Core Gateway bootcamp! 🎉*
