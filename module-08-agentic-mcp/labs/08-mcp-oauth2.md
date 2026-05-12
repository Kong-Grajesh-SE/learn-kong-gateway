# Lab 08-B - MCP with OAuth2 + PKCE

> **Goal:** Secure the MCP endpoint with OAuth2 Authorization Code + PKCE flow, then connect VS Code GitHub Copilot and Claude Desktop as authenticated MCP clients.

## Architecture

```
VS Code / Claude Desktop (MCP client)
              ↓
    OAuth2 Authorization Code + PKCE
              ↓
    GET /oauth2/authorize → Keycloak login
              ↓
    Keycloak issues auth code
              ↓
    Client exchanges code for access token (with PKCE verifier)
              ↓
    POST /mcp-oauth/tools  Bearer <token>
              ↓
    Kong ai-mcp-oauth2 validates token
              ↓
    Kong ai-mcp-proxy (passthrough) → Express MCP server
```

## Step 1 - Create the OAuth2 route

```bash
curl -s -X POST http://localhost:8001/services/mcp-services/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "baseMCP-Oauth",
    "paths": ["/mcp-oauth/tools"],
    "methods": ["POST", "GET"],
    "strip_path": false
  }' | jq '{id, name}'
```

## Step 2 - Configure ai-mcp-oauth2 plugin

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/baseMCP-Oauth/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-mcp-oauth2",
    "config": {
      "issuer": "http://localhost:8080/realms/workshop",
      "client_id": "mcp-oauth-client",
      "client_secret": "mcp-oauth-secret",
      "scopes": ["openid", "profile", "mcp-tools"],
      "redirect_uri": "http://localhost:8000/mcp-oauth/callback",
      "pkce_required": true,
      "token_endpoint_auth_method": "client_secret_post",
      "verify_parameters": ["aud", "exp", "iss"]
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
routes:
  - name: baseMCP-Oauth
    paths: [/mcp-oauth/tools]
    methods: [POST, GET]
    plugins:
      - name: ai-mcp-oauth2
        config:
          issuer: "http://localhost:8080/realms/workshop"
          client_id: mcp-oauth-client
          client_secret: mcp-oauth-secret
          scopes: [openid, profile, mcp-tools]
          redirect_uri: "http://localhost:8000/mcp-oauth/callback"
          pkce_required: true
          token_endpoint_auth_method: client_secret_post
      - name: ai-mcp-proxy
        config:
          listener: passthrough-listener
          upstream_path: /mcp/tools
          timeout: 30000
```

:::

## Step 3 - Register Keycloak client

In Keycloak Admin Console ([http://localhost:8080/admin](http://localhost:8080/admin)):

1. Navigate to **Clients** → **Create client**
2. Set **Client ID**: `mcp-oauth-client`
3. Enable **Standard flow** (Authorization Code)
4. Set **Valid redirect URIs**: `http://localhost:8000/mcp-oauth/callback`
5. Under **Credentials**, copy the client secret
6. Create a custom scope `mcp-tools`

Or import via Keycloak REST API:

```bash
# Get admin token
ADMIN_TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/master/protocol/openid-connect/token \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin" \
  | jq -r '.access_token')

# Create client
curl -s -X POST http://localhost:8080/admin/realms/workshop/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "mcp-oauth-client",
    "publicClient": false,
    "redirectUris": ["http://localhost:8000/mcp-oauth/callback"],
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": false
  }'
```

## Step 4 - Connect VS Code GitHub Copilot

Create `.vscode/mcp.json` in your workspace:

```json
{
  "servers": {
    "kong-travel-mcp": {
      "type": "http",
      "url": "http://localhost:8000/mcp-oauth/tools",
      "headers": {
        "Content-Type": "application/json"
      },
      "auth": {
        "type": "oauth2",
        "authorizationUrl": "http://localhost:8080/realms/workshop/protocol/openid-connect/auth",
        "tokenUrl": "http://localhost:8080/realms/workshop/protocol/openid-connect/token",
        "clientId": "mcp-oauth-client",
        "scopes": ["openid", "profile", "mcp-tools"],
        "pkce": true
      }
    }
  }
}
```

Reload VS Code → GitHub Copilot → **Tools** will now include:
- `search_flights`
- `book_flight`
- `get_weather`
- `search_hotels`
- `book_hotel`

## Step 5 - Connect Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "kong-travel": {
      "type": "http",
      "url": "http://localhost:8000/mcp-oauth/tools",
      "oauth": {
        "clientId": "mcp-oauth-client",
        "authorizationUrl": "http://localhost:8080/realms/workshop/protocol/openid-connect/auth",
        "tokenUrl": "http://localhost:8080/realms/workshop/protocol/openid-connect/token",
        "scopes": ["openid", "mcp-tools"],
        "pkce": true
      }
    }
  }
}
```

## Step 6 - Test with a bearer token

```bash
# Get a token via client credentials (for testing)
TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/workshop/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=mcp-oauth-client" \
  -d "client_secret=mcp-oauth-secret" \
  | jq -r '.access_token')

# Call the secured MCP endpoint
curl -s -X POST http://localhost:8000/mcp-oauth/tools \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }' | jq '.result.tools[].name'
```

## Plugin Pairing Rules

::: warning Important
`ai-mcp-oauth2` **must** be paired with `ai-mcp-proxy` in `passthrough-listener` mode. Do NOT use `conversion-listener` mode on the OAuth2 route.
:::

| Route | ai-mcp-proxy mode | ai-mcp-oauth2 |
|---|---|---|
| `/mcp/tools` | `conversion-listener` | ❌ No |
| `/mcp-oauth/tools` | `passthrough-listener` | ✅ Yes |

---

*Next: [Lab 08-C - A2A Agents →](./08-a2a-agents)*
