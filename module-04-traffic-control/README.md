# Module 04 - Traffic & Resilience

> **The scenario.** The travel app is growing fast. A free-tier scraper is back at it - same client, ~50 requests/second. Meanwhile, your `flights` upstream is slow because everyone's hitting it for the same `popular-routes` listing.
>
> In the next ~60 minutes you'll add two plugins that fix both: **rate-limiting** (cut the scraper down to size, fairly per Consumer) and **proxy-cache** (serve repeat requests from Kong's memory, never bothering the upstream).

## What you'll have at the end

- Rate limit `flights-route`: anonymous → **10 requests/minute**, authenticated `web-app` → **100/min**, `mobile-app` → **300/min**.
- Cache `GET /flights/anything/2xx`: first request hits the upstream (~200ms), every subsequent request inside the cache window returns in <10ms from Kong.
- Concrete `X-RateLimit-*` and `X-Cache-Status` response headers that prove which plugin handled the request.

```bash
$ for i in 1 2 3 4 5; do
    curl -s -o /dev/null -w '%{http_code}  %{time_total}s\n' $KONNECT_PROXY_URL/flights/get
  done
200  0.213s    ← first hit, upstream cold
200  0.008s    ← cached, served by Kong
200  0.007s    ← cached
200  0.009s    ← cached
200  0.008s    ← cached
```

## Who this module is for

You finished M03. You have a working Konnect CP, a `flights-svc` Service + `flights-route` Route, two Consumers (`web-app`, `mobile-app`) with API keys, and an `anonymous` Consumer.

## Three concepts you need today

| Concept | What it is | Why it matters today |
|---|---|---|
| **Rate-limit window** | How many requests are allowed in a given interval (`60/minute`, `1000/hour`) | Different Consumers should get different limits - paid tier vs free, internal vs external |
| **Rate-limit identifier** | What Kong uses to count: `consumer`, `credential`, `ip`, `header`, `path` | "Limit per IP" and "limit per Consumer" produce very different bills |
| **Cache key** | The hash of method + path + (optional) headers/query that determines a cache hit | Two requests with the same key share one cached response. Get this wrong and you serve user A's data to user B. |

The new shape:

```
Client  ─▶  rate-limiting  ─▶  proxy-cache  ─▶  Service  ─▶  Upstream
              │                  │
              │ counts requests   │ checks cache key
              │ per identifier    │ HIT → return, no upstream call
              ▼                   │ MISS → forward, then cache the response
            429 if over           ▼
                                Upstream only sees MISS traffic
```

**Plugin order matters.** Kong runs `rate-limiting` *before* `proxy-cache` so that even cached responses count against the limit. Otherwise a hot URL could let abusers bypass throttling.

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 04-A | [Rate Limiting](./labs/04-rate-limiting) | ~35 min | Per-Consumer limits, observe `X-RateLimit-*` headers, watch a 429, switch identifier from IP → consumer |
| 04-B | [Proxy Cache](./labs/04-proxy-cache) | ~25 min | Cache GETs, see latency drop, observe `X-Cache-Status`, manual invalidation, what NOT to cache |

## Exit ticket

1. With `identifier: consumer`, two anonymous users share one rate-limit bucket. With `identifier: ip`, they each get their own. Which is more "fair" and when?
2. What's in a cache key by default, and what additional fields would you add for an API that returns different responses per Consumer?
3. Why does Kong run `rate-limiting` *before* `proxy-cache` in the plugin chain?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| Rate-limit headers don't appear in responses | The plugin isn't attached at the scope you think - check Konnect → Plugins → filter by Service/Route. |
| Limits seem off across multiple Kong nodes | You're using `strategy: local` - limits are per-node. Switch to `cluster` (DB) or `redis` (Konnect Enterprise). |
| `proxy-cache` serves stale data to authenticated users | Cache key doesn't include the auth header / Consumer ID. Add `cache_by_headers` or set `cache_ttl` low. |
| Cache HITs but latency is still 200ms | You're measuring TCP+TLS setup, not just the response. Use HTTP/2 keep-alive or repeat the loop several times. |
| Suddenly every request is a MISS | Upstream is sending `Cache-Control: no-store` - `proxy-cache` respects upstream cache directives by default. |

## What's next

**[Module 05 - Transformations](/module-05-transformations/)** rewrites requests and responses in flight - inject headers, rename query params, strip sensitive fields. After that comes M06 (Observability) and M07 (Enterprise & Advanced - JWT, HMAC, ACL groups, OIDC, OPA, Datakit, RBAC).

---

*Previous: [Module 03 - Easy Wins](/module-03-authentication/) · Next: [Module 05 - Transformations →](/module-05-transformations/)*

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
