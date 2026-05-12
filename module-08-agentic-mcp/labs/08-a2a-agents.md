# Lab 08-C - A2A (Agent-to-Agent) Routing

> **Goal:** Configure Kong to route Agent-to-Agent (A2A) calls, enabling a primary AI agent to delegate tasks to specialised sub-agents through the gateway.

## What is A2A?

A2A (Agent-to-Agent) is Google's proposed open standard for AI agents to communicate with each other. A primary "orchestrator" agent discovers and delegates tasks to specialised sub-agents via HTTP:

```
User → Orchestrator Agent
              ↓
        "I need flights + hotel + weather"
              ↓
    Kong A2A Router
    ├── /a2a/flights-agent  → FlightSearchAgent
    ├── /a2a/hotel-agent    → HotelBookingAgent
    └── /a2a/weather-agent  → WeatherAgent
```

## Step 1 - The A2A backend

The Express server exposes sub-agents at:

```bash
# List available agents
curl -s http://localhost:3001/a2a/agents | jq '.[].name'

# Test a sub-agent directly
curl -s -X POST http://localhost:3001/a2a/flights \
  -H "Content-Type: application/json" \
  -d '{"task": "Find flights from SFO to LHR next Tuesday"}' \
  | jq '.result'
```

## Step 2 - Create A2A service and routes

```bash
# Create A2A service
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "a2a-services",
    "host": "host.docker.internal",
    "port": 3001,
    "protocol": "http"
  }' | jq '{id, name}'

# Route: agent discovery endpoint
curl -s -X POST http://localhost:8001/services/a2a-services/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "a2a-agents-list",
    "paths": ["~/\\.well-known/agent\\.json$"],
    "methods": ["GET"],
    "strip_path": false
  }' | jq '{id, name}'

# Route: sub-agent calls (wildcard)
curl -s -X POST http://localhost:8001/services/a2a-services/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "a2a-agent-calls",
    "paths": ["~/a2a/(?P<agent>[a-z-]+)$"],
    "methods": ["POST"],
    "strip_path": false
  }' | jq '{id, name}'
```

## Step 3 - Declare the decK YAML

```yaml
_format_version: '3.0'

services:
  - name: a2a-services
    host: host.docker.internal
    port: 3001
    protocol: http
    routes:
      # Agent Card discovery (A2A spec)
      - name: a2a-discovery
        paths: [~/.well-known/agent\.json$]
        methods: [GET]
        strip_path: false

      # Flights sub-agent
      - name: a2a-flights
        paths: [~/a2a/flights$]
        methods: [POST]
        strip_path: false
        plugins:
          - name: rate-limiting
            config:
              minute: 30
          - name: key-auth
            config:
              key_names: [X-Agent-Key]
              hide_credentials: true

      # Hotels sub-agent
      - name: a2a-hotels
        paths: [~/a2a/hotels$]
        methods: [POST]
        strip_path: false
        plugins:
          - name: rate-limiting
            config:
              minute: 30

      # Weather sub-agent
      - name: a2a-weather
        paths: [~/a2a/weather$]
        methods: [POST]
        strip_path: false
        plugins:
          - name: rate-limiting
            config:
              minute: 60
```

## Step 4 - Test A2A discovery

```bash
# A2A Agent Card (describes agent capabilities)
curl -s http://localhost:8000/.well-known/agent.json | jq '{
  name: .name,
  description: .description,
  skills: [.skills[].id]
}'
```

Expected:
```json
{
  "name": "TravelOrchestratorAgent",
  "description": "Multi-skill travel planning agent",
  "skills": ["flight-search", "hotel-booking", "weather-check"]
}
```

## Step 5 - Test A2A task delegation

```bash
# Delegate to flights sub-agent
curl -s -X POST http://localhost:8000/a2a/flights \
  -H "Content-Type: application/json" \
  -H "X-Agent-Key: orchestrator-key-xyz" \
  -d '{
    "id": "task-001",
    "message": {
      "role": "user",
      "parts": [{"type": "text", "text": "Find round-trip flights SFO to LHR in June 2026"}]
    }
  }' | jq '.result.parts[0].text | fromjson | .[0]'

# Delegate to weather sub-agent
curl -s -X POST http://localhost:8000/a2a/weather \
  -H "Content-Type: application/json" \
  -H "X-Agent-Key: orchestrator-key-xyz" \
  -d '{
    "id": "task-002",
    "message": {
      "role": "user",
      "parts": [{"type": "text", "text": "What is the weather at LHR?"}]
    }
  }' | jq '.result.parts[0].text | fromjson'
```

## Step 6 - Add observability to A2A routes

```bash
# Enable OpenTelemetry on A2A routes for distributed tracing
curl -s -X POST http://localhost:8001/services/a2a-services/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "opentelemetry",
    "config": {
      "endpoint": "http://otel-collector:4318/v1/traces",
      "resource_attributes": {
        "service.name": "kong-a2a-router",
        "ai.agent.type": "orchestrator"
      }
    }
  }'
```

## A2A Agent Card Format (standard)

```json
{
  "name": "TravelAgent",
  "description": "AI agent for travel planning",
  "url": "http://localhost:8000/a2a/travel",
  "version": "1.0.0",
  "capabilities": {
    "streaming": false,
    "pushNotifications": false
  },
  "skills": [
    {
      "id": "flight-search",
      "name": "Search Flights",
      "description": "Search available flights between airports",
      "inputModes": ["text"],
      "outputModes": ["text", "data"]
    }
  ],
  "authentication": {
    "schemes": ["bearer"]
  }
}
```

## Summary

| Concept | Kong Config |
|---|---|
| Agent discovery | Route on `/.well-known/agent.json` |
| Sub-agent routing | Route pattern `~/a2a/(?P<agent>[a-z-]+)$` |
| Agent auth | Key Auth with `X-Agent-Key` header |
| Rate limiting | Per-agent rate limits |
| Tracing | OpenTelemetry for end-to-end agent traces |

---

*Next: [Module 09 - Enterprise & CI/CD →](/module-09-enterprise/)*
