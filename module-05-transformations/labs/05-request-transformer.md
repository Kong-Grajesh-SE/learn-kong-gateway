# Lab 05-A — Request Transformer

> **Goal.** In ~30 minutes you'll attach `request-transformer-advanced` to `flights-route` and use all five operations (`add`, `remove`, `replace`, `rename`, `append`). You'll also use **template variables** to inject per-Consumer values without writing one plugin per Consumer.

::: tip Picking up from M04
Start from a clean CP. Same baseline as before: `flights-svc` + `flights-route` + Consumers + `key-auth`.

```bash
echo "Token: ${KONNECT_TOKEN:0:8}…  CP: $KONNECT_CP_NAME  Proxy: $KONNECT_PROXY_URL"
```
:::

---

## Step 1 — Rebuild the baseline (3 min)

```yaml [kong.yaml]
_format_version: '3.0'

consumers:
  - username: web-app
    custom_id: web-001
    keyauth_credentials:
      - key: web-app-secret-key-001
    tags: [module-05]
  - username: mobile-app
    custom_id: mobile-001
    keyauth_credentials:
      - key: mobile-app-secret-key-002
    tags: [module-05]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-05]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        plugins:
          - name: key-auth
            config:
              key_names: [X-API-Key]
              hide_credentials: true
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

**✅ Checkpoint.** `curl $KONNECT_PROXY_URL/flights/anything -H 'X-API-Key: web-app-secret-key-001'` returns 200 and httpbin echoes back the request.

---

## Step 2 — Add a static header (5 min)

Inject `X-API-Version: v3` into every outbound request.

```yaml [Append plugin to flights-route]
plugins:
  - name: key-auth
    config: { … }
  - name: request-transformer-advanced
    config:
      add:
        headers:
          - "X-API-Version:v3"
          - "X-Tenant-Type:travel"
```

Sync. Wait 15s.

```bash
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H 'X-API-Key: web-app-secret-key-001' \
  | jq '.headers | {"X-Api-Version", "X-Tenant-Type"}'
