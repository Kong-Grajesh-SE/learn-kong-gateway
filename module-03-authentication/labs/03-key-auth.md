# Lab 03-A - Consumers & key-auth

> **Goal.** In ~45 minutes you'll create two Consumers, give each one an API key, attach `key-auth` to a Route, and test what happens with no key, a wrong key, and the right key. You'll finish with a gateway that knows *who* is calling - the foundation everything in M04+ builds on.

::: tip Picking up from M02
Make sure you ran the M02 cleanup at the end of Lab 02-B. The lab assumes an empty CP.

```bash
echo "Token: ${KONNECT_TOKEN:0:8}…  CP: $KONNECT_CP_NAME  Proxy: $KONNECT_PROXY_URL"
```
:::

---

## Step 1 - Rebuild a minimal gateway (3 min)

Single Service + single Route. We'll add plugins on top.

```yaml [kong.yaml]
_format_version: '3.0'
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-03]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        tags: [module-03]
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

**✅ Checkpoint.** `curl $KONNECT_PROXY_URL/flights/get` returns 200 (wait ~15s after sync).

---

## Step 2 - Create two Consumers (5 min)

A **Consumer** is the named identity of an API caller. Each one has a `username`, an optional `custom_id`, and credentials (which we'll add next).

::: code-group

```yaml [kong.yaml - append consumers]
_format_version: '3.0'
consumers:
  - username: web-app
    custom_id: web-001
    tags: [module-03]
  - username: mobile-app
    custom_id: mobile-001
    tags: [module-03]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-03]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

```bash [Admin API alternative]
for U in web-app:web-001 mobile-app:mobile-001; do
  USERNAME=${U%:*}; CUSTOM_ID=${U#*:}
  curl -sS -X POST \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    -H "Content-Type: application/json" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumers" \
    -d "{\"username\":\"$USERNAME\",\"custom_id\":\"$CUSTOM_ID\",\"tags\":[\"module-03\"]}" \
    | jq -r '"created " + .username'
done
```

:::

**✅ Checkpoint.** Konnect → **Consumers** → both `web-app` and `mobile-app` listed with their `custom_id`.

::: info `username` vs `custom_id`
- `username` is Kong's unique identifier - required, must be unique.
- `custom_id` is *your* identifier - typically the user's ID in your own database. Kong stores it but doesn't enforce uniqueness.
- Both end up in headers (`X-Consumer-Username`, `X-Consumer-Custom-ID`) that Kong forwards upstream after auth.
:::

---

## Step 3 - Attach `key-auth` to the Route (3 min)

`key-auth` is a plugin. Attaching it to `flights-route` means Kong runs it for every request that matches that Route.

```yaml [Append plugin to flights-route]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        plugins:
          - name: key-auth
            config:
              key_names: [X-API-Key, apikey]   # header or query param names
              key_in_header: true
              key_in_query: true
              hide_credentials: true            # strip key before upstream sees it
```

Sync. Wait ~15s.

**✅ Checkpoint.** Konnect → **flights-route** → **Plugins** tab → `key-auth` listed and **enabled**.

---

## Step 4 - Hit the protected route without a key (2 min)

```bash
curl -i $KONNECT_PROXY_URL/flights/get
# HTTP/2 401
# {"message":"No API key found in request","request_id":"..."}
```

That's the test working. Kong's saying "I won't talk to anyone I can't identify."

::: tip Why 401 and not 403?
- **401 Unauthorized** = "I don't know who you are." → missing/invalid credentials.
- **403 Forbidden** = "I know who you are, but you can't do that." → wrong identity for this resource.

`key-auth` returns 401. ACL (M04) returns 403 once identity is known but not allowed.
:::

---

## Step 5 - Generate API keys for each Consumer (5 min)

::: code-group

```yaml [kong.yaml - full version with keyauth_credentials]
_format_version: '3.0'
consumers:
  - username: web-app
    custom_id: web-001
    keyauth_credentials:
      - key: web-app-secret-key-001
        tags: [module-03]
  - username: mobile-app
    custom_id: mobile-001
    keyauth_credentials:
      - key: mobile-app-secret-key-002
        tags: [module-03]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        plugins:
          - name: key-auth
            config:
              key_names: [X-API-Key, apikey]
              key_in_header: true
              key_in_query: true
              hide_credentials: true
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

```bash [Admin API alternative]
curl -sS -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumers/web-app/key-auth" \
  -d '{"key":"web-app-secret-key-001"}' | jq '{key, consumer:.consumer.username}'

curl -sS -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumers/mobile-app/key-auth" \
  -d '{"key":"mobile-app-secret-key-002"}' | jq '{key, consumer:.consumer.username}'
```

:::

::: warning Real keys must be random
We're using human-readable keys for the lab so you can tell them apart. In production, **omit the `key` field** and Kong generates a high-entropy string. Never check API keys into source control.
:::

**✅ Checkpoint.** Konnect → **Consumers** → click `web-app` → **Credentials** → `key-auth` shows the key.

---

## Step 6 - Authenticate as each Consumer (5 min)

```bash
# As web-app - pass the key in the header
curl -s $KONNECT_PROXY_URL/flights/get \
  -H 'X-API-Key: web-app-secret-key-001' \
  | jq '{consumer: .headers["X-Consumer-Username"], custom_id: .headers["X-Consumer-Custom-Id"]}'
