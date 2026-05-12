# Module 01 - Orientation & Setup

> **What is Kong Gateway?** Kong is a cloud-native, platform-agnostic API gateway that sits in front of your APIs and manages authentication, traffic control, logging, and more - through a powerful plugin architecture.

## Overview

| | |
|---|---|
| **Duration** | ~60 minutes |
| **Level** | Beginner |
| **Platform** | Konnect (cloud.konghq.com) + local Docker Data Plane |
| **Deployment** | Hybrid mode - CP in Konnect, DP on your laptop |
| **Test upstream** | httpbin.konghq.com + kong-air (optional) |
| **Outcome** | Hybrid Data Plane connected, first proxied request, familiarity with Konnect |

::: info This bootcamp uses Konnect + Hybrid mode
The **Control Plane** is hosted on Konnect. Your **Data Plane** runs locally in Docker. All management goes through Konnect (UI or decK CLI). [→ Why? Learn about all deployment options](/deployment-overview)
:::

## Learning Objectives

By the end of this module you will be able to:

- Describe the Kong Gateway request lifecycle
- Connect a local Docker Data Plane to Konnect
- Create Services and Routes using decK YAML
- Make your first proxied API call through Kong
- Test APIs using both curl and Insomnia

## What is an API Gateway?

An API gateway is a **reverse proxy** that sits between API clients and backend services. It handles cross-cutting concerns so your services don't have to:

```
Client → Kong Data Plane (:8000) → Your Backend (httpbin.konghq.com)
                  ↕
         Konnect Control Plane (cloud.konghq.com)
           ← config pushed via mTLS
```

Kong Gateway processes every request through a **plugin chain**:

```
Request In
   ↓
[Pre-plugin phase]   ← Key Auth, JWT, Rate Limiting, CORS …
   ↓
Upstream Service
   ↓
[Post-plugin phase]  ← Response Transformer, Logging …
   ↓
Response Out
```

## Kong Core Concepts

| Concept | Description |
|---|---|
| **Service** | A named upstream API (e.g. `mytravel-api`) |
| **Route** | A matching rule (path, host, method) that maps to a Service |
| **Plugin** | Middleware attached to a Service, Route, or Consumer |
| **Consumer** | A user or application that calls your APIs |
| **Upstream** | A load-balanced pool of backend targets |
| **decK** | CLI tool to manage Kong config as declarative YAML |

## Deployment Topologies

| Mode | Description | Use Case |
|---|---|---|
| **Traditional (DB)** | Kong + PostgreSQL | Development, small teams |
| **DB-less** | Kong reads declarative YAML | GitOps, edge, Kubernetes |
| **Hybrid** | Control Plane (CP) + Data Plane (DP) | Production, Konnect |

## Prerequisites

| Tool | Check | Install |
|---|---|---|
| Docker Desktop | `docker --version` | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose | `docker compose version` | Bundled with Docker Desktop |
| curl | `curl --version` | Pre-installed on macOS/Linux |
| jq | `jq --version` | `brew install jq` |
| decK CLI | `deck version` | `brew install kong/tap/deck` |

## Labs

| Lab | Topic |
|---|---|
| [01-A: Install & Verify](/module-01-orientation/labs/01-install-verify) | Deploy Kong via Docker Compose, verify all ports |
| [01-B: First API Call](/module-01-orientation/labs/01-first-api-call) | Create a Service, Route, and proxy your first request |

## Key Ports

| Port | Service | Description |
|---|---|---|
| `8000` | Kong Proxy | HTTP traffic to your APIs |
| `8443` | Kong Proxy | HTTPS traffic |
| `8001` | Admin API | REST API for managing Kong |
| `8002` | Kong Manager | Admin web UI |
| `5432` | PostgreSQL | Kong's configuration database |

## Resources

- [Kong Gateway Docs](https://developer.konghq.com/gateway/)
- [Kong Gateway Quickstart](https://get.konghq.com/quickstart)
- [decK CLI](https://developer.konghq.com/deck/)
- [Plugin Hub](https://developer.konghq.com/plugins/)

---

*Next: [Module 02 - Core Gateway Concepts →](/module-02-core-gateway/)*
