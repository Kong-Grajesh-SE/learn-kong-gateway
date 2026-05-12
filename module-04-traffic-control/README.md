# Module 04 - Traffic Control

> Kong's traffic control plugins protect your backends from overload, enforce access policies, and provide circuit breaking capabilities - all without changing your upstream services.

## Overview

| | |
|---|---|
| **Duration** | ~90 minutes |
| **Level** | Intermediate |
| **Stack** | Kong Gateway, decK |
| **Outcome** | Rate limiting by IP/consumer, ACL groups, circuit breaker |

## Learning Objectives

- Configure rate limiting at global, service, and consumer level
- Implement consumer group-based access control with ACL
- Set up health-checked circuit breaking via Upstreams

## Traffic Control Plugins

| Plugin | Purpose | Key Config |
|---|---|---|
| **rate-limiting** | Limit requests per window | `second`, `minute`, `hour`, `day` |
| **rate-limiting-advanced** | Sliding window, Redis, consumer groups | `window_size`, `strategy` |
| **request-size-limiting** | Block oversized request bodies | `allowed_payload_size` |
| **response-ratelimiting** | Limit based on response headers | `limits` |
| **acl** | Allow/deny by consumer group | `allow` / `deny` lists |
| **ip-restriction** | Allow/deny by IP CIDR | `allow` / `deny` lists |
| **bot-detection** | Block known bot user agents | `allow` / `deny` patterns |

## Rate Limiting Strategy Options

| Strategy | Description | Requires |
|---|---|---|
| `local` | In-memory per-node | Nothing |
| `cluster` | Shared via Kong DB | PostgreSQL |
| `redis` | Shared via Redis | Redis |

::: tip Production Recommendation
Use `redis` strategy in production for accurate rate limiting across multiple Kong data plane nodes.
:::

## Rate Limit Headers

When rate limiting is applied, Kong adds these response headers:

```
X-RateLimit-Limit-Minute: 100
X-RateLimit-Remaining-Minute: 87
X-RateLimit-Reset-Minute: 42
Retry-After: 42    (when limit exceeded → 429)
```

## Labs

| Lab | Topic |
|---|---|
| [04-A: Rate Limiting](/module-04-traffic-control/labs/04-rate-limiting) | Apply rate limits by IP, consumer, and with Redis |
| [04-B: Circuit Breaker](/module-04-traffic-control/labs/04-circuit-breaker) | Upstream health checks, passive circuit breaking |
| [04-C: ACL Groups](/module-04-traffic-control/labs/04-acl) | Access control lists with consumer groups |

## Plugin Quick Reference

> Condensed configs for every plugin used in this module. See the [full Plugin Reference](/plugin-reference) for all parameters and advanced examples.

### rate-limiting-advanced

```yaml
plugins:
  - name: rate-limiting-advanced
    config:
      limit: [60, 1000]              # requests per window
      window_size: [60, 3600]        # window in seconds (minute, hour)
      window_type: sliding           # sliding | fixed
      identifier: consumer           # consumer | ip | credential | header
      sync_rate: 10                  # sync to Redis every 10s
      namespace: api-gateway-bootcamp
```

| Parameter | Default | Description |
|---|---|---|
| `limit` | - | Request limits per window (array, matches `window_size`) |
| `window_size` | - | Window durations in seconds |
| `window_type` | `sliding` | `sliding` (smooth) or `fixed` (resets on interval) |
| `identifier` | `consumer` | What to rate-limit by: `consumer`, `ip`, `credential`, `header`, `path` |
| `sync_rate` | `-1` | How often (seconds) to sync counters to Redis (`-1` = every request) |
| `hide_client_headers` | `false` | Suppress `X-RateLimit-*` response headers |

**Response headers Kong adds:**
```
X-RateLimit-Limit-Minute: 60
X-RateLimit-Remaining-Minute: 47
RateLimit-Reset: 13
Retry-After: 13   ← only on 429
```

**Lab:** [04-A: Rate Limiting](/module-04-traffic-control/labs/04-rate-limiting)