```

Expected:
```json
{ "consumer": "web-app", "custom_id": "web-001" }
```

🎯 Kong validated the key, identified the Consumer, and **injected `X-Consumer-*` headers** so your upstream knows who's calling. The upstream **never sees the API key itself** because you set `hide_credentials: true`.

```bash
# As mobile-app - pass the key in the QUERY STRING instead (we allowed both)
curl -s "$KONNECT_PROXY_URL/flights/get?apikey=mobile-app-secret-key-002" \
  | jq '.headers["X-Consumer-Username"]'
# "mobile-app"
```

```bash
# Wrong key
curl -i $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: definitely-not-a-real-key' | head -3
# HTTP/2 401
# {"message":"Unauthorized","request_id":"..."}
```

**✅ Checkpoint.** Three distinct outcomes: valid key → 200 + correct Consumer headers, wrong key → 401, no key → 401.

---

## Step 7 - Headers Kong injects after auth (3 min - read)

Run one successful authenticated request and inspect what httpbin saw:

```bash
curl -s $KONNECT_PROXY_URL/flights/get \
  -H 'X-API-Key: web-app-secret-key-001' \
  | jq '.headers | to_entries | map(select(.key | test("X-Consumer|X-Credential"; "i"))) | from_entries'
```

Expected:
```json
{
  "X-Consumer-Id": "<uuid>",
  "X-Consumer-Username": "web-app",
  "X-Consumer-Custom-Id": "web-001",
  "X-Credential-Identifier": "<uuid of the key-auth credential>"
}
```

These four headers are how every downstream service identifies the caller - without needing to validate the API key itself. Your upstream can trust them because they come from inside Kong, not from the client. **Don't forward `X-Consumer-*` blindly to every upstream** - only ones inside your trust boundary.

---

## Step 8 - Anonymous fallback (8 min) 🧪

Sometimes you want **mixed access**: identified Consumers get full features, unauthenticated users get a degraded experience. Kong supports that with the `anonymous` config.

First, create an "anonymous" Consumer:

```yaml [Append to consumers]
consumers:
  - username: anonymous
    tags: [module-03]
  - username: web-app
    custom_id: web-001
    keyauth_credentials:
      - key: web-app-secret-key-001
  - username: mobile-app
    custom_id: mobile-001
    keyauth_credentials:
      - key: mobile-app-secret-key-002
```

`key-auth` needs the anonymous Consumer's **UUID** (not the username) in its config. Fetch it:

```bash
ANON_ID=$(curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumers/anonymous" \
  | jq -r '.id')
echo "Anonymous consumer ID: $ANON_ID"
```

Update the plugin config (substitute the UUID):

```yaml
plugins:
  - name: key-auth
    config:
      key_names: [X-API-Key, apikey]
      key_in_header: true
      key_in_query: true
      hide_credentials: true
      anonymous: <paste-the-UUID-here>
```

Sync. Now retry without a key:

```bash
curl -s $KONNECT_PROXY_URL/flights/get | jq '.headers["X-Consumer-Username"]'
# "anonymous"   ← request goes through, identified as the anonymous Consumer
```

::: tip When anonymous fallback is useful
- Public read, authenticated write (rate-limit the anonymous Consumer hard, paid Consumers loosely).
- Soft launches: API is "open" but every call is still tagged, so you can see if usage matches expectations.

When it's a footgun: any plugin that runs *after* auth (rate-limit, ACL) needs to remember the anonymous case. Forgetting that = "why is everyone hitting my rate limit?"
:::

**✅ Checkpoint.** Request with no key → 200, `X-Consumer-Username: anonymous`. Request with a valid key → 200, `X-Consumer-Username: web-app` or `mobile-app`.

---

## Step 9 - Disable `key-auth` before moving on (1 min)

Lab 03-B doesn't need authentication. Drop the plugin from the Route (keep the Consumers - we'll need them again in M04):

```yaml [Drop key-auth from flights-route]
services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        # plugins: removed
```

Sync. Now `curl $KONNECT_PROXY_URL/flights/get` (no headers) should return 200.

::: tip Why disable instead of stacking?
Plugins applied to the same Route compose into a *plugin chain* - `key-auth` first, then the next, then the next. For the next lab we want a clean baseline so it's obvious which plugin is responsible for which behaviour. In production you'll have many plugins per Route; here we keep them isolated for teaching.
:::

---

## Recap

You added **Consumers** to Kong for the first time and used them via `key-auth`:

```
Client (with X-API-Key)  ─▶ Kong Gateway
                              ├─ key-auth: look up key → web-app Consumer
                              ├─ inject X-Consumer-Username: web-app
                              ├─ strip the API key from the request
                              └─ forward to httpbin
```

You learned:
- Consumers are how Kong names callers; credentials live on Consumers.
- `key-auth` is the gentlest auth plugin - one config block, no IdP.
- After auth, Kong inserts `X-Consumer-*` headers that upstreams can trust.
- `hide_credentials: true` strips the key before upstream sees it.
- `anonymous: <id>` lets you mix authenticated and unauthenticated access on the same Route.

---

## Cleanup

**Don't clean up yet.** Lab 03-B reuses this Service and the Consumers. Full M03 cleanup is at the end of 03-B.

---

**Next:** [Lab 03-B - CORS, IP Restriction, Correlation ID →](./03-easy-wins)
