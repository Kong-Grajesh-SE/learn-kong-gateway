# Lab 01-B - First API Call Through Kong

> **Goal:** Create your first Kong Service and Route, then send real HTTP traffic through the Data Plane. Test using both the terminal (curl) and Insomnia.

We'll use [**httpbin.konghq.com**](https://httpbin.konghq.com) - Kong's own hosted httpbin instance - as our upstream. No local backend required.

::: tip Testing options
Every step shows both **curl (Terminal)** and **Insomnia (GUI)**. Use whichever you prefer. Results are identical.
:::

---

## Upstream: httpbin.konghq.com

httpbin is a simple HTTP echo service. Useful endpoints:

| Endpoint | What it returns |
|---|---|
| `/get` | Your request headers, origin IP, URL |
| `/post` | Echo of your POST body |
| `/headers` | All HTTP headers Kong forwarded |
| `/status/200` | Returns the given HTTP status code |
| `/delay/1` | Delays response by N seconds |
| `/uuid` | Returns a random UUID |
| `/ip` | Returns your public IP |

```bash
# Verify the upstream works directly (before routing through Kong)
curl -s https://httpbin.konghq.com/get | jq '{url, origin}'
```

---

## Step 1 - Create a Service

A **Service** in Kong represents an upstream backend API.

::: code-group

```bash [curl - Terminal]
deck gateway sync - --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp << 'YAML'
_format_version: '3.0'

services:
  - name: httpbin-service
    url: https://httpbin.konghq.com
    tags: [bootcamp, lab-01]
YAML
```

```yaml [decK YAML file]
# httpbin-service.yaml
_format_version: '3.0'

services:
  - name: httpbin-service
    url: https://httpbin.konghq.com
    tags: [bootcamp, lab-01]
```

:::

```bash
# If using a YAML file:
deck gateway sync httpbin-service.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

::: details Verify in Konnect UI
1. Open Konnect → **bootcamp-cp** → **Gateway Services**
2. You should see **httpbin-service** listed
3. Click it to see the host (`httpbin.konghq.com`), port (443), protocol (HTTPS)
:::

---

## Step 2 - Create a Route

A **Route** maps an incoming request path/host/method to a Service.

::: code-group

```yaml [decK YAML - add Route to Service]
# httpbin-service.yaml (updated)
_format_version: '3.0'

services:
  - name: httpbin-service
    url: https://httpbin.konghq.com
    tags: [bootcamp, lab-01]
    routes:
      - name: httpbin-route
        paths:
          - /demo
        strip_path: true
        tags: [bootcamp, lab-01]
```

:::

```bash
deck gateway sync httpbin-service.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

> **`strip_path: true`** - Kong removes `/demo` before forwarding: `/demo/get` → `/get`

---

## Step 3 - Send a Proxied Request

Kong is running on `:8000`. Route is `/demo`. Upstream path becomes `/get`.

::: code-group

```bash [curl - Terminal]
# Basic GET through Kong
curl -s http://localhost:8000/demo/get | jq .

# Just the key fields
curl -s http://localhost:8000/demo/get | jq '{url, origin, headers}'
```

```text [Insomnia - GUI]
1. Open Insomnia
2. Click  +  → New Request
3. Set method: GET
4. URL: http://localhost:8000/demo/get
5. Click  Send
6. In the response, expand the JSON body
   - "url" shows the upstream URL (httpbin.konghq.com/get)
   - "headers" shows what Kong forwarded
```

:::

Expected response:
```json
{
  "url": "https://httpbin.konghq.com/get",
  "origin": "172.17.0.1",
  "headers": {
    "Host": "httpbin.konghq.com",
    "X-Forwarded-For": "172.17.0.1",
    "X-Forwarded-Host": "localhost",
    "X-Forwarded-Port": "8000",
    "X-Forwarded-Proto": "http",
    "X-Kong-Request-Id": "abc123..."
  }
}
```

---

## Step 4 - Inspect Kong-Added Headers

Notice the headers Kong automatically injects:

| Header | Source | Meaning |
|---|---|---|
| `X-Kong-Request-Id` | Kong core | Unique request ID for tracing |
| `X-Forwarded-For` | Kong core | Original client IP |
| `X-Forwarded-Host` | Kong core | Original Host header |
| `X-Forwarded-Port` | Kong core | Original port |
| `X-Forwarded-Proto` | Kong core | Original protocol (http/https) |

::: code-group

```bash [curl - Terminal]
# Test a POST request
curl -s -X POST http://localhost:8000/demo/post \
  -H "Content-Type: application/json" \
  -d '{"booking": "NYC-LON", "seats": 2}' | jq '{url, json, headers}'
```

```text [Insomnia - GUI]
1. New Request → POST
2. URL: http://localhost:8000/demo/post
3. Body tab → JSON → paste:
   {"booking": "NYC-LON", "seats": 2}
4. Send
5. Check "json" in response - Kong forwarded your body
```

:::

---

## Step 5 - Test Status Codes & Error Handling

```bash
# Force a 404 from upstream
curl -i http://localhost:8000/demo/status/404
# HTTP/1.1 404 Not Found

# Force a 503 from upstream
curl -i http://localhost:8000/demo/status/503
# HTTP/1.1 503 Service Unavailable

# Test latency (1 second delay)
time curl -s http://localhost:8000/demo/delay/1 | jq .url
```

---

## Step 6 - Add the kong-air Service (Optional)

If you have the kong-air backend running locally (`npm run dev` in get-started-guide on port 3001):

::: code-group

```yaml [kong-air.yaml]
_format_version: '3.0'

services:
  - name: kong-air
    url: http://host.docker.internal:3001
    tags: [bootcamp, kong-air]
    routes:
      - name: kong-air-route
        paths:
          - /kong-air
        strip_path: true
        tags: [bootcamp, kong-air]
```

:::

::: info host.docker.internal
Docker containers use `host.docker.internal` to reach services running on your laptop's localhost. On Linux, use your host IP or `--add-host=host.docker.internal:host-gateway` in the compose file.
:::

```bash
deck gateway sync kong-air.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

```bash
# Test kong-air through Kong
curl -s http://localhost:8000/kong-air/api/flights | jq .[0]

# Test with Insomnia:
# GET http://localhost:8000/kong-air/api/flights
```

---

## Step 7 - Export current config with decK

```bash
# Dump your current Konnect config to a file
deck gateway dump \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp \
  --output-file kong-config.yaml

cat kong-config.yaml
```

---

## Summary

| Concept | What you did |
|---|---|
| **Service** | Registered `httpbin.konghq.com` as an upstream |
| **Route** | Mapped `/demo` path to the Service |
| **Proxy** | Sent traffic through Kong on `:8000` |
| **Headers** | Observed Kong's forwarding headers |
| **decK** | Declared config as YAML, synced to Konnect |

---

**Next:** [📋 Module 01 Overview →](../) or [🔀 Module 02 - Core Concepts →](/module-02-core-gateway/)