```

Expected:
```json
{ "X-Api-Version": "v3", "X-Tenant-Type": "travel" }
```

🎯 Both headers reached httpbin. They were not on the original request — Kong added them.

::: tip `add` vs `replace`
- **`add`** — only sets the header if the request didn't already have it.
- **`replace`** — overwrites whatever was there.

Subtle but matters: with `add`, a malicious client could send `X-API-Version: v0` and bypass your value. Use `replace` for headers your upstream **must** trust.
:::

---

## Step 3 — Use a template variable for per-Consumer values (7 min) 🎯

`X-Tenant-Id: <consumer.custom_id>` — the value differs per Consumer. Without templates you'd need one plugin per Consumer. With templates, one plugin handles them all.

```yaml [Update the plugin's add.headers]
- name: request-transformer-advanced
  config:
    add:
      headers:
        - "X-API-Version:v3"
        - "X-Tenant-Type:travel"
        - "X-Tenant-Id:$(consumer.custom_id)"
        - "X-Calling-User:$(consumer.username)"
```

Sync. Wait 15s.

Call as each Consumer:

```bash
echo "── web-app ──"
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H 'X-API-Key: web-app-secret-key-001' \
  | jq '.headers | {"X-Tenant-Id", "X-Calling-User"}'

echo "── mobile-app ──"
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H 'X-API-Key: mobile-app-secret-key-002' \
  | jq '.headers | {"X-Tenant-Id", "X-Calling-User"}'
```

Expected:
```json
── web-app ──
{ "X-Tenant-Id": "web-001",    "X-Calling-User": "web-app" }
── mobile-app ──
{ "X-Tenant-Id": "mobile-001", "X-Calling-User": "mobile-app" }
```

🎯 Same plugin, different values per Consumer. The template runs **after** `key-auth` identifies the Consumer.

::: info Template variables available
- `$(consumer.username)`, `$(consumer.custom_id)`, `$(consumer.id)` — after auth
- `$(headers.x-custom-header)` — any request header
- `$(query_string.foo)` — any query param
- `$(uri_captures.foo)` — regex capture groups from the matched route
- `$(route.name)`, `$(service.name)` — current entity names

Variables that don't resolve come back as empty strings — silently. Always test with curl before shipping.
:::

---

## Step 4 — Rename query params for a v2 → v3 API migration (7 min) 🎯

Old clients send `?page=2&size=20`. New API expects `?offset=2&limit=20`. You don't want to break old clients — Kong can translate transparently.

```yaml [Add rename to the plugin]
- name: request-transformer-advanced
  config:
    add:
      headers: [ … ]
    rename:
      querystring:
        - "page:offset"     # ?page= → ?offset=
        - "size:limit"      # ?size= → ?limit=
```

Sync. Wait 15s.

```bash
curl -s "$KONNECT_PROXY_URL/flights/anything?page=2&size=20" \
  -H 'X-API-Key: web-app-secret-key-001' \
  | jq '.args'
```

Expected:
```json
{ "offset": "2", "limit": "20" }
```

🎯 Old client URL, new API contract. Upstream never saw the old names.

::: tip `rename` is `*-advanced` only
The basic `request-transformer` plugin doesn't have `rename` — you'd have to chain `add` + `remove`, which is error-prone. Use `-advanced`.
:::

---

## Step 5 — Strip a sensitive query param (3 min)

Frontends sometimes ship `?debug=true` in dev. You don't want that flag reaching production upstreams.

```yaml [Add remove to the plugin]
- name: request-transformer-advanced
  config:
    add:
      headers: [ … ]
    rename:
      querystring: [ … ]
    remove:
      querystring: [debug, trace, _internal]
      headers: [X-Internal-Debug, X-Forwarded-Secret]
```

Sync. Wait 15s.

```bash
curl -s "$KONNECT_PROXY_URL/flights/anything?debug=true&trace=full&legitParam=ok" \
  -H 'X-API-Key: web-app-secret-key-001' \
  -H 'X-Internal-Debug: leaked-sql' \
  | jq '.args, .headers["X-Internal-Debug"]'
```

Expected:
```json
{ "legitParam": "ok" }          ← debug and trace stripped
null                            ← X-Internal-Debug stripped
```

🎯 Sensitive fields never reached the upstream.

---

## Step 6 — Replace a header (3 min)

Sometimes the *client* sets a header you want to **force** to a different value. (Your CDN sets `X-Forwarded-For` but you want Kong's view to win.)

```yaml
- name: request-transformer-advanced
  config:
    add:     { … }
    remove:  { … }
    rename:  { … }
    replace:
      headers:
        - "X-Source:kong-gateway"        # always force this
        - "X-API-Version:v3"             # was in add; replace ensures override
```

Sync. Test:

```bash
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H 'X-API-Key: web-app-secret-key-001' \
  -H 'X-Source: malicious-client' \
  -H 'X-API-Version: v0' \
  | jq '.headers | {"X-Source", "X-Api-Version"}'
```

Expected:
```json
{ "X-Source": "kong-gateway", "X-Api-Version": "v3" }
```

Even though the client tried to inject their own values, Kong's `replace` wins.

::: info `add` vs `replace`, restated
| Operation | If header is missing | If header exists |
|---|---|---|
| `add` | sets it | leaves the existing value |
| `replace` | does nothing | overwrites |
| `add` + `replace` listing same header | sets it OR overwrites (the union) | ← most robust default |

For headers you must trust, list under **both** `add` and `replace`. Belt and suspenders.
:::

---

## Step 7 — Append (allow multiple values) (2 min)

`append` adds a value *next to* any existing one — useful for headers that legitimately support multiple values.

```yaml
append:
  headers:
    - "Via:1.1 kong-gateway"        # protocol-trace standard
```

Test:

```bash
curl -s $KONNECT_PROXY_URL/flights/anything \
  -H 'X-API-Key: web-app-secret-key-001' \
  -H 'Via: 1.0 my-proxy' \
  | jq '.headers["Via"]'
# "1.0 my-proxy, 1.1 kong-gateway"
```

Both values are present — that's `append`.

---

## Recap

You used every transform verb on requests:

```
operation     where                                              example
add           if missing                                         "X-API-Version:v3"
replace       always overwrite                                   "X-Source:kong-gateway"
remove        delete entirely                                    "querystring: [debug, trace]"
rename        change the key, keep the value                     "page:offset"
append        add a value (multi-value header)                   "Via:1.1 kong-gateway"
```

Each works on **headers**, **querystring**, and **body** (where applicable). Template variables let you do per-Consumer / per-Route logic in a single plugin.

---

## Cleanup

**Don't clean up yet.** Lab 05-B uses the same Service/Route and the request transformer's output. Full M05 cleanup is at the end of 05-B.

---

**Next:** [Lab 05-B — Response Transformer →](./05-response-transformer)
