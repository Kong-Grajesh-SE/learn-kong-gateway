# Module 05 - Transformations

> **The scenario.** Your travel platform is evolving fast. The frontend team wants the new `/v3` shape: `flightId` renamed from `id`, no internal `_debug` fields. The backend can't be changed - it's a vendor product. And every outbound request must carry an `X-API-Version: v3` header so analytics can tell new clients from old.
>
> In the next ~60 minutes you'll **rewrite requests and responses in flight** using two plugins. Header injection, body field renames, sensitive-field stripping, conditional transforms. No backend change.

## What you'll have at the end

A gateway that:
- **Injects** `X-API-Version: v3` and `X-Tenant-Id: <consumer.custom_id>` into every outbound request.
- **Renames** the query param `page → offset` and `size → limit` so old clients work against a new API.
- **Removes** `_debug` and `internal_id` fields from every response.
- **Adds** `X-Bootcamp-Module: 05` to every response so you can see your transformer was the last thing that ran.

```bash
$ curl -s "$KONNECT_PROXY_URL/flights/anything?page=2&size=20" \
    -H 'X-API-Key: web-app-secret-key-001' \
  | jq '.headers["X-Api-Version"], .args'
"v3"
{ "offset": "2", "limit": "20" }     ← page renamed → offset, size → limit
```

## Who this module is for

You finished M03. You have a Service + Route + Consumers + `key-auth`. M04 is helpful but optional - transformers don't depend on rate-limit or cache.

## Three concepts you need today

| Concept | What it is | Why it matters today |
|---|---|---|
| **Transform phases** | `add` / `remove` / `replace` / `rename` / `append` operations on headers, querystring, body | These are the verbs of every transformer plugin |
| **Template variables** | Strings like `$(consumer.username)` Kong resolves at runtime per request | Lets you inject **per-Consumer** values without writing separate plugins for each |
| **Request vs response phase** | Plugin runs either before forwarding (request) or after the upstream replies (response) | Determines whether the upstream sees your edit or only the client does |

Plugin chain shape:

```
Client → key-auth → request-transformer-advanced → upstream
                              │
              add: X-API-Version: v3
              rename: ?page → ?offset
              replace: $(consumer.custom_id) into header

Upstream response → response-transformer-advanced → Client
                              │
              remove: ._debug, .internal_id
              add: X-Bootcamp-Module: 05
```

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 05-A | [Request Transformer](./labs/05-request-transformer) | ~30 min | Add an API-version header, inject per-Consumer tenant ID via templates, rename query params during a v2→v3 migration |
| 05-B | [Response Transformer](./labs/05-response-transformer) | ~30 min | Strip internal/debug fields, add metadata, conditional transforms based on status code |

::: tip Why `*-transformer-advanced` and not the basic ones?
The basic `request-transformer` / `response-transformer` plugins are Kong OSS. The `-advanced` versions are Konnect Enterprise - they add **template variables**, **rename**, and **conditional transforms**, all of which are essential the moment you have Consumers or per-tenant logic. Konnect serverless includes the advanced variants. We use the advanced ones throughout.
:::

## Exit ticket

1. You want to inject `X-Tenant-Id: <the user's custom_id>` on every request. Which plugin, which operation, which template variable?
2. A client sends `Cache-Control: no-cache`. You want the upstream to ignore that header. Which transformer + which operation?
3. The upstream returns `{"data": [...], "_debug": {"sql": "SELECT …"}}`. You want clients to see only `data`. Which plugin + which operation?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| Template variable resolves to literal `$(consumer.username)` instead of the value | The advanced plugin variant isn't installed. Konnect serverless has it; some legacy decK files use the OSS plugin name. Use `request-transformer-advanced`. |
| Body changes aren't applied | Plugin only modifies bodies with matching `content-type`. Defaults are `application/json` only - add `application/x-www-form-urlencoded` etc. if needed. |
| `remove.headers: [Authorization]` removes the key but downstream still sees it | The header was set by a *later* plugin (e.g. `request-transformer` running before `oauth2`). Check plugin priority. |
| Renamed query params don't reach the upstream | `rename` is in `request-transformer-advanced`, not basic. Double-check the plugin `name` field. |
| Response transformer doesn't fire on 5xx | Default config skips error responses - set `replace.if_status` or `add.if_status` to include 5xx if you really want to. Usually you don't. |

## What's next

**[Module 06 - Observability](/module-06-observability/)** wires logs, metrics, and distributed traces. The correlation-id you set up in M03 finally pays off - you'll see it flow into Prometheus labels, HTTP-log lines, and OpenTelemetry spans.

---

*Previous: [Module 04 - Traffic & Resilience](/module-04-traffic-control/) · Next: [Module 06 - Observability →](/module-06-observability/)*
