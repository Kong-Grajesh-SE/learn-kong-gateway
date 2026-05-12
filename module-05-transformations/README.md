# Module 05 - Transformations

> Kong's transformer plugins let you reshape API requests and responses on the fly - without changing your backend. Add, remove, or rewrite headers, body fields, and query parameters.

## Overview

| | |
|---|---|
| **Duration** | ~75 minutes |
| **Level** | Intermediate |
| **Stack** | Kong Gateway, decK |
| **Outcome** | Request/response transformation pipeline with correlation IDs |

## Learning Objectives

- Add, remove, and replace request headers and body fields
- Inject metadata into responses
- Implement request/response transformation chains
- Add correlation IDs for distributed tracing

## Transformation Plugins

| Plugin | Scope | Purpose |
|---|---|---|
| **request-transformer** | Free tier | Add/remove/replace request headers, body, query |
| **response-transformer** | Free tier | Add/remove/replace response headers, body |
| **request-transformer-advanced** | Enterprise | Above + arrays, templates, conditional transforms |
| **response-transformer-advanced** | Enterprise | Above + JSON path transforms |
| **correlation-id** | Free tier | Inject unique request ID for tracing |
| **pre-function** | Free tier | Run Lua code before plugins |
| **post-function** | Free tier | Run Lua code after plugins |

## Transformation Operations

All transformer plugins support these operations on `headers`, `querystring`, and `body`:

| Operation | Effect |
|---|---|
| `add` | Add if the key does not already exist |
| `append` | Add a value (allows multiple values for same key) |
| `remove` | Delete the key entirely |
| `replace` | Overwrite if the key exists |
| `rename` | Rename a key (request-transformer-advanced only) |

## Labs

| Lab | Topic |
|---|---|
| [05-A: Request Transformer](/module-05-transformations/labs/05-request-transformer) | Inject auth headers, strip sensitive fields, add versioning |
| [05-B: Response Transformer](/module-05-transformations/labs/05-response-transformer) | Add CORS headers, strip internal fields, inject metadata |
| [05-C: Correlation ID](/module-05-transformations/labs/05-correlation-id) | Trace requests end-to-end with unique IDs |

## Plugin Quick Reference

> Condensed configs for every plugin used in this module. See the [full Plugin Reference](/plugin-reference) for all parameters, template variables, and advanced examples.

### request-transformer-advanced

```yaml
plugins:
  - name: request-transformer-advanced
    config:
      add:
        headers:
          - "X-Kong-Proxied:true"
          - "X-Consumer-Username:$(consumer.username)"   # template variable
        querystring: []
        body: []
      remove:
        headers: [X-Internal-Debug, X-Forwarded-Secret]
        querystring: [debug, trace]
      replace:
        headers: ["X-API-Version:v3"]
      rename:
        querystring:
          - "page:offset"      # ?page= → ?offset= upstream
          - "size:limit"
```

**Template variables available:**

| Variable | Value |
|---|---|
| `$(consumer.username)` | Authenticated consumer username |
| `$(consumer.id)` | Consumer UUID |
| `$(route.id)` | Route UUID |
| `$(service.name)` | Service name |
| `$(date.timestamp)` | Unix epoch timestamp |

| Operation | Behaviour |
|---|---|
| `add` | Add if the field does **not** already exist |
| `append` | Add even if field exists (creates multi-value) |
| `remove` | Delete field |
| `replace` | Overwrite if field exists; no-op if absent |
| `rename` | Rename the key (value unchanged) |
| `allow` | Allowlist — all other fields are stripped |

**Lab:** [05-A: Request Transformer](/module-05-transformations/labs/05-request-transformer)

---

### response-transformer-advanced

```yaml
plugins:
  - name: response-transformer-advanced
    config:
      add:
        headers: ["X-Powered-By:Kong Gateway"]
        json: ["metadata.gateway:\"kong\"", "api_version:\"v2\""]
        json_types: [string, string]
      remove:
        headers: [X-Served-By, Via, Server]
        json: [data.internal_cost, data.provider_id]
      replace:
        json: ["status:\"processed\""]
        json_types: [string]
```

| Operation | Description |
|---|---|
| `add.json` | Add JSON key:value if absent (supports dotted paths) |
| `remove.json` | Remove JSON field by key or dotted path |
| `replace.json` | Overwrite JSON field if it exists |
| `allow.json` | Allowlist — all other JSON fields stripped from response |
| `transform.functions` | Lua snippets for arbitrary body manipulation |

**Lab:** [05-B: Response Transformer](/module-05-transformations/labs/05-response-transformer)

---

### correlation-id

```yaml
plugins:
  - name: correlation-id
    config:
      header_name: X-Request-ID
      generator: uuid#counter     # uuid | uuid#counter | tracker
      echo_downstream: true       # return the ID in the response
```

| Parameter | Default | Description |
|---|---|---|
| `header_name` | `Kong-Request-ID` | Header injected into request and response |
| `generator` | `uuid#counter` | ID format: `uuid`, `uuid#counter`, `tracker` |
| `echo_downstream` | `false` | Include the ID in the response headers |

**Lab:** [05-C: Correlation ID](/module-05-transformations/labs/05-correlation-id)

---

## Reference Config from get-started-guide

The mytravel demo uses these plugins on the bookings route:

```yaml
# On POST /api/bookings:
plugins:
  - name: request-transformer-advanced   # add audit headers
  - name: response-transformer           # inject demo:injected-by-kong header
  - name: response-transformer-advanced  # advanced JSON body transforms
```

## Resources

- [Request Transformer Advanced](https://developer.konghq.com/plugins/request-transformer-advanced/)
- [Response Transformer plugin](https://developer.konghq.com/plugins/response-transformer/)
- [Correlation ID plugin](https://developer.konghq.com/plugins/correlation-id/)
- [Full Plugin Reference →](/plugin-reference)

---

*Previous: [Module 04](/module-04-traffic-control/) · Next: [Module 06 - Observability →](/module-06-observability/)*
