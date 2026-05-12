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

- [Request Transformer plugin](https://developer.konghq.com/plugins/request-transformer/)
- [Response Transformer plugin](https://developer.konghq.com/plugins/response-transformer/)
- [Request Transformer Advanced](https://developer.konghq.com/plugins/request-transformer-advanced/)
- [Correlation ID plugin](https://developer.konghq.com/plugins/correlation-id/)

---

*Previous: [Module 04](/module-04-traffic-control/) · Next: [Module 06 - Observability →](/module-06-observability/)*
