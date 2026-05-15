---
title: Prerequisites
description: Everything you need installed before starting the Kong API Gateway Bootcamp.
---

# ✅ Prerequisites

> Before starting any lab, verify that every tool below is installed and working. Each section shows the install command, verify command, and the minimum required version.

::: warning ⚙️ Kong Gateway 3.14+ required
This bootcamp targets **Kong Gateway 3.14 or newer**. Some labs rely on 3.14-era plugin schemas (`request-transformer-advanced` `rename` operation, `opentelemetry` plugin config), 3.4+ headers (`X-Forwarded-Path`, `X-Forwarded-Prefix`), and 3.11+ plugins (`datakit`).

- **Konnect** (recommended): Konnect Cloud always runs the latest released Kong version - you're already on 3.14+.
- **Self-hosted hybrid**: pin the Data Plane container to `kong/kong-gateway:3.14` in your `docker-compose.yml` (the hybrid lab in [Module 01](/module-01-orientation/labs/01-hybrid-docker-setup) already does this).
- **Self-hosted Kong OSS**: not supported for the Enterprise plugins in M07 (`opa`, `datakit`, `upstream-oauth`, `request-transformer-advanced`).
:::

## Required Tools

| Tool | Purpose | Min Version | Install |
|---|---|---|---|
| **Kong Gateway** | The gateway itself | **3.14+** | Konnect cloud (free tier) - or Docker image `kong/kong-gateway:3.14` for hybrid |
| **Konnect account** | Hosts the Control Plane | Free tier | [cloud.konghq.com](https://cloud.konghq.com) |
| **Docker Desktop** | Run hybrid Data Plane locally (optional) | 4.x | [docker.com/get-started](https://www.docker.com/get-started) |
| **Docker Compose** | Multi-container orchestration | v2.x | Bundled with Docker Desktop |
| **curl** | Terminal API testing | any | Pre-installed on macOS/Linux |
| **jq** | JSON pretty-printing | 1.6+ | `brew install jq` |
| **decK CLI** | Kong declarative config | 1.43+ (matches Kong 3.14) | See below |
| **Insomnia** | GUI API testing (optional) | 9.x+ | [insomnia.rest](https://insomnia.rest) |
| **Node.js** | kong-air backend (optional) | 20 LTS | [nodejs.org](https://nodejs.org) |
| **Git** | Clone repos | 2.x | Pre-installed on macOS |

---

## 🐳 Docker Desktop

::: tip Required for all labs
All Kong Data Planes run via Docker Compose. You need Docker Desktop with at least 4 GB RAM allocated.
:::

```bash
# Verify Docker is running
docker --version
# Docker version 27.x.x, build ...

docker compose version
# Docker Compose version v2.x.x

# Verify resources (should show ≥4 GB)
docker system info | grep -E "Memory|CPUs"
```

**Docker Desktop settings** - increase resources if needed:  
Settings → Resources → Memory: **4 GB** minimum, **8 GB** recommended

---

## 🔵 jq

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt-get install -y jq

# Verify
jq --version
# jq-1.7.x
```

---

## 📦 decK CLI

decK is Kong's GitOps tool for managing configuration declaratively.

```bash
# macOS
brew install kong/deck/deck

# Linux
curl -sL https://github.com/Kong/deck/releases/latest/download/deck_linux_amd64.tar.gz \
  | tar -xz -C /usr/local/bin deck

# Verify
deck version
# decK v1.35.x (...)
```

---

## 🎮 Insomnia

Insomnia is a GUI REST/gRPC/GraphQL client - a great alternative to curl.

1. Download from [insomnia.rest](https://insomnia.rest/download)
2. Install and launch
3. Create a free account (optional, for sync)
4. From the **Dashboard**, create a new **Collection** named `Kong Bootcamp`

::: info Insomnia vs curl
Every lab provides **both** curl commands and Insomnia steps. Use whichever you prefer.
:::

---

## ☁️ Kong Konnect Account

All bootcamp labs use **Konnect** - Kong's managed control plane.

1. Go to [cloud.konghq.com](https://cloud.konghq.com)
2. Sign up with email or SSO (Google / GitHub)
3. Choose the **Free** tier (no credit card required)
4. Complete the onboarding wizard

::: tip Free tier includes
- 1 Control Plane
- Unlimited Data Planes
- Full plugin library
- Analytics (7-day retention)
:::

### Create a Personal Access Token (PAT)

Your PAT authenticates decK and the CLI tools.

1. Click your avatar (top-right) → **Personal Access Tokens**
2. Click **Generate Token**
3. Name it `bootcamp-pat`, expiry: 1 year
4. **Copy and save** - it won't be shown again

```bash
# Store in your shell profile
echo 'export KONNECT_TOKEN="kpat_your_token_here"' >> ~/.zshrc
source ~/.zshrc

# Verify (should print your token)
echo $KONNECT_TOKEN

# Confirm your Konnect CP is running Kong 3.14+
# (replace REGION + CP_ID with yours)
curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://us.api.konghq.com/v2/control-planes/<your-cp-id>" \
  | jq '.config.cluster_type, .config.cloud_gateway'
# Expected: serverless CPs report the Konnect-managed runtime version (3.14+).
```

---

## 🟢 Node.js (Optional - kong-air backend)

Required only for modules that use the local **kong-air** demo backend.

```bash
# macOS - using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
nvm install 20
nvm use 20

# Verify
node --version   # v20.x.x
npm --version    # 10.x.x
```

### Start the kong-air backend

```bash
git clone https://github.com/Kong-Grajesh-SE/get-started-guide
cd get-started-guide
npm install
npm run dev   # starts on :3001
```

---

## 🧪 Quick Verification Checklist

Run this script to verify everything at once:

```bash
#!/usr/bin/env bash
echo "=== Kong Bootcamp Prerequisites Check ==="

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  ✅  $name"
  else
    echo "  ❌  $name - NOT FOUND"
  fi
}

check "Docker"          "docker --version"
check "Docker Compose"  "docker compose version"
check "curl"            "curl --version"
check "jq"              "jq --version"
check "decK"            "deck version"
check "Node.js"         "node --version"
check "Git"             "git --version"

if [[ -n "$KONNECT_TOKEN" ]]; then
  echo "  ✅  KONNECT_TOKEN is set"
else
  echo "  ❌  KONNECT_TOKEN - not set (run: export KONNECT_TOKEN=kpat_...)"
fi

# Kong Gateway version check (hybrid Docker DP)
if docker ps --format '{{.Image}}' 2>/dev/null | grep -q 'kong/kong-gateway'; then
  KONG_VER=$(docker ps --format '{{.Image}}' | grep 'kong/kong-gateway' | head -1 | sed 's/.*://')
  case "$KONG_VER" in
    3.14*|3.15*|3.16*|3.2*|3.3*|3.4*)  echo "  ✅  Kong Gateway version $KONG_VER (≥ 3.14)" ;;
    *)                                  echo "  ❌  Kong Gateway version $KONG_VER - bootcamp requires 3.14+. Update your image tag." ;;
  esac
else
  echo "  ℹ️   No local Kong DP detected - assuming you're using Konnect serverless (always 3.14+)."
fi
```

---

## 🌐 Test Services

These are the upstream services used throughout the bootcamp:

| Service | URL | Purpose |
|---|---|---|
| **httpbin (Kong-hosted)** | `https://httpbin.konghq.com` | Echo/inspect HTTP requests - primary test target |
| **httpbin (public)** | `https://httpbin.org` | Alternative public instance |
| **kong-air backend** | `http://localhost:3001` | Local demo airline API (requires Node.js) |

```bash
# Verify Kong-hosted httpbin is reachable
curl -s https://httpbin.konghq.com/get | jq '{url, origin}'
```

Expected response:
```json
{
  "url": "https://httpbin.konghq.com/get",
  "origin": "your.ip.address"
}
```

---

**You're ready!** → [🏗️ Deployment Options →](/deployment-overview)
