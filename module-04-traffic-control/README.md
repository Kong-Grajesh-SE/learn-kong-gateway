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

## Rate Limiting Priority

When multiple rate limit plugins apply (global + service + route), Kong enforces **the most restrictive**:

```
Global: 1000 req/hour
Service: 500 req/hour   ← this wins for this service
Route: 100 req/minute   ← this wins for this route
```

## Resources

- [Rate Limiting plugin](https://developer.konghq.com/plugins/rate-limiting/)
- [Rate Limiting Advanced plugin](https://developer.konghq.com/plugins/rate-limiting-advanced/)
- [ACL plugin](https://developer.konghq.com/plugins/acl/)
- [Kong load balancing guide](https://developer.konghq.com/gateway/load-balancing/)

---

*Previous: [Module 03](/module-03-authentication/) · Next: [Module 05 - Transformations →](/module-05-transformations/)*
