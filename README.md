# Kong API Gateway Bootcamp

A partner-ready, end-to-end bootcamp for mastering Kong Gateway - the world's most-deployed API gateway. Nine structured modules, fully hands-on, from core concepts to enterprise AI and CI/CD.

## Overview

| | |
|---|---|
| **Format** | 9 structured modules |
| **Flow** | Core → Auth → Traffic → Transform → Observe → AI → Agents → Enterprise |
| **Platform** | macOS · Linux · Docker |
| **Audience** | Developers, DevOps, Platform teams, Enterprise architects |
| **Demo repo** | [get-started-guide](https://github.com/Kong-Grajesh-SE/get-started-guide) |

## Bootcamp Modules

| # | Module | Key Topics |
|---|---|---|
| 01 | **Orientation & Setup** | Install, architecture, first proxied request, Kong Manager |
| 02 | **Core Gateway Concepts** | Services, Routes, Upstreams, Consumers, decK |
| 03 | **Authentication Plugins** | Key Auth, JWT, OIDC / Keycloak |
| 04 | **Traffic Control** | Rate Limiting, Circuit Breaker, ACL groups |
| 05 | **Transformations** | Request/Response Transformer, Correlation ID |
| 06 | **Observability** | HTTP Logging, Prometheus + Grafana, OpenTelemetry |
| 07 | **AI Gateway** | ai-proxy-advanced, Prompt Guard, Semantic Cache, PII Sanitizer |
| 08 | **Agentic AI & MCP** | ai-mcp-proxy, OAuth2+PKCE, A2A agents |
| 09 | **Enterprise & CI/CD** | OIDC Auth Code, Developer Portal, decK GitOps, RBAC |

## Learning Journey

```
Foundation   → Module 01: Orientation & Setup
Core         → Module 02: Services, Routes, Upstreams
Security     → Module 03: Authentication Plugins
Traffic      → Module 04: Rate Limiting & Circuit Breaker
Transform    → Module 05: Request/Response Transformers
Observe      → Module 06: Logs, Metrics, Traces
AI           → Module 07: AI Gateway
Agents       → Module 08: MCP & Agentic AI
Enterprise   → Module 09: OIDC, Developer Portal, CI/CD
```

## Prerequisites

- Basic HTTP knowledge (REST, headers, status codes)
- Docker Desktop installed
- Terminal / command line familiarity
- A free [Kong Konnect account](https://cloud.konghq.com) (required for Module 09)

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
├── module-07-ai-gateway/
│   ├── README.md
│   └── labs/
│       ├── 07-ai-proxy.md
│       ├── 07-prompt-guard.md
│       ├── 07-semantic-cache.md
│       ├── 07-prompt-templates.md
│       └── 07-pii-sanitizer.md
├── module-08-agentic-mcp/
│   ├── README.md
│   └── labs/
│       ├── 08-mcp-proxy.md
│       ├── 08-mcp-oauth2.md
│       └── 08-a2a-agents.md
└── module-09-enterprise/
    ├── README.md
    └── labs/
        ├── 09-oidc-auth-code.md
        ├── 09-dev-portal.md
        ├── 09-deck-cicd.md
        └── 09-rbac-teams.md
```

## Resources

| Resource | URL |
|---|---|
| Kong Gateway docs | https://developer.konghq.com/gateway/ |
| Kong Plugin Hub | https://developer.konghq.com/plugins/ |
| Kong Konnect | https://cloud.konghq.com |
| decK docs | https://developer.konghq.com/deck/ |
| AI Gateway | https://developer.konghq.com/ai-gateway/ |
| MCP specification | https://modelcontextprotocol.io/ |

© Kong Inc. 2026 - The AI Connectivity Company
