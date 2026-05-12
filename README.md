# Kong API Gateway Bootcamp

A partner-ready, end-to-end bootcamp for mastering Kong Gateway - the world's most-deployed API gateway. Nine structured modules, fully hands-on, from core concepts to enterprise AI and CI/CD.

## Overview

| | |
|---|---|
| **Format** | 7 structured modules + Plugin Reference |
| **Flow** | Core → Auth → Traffic → Transform → Observe → Enterprise |
| **Platform** | macOS · Linux · Docker |
| **Audience** | Developers, DevOps, Platform teams, Enterprise architects |
| **Demo repo** | [get-started-guide](https://github.com/Kong-Grajesh-SE/get-started-guide) |
| **Plugin Reference** | [plugin-reference.md](./plugin-reference.md) — quick configs for all 17 plugins |

## Bootcamp Modules

| # | Module | Key Topics | Plugins |
|---|---|---|---|
| 01 | **Orientation & Setup** | Install, architecture, first proxied request, Kong Manager | — |
| 02 | **Core Gateway Concepts** | Services, Routes, Upstreams, Consumers, decK | — |
| 03 | **Authentication Plugins** | Key Auth, JWT, HMAC Auth, OIDC / Keycloak | `key-auth` `hmac-auth` `jwt` `openid-connect` |
| 04 | **Traffic Control** | Rate Limiting, Circuit Breaker, ACL, CORS, IP Restriction, Caching | `rate-limiting-advanced` `acl` `cors` `ip-restriction` `proxy-cache` |
| 05 | **Transformations** | Request/Response Transformer, Correlation ID | `request-transformer-advanced` `response-transformer-advanced` `correlation-id` |
| 06 | **Observability** | HTTP Logging, Prometheus + Grafana, OpenTelemetry | `http-log` `prometheus` `opentelemetry` |
| 07 | **OIDC & RBAC** | OIDC Auth Code Flow, RBAC, Upstream OAuth, OPA, Datakit | `openid-connect` `upstream-oauth` `opa` `datakit` |

## Learning Journey

```
Foundation   → Module 01: Orientation & Setup
Core         → Module 02: Services, Routes, Upstreams, Consumers
Security     → Module 03: Key Auth · HMAC Auth · JWT · OIDC
Traffic      → Module 04: Rate Limiting · ACL · CORS · IP Restriction · Caching
Transform    → Module 05: Request/Response Transformers · Correlation ID
Observe      → Module 06: HTTP Logs · Prometheus · OpenTelemetry
Enterprise   → Module 07: OIDC (Kong Identity) · RBAC · Upstream OAuth · OPA · Datakit
```

## Plugins Covered

17 plugins across 6 categories — each with quick config, parameter table, and lab link.
See the **[Plugin Reference →](./plugin-reference.md)** for the full reference.

| Category | Plugins |
|---|---|
| **Authentication** | `key-auth` · `hmac-auth` · `jwt` · `openid-connect` · `upstream-oauth` |
| **Authorization** | `acl` |
| **Security** | `cors` · `ip-restriction` · `opa` |
| **Traffic Control** | `rate-limiting-advanced` · `proxy-cache` · `proxy-cache-advanced` · `datakit` |
| **Transformation** | `request-transformer-advanced` · `response-transformer-advanced` · `correlation-id` |
| **Observability** | `http-log` · `prometheus` · `opentelemetry` |

## Prerequisites

- Basic HTTP knowledge (REST, headers, status codes)
- Docker Desktop installed
- Terminal / command line familiarity
- A free [Kong Konnect account](https://cloud.konghq.com) (required for Module 07)

## Quick Start

```bash
# 1. Clone the bootcamp
git clone https://github.com/Kong-Grajesh-SE/api-gateway-bootcamp
cd api-gateway-bootcamp

# 2. Install dependencies
npm install

# 3. Start the docs site locally
npm run docs:dev
```

Open [http://localhost:5173](http://localhost:5173) to view the bootcamp site.

## Demo Repository

All practical labs reference the [get-started-guide](https://github.com/Kong-Grajesh-SE/get-started-guide) repo which includes:

| Component | Description |
|---|---|
| `server/` | Express.js backend with 27 API endpoints (flights, hotels, cars, weather, MCP tools) |
| `deck/` | Full declarative Kong config (services, plugins, consumers) |
| `docker-compose.yml` | Kong + PostgreSQL + Keycloak + Ollama stack |
| `docs/` | Reference guides for each workshop topic |

```bash
# Start the demo backend
cd get-started-guide
npm install
npm run dev:all     # starts frontend (:5173) + backend (:3001)
```

## Repo Structure

```
api-gateway-bootcamp/
├── README.md
├── index.md                         ← VitePress home page
├── plugin-reference.md              ← Quick configs for all 17 plugins
├── package.json
├── public/
│   ├── logomark.svg                 ← Kong logomark
│   ├── kong-gateway-logo.svg        ← Kong Gateway product logo
│   └── favicon.png
├── docs/.vitepress/
│   ├── config.js                    ← VitePress + navigation config
│   └── theme/
│       ├── index.js                 ← extends default theme
│       └── style.css                ← Kong brand design system
├── module-01-orientation/
│   ├── README.md
│   └── labs/
│       ├── 01-install-verify.md
│       └── 01-first-api-call.md
├── module-02-core-gateway/
│   ├── README.md
│   └── labs/
│       ├── 02-services-routes.md
│       ├── 02-upstreams.md
│       └── 02-consumers.md
├── module-03-authentication/
│   ├── README.md
│   └── labs/
│       ├── 03-key-auth.md
│       ├── 03-jwt-auth.md
│       └── 03-oidc-keycloak.md
├── module-04-traffic-control/
│   ├── README.md
│   └── labs/
│       ├── 04-rate-limiting.md
│       ├── 04-circuit-breaker.md
│       └── 04-acl.md
├── module-05-transformations/
│   ├── README.md
│   └── labs/
│       ├── 05-request-transformer.md
│       ├── 05-response-transformer.md
│       └── 05-correlation-id.md
├── module-06-observability/
│   ├── README.md
│   └── labs/
│       ├── 06-http-logging.md
│       ├── 06-prometheus.md
│       └── 06-opentelemetry.md
├── module-07-enterprise/
    ├── README.md
    └── labs/
        ├── 07-oidc-auth-code.md
        └── 07-rbac-teams.md
```

## Resources

| Resource | URL |
|---|---|
| Kong Gateway docs | https://developer.konghq.com/gateway/ |
| Kong Plugin Hub | https://developer.konghq.com/plugins/ |
| Kong Konnect | https://cloud.konghq.com |
| decK docs | https://developer.konghq.com/deck/ |
| OPA (Open Policy Agent) | https://www.openpolicyagent.org/ |
| AI Gateway | https://developer.konghq.com/ai-gateway/ |
| MCP specification | https://modelcontextprotocol.io/ |

© Kong Inc. 2026 - The AI Connectivity Company
