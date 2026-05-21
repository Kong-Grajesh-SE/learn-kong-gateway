# Lab 01 - Your First Gateway (Quick Start)

> **Goal.** In ~45 minutes, create a serverless gateway on Konnect, define a Service + Route, and send your first proxied request through it.
>
> **No Docker required.** Konnect runs the gateway for you. If you prefer running it locally in Docker, see [01-hybrid-docker-setup](./01-hybrid-docker-setup) instead.

Throughout the lab, every step ends with a **✅ Checkpoint** so you know you're on track before continuing.

---

## Step 1 - Create a Control Plane (5 min)

A **Control Plane (CP)** is the brain that holds your gateway's configuration. Konnect runs it for you.

1. Log in to [cloud.konghq.com](https://cloud.konghq.com).
2. **API Gateway** in the left sidebar → **Gateways** → **+ New Gateway**.
3. Choose **Kong Gateway (Serverless)**.
4. Name it: `bootcamp-cp`.
5. Region: pick the closest to you (US, EU, AU).
6. Click **Create**.

When the CP page loads, you'll see two things to copy:

- The **Proxy URL** (looks like `https://abc123.us.serverless.gateways.konggateway.com`).
- The **Control Plane ID** in the page URL (a UUID).

::: tip Save them now
```bash
export KONNECT_PROXY_URL=https://abc123.us.serverless.gateways.konggateway.com
export KONNECT_CP_ID=<the-uuid-from-the-url>
export KONNECT_REGION=us   # or eu / au
export KONNECT_CP_NAME=bootcamp-cp
```
:::

**✅ Checkpoint.** Your CP shows a green "Healthy" status. The proxy URL responds to a basic curl (we'll test in Step 3).

---

## Step 2 - Get a Personal Access Token (2 min)

A **PAT** authorizes your API calls and decK commands.

1. Top-right avatar → **Personal Access Tokens**.
2. **+ Generate Token**. Name: `bootcamp`. Copy it - it's shown only once.

```bash
export KONNECT_TOKEN=kpat_xxxxxxxxxxx
```

**✅ Checkpoint.** Confirm the API is reachable:

```bash
curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
  https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID} \
  | jq '{id, name, config}'
```

You should see your CP's name and config. If you get `403`, your token region doesn't match your CP region - regenerate the token while logged into the right region's Konnect tenant.

---

## Step 3 - Verify the gateway is alive (2 min)

The gateway is running but has no Services yet. Hitting it should return Kong's default 404:

```bash
curl -s $KONNECT_PROXY_URL/ | jq
```

Expected:

```json
{
  "message": "no Route matched with those values",
  "request_id": "abc...123"
}
```

::: info Why this is a good thing
That JSON is Kong itself answering - not your code, not httpbin, not Konnect. The proxy URL points at a real Kong gateway. No Route matches `/` because we haven't created one. The `request_id` is the trace ID Kong assigns to every request.
:::

**✅ Checkpoint.** You got the JSON above (HTTP 404 is correct - that's the right kind of 404).

---

## Step 4 - Create a Service (5 min)

A **Service** names the upstream API Kong will forward to. We'll use `httpbin.konghq.com` - Kong's own httpbin echo service.

You can configure Kong two ways: the **Konnect Admin API** (imperative - "do this now") or **decK** (declarative - "here's the final state, make it match"). decK is what you'll use in production for GitOps. For this lab, either works - pick one.

::: code-group

```bash [Konnect Admin API (curl)]
curl -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/services" \
  -d '{
    "name": "httpbin-service",
    "url": "https://httpbin.konghq.com",
    "tags": ["bootcamp"]
  }' | jq
```

```yaml [decK YAML]
# Save as kong.yaml
_format_version: '3.0'
services:
  - name: httpbin-service
    url: https://httpbin.konghq.com
    tags: [bootcamp]
```

```bash [decK apply]
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

:::

::: tip Admin API vs decK - when to use which
- **Admin API** is great for one-off explorations and scripting. State lives only in Konnect.
- **decK** treats Konnect config as code: review YAML in PRs, `deck diff` before applying, `deck dump` to back up. Use this in production.
:::

**✅ Checkpoint.** Konnect → **Gateway Services** → confirm `httpbin-service` listed with `host=httpbin.konghq.com`, `protocol=https`, `port=443`.

::: warning Common slip
If you typed `host: httpbin.konghq.com` instead of `url: https://httpbin.konghq.com`, Kong stores `protocol=http`, `port=80`. The `url` field is parsed; the individual fields aren't. Delete and recreate with `url:`.
:::

---

## Step 5 - Create a Route (5 min)

A **Route** matches incoming requests and sends them to a Service. We'll match path `/demo`.

::: code-group

```bash [Konnect Admin API]
curl -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/routes" \
  -d '{
    "name": "httpbin-route",
    "paths": ["/demo"],
    "strip_path": true,
    "service": { "name": "httpbin-service" },
    "tags": ["bootcamp"]
  }' | jq
```

```yaml [decK YAML - append to kong.yaml]
_format_version: '3.0'
services:
  - name: httpbin-service
    url: https://httpbin.konghq.com
    tags: [bootcamp]
    routes:
      - name: httpbin-route
        paths: [/demo]
        strip_path: true
        tags: [bootcamp]
```

```bash [decK apply]
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

:::

**What `strip_path: true` does.** Kong removes the matched prefix (`/demo`) before forwarding upstream. So `/demo/get` → `/get` on httpbin. We'll see this in Step 6.

**✅ Checkpoint.** Konnect → click `httpbin-service` → **Routes** tab → confirm `httpbin-route` listed with path `/demo` and `strip_path: true`.

---

## Step 6 - Send your first proxied request (3 min)

Wait ~15 seconds for the route to propagate to the serverless Data Plane (it polls Konnect roughly every 10s). Then:

```bash
curl -s $KONNECT_PROXY_URL/demo/get | jq
```

If you get `no Route matched`, wait another 15s and retry. **Don't panic - this is normal on a fresh serverless DP.**

Expected response (abbreviated):

```json
{
  "url": "https://abc123.us.serverless.gateways.konggateway.com/get",
  "origin": "203.0.113.42",
  "headers": {
    "Host": "httpbin.konghq.com",
    "X-Forwarded-Host": "abc123.us.serverless.gateways.konggateway.com",
    "X-Forwarded-Path": "/demo/get",
    "X-Forwarded-Prefix": "/demo",
    "X-Kong-Request-Id": "828e6d71e7f03213182a4536980cf208"
  }
}
```

🎉 **You just proxied your first request through Kong.** Read what happened:

| What Kong did | Evidence in the response |
|---|---|
| Matched `/demo` and stripped the prefix | `url` ends in `/get`, not `/demo/get` |
| Forwarded to httpbin | `Host: httpbin.konghq.com` in the headers |
| Recorded the original client request path | `X-Forwarded-Path: /demo/get` |
| Tagged the request for tracing | `X-Kong-Request-Id: 828e6d71...` |

::: info Why does `url` show your gateway hostname, not httpbin's?
httpbin reconstructs the URL using `X-Forwarded-Host`, so it reflects what the *client* saw, not what httpbin saw on its own socket. This is normal - and useful when debugging which gateway a request came through.
:::

---

## Step 7 - POST a body (3 min)

```bash
curl -s -X POST $KONNECT_PROXY_URL/demo/post \
  -H "Content-Type: application/json" \
  -d '{"booking":"NYC-LON","seats":2}' \
  | jq '.json'
```

Expected:

```json
{ "booking": "NYC-LON", "seats": 2 }
```

httpbin echoes back the body you sent. Kong didn't modify it - it forwarded the bytes as-is. (Modifying request bodies is what Transformer plugins are for. We'll get there.)

---

## Step 8 - Test failure modes (3 min)

Pretend the upstream is broken. httpbin can simulate any status code:

```bash
curl -i $KONNECT_PROXY_URL/demo/status/503
# HTTP/2 503
```

That `503` comes from httpbin, not Kong. Compare with a request to a path Kong doesn't know:

```bash
curl -i $KONNECT_PROXY_URL/no-such-path
# HTTP/2 404
# {"message":"no Route matched with those values","request_id":"..."}
```

That `404` comes from **Kong**, not the upstream. (Kong never even tried to forward - no Route matched.)

::: tip Why this distinction matters
Later, when something breaks in production, your first triage question will be: "Did Kong reject this, or did the upstream?" The presence of `X-Kong-Request-Id` and Kong-shaped error JSON tells you it was Kong. A status code with the upstream's body shape tells you it was the upstream.
:::

---

## Step 9 - See your traffic in Konnect Analytics (2 min)

Konnect → **Analytics**. Within ~1 minute, you should see your requests by status code, latency, and Service/Route.

Filter by Service: `httpbin-service`. You'll see all the requests you just sent - including the 503 and 404.

**✅ Checkpoint.** You can see at least 5–10 of your requests in Analytics.

---

## Recap - what you just built

```
You              Kong Gateway                 httpbin.konghq.com
  │                    │                              │
  │  GET /demo/get     │                              │
  │ ─────────────────→ │  match Route /demo           │
  │                    │  strip_path: true            │
  │                    │  add X-Kong-Request-Id       │
  │                    │  add X-Forwarded-Path        │
  │                    │ ─── GET /get ──────────────→ │
  │                    │ ←── 200 OK ───────────────── │
  │ ←── 200 OK ─────── │                              │
```

You created:
- A **Service** (`httpbin-service`) - names an upstream API.
- A **Route** (`httpbin-route` at `/demo`) - maps client URLs to that Service.
- A real proxied request that Kong handled end-to-end.

No plugins. Just routing. Module 02 layers on multiple Services, smarter Route matching, and load-balanced **Upstreams**.

---

## Exit ticket - answers

1. **Service vs Route?** A Service names *where* requests go (the upstream). A Route names *which* requests qualify (path/host/method matching). One Service can have many Routes.
2. **`strip_path: true`?** Kong removes the matched path prefix before forwarding. `/demo/get` → `/get`. With `false`, the upstream would see `/demo/get` as-is - useful if your upstream expects the full path.
3. **`X-Kong-Request-Id`?** Every request gets a unique ID Kong threads through its logs, your upstream's logs (if you forward the header), and Konnect Analytics. When something breaks, you join three datasets on this one ID.

---

## Clean up

Before Module 02, remove what you created so the next module starts clean:

::: code-group

```bash [decK - wipe the CP]
echo '_format_version: "3.0"' | deck gateway sync - \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

```bash [Konnect Admin API]
curl -X DELETE -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/routes/httpbin-route"
curl -X DELETE -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/services/httpbin-service"
```

:::

::: tip Verify with the bootcamp script
Run `./scripts/verify-module-01.sh serverless` from the repo root - it walks every step above automatically, including the cleanup.
:::

---

**Next:** [Module 02 - Routing & Topology →](/module-02-core-gateway/)

