# Lab 08-A - MCP Proxy

> **Goal:** Configure Kong's `ai-mcp-proxy` plugin to translate between REST and MCP protocol, enabling AI agents to call travel tools via a standard HTTP endpoint.

## How ai-mcp-proxy Works

The `ai-mcp-proxy` plugin operates in two modes:

| Mode | Description | Use Case |
|---|---|---|
| `conversion-listener` | Kong translates REST ↔ MCP format | Web UI, curl, non-MCP clients |
| `passthrough-listener` | Kong forwards MCP as-is | VS Code, Claude, MCP-native clients |

## Step 1 - Start the MCP backend

The Express server exposes a JSON-RPC handler at `POST /mcp/tools`:

```bash
cd get-started-guide
npm run server
```

Test the backend directly:

```bash
# List available tools (MCP initialize)
curl -s -X POST http://localhost:3001/mcp/tools \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }' | jq '.result.tools[] | {name, description}'
```

## Step 2 - Create the MCP service and route

```bash
# Create service
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mcp-services",
    "host": "host.docker.internal",
    "port": 3001,
    "protocol": "http"
  }' | jq '{id, name}'

# Create route A: unauthenticated MCP proxy
curl -s -X POST http://localhost:8001/services/mcp-services/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "baseMCP",
    "paths": ["/mcp/tools"],
    "methods": ["POST", "GET"],
    "strip_path": false
  }' | jq '{id, name}'
```

## Step 3 - Configure ai-mcp-proxy (conversion mode)

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/baseMCP/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-mcp-proxy",
    "config": {
      "listener": "conversion-listener",
      "upstream_path": "/mcp/tools",
      "timeout": 30000
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
services:
  - name: mcp-services
    host: host.docker.internal
    port: 3001
    routes:
      - name: baseMCP
        paths: [/mcp/tools]
        methods: [POST, GET]
        plugins:
          - name: ai-mcp-proxy
            config:
              listener: conversion-listener
              upstream_path: /mcp/tools
              timeout: 30000
```

:::

## Step 4 - Test MCP tool calls via Kong

```bash
# List tools
curl -s -X POST http://localhost:8000/mcp/tools \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }' | jq '.result.tools[] | {name}'

# Call search_flights tool
curl -s -X POST http://localhost:8000/mcp/tools \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "search_flights",
      "arguments": {
        "origin": "SFO",
        "destination": "LHR",
        "date": "2026-06-15"
      }
    }
  }' | jq '.result.content[0].text | fromjson | .[0]'

# Call get_weather tool
curl -s -X POST http://localhost:8000/mcp/tools \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "get_weather",
      "arguments": {"airport": "LHR"}
    }
  }' | jq '.result.content[0].text | fromjson'
```

## Step 5 - MCP Initialize handshake

```bash
# Send the MCP initialize handshake
curl -s -X POST http://localhost:8000/mcp/tools \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {"tools": {}},
      "clientInfo": {"name": "curl-test", "version": "1.0.0"}
    }
  }' | jq '{version: .result.protocolVersion, serverName: .result.serverInfo.name}'
```

## Step 6 - Add rate limiting to MCP

```bash
curl -s -X POST http://localhost:8001/routes/baseMCP/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 60,
      "policy": "local"
    }
  }'
```

## MCP Protocol Reference

| JSON-RPC method | Description |
|---|---|
| `initialize` | Handshake - exchange capabilities |
| `tools/list` | Get all available tool definitions |
| `tools/call` | Execute a specific tool |
| `resources/list` | List available resources (files, data) |
| `prompts/list` | List available prompt templates |

---

*Next: [Lab 08-B - MCP + OAuth2 →](./08-mcp-oauth2)*
