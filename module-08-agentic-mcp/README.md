# Module 08 - Agentic AI & MCP

> The Model Context Protocol (MCP) is the emerging standard for connecting AI agents to external tools and data sources. Kong secures and proxies MCP tool calls without changing your upstream servers.

## Overview

| | |
|---|---|
| **Duration** | ~2 hours |
| **Level** | Advanced |
| **Stack** | Kong Gateway, Express.js MCP server, OAuth2/PKCE, VS Code |
| **Outcome** | Secured MCP endpoint, OAuth2-authenticated agents, A2A routing |

## Learning Objectives

- Understand the MCP protocol and JSON-RPC tool calls
- Proxy MCP over HTTP with Kong's `ai-mcp-proxy` plugin
- Secure MCP with OAuth2 + PKCE using `ai-mcp-oauth2`
- Connect VS Code and Claude Desktop to Kong-protected MCP
- Route A2A (Agent-to-Agent) calls across sub-agents

## What is MCP?

MCP (Model Context Protocol) is a JSON-RPC 2.0 protocol that allows AI assistants to call external tools:

```
VS Code Copilot → MCP client → POST /mcp/tools → Kong → Express MCP server
                                                     ↕
                                              Tool: search_flights
                                              Tool: book_hotel
                                              Tool: get_weather
```

## Architecture - Two Routes, Same Backend

| Route | Path | Plugins | Auth | Use Case |
|---|---|---|---|---|
| `baseMCP` | `POST /mcp/tools` | `ai-mcp-proxy` (conversion) | None | Web demo, curl tests |
| `baseMCP-Oauth` | `POST /mcp-oauth/tools` | `ai-mcp-oauth2` + `ai-mcp-proxy` | OAuth2 + PKCE | VS Code, Claude, agents |

```
Same upstream (Express :3001/mcp/tools)
          ↓
┌──────────────────────────────────────────┐
│ Route A: POST /mcp/tools                 │
│ Plugin:  ai-mcp-proxy (conversion-mode)  │
│ Kong translates REST ↔ MCP               │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ Route B: POST /mcp-oauth/tools           │
│ Plugin 1: ai-mcp-oauth2                  │ ← OAuth2 + PKCE check
│ Plugin 2: ai-mcp-proxy (passthrough)     │ ← forward MCP as-is
└──────────────────────────────────────────┘
```

## MCP Tools in the Demo

| Tool | MCP Method | Description |
|---|---|---|
| `search_flights` | `tools/call` | Search available flights |
| `book_flight` | `tools/call` | Book a flight |
| `get_weather` | `tools/call` | Weather by IATA airport code |
| `search_hotels` | `tools/call` | Search hotels |
| `book_hotel` | `tools/call` | Reserve a hotel room |

## Labs

| Lab | Topic |
|---|---|
| [08-A: MCP Proxy](/module-08-agentic-mcp/labs/08-mcp-proxy) | Configure ai-mcp-proxy, test tool calls with curl |
| [08-B: MCP + OAuth2](/module-08-agentic-mcp/labs/08-mcp-oauth2) | Secure MCP with OAuth2 PKCE, connect VS Code |
| [08-C: A2A Agents](/module-08-agentic-mcp/labs/08-a2a-agents) | Route Agent-to-Agent calls through Kong |

## Resources

- [MCP specification](https://modelcontextprotocol.io/)
- [ai-mcp-proxy plugin](https://developer.konghq.com/plugins/ai-mcp-proxy/)
- [ai-mcp-oauth2 plugin](https://developer.konghq.com/plugins/ai-mcp-oauth2/)
- [Kong Agentic AI overview](https://developer.konghq.com/ai-gateway/)

---

*Previous: [Module 07](/module-07-ai-gateway/) · Next: [Module 09 - Enterprise →](/module-09-enterprise/)*
