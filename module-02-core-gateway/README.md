# Module 02 - Core Gateway Concepts

> The four pillars of Kong: **Services**, **Routes**, **Upstreams**, and **Consumers**. Master these and you can model any API topology.

## Overview

| | |
|---|---|
| **Duration** | ~90 minutes |
| **Level** | Beginner–Intermediate |
| **Stack** | Kong Gateway, Express.js backend, decK |
| **Outcome** | Full declarative config for a travel API with load balancing |

## Learning Objectives

- Configure Services and Routes with advanced matching rules
- Set up Upstreams with multiple targets for load balancing
- Create Consumers with credentials
- Write and apply declarative YAML with decK

## Services

A **Service** maps a logical name to an upstream API. Kong uses the service's `host`, `port`, and `protocol` to forward requests.

```yaml
services:
  - name: mytravel-com-api
    host: host.docker.internal   # or an Upstream name
    port: 3001
    protocol: http
    connect_timeout: 60000
    read_timeout: 60000
    retries: 5
```

### Service vs Upstream

| | Service | Upstream |
|---|---|---|
| **Purpose** | Names an API | Load-balances across targets |
| **host field** | IP / hostname / Upstream name | N/A |
| **When to use** | Always | When you have >1 backend target |

## Routes

A **Route** is a matching rule that determines which requests go to a Service.

### Matching Priority

Kong evaluates routes in this priority order:

1. **Longer paths** take precedence (`/api/flights` > `/api`)
2. **More specific methods** (GET only > GET+POST)
3. **Headers** matching rules

```yaml
routes:
  - name: flights-get
    paths:
      - ~/api/flights$          # regex match
    methods: [GET]
    strip_path: false
    preserve_host: true
    protocols: [http, https]
```

### Route Matching Examples

| Pattern | Matches | Doesn't match |
|---|---|---|
| `/api/flights` | `/api/flights`, `/api/flights/` | `/api/flight` |
| `~/api/flights$` | `/api/flights` only (regex) | `/api/flights/123` |
| `~/api/flights/\d+` | `/api/flights/456` | `/api/flights/abc` |

## Upstreams

An **Upstream** is a virtual hostname pointing to a pool of backend **targets**. This enables load balancing and health checks.

```yaml
upstreams:
  - name: mytravel-upstream
    algorithm: round-robin       # round-robin | least-connections | consistent-hashing
    healthchecks:
      active:
        healthy:
          interval: 5
          successes: 2
        unhealthy:
          interval: 5
          http_failures: 3
    targets:
      - target: backend-1:3001
        weight: 100
      - target: backend-2:3001
        weight: 100
```

### Load Balancing Algorithms

| Algorithm | Best For |
|---|---|
| `round-robin` | Equal-weight servers |
| `least-connections` | Variable request duration |
| `consistent-hashing` | Session affinity (sticky sessions) |
| `latency` | Optimise for fastest response |

## Consumers

A **Consumer** represents an API client - a user, application, or service.

```yaml
consumers:
  - username: travel-app
    custom_id: app-001
    tags: [web, v2]
```

Consumers are the "who" in Kong's auth model. Plugins like Key Auth, JWT, and OAuth2 attach **credentials** to consumers.

## The mytravel-com-api Service

The reference demo uses a travel API with 14 routes covering:

| Resource | Endpoints |
|---|---|
| Flights | `GET /api/flights`, `GET /api/flights/:id`, `POST /api/bookings` |
| Hotels | `GET /api/hotels`, `GET /api/hotels/:id`, `POST /api/hotels/reserve` |
| Cars | `GET /api/cars`, `GET /api/cars/:id`, `POST /api/cars/reserve` |
| Weather | `GET /api/weather/:airport` |
| Users | `GET /api/users/profile` (OIDC protected) |
| Health | `GET /health` |

## decK - Declarative Configuration

decK is Kong's GitOps tool. Manage your entire gateway config in YAML.

```bash
# Install
brew install kong/tap/deck

# Diff - preview what would change
deck gateway diff --kong-addr http://localhost:8001 kong-state.yaml

# Sync - apply the config
deck gateway sync --kong-addr http://localhost:8001 kong-state.yaml

# Dump - export current config
deck gateway dump --kong-addr http://localhost:8001 > kong-state.yaml

# Validate - lint without connecting to Kong
deck file validate kong-state.yaml
```

## Labs

| Lab | Topic |
|---|---|
| [02-A: Services & Routes](/module-02-core-gateway/labs/02-services-routes) | Configure the travel API with advanced route matching |
| [02-B: Upstreams & Load Balancing](/module-02-core-gateway/labs/02-upstreams) | Set up an upstream with health checks and two targets |
| [02-C: Consumers](/module-02-core-gateway/labs/02-consumers) | Create consumers and manage their lifecycle with decK |

## Resources

- [Services API reference](https://developer.konghq.com/gateway/entities/service/)
- [Routes API reference](https://developer.konghq.com/gateway/entities/route/)
- [Upstreams API reference](https://developer.konghq.com/gateway/entities/upstream/)
- [decK docs](https://developer.konghq.com/deck/)

---

*Previous: [Module 01](/module-01-orientation/) · Next: [Module 03 - Authentication →](/module-03-authentication/)*