---

### acl

```yaml
plugins:
  - name: acl
    config:
      allow: [premium-tier, admin-tier]   # OR use deny:, not both
      hide_groups_header: true
```

**Assign consumer to a group:**
```bash
# Create group
curl -X PUT http://localhost:8001/consumer_groups/premium-tier

# Add consumer
curl -X POST http://localhost:8001/consumer_groups/premium-tier/consumers \
  -d '{"consumer": "travel-web-app"}'
```

| Parameter | Description |
|---|---|
| `allow` | Groups permitted to access the resource |
| `deny` | Groups blocked from accessing the resource |
| `hide_groups_header` | Don't forward `X-Consumer-Groups` to upstream |

::: warning Must be paired with an auth plugin
ACL only works when a consumer is already identified. Pair it with `key-auth`, `jwt`, or `openid-connect`.
:::

**Lab:** [04-C: ACL Groups](/module-04-traffic-control/labs/04-acl)

---

### cors

```yaml
plugins:
  - name: cors
    config:
      origins: ["https://app.example.com"]
      methods: [GET, POST, PUT, DELETE, OPTIONS]
      headers: [Authorization, Content-Type, X-API-Key]
      credentials: true
      max_age: 3600
      preflight_continue: false
```

| Parameter | Default | Description |
|---|---|---|
| `origins` | `["*"]` | Allowed origins (explicit list or `*`) |
| `methods` | all standard | HTTP methods to allow |
| `headers` | `[]` | Allowed request headers |
| `credentials` | `false` | Allow cookies/auth. Incompatible with `origins: ["*"]` |
| `max_age` | `null` | Preflight cache lifetime in seconds |

---

### ip-restriction

```yaml
plugins:
  - name: ip-restriction
    config:
      allow:
        - 10.0.0.0/8
        - 192.168.1.100
      status: 403
      message: "Your IP address is not permitted."
```

| Parameter | Default | Description |
|---|---|---|
| `allow` | `[]` | Allowlisted IPs/CIDRs - all others blocked |
| `deny` | `[]` | Denylisted IPs/CIDRs - all others allowed |
| `status` | `403` | HTTP status when denied |

---

### proxy-cache

```yaml
plugins:
  - name: proxy-cache
    config:
      strategy: memory
      response_code: [200, 301]
      request_method: [GET, HEAD]
      content_type: [application/json]
      cache_ttl: 300
      cache_control: false
```

**Check cache status:**
```bash
curl -si http://localhost:8000/api/flights | grep X-Cache
# X-Cache-Status: Miss  → first request (now cached)
# X-Cache-Status: Hit   → served from cache
```

| Parameter | Default | Description |
|---|---|---|
| `strategy` | `memory` | `memory` (OSS) or use `proxy-cache-advanced` for Redis |
| `cache_ttl` | `300` | Cache entry lifetime in seconds |
| `response_code` | `[200,301,404]` | Status codes to cache |
| `request_method` | `[GET,HEAD]` | Methods to cache |

---

## Rate Limiting Priority

When multiple rate limit plugins apply (global + service + route), Kong enforces **the most restrictive**:

```
Global: 1000 req/hour
Service: 500 req/hour   ← this wins for this service
Route: 100 req/minute   ← this wins for this route
```

## Resources

- [Rate Limiting Advanced plugin](https://developer.konghq.com/plugins/rate-limiting-advanced/)
- [ACL plugin](https://developer.konghq.com/plugins/acl/)
- [CORS plugin](https://developer.konghq.com/plugins/cors/)
- [IP Restriction plugin](https://developer.konghq.com/plugins/ip-restriction/)
- [Proxy Cache plugin](https://developer.konghq.com/plugins/proxy-cache/)
- [Kong load balancing guide](https://developer.konghq.com/gateway/load-balancing/)
- [Full Plugin Reference →](/plugin-reference)

---

*Previous: [Module 03](/module-03-authentication/) · Next: [Module 05 - Transformations →](/module-05-transformations/)*
