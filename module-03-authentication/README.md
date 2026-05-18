# Module 03 - Easy Wins

> **The scenario.** Your gateway routes traffic correctly. But:
> - **Anyone** can call your API. There's no notion of "who".
> - A browser frontend at `app.mytravel.com` can't call the gateway because the browser blocks the request (CORS).
> - You spotted a scraper hitting you from one specific IP. You can't block it.
> - When a request explodes somewhere in your stack, you can't trace it end-to-end.
>
> In the next ~90 minutes you'll fix all four with **four Tier-1 plugins** - each is a single config block, zero external infrastructure. Maximum learning per minute. This is also where **Consumers** get a real job to do.

## What you'll have at the end

A gateway with four plugins enabled and tested:

| Plugin | What it does | Where it's attached |
|---|---|---|
| `key-auth` | Reject requests missing a valid API key | The `flights-route` only |
| `cors` | Allow your browser frontend to call cross-origin | All routes (global) |
| `ip-restriction` | Allow / deny by client IP | The `flights-route` only |
| `correlation-id` | Inject a unique ID per request | All routes (global) |

And two real Consumers (`web-app`, `mobile-app`) with their own API keys, so your API actually knows who's calling.

## Who this module is for

You finished M01 and M02. You can create Services, Routes, and Upstreams. Same prereqs (`curl`, `jq`, Konnect PAT, same CP).

::: tip Why these four, in this order?
| Plugin | Difficulty | Why |
|---|---|---|
| `key-auth` | ★★ | Needs a Consumer - your first real plugin requiring an associated entity |
| `cors` | ★ | One config block. Pure config, no entities. |
| `ip-restriction` | ★ | One config block. Allow / deny list. |
| `correlation-id` | ★ | One config block. Header in, header out. |

JWT, HMAC, OIDC, and OAuth2 are deferred to **Module 04** (Identity & ACL) and **Module 08** (Enterprise) - they need either external IdPs or significantly more setup. Here we want immediate wins.
:::

## Three concepts you need today

| Concept | What it is | Why it matters today |
|---|---|---|
| **Plugin** | Middleware Kong runs at fixed phases (auth, transform, etc.) on every matching request | Plugins are how you add behaviour to a gateway without changing the upstream |
| **Consumer** | A named identity for an API caller (a web app, a mobile app, a service) | `key-auth` validates the request *and* tells you *which Consumer* it belongs to |
| **Plugin scope** | A plugin can be attached globally, per-Service, per-Route, or per-Consumer | More specific scope **overrides** more general - same precedence rules as M02 routes |

The new shape:

```
                                          ┌──── plugin (correlation-id) - global
Client ─▶ Kong Gateway ─▶ Route ─▶ Service ─▶ Upstream ─▶ httpbin
              │           │
              │           └─ plugin: key-auth, ip-restriction (attached to flights-route only)
              └───────── plugin: cors (global)
```

Plugins run on **every** request that reaches them. Cheap to add, cheap to remove.

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 03-A | [Consumers & key-auth](./labs/03-key-auth) | ~45 min | Create two Consumers, attach `key-auth` to a Route, test access from each Consumer's perspective. Cover key-in-header vs query, hidden credentials, anonymous fallback. |
| 03-B | [CORS, IP restriction, correlation-id](./labs/03-easy-wins) | ~45 min | Three Tier-1 plugins back to back. One config block each, then test the failure mode each one prevents. |

## Exit ticket

After the labs, can you answer these without looking?

1. After `key-auth` succeeds, how does the **upstream** know which Consumer made the request? (Hint: not by reading the API key.)
2. You attach `cors` globally **and** a different `cors` config to one Route. Which one wins for that Route?
3. Why does enabling `correlation-id` matter even before you have a logging plugin set up?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| `401 No API key found in request` after adding `key-auth` | Working as designed - that's the test. Now generate a key for a Consumer and pass it in `X-API-Key`. |
| Browser still gets CORS errors after enabling `cors` | You probably forgot the `OPTIONS` preflight. `cors` plugin handles it, but your route must allow `OPTIONS` in its `methods` list (or leave methods unset). |
| `ip-restriction` blocked your own laptop and now you're locked out | You set `allow` instead of `deny` and forgot to include your IP. Reach the plugin via the Konnect UI and edit it there. |
| `correlation-id` header isn't appearing in logs | Default generator is `uuid#counter` - confirm the plugin is attached at the right scope. Check `Konnect → Plugins`. |
| Plugin attached to a Consumer is ignored | Consumer-scoped plugins only run *after* an auth plugin has identified the Consumer. Without `key-auth` (or similar), Kong has no Consumer to look up. |

## What's next

**Module 04 - Identity & ACL** deepens Consumers: consumer groups, ACL allow/deny, JWT, HMAC. Then **Module 05 - Traffic & Resilience** adds rate-limiting, proxy-cache, and circuit-breaker patterns. JWT/HMAC are intentionally deferred - they reuse the Consumer mental model you'll build today, just with different credential types.

---

*Previous: [Module 02 - Routing & Topology](/module-02-core-gateway/) · Next: Module 04 - Identity & ACL (coming soon)*

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
