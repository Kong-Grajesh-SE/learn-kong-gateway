# Lab 02-C - Consumers

> **Goal:** Create API consumers, attach credentials, and manage consumer lifecycle with decK.

## What is a Consumer?

A **Consumer** is the identity of an API caller in Kong. Consumers can be:
- A frontend web app
- A mobile application
- A microservice calling another microservice
- A developer testing the API

Consumers hold **credentials** (API keys, JWT secrets, OAuth2 tokens) that Kong checks against incoming requests.

## Step 1 - Create consumers via Admin API

```bash
# Create consumer: travel-web-app
curl -s -X POST http://localhost:8001/consumers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "travel-web-app",
    "custom_id": "app-001",
    "tags": ["web", "production"]
  }' | jq '{id, username, custom_id}'

# Create consumer: travel-mobile-app
curl -s -X POST http://localhost:8001/consumers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "travel-mobile-app",
    "custom_id": "app-002",
    "tags": ["mobile", "production"]
  }' | jq '{id, username, custom_id}'

# Create consumer: dev-tester (for development)
curl -s -X POST http://localhost:8001/consumers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dev-tester",
    "custom_id": "dev-001",
    "tags": ["dev", "testing"]
  }' | jq '{id, username, custom_id}'
```

## Step 2 - List and inspect consumers

```bash
# List all consumers
curl -s http://localhost:8001/consumers | jq '.data[] | {username, tags}'

# Get a specific consumer
curl -s http://localhost:8001/consumers/travel-web-app | jq '.'

# Filter by tag
curl -s "http://localhost:8001/consumers?tags=production" | jq '.data | length'
```

## Step 3 - Consumers in decK YAML

::: tip
Managing consumers declaratively in decK is the recommended approach for production environments.
:::

```yaml
_format_version: '3.0'

consumers:
  - username: travel-web-app
    custom_id: app-001
    tags: [web, production]

  - username: travel-mobile-app
    custom_id: app-002
    tags: [mobile, production]

  - username: dev-tester
    custom_id: dev-001
    tags: [dev, testing]
```

Apply:

```bash
deck gateway sync --kong-addr http://localhost:8001 consumers.yaml
```

## Step 4 - Consumer groups (Enterprise)

Consumer groups let you apply plugins to a set of consumers at once:

```bash
# Create a group
curl -s -X POST http://localhost:8001/consumer_groups \
  -H "Content-Type: application/json" \
  -d '{"name": "premium-tier"}' | jq '{id, name}'

# Add consumer to group
curl -s -X POST \
  http://localhost:8001/consumer_groups/premium-tier/consumers \
  -H "Content-Type: application/json" \
  -d '{"consumer": "travel-web-app"}'

# List members
curl -s http://localhost:8001/consumer_groups/premium-tier/consumers | \
  jq '.data[] | .username'
```

## Step 5 - Export and verify with decK

```bash
# Dump the entire config including consumers
deck gateway dump --kong-addr http://localhost:8001 > full-state.yaml

# View consumers section
cat full-state.yaml | grep -A 10 "consumers:"
```

## Consumer Lifecycle

| Operation | Admin API | decK |
|---|---|---|
| Create | `POST /consumers` | Add to YAML, sync |
| Update | `PATCH /consumers/:id` | Edit YAML, sync |
| Delete | `DELETE /consumers/:id` | Remove from YAML, sync |
| Bulk import | N/A | `deck gateway sync` |
| Audit | N/A | `deck gateway diff` |

## Summary

| Object | What it represents |
|---|---|
| Consumer | API caller identity (app or user) |
| Custom ID | External system ID (e.g. database user ID) |
| Tags | Labels for filtering and organisation |
| Consumer Group | Collection of consumers for bulk policies |

---

*Next: [Module 03 - Authentication Plugins →](/module-03-authentication/)*
