# Lab 07-F — Datakit Orchestration

> **Goal.** In ~30 minutes you'll use `datakit` to compose a multi-step pipeline at the gateway: fetch a token from one API, transform it with jq, then inject the result into the upstream request. **One plugin, one config block, no upstream code changes.**
>
> **When you'd reach for Datakit.** The upstream needs work the upstream itself can't (or shouldn't) do — calling another service, reshaping data, evaluating conditional logic. Without Datakit you'd chain several Kong plugins or write a microservice; with Datakit it's a single DAG declared inline.

::: warning Enterprise plugin
`datakit` requires **Kong Gateway Enterprise** or **Konnect**. Min version: Kong Gateway 3.11 — we're on 3.14, so this works.
:::

## How Datakit Works

Datakit lets you define a **directed acyclic graph (DAG)** of nodes. Each node does one thing (call an API, transform with jq, evaluate a condition, etc.) and passes its output to the next node.

```
request →
  [static: TOKEN_BODY]  → provide client_credentials payload
  [call: FETCH_TOKEN]   → POST to IdP, get access_token
  [jq: AUTH_HEADER]     → build { Authorization: "Bearer <token>" }
                           → service_request.headers (injected upstream)
→ upstream API (receives Bearer token)
```

## Part A - Third-Party Auth Injection

### Step 1 - Apply Datakit to a service

::: code-group

```yaml [decK YAML]
services:
  - name: partner-api
    plugins:
      - name: datakit
        config:
          nodes:
            - name: TOKEN_BODY
              type: static
              values:
                grant_type: client_credentials
                client_id: kong-client
                client_secret: kong-secret

            - name: FETCH_TOKEN
              type: call
              url: https://idp.example.com/oauth/token
              method: POST
              input: TOKEN_BODY

            - name: AUTH_HEADER
              type: jq
              input: FETCH_TOKEN.body
              jq: '{ "Authorization": ("Bearer " + .access_token) }'
              output: service_request.headers
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/services/partner-api/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "datakit",
    "config": {
      "nodes": [
        {
          "name": "TOKEN_BODY",
          "type": "static",
          "values": {
            "grant_type": "client_credentials",
            "client_id": "kong-client",
            "client_secret": "kong-secret"
          }
        },
        {
          "name": "FETCH_TOKEN",
          "type": "call",
          "url": "https://idp.example.com/oauth/token",
          "method": "POST",
          "input": "TOKEN_BODY"
        },
        {
          "name": "AUTH_HEADER",
          "type": "jq",
          "input": "FETCH_TOKEN.body",
          "jq": "{ \"Authorization\": (\"Bearer \" + .access_token) }",
          "output": "service_request.headers"
        }
      ]
    }
  }' | jq '{id, name}'
```

:::

## Part B - Conditional Request Routing (Branch)

### Step 2 - Block unauthenticated consumers with exit node

```yaml
config:
  nodes:
    - name: CHECK_CONSUMER
      type: property
      property: consumer.username
      output: CONSUMER_NAME

    - name: IS_AUTHENTICATED
      type: jq
      input: CONSUMER_NAME
      jq: '. != null and . != ""'

    - name: GUARD
      type: branch
      input: IS_AUTHENTICATED
      then: []         # continue to upstream
      else:
        - name: DENY
          type: exit
          status: 401
          body: '{"message":"Authentication required"}'
```

## Part C - Response Enrichment

### Step 3 - Add metadata to upstream response

```yaml
config:
  nodes:
    - name: ADD_META
      type: jq
      input: service_response.body
      jq: '. + { "_gateway": "kong", "_served_at": now | todate }'
      output: response.body
```

## Part D - JWT Sign for Upstream

### Step 4 - Sign a JWT and inject it upstream

```yaml
config:
  nodes:
    - name: JWT_PAYLOAD
      type: static
      values:
        sub: "kong-gateway"
        aud: "partner-api"

    - name: SIGN_JWT
      type: jwt_sign
      input: JWT_PAYLOAD
      algorithm: HS256
      secret: "my-signing-secret"

    - name: INJECT_JWT
      type: jq
      input: SIGN_JWT
      jq: '{ "Authorization": ("Bearer " + .) }'
      output: service_request.headers
```

## Implicit Nodes (Always Available)

| Node | Inputs | Outputs |
|---|---|---|
| `request` | - | `body`, `headers`, `query`, `method`, `path` |
| `service_request` | `body`, `headers`, `query` | - |
| `service_response` | - | `body`, `headers`, `status` |
| `response` | `body`, `headers` | - |

## Node Type Reference

| Type | Purpose |
|---|---|
| `call` | HTTP request to external API (runs async/parallel by default) |
| `jq` | Transform data with a jq expression |
| `static` | Provide hardcoded values as input |
| `property` | Get or set Kong context values (`consumer`, `route`, `kong.ctx.shared.*`) |
| `exit` | Return response to client immediately, bypassing upstream |
| `branch` | Conditional: `then`/`else` node lists based on a boolean |
| `cache` | Store or retrieve data in memory or Redis |
| `jwt_decode` | Decode a JWT (no signature check) |
| `jwt_sign` | Create and sign a new JWT (HS256/RS256/ES256) |
| `jwt_verify` | Verify JWT signature and claims (JWKS/JWK/PEM/HMAC) |
| `xml_to_json` | Parse XML string into JSON |
| `json_to_xml` | Serialize JSON to XML string |

## Configuration Reference

| Parameter | Description |
|---|---|
| `nodes` | Array of node definitions forming the workflow DAG |
| `nodes[].name` | Unique node identifier used in input/output references |
| `nodes[].type` | Node type (see table above) |
| `nodes[].input` | Single input: `{node}` or `{node}.{field}` |
| `nodes[].output` | Single output: writes result to this target |
| `resources.cache` | Cache resource config for `cache` nodes (`strategy: memory` or `redis`) |
| `debug` | Enable detailed error output - **dev/test only, never production** |

---

*Previous: [Lab 07-D - OPA](./07-opa) · Back to [Module 07 Overview →](/module-07-enterprise/)*
