# Kong API Gateway Bootcamp

![Kong Gateway 3.14+](https://img.shields.io/badge/Kong%20Gateway-3.14%2B-CCFF00?style=for-the-badge&labelColor=001408)
![Platform: Konnect](https://img.shields.io/badge/Platform-Konnect-CCFF00?style=for-the-badge&labelColor=001408)
![Modules: 8](https://img.shields.io/badge/Modules-8-CCFF00?style=for-the-badge&labelColor=001408)

> ⚙️ **Requires Kong Gateway 3.14 or newer**, deployed on Konnect (free tier works) or self-hosted. Plugin schemas, header behavior (`X-Forwarded-Path`, `X-Forwarded-Prefix`), and decK syntax assume 3.14+. Older Kong releases will fail several labs.

A partner-ready, end-to-end bootcamp for mastering Kong Gateway. Eight structured modules, fully hands-on - from your first proxied request to a 15-step production capstone - plus specialist deep-dives.

## Overview

| | |
|---|---|
| **Kong version** | **Kong Gateway 3.14+** (older versions will fail several labs) |
| **Format** | 8 modules (incl. Capstone) + Plugin Reference + Specialist Bootcamps |
| **Flow** | Foundations → Easy Wins → Traffic → Transform → Observe → Advanced → Capstone |
| **Platform** | macOS · Linux · Docker (Konnect serverless works without Docker) |
| **Audience** | Developers, DevOps, Platform teams, Enterprise architects |
| **Plugin Reference** | [plugin-reference.md](./plugin-reference.md) - quick configs for every plugin |

## Bootcamp Modules

| # | Module | Key Topics | Plugins |
|---|---|---|---|
| 01 | **Your First Gateway** | Konnect serverless, Service + Route, first proxied request, decK vs Admin API | - |
| 02 | **Routing & Topology** | Multiple Services, route-matching priority, Upstreams, active/passive health checks | - |
| 03 | **Easy Wins** | Consumers, key-auth, CORS, IP restriction, correlation-id | `key-auth` `cors` `ip-restriction` `correlation-id` |
| 04 | **Traffic & Resilience** | Per-Consumer rate limits, Retry-After, proxy-cache, cache invalidation | `rate-limiting` `proxy-cache` |
| 05 | **Transformations** | Request/response rewriting, template variables, rename for migrations, conditional transforms | `request-transformer-advanced` `response-transformer-advanced` |
| 06 | **Observability** | http-log + redaction, RED queries in Prometheus, OTLP distributed traces | `http-log` `prometheus` `opentelemetry` |
| 07 | **Enterprise & Advanced** | JWT + HMAC, Consumer Groups + ACL, OIDC Auth Code, Upstream OAuth, OPA, Datakit, RBAC | `jwt` `hmac-auth` `acl` `openid-connect` `upstream-oauth` `opa` `datakit` |
| 08 | **Capstone** | Design the production gateway: 11+ plugins, 3 Consumer tiers, 15-step acceptance test | (integration) |

## Learning Journey

```
Foundation     → M01: Your First Gateway (Konnect serverless, ~60 min)
Topology       → M02: Routing & Topology (Services / Routes / Upstreams / health)
Easy Wins      → M03: key-auth · cors · ip-restriction · correlation-id (Tier 1)
Traffic        → M04: rate-limiting · proxy-cache (per-tier guardrails)
Transform      → M05: request/response transformer-advanced (in-flight rewrites)
Observe        → M06: http-log · prometheus · opentelemetry (3 pillars)
Advanced       → M07: JWT · HMAC · ACL+groups · OIDC · upstream-oauth · OPA · Datakit · RBAC
Capstone       → M08: design + 15-step acceptance test (~3 h)
```

## Plugins Covered

20 plugins across 6 categories - each with quick config, parameter table, and lab link.
See the **[Plugin Reference →](./plugin-reference.md)** for the full reference.

| Category | Plugins |
|---|---|
| **Authentication** | `key-auth` · `hmac-auth` · `jwt` · `openid-connect` · `upstream-oauth` |
| **Authorization** | `acl` |
| **Security** | `cors` · `ip-restriction` · `opa` |
| **Traffic Control** | `rate-limiting-advanced` · `proxy-cache` · `proxy-cache-advanced` · `datakit` |
| **Transformation** | `request-transformer-advanced` · `response-transformer-advanced` · `correlation-id` |
| **Observability** | `http-log` · `prometheus` · `opentelemetry` |

## Specialist Bootcamps

After completing the core modules, go deep with these specialist tracks:

| Bootcamp | Focus | Link |
|---|---|---|
| **AI Gateway** | LLM proxy, prompt injection guards, semantic caching, PII sanitization | [learn-kong-ai-gateway ↗](https://kong-grajesh-se.github.io/learn-kong-ai-gateway/) |
| **Agentic AI & MCP** | MCP proxy, OAuth2/PKCE for agents, Agent-to-Agent routing | [learn-kong-agentic-bootcamp ↗](https://kong-grajesh-se.github.io/learn-kong-agentic-bootcamp/) |
| **Developer Portal** | Publish APIs, OIDC SSO, self-service app registration, RBAC | [learn-kong-dev-portal ↗](https://kong-grajesh-se.github.io/learn-kong-dev-portal/) |
| **APIOps** | GitOps with decK, GitHub Actions CI/CD, quality gates | [learn-kong-apiops-bootcamp ↗](https://kong-grajesh-se.github.io/learn-kong-apiops-bootcamp/) |
| **Insomnia** | API design, testing, and debugging with Insomnia | [learn-insomnia ↗](https://kong-grajesh-se.github.io/learn-insomnia/) |
| **Bring Your Own Agent** | Plug your own agent into Kong's MCP/AI infrastructure | [bring-your-own-agent ↗](https://kong-grajesh-se.github.io/bring-your-own-agent/) |

## Prerequisites

- Basic HTTP knowledge (REST, headers, status codes)
- Docker Desktop installed
- Terminal / command line familiarity
- A free [Kong Konnect account](https://cloud.konghq.com) (required for Module 07)

## Quick Start

```bash
# 1. Clone the bootcamp
git clone https://github.com/Kong-Grajesh-SE/learn-kong-gateway
cd api-gateway-bootcamp

# 2. Install dependencies
npm install

# 3. Start the docs site locally
npm run docs:dev
```

Open [http://localhost:5173](http://localhost:5173) to view the bootcamp site.

## Repo Structure

```
api-gateway-bootcamp/
├── README.md
├── index.md                         ← VitePress home page
├── plugin-reference.md              ← Quick configs for all 20 plugins
├── prerequisites.md
├── deployment-overview.md
├── api-specs.md
├── package.json
├── public/
│   ├── kong-gateway-logo.svg
│   └── favicon.png
├── docs/.vitepress/
│   ├── config.js                    ← VitePress + navigation config
│   └── theme/
│       ├── index.js
│       └── style.css
├── module-01-orientation/
│   ├── README.md
│   └── labs/
│       ├── 01-quick-start.md
│       └── 01-hybrid-docker-setup.md   ← optional
├── module-02-core-gateway/
│   ├── README.md
│   └── labs/
│       ├── 02-services-routes.md    ← multi-service routing
│       └── 02-upstreams.md          ← upstreams + health checks
├── module-03-authentication/         ← "Easy Wins" - Tier-1 plugins
│   ├── README.md
│   └── labs/
│       ├── 03-key-auth.md            ← Consumers + key-auth deep dive
│       └── 03-easy-wins.md           ← cors + ip-restriction + correlation-id
├── module-04-traffic-control/        ← "Traffic & Resilience"
│   ├── README.md
│   └── labs/
│       ├── 04-rate-limiting.md       ← per-Consumer limits, 429 + Retry-After
│       └── 04-proxy-cache.md         ← cache GETs in Kong's memory
├── module-05-transformations/
│   ├── README.md
│   └── labs/
│       ├── 05-request-transformer.md
│       └── 05-response-transformer.md
├── module-06-observability/
│   ├── README.md
│   └── labs/
│       ├── 06-http-logging.md
│       ├── 06-prometheus.md
│       └── 06-opentelemetry.md
├── module-07-enterprise/                ← "Enterprise & Advanced"
│   ├── README.md
│   └── labs/
│       ├── 07-advanced-auth.md           ← JWT + HMAC
│       ├── 07-consumer-groups-acl.md     ← Consumer Groups + ACL + tier limits
│       ├── 07-oidc-auth-code.md          ← browser SSO
│       ├── 07-upstream-oauth.md          ← M2M token injection
│       ├── 07-opa.md                     ← policy-as-code with Rego
│       ├── 07-datakit.md                 ← multi-step orchestration
│       └── 07-rbac-teams.md              ← Kong Manager workspaces
└── module-08-capstone/                  ← integrated capstone scenario
    ├── README.md
    └── labs/
        └── 08-capstone.md                ← 11+ plugins, 15-step acceptance test
```

## Resources

| Resource | URL |
|---|---|
| Kong Gateway docs | https://developer.konghq.com/gateway/ |
| Kong Plugin Hub | https://developer.konghq.com/plugins/ |
| Kong Konnect | https://cloud.konghq.com |
| OPA (Open Policy Agent) | https://www.openpolicyagent.org/ |

© Kong Inc. 2026 - The AI Connectivity Company

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
