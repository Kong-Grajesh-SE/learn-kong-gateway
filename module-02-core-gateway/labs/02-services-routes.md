# Lab 02-A — Multi-Service Routing

> **Goal.** In ~40 minutes you'll register **three Services**, route them by **path and method**, and learn what happens when routes overlap or conflict. We'll deliberately break things so you can see Kong's matching priority in action.

::: tip Picking up from M01
This lab assumes the same Konnect Control Plane and env vars from [Module 01](/module-01-orientation/). If you ran the cleanup at the end of M01, your CP is empty — exactly what we want.

```bash
echo "Token: ${KONNECT_TOKEN:0:8}…  CP: $KONNECT_CP_NAME  Proxy: $KONNECT_PROXY_URL"
```
:::

---

## Step 1 — Register three Services (5 min)

Three Services, all backed by `httpbin.konghq.com` (we're focused on routing today, not real backends):

::: code-group

```yaml [kong.yaml — decK]
_format_version: '3.0'
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-02, bootcamp]
  - name: hotels-svc
    url: https://httpbin.konghq.com
    tags: [module-02, bootcamp]
  - name: cars-svc
    url: https://httpbin.konghq.com
    tags: [module-02, bootcamp]
```

```bash [Apply with decK]
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

```bash [Admin API alternative]
for SVC in flights-svc hotels-svc cars-svc; do
  curl -sS -X POST \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    -H "Content-Type: application/json" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/services" \
    -d "{\"name\":\"$SVC\",\"url\":\"https://httpbin.konghq.com\",\"tags\":[\"module-02\"]}" \
    | jq -r '"created " + .name'
done
```

:::

**✅ Checkpoint.** Konnect → **Gateway Services** → all three Services exist, each pointing at `httpbin.konghq.com:443`.

::: info Why three Services backed by the same upstream?
Real APIs would have three different upstream hostnames. We use the same one so this lab works on a serverless gateway without you running anything locally. The Service is just a *name* — what matters here is how Routes select between them.
:::

---

## Step 2 — Route each Service by path (5 min)

We want:
- `GET /flights/*` → `flights-svc`
- `GET /hotels/*`  → `hotels-svc`
- `GET /cars/*`    → `cars-svc`

::: code-group

```yaml [Replace kong.yaml]
_format_version: '3.0'
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
  - name: hotels-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - name: hotels-route
        paths: [/hotels]
        strip_path: true
  - name: cars-svc
    url: https://httpbin.konghq.com
    tags: [module-02]
    routes:
      - name: cars-route
        paths: [/cars]
        strip_path: true
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

:::

Wait ~15 seconds for propagation, then verify each Service is reachable through its own path:

```bash
for P in flights hotels cars; do
  URL=$(curl -s $KONNECT_PROXY_URL/$P/get | jq -r '.url')
  echo "$P → $URL"
done
```

Expected:
```
flights → https://<your-gateway>/get
hotels  → https://<your-gateway>/get
cars    → https://<your-gateway>/get
```

(Same httpbin upstream — but the *Route* selected is different. You'll see this split in Konnect Analytics when you filter by Route.)

**✅ Checkpoint.** All three paths return 200, and Konnect Analytics shows traffic across three Routes.

---

## Step 3 — Deliberately overlap two routes (10 min) 🧪

Real APIs constantly have overlapping paths — `/flights` and `/flights/premium` are both valid. Let's see how Kong decides.

Add a more specific route for premium flights:

```yaml [Update flights-svc with a second route]
- name: flights-svc
  url: https://httpbin.konghq.com
  tags: [module-02]
  routes:
    - name: flights-route
      paths: [/flights]
      strip_path: true
    - name: flights-premium-route
      paths: [/flights/premium]
      strip_path: true
```

Sync and wait 15s. Now hit both paths:

```bash
# /flights/premium/get → should match the MORE SPECIFIC route
curl -s $KONNECT_PROXY_URL/flights/premium/get | jq -r '.url'

# /flights/economy/get → no specific route → falls back to /flights
curl -s $KONNECT_PROXY_URL/flights/economy/get | jq -r '.url'
```

::: tip Make Kong tell you which Route matched
Kong doesn't return the matched Route name as a header by default. Open Konnect → **Analytics** → filter `service=flights-svc` for the last minute. You'll see two routes lighting up. The first request hit `flights-premium-route`; the second hit `flights-route`.
:::

**The rule:** Kong picks the route whose path is the **longest prefix** that matches the request. `/flights/premium` (16 chars) beats `/flights` (8 chars) when the request is `/flights/premium/get`.

**✅ Checkpoint.** You understand: when two paths both match, **longer wins**.

---

## Step 4 — Now overlap by method (10 min) 🧪

Routes can also be filtered by HTTP method. Restrict the premium route to `POST` only — for booking premium flights:

```yaml
- name: flights-svc
  url: https://httpbin.konghq.com
  routes:
    - name: flights-route
      paths: [/flights]
      strip_path: true
    - name: flights-premium-route
      paths: [/flights/premium]
      methods: [POST]      # ← new
      strip_path: true
```

Sync and wait 15s.

```bash
# GET /flights/premium/get → no POST route at this path → falls back to /flights
curl -s -o /dev/null -w 'GET premium → %{http_code}\n'  $KONNECT_PROXY_URL/flights/premium/get

# POST /flights/premium/post → matches flights-premium-route
curl -s -o /dev/null -w 'POST premium → %{http_code}\n' -X POST \
  -H 'Content-Type: application/json' -d '{"class":"first"}' \
  $KONNECT_PROXY_URL/flights/premium/post
```

Both return 200 — but they hit **different Routes**. Verify in Konnect Analytics.

::: info Route matching priority — the actual order
Kong evaluates routes in this order (highest wins):
1. **Longer path prefix** ✓ (Step 3)
2. **Path = regex** outranks plain prefix
3. **More specific method** ✓ (this step) — a route restricted to `[POST]` outranks one accepting any method
4. **Header match** — a route requiring `Header: value` outranks one without
5. **Host match** — a route requiring a specific Host outranks a host-less one
:::

**✅ Checkpoint.** You can predict which Route wins given two overlapping definitions.

---

## Step 5 — Test with the wrong method (3 min)

A booking should be `POST`. What if a client mistakenly sends `DELETE`?

```bash
curl -s -i -X DELETE $KONNECT_PROXY_URL/flights/premium/delete | head -3
```

What did Kong do?

::: details Answer
Kong sees `DELETE /flights/premium/delete`. The premium route requires `methods: [POST]` — no match. Kong falls back to `flights-route` (no method restriction → accepts any). The request reaches httpbin, which returns the DELETE response.

The fix for production: pin **every** Route to the methods it actually expects, so Kong returns a clean 404 (or you add the `request-termination` plugin to deny). Try adding `methods: [GET]` to `flights-route` and re-running.
:::

---

## Step 6 — Path stripping revisited (3 min)

You set `strip_path: true` on every Route. That's why `/flights/get` becomes `/get` upstream. What if the upstream actually expects the full prefix?

Flip `flights-route` to `strip_path: false`:

```yaml
- name: flights-route
  paths: [/flights]
  strip_path: false
```

Sync, wait, then:

```bash
curl -s $KONNECT_PROXY_URL/flights/get | jq -r '.url, .status'
# url now shows /flights/get (upstream saw the prefix)
# httpbin returns 404 because it has no /flights endpoint
```

This is the most common production bug: `strip_path` mismatch between gateway and upstream expectations.

::: tip Default decision
For *most* upstreams, `strip_path: true` is correct — Kong handles the routing prefix, the upstream stays unaware. Set it to `false` only when the upstream genuinely expects the prefix (e.g. when forwarding to another API gateway).
:::

Revert to `strip_path: true` so the rest of the lab keeps working:

```yaml
- name: flights-route
  paths: [/flights]
  strip_path: true
```

---

## Step 7 — Inspect via Konnect UI (2 min)

Konnect → **Gateway Services** → click `flights-svc` → **Routes** tab.

You should see both `flights-route` and `flights-premium-route` with their paths, methods, and `strip_path` settings.

::: tip Konnect UI vs decK — pick one source of truth
Editing routes in the UI works fine for one-off experiments. But the moment you `deck gateway sync` again, your UI edits get overwritten by whatever is in `kong.yaml`. In production, the YAML is the source of truth; in Konnect dev environments, the UI is fine.
:::

---

## Recap — what you just built

```
GET  /hotels/*           → hotels-svc       (single route)
GET  /cars/*             → cars-svc         (single route)
GET  /flights/*          → flights-svc      (catch-all for flights)
POST /flights/premium/*  → flights-svc      (more specific — wins for POST)
```

You learned Kong's route matching obeys a strict precedence:
- **Longer path > shorter path**
- **Method-restricted > any method**
- **With header/host filter > without**

This becomes critical in Module 03+ when plugins attach to *specific* routes. Attaching `key-auth` to `flights-premium-route` but not `flights-route` would mean only POST-to-premium needs an API key — exactly the kind of pattern real APIs need.

---

## Cleanup

**Don't clean up yet.** Lab 02-B reuses `flights-svc`. The full M02 cleanup is at the end of 02-B.

---

**Next:** [Lab 02-B — Upstreams & Health Checks →](./02-upstreams)
