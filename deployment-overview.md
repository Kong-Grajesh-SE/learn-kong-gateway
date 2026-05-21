---
title: Kong Deployment Options
description: Understand Kong's deployment topologies - Konnect, Hybrid, Traditional, DB-less. This bootcamp uses Konnect + Hybrid.
---

# 🏗️ Kong Deployment Options

> Kong Gateway can be deployed in multiple topologies. This page explains all options and tells you which one we use in this bootcamp and why.

---

## This Bootcamp: Konnect + Hybrid Mode ☁️ + 🖥️

::: tip What we use in every lab
**Control Plane (CP):** hosted by Kong on Konnect (cloud.konghq.com)  
**Data Plane (DP):** runs locally on your machine via Docker  
**Database:** none - the DP is DB-less, config is pushed from Konnect
:::

```
                ┌─────────────────────────────────┐
                │  Konnect (cloud.konghq.com)     │
                │  ┌──────────────────────────┐   │
                │  │  Control Plane (CP)      │   │
                │  │  - Kong Manager UI       │   │
                │  │  - decK target           │   │
                │  │  - Plugin management     │   │
                │  └──────────┬───────────────┘   │
                └─────────────│───────────────────┘
                              │ mTLS (port 443)
                              │ config push
                ┌─────────────▼───────────────────┐
                │  Your laptop (Docker)           │
                │  ┌──────────────────────────┐   │
                │  │  Data Plane (DP)         │   │
                │  │  - Handles live traffic  │   │
                │  │  - :8000 Proxy HTTP      │   │
                │  │  - :8443 Proxy HTTPS     │   │
                │  └──────────┬───────────────┘   │
                └─────────────│───────────────────┘
                              │
                ┌─────────────▼───────────────────┐
                │  Upstream Services              │
                │  httpbin.konghq.com | :3001     │
                └─────────────────────────────────┘
```

### Why Hybrid + Konnect for learning?

| Benefit | Detail |
|---|---|
| **No PostgreSQL to manage** | DP is DB-less - config pushed from CP |
| **Real enterprise topology** | Same pattern used in production |
| **Free tier available** | No credit card required |
| **GUI + CLI + GitOps** | Manage via Konnect UI, decK, or Admin API |
| **One local container** | Just the DP - lightweight on your machine |

---

## All Deployment Options

### 1. 🌐 Konnect (Fully Managed SaaS)

Kong manages both the Control Plane and optionally the Data Planes.

```
Konnect Cloud
├── Control Plane (fully managed)
│   ├── Kong Manager
│   ├── Plugin catalog
│   └── Analytics
└── Data Plane Options
    ├── Konnect-hosted DP (in cloud)
    └── Self-managed DP (your infra)
```

**Best for:** Teams that want zero infrastructure to manage.  
**Docs:** [docs.konghq.com/konnect](https://docs.konghq.com/konnect/)

---

### 2. 🔀 Hybrid Mode (CP + DP separated)

Control Plane and Data Plane run separately. CP manages config; DP handles traffic.

```bash
# docker-compose.yml snippet - Data Plane only
kong-dp:
  image: kong/kong-gateway:3.14
  environment:
    KONG_ROLE: data_plane
    KONG_DATABASE: "off"
    KONG_CLUSTER_CONTROL_PLANE: "<your-cp>.cp0.konghq.com:443"
    KONG_CLUSTER_CERT: /etc/secrets/tls.crt
    KONG_CLUSTER_CERT_KEY: /etc/secrets/tls.key
```

**Best for:** On-prem or VPC deployments with Konnect as the CP.  
**This bootcamp uses this mode.**

---

### 3. 🗄️ Traditional Mode (with Database)

Kong stores all config in a PostgreSQL (or Cassandra) database. Both Admin API and Proxy run in the same process.

```yaml
# docker-compose.yml snippet
kong:
  environment:
    KONG_DATABASE: postgres
    KONG_PG_HOST: kong-db
    KONG_ADMIN_LISTEN: "0.0.0.0:8001"
```

**Ports:**

| Port | Service |
|---|---|
| `:8000` | Proxy (HTTP) |
| `:8443` | Proxy (HTTPS) |
| `:8001` | Admin API |
| `:8002` | Kong Manager |

**Best for:** Simple self-hosted setups, local development without Konnect.  

::: warning Database required
Traditional mode requires PostgreSQL. All config is stored in the DB. If the DB goes down, new config changes can't be applied.
:::

---

### 4. 📋 DB-less Mode

Kong runs without a database. Config is provided via a static YAML file or the `/config` endpoint. No state persistence - useful for testing.

```bash
kong:
  environment:
    KONG_DATABASE: "off"
    KONG_DECLARATIVE_CONFIG: /kong/declarative/kong.yaml
```

**Best for:** Kubernetes sidecar patterns, GitOps-only deployments, testing.

::: info Ephemeral
In DB-less mode, config is loaded at startup. Admin API write operations are rejected. Use decK to push config via the `/config` endpoint.
:::

---

## Comparison Table

| Feature | Konnect + Hybrid | Traditional | DB-less | Konnect SaaS |
|---|---|---|---|---|
| Database needed | ❌ (DP side) | ✅ PostgreSQL | ❌ | ❌ |
| Kong Manager | ☁️ In Konnect | ✅ Local :8002 | ❌ | ☁️ In Konnect |
| Admin API (local) | ❌ | ✅ :8001 | ✅ :8001 (read) | ❌ |
| decK target | Konnect | localhost:8001 | localhost:8001 | Konnect |
| DP scales independently | ✅ | ❌ | ✅ | ✅ |
| Good for production | ✅✅ | ✅ | Stateless only | ✅✅ |
| Good for bootcamp | ✅ **This one** | ✅ Simple alt | Learning only | ✅ |

---

## Using Traditional Mode Instead (optional)

If you prefer a fully local setup without a Konnect account, you can follow the Traditional mode setup. Replace Module 01 Lab A with this docker-compose:

::: details Traditional Mode docker-compose.yml

```yaml
version: '3.8'
services:
  kong-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: kong
      POSTGRES_DB: kong
      POSTGRES_PASSWORD: kongpass
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "kong"]
      interval: 5s
      retries: 5
    networks: [kong-net]

  kong-migrations:
    image: kong/kong-gateway:3.14
    command: kong migrations bootstrap
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-db
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kongpass
      KONG_PG_DATABASE: kong
    depends_on:
      kong-db:
        condition: service_healthy
    networks: [kong-net]
    restart: on-failure

  kong:
    image: kong/kong-gateway:3.14
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-db
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kongpass
      KONG_PG_DATABASE: kong
      KONG_ADMIN_LISTEN: "0.0.0.0:8001"
      KONG_ADMIN_GUI_URL: "http://localhost:8002"
    ports:
      - "8000:8000"
      - "8443:8443"
      - "8001:8001"
      - "8002:8002"
    depends_on:
      kong-db:
        condition: service_healthy
    networks: [kong-net]

networks:
  kong-net:
    driver: bridge
```

```bash
docker compose up -d
# Wait for migrations, then verify:
curl -s http://localhost:8001/status | jq .database.reachable
# true
```

:::

---

**Next step:** [🧭 Module 01 - Orientation & Setup →](/module-01-orientation/)

