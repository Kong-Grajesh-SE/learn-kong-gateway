# Lab 09-D - RBAC & Teams

> **Goal:** Configure Kong Manager RBAC with roles and workspaces. Create team-based isolation so different teams manage their own services without interfering.

## Kong RBAC Architecture

```
Organization
└── Workspaces (isolation boundaries)
    ├── default/         ← shared services
    ├── team-flights/    ← flights team owns this
    ├── team-ai/         ← AI team owns this
    └── team-partners/   ← partner team owns this

Each workspace has its own:
  ├── Admins (can manage services, plugins)
  ├── Developers (read-only)
  └── Custom roles
```

## Step 1 - Enable RBAC (Kong Enterprise)

::: warning
RBAC requires Kong Gateway Enterprise. The `admin_gui_auth` configuration must be set before enabling RBAC.
:::

In `kong.conf`:
```
enforce_rbac = on
admin_gui_auth = basic-auth
admin_gui_session_conf = {"secret": "change-me!", "storage": "kong", "cookie_secure": false}
```

Or via environment variable:
```bash
docker run -e KONG_ENFORCE_RBAC=on \
           -e KONG_ADMIN_GUI_AUTH=basic-auth \
           kong/kong-gateway:3.9
```

## Step 2 - Create workspaces

```bash
# Create workspaces (Enterprise)
for ws in team-flights team-ai team-partners; do
  curl -s -X POST http://localhost:8001/workspaces \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$ws\"}" | jq '{name, id}'
done
```

## Step 3 - Create RBAC roles

```bash
# Create a read-only viewer role
curl -s -X POST http://localhost:8001/rbac/roles \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gateway-viewer",
    "comment": "Read-only access to Kong Manager"
  }' | jq '{name, id}'

# Add permissions to viewer role
curl -s -X POST http://localhost:8001/rbac/roles/gateway-viewer/endpoints \
  -H "Content-Type: application/json" \
  -d '{
    "endpoint": "*",
    "workspace": "default",
    "actions": ["read"]
  }'

# Create a developer role (services + routes + plugins)
curl -s -X POST http://localhost:8001/rbac/roles \
  -H "Content-Type: application/json" \
  -d '{"name": "gateway-developer"}' | jq '{name, id}'

for endpoint in services routes plugins consumers; do
  curl -s -X POST http://localhost:8001/rbac/roles/gateway-developer/endpoints \
    -H "Content-Type: application/json" \
    -d "{
      \"endpoint\": \"/$endpoint\",
      \"workspace\": \"default\",
      \"actions\": [\"read\", \"create\", \"update\", \"delete\"]
    }"
done
```

## Step 4 - Create RBAC users

```bash
# Create admin user for flights team
curl -s -X POST http://localhost:8001/rbac/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "flights-team-admin",
    "user_token": "flights-admin-token-xyz",
    "enabled": true,
    "comment": "Flights team gateway admin"
  }' | jq '{name, id}'

# Assign role to user in flights workspace
curl -s -X POST http://localhost:8001/rbac/users/flights-team-admin/roles \
  -H "Content-Type: application/json" \
  -d '{"roles": ["gateway-developer"]}'

# Assign workspace
curl -s -X POST http://localhost:8001/workspaces/team-flights/meta/rbac \
  -H "Content-Type: application/json" \
  -d '{"rbac_user": "flights-team-admin"}'
```

## Step 5 - Workspace isolation in practice

```bash
# Create a service in the flights workspace
curl -s -X POST http://localhost:8001/team-flights/services \
  -H "Kong-Admin-Token: flights-admin-token-xyz" \
  -H "Content-Type: application/json" \
  -d '{"name": "internal-flights-api", "url": "http://internal-flights:3001"}'

# This user CANNOT access the AI workspace
curl -si http://localhost:8001/team-ai/services \
  -H "Kong-Admin-Token: flights-admin-token-xyz" | head -3
# HTTP/1.1 403 Forbidden
```

## Step 6 - Consumer groups for rate limiting tiers

```yaml
_format_version: '3.0'

consumer_groups:
  - name: free-tier
  - name: professional-tier
  - name: enterprise-tier

consumers:
  - username: startup-app
    groups:
      - name: free-tier

  - username: growth-app
    groups:
      - name: professional-tier

  - username: enterprise-corp
    groups:
      - name: enterprise-tier

# Rate limiting with per-group overrides
plugins:
  - name: rate-limiting-advanced
    config:
      limit: [100]              # free-tier default
      window_size: [60]
      identifier: consumer
      strategy: redis
      consumer_groups:
        - consumer_group: professional-tier
          config:
            limit: [1000]
            window_size: [60]
        - consumer_group: enterprise-tier
          config:
            limit: [10000]
            window_size: [60]
```

## RBAC Predefined Roles Reference

| Role | Description |
|---|---|
| `super-admin` | Full access to all workspaces and RBAC management |
| `admin` | Full access within a workspace |
| `developer` | Manage services, routes, plugins in a workspace |
| `viewer` | Read-only access |
| `read-only` | Read-only to all endpoints |

## Summary

| Enterprise Feature | What it enables |
|---|---|
| **Workspaces** | Team isolation - each team owns their namespace |
| **RBAC Users** | Human admins with specific permissions |
| **RBAC Roles** | Permission bundles (read/create/update/delete) |
| **Consumer Groups** | Tiered rate limiting and policies |
| **Admin GUI Auth** | Keycloak/OIDC SSO for Kong Manager login |

---

*🎉 Congratulations! You've completed the Kong API Gateway Bootcamp.*

[← Back to Home](/)*
