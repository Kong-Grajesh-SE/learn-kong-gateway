# Module 08 - Capstone

> **The scenario.** It's launch week. Your travel platform - `mytravel.com` - is going public on Monday. You're the platform engineer. The gateway has to be ready. You've spent seven modules learning every plugin you'll need. **Today you design and build the production gateway end-to-end.** No more hand-holding.
>
> This is the only module where you make **architectural decisions** before you start typing. Read the brief, pick your plugins, sketch your config, then execute.

## What you'll have at the end

A single Konnect gateway in front of one mock backend, fronted by **at least 11 plugins** working in concert:

| Layer | Plugins | Why |
|---|---|---|
| Identity | `key-auth`, `jwt` | Two auth methods - partners use JWT, internal apps use keys |
| Authorization | `acl` | Tier-based access by Consumer Group |
| Throughput | `rate-limiting` | Per-tier limits with `Retry-After` |
| Edge | `cors`, `ip-restriction` | Browser allow-list + IP allow-list for internal endpoints |
| Performance | `proxy-cache` | Cache popular GETs |
| Shape | `request-transformer-advanced`, `response-transformer-advanced` | v2→v3 migration, strip internal fields |
| Tracing | `correlation-id` | One ID, end-to-end |
| Observability | `prometheus`, `opentelemetry`, `http-log` | Metrics + traces + logs |

By the end you'll be able to pass a 15-step **acceptance test script** - each step proves a different plugin is doing its job correctly.

## Who this module is for

You completed M01–M07 (or know the equivalent material cold). You have:
- A Konnect Control Plane + Personal Access Token.
- Familiarity with decK *and* the Konnect Admin API.
- Comfort reading the Konnect dashboard.

::: tip This is the **first** module where you'll have to make a wrong call
The earlier modules guide you to the right answer at each step. The capstone deliberately presents trade-offs without telling you which choice is "right". The 15-step acceptance script tells you whether you got it right - not the prose. Resist the urge to peek ahead.
:::

## The platform contract - read carefully

Your travel API has **three Consumer tiers**:

| Tier | Auth method | Rate limit | Allowed routes |
|---|---|---|---|
| **free** | `key-auth` API key | 10 req/min | `/v3/flights/*` GET only |
| **partner** | `jwt` (signed by partner IdP, HS256) | 100 req/min | `/v3/flights/*`, `/v3/bookings/*` |
| **internal** | `key-auth` API key, IP-restricted to office CIDR | 1000 req/min | All routes including `/v3/admin/*` |

**Cross-cutting requirements:**

- **Path migration.** The backend serves `/v2/...`. Clients call `/v3/...`. Kong must rewrite paths during the migration window.
- **Body migration.** Clients send `{"flightId":...}`; backend expects `{"id":...}`. Rewrite request body field names.
- **Response shaping.** The backend returns `_debug` and `internal_id` fields on every response. Clients must never see them.
- **Browser support.** Web app at `https://app.mytravel.com` must work from a browser.
- **One-ID tracing.** Every request, regardless of tier, gets a single correlation ID propagated to logs, metrics, and traces.
- **No upstream stampedes.** Popular routes (`GET /v3/flights/popular`) must be cacheable for 60s.

## Three concepts you need today

| Concept | What it is | Why it matters today |
|---|---|---|
| **Plugin chain order** | Kong runs plugins in fixed phase order (cert → auth → rewrites → access → balancer → response). Multiple plugins in the same phase run by priority (higher first). | If `cors` runs *after* `key-auth`, browser preflight gets 401. Order matters - get this wrong and you'll be debugging for an hour. |
| **Scope precedence** | More specific scope wins: Consumer-Route > Route > Service > Global. | You want one rate limit per-tier; you'll attach 3 plugins scoped to `consumer_group`, *not* one global plugin. |
| **State carry-over** | Plugins set headers (`X-Consumer-*`, `traceparent`, `X-RateLimit-*`). Later plugins and the upstream **read** them. | `request-transformer-advanced` reads `$(consumer.custom_id)` - that variable only resolves after `key-auth` or `jwt` ran. Order = read order. |

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 08 | [Capstone: Production Gateway](./labs/08-capstone) | ~2.5–3 hours | Design, build, and prove out the full production gateway end-to-end. 15-step acceptance test at the end. |

There's only one lab - but it's the longest in the bootcamp. Block out a real session for it.

## How to know you're done

Run the 15-step acceptance script at the end of the lab. **Every step must pass.** If a step fails, it tells you which plugin (or which scope) is wrong. Iterate until 15/15.

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| `cors` preflight returns 401 | `cors` plugin priority is *lower* than `key-auth` - flip the order, or attach `cors` globally so it runs *before* per-route auth |
| Partner JWT validates but `X-Consumer-Username` is wrong | The `key_claim_name` in the JWT plugin doesn't match the `key` in the Consumer's `jwt_secrets` - same JWT, different mapping |
| Rate limits "fight" across tiers | You attached one plugin route-scoped *and* per-Consumer-Group - the route-scoped one wins for everyone. Remove it. |
| `proxy-cache` HIT counts against the rate limit | Working as designed - `rate-limiting` runs *before* `proxy-cache`. Cached requests still count. (Usually what you want - abusers shouldn't get free traffic from your cache.) |
| `$(consumer.custom_id)` in a transformer resolves to empty | The transformer is set up before `key-auth` ran. Re-check phase order. |
| Internal route is reachable from a non-office IP | `ip-restriction` was scoped to the wrong Route. Check the `route:` field on the plugin. |
| Observability plugins are scoped per-route - only one route emits metrics | Promote `prometheus`, `correlation-id`, `opentelemetry` to **global** scope. |

## What's next

This is the final module of the core bootcamp. From here:

- Run the verification script (coming soon).
- Tackle a **specialist bootcamp** - AI Gateway, Agentic AI & MCP, Developer Portal, APIOps.
- Take what you've built into your real team's environment.

::: tip If you got 15/15
You're now competent enough to **design** a Kong deployment, not just follow one. The next time someone asks "how would you put Kong in front of X?" - you have a defensible answer.
:::

---

*Previous: [Module 07 - Enterprise & Advanced](/module-07-enterprise/) · Home: [Bootcamp index](/)*
