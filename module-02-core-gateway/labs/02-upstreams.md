# Lab 02-B - Upstreams & Health Checks

> **Goal.** In ~50 minutes you'll move `flights-svc` from a single backend to a pool of **two targets** with **weighted load balancing**, then add **active and passive health checks** that auto-remove sick targets - and put them back when they recover.

Picking up from Lab 02-A. Same Konnect CP, same env vars. The three Services (`flights-svc`, `hotels-svc`, `cars-svc`) and their routes are still in place.

---

## Step 1 - Why Upstreams? (2 min - read, don't run)

Right now `flights-svc` has a single backend baked in:

```yaml
services:
  - name: flights-svc
    url: https://httpbin.konghq.com   # ← one fixed backend
```

If `httpbin.konghq.com` goes down, every `/flights/*` request fails. There's no way to add a second backend, weight them, or run health checks.

The fix is to put an **Upstream** between the Service and the backends:

```
Service  ── host:  flights-pool ──▶ Upstream "flights-pool"
                                       ├── Target: httpbin.konghq.com:443  weight 100
                                       └── Target: httpbin.org:443         weight  50
```

The Service's `host` field points at the Upstream **name** instead of a real hostname. Kong sees `flights-pool` isn't a DNS name - it's an Upstream - and picks a target from the pool for every request.

---

## Step 2 - Create the Upstream and its Targets (8 min)

::: code-group

```yaml [Replace kong.yaml]
_format_version: '3.0'

upstreams:
  - name: flights-pool
    algorithm: round-robin
    slots: 10000
    tags: [module-02]
    targets:
      - target: httpbin.konghq.com:443
        weight: 100
      - target: httpbin.org:443
        weight: 50

services:
  - name: flights-svc
    host: flights-pool       # ← was url:, now host: pointing at the Upstream
    port: 443
    protocol: https
    tags: [module-02]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
      - name: flights-premium-route
        paths: [/flights/premium]
        methods: [POST]
        strip_path: true

  # hotels-svc and cars-svc unchanged
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

::: warning Two ways to break this - both common
- **`url: https://flights-pool`** - wrong. Kong tries to DNS-resolve `flights-pool` and fails. Use `host: flights-pool` + `port: 443` + `protocol: https` instead.
- Forgetting `protocol: https` - Kong defaults to `http` and gets a TLS error from httpbin.
:::

**✅ Checkpoint.** Konnect → **Upstreams** → `flights-pool` listed with **2 targets**, both **healthy**. Konnect → **Services** → `flights-svc` now shows `host=flights-pool`.

---

## Step 3 - Watch round-robin in action (6 min)

Wait ~15s for propagation, then hammer the route 6 times:

```bash
for i in {1..6}; do
  curl -s $KONNECT_PROXY_URL/flights/get | jq -r '.headers.Host'
done
```

Both targets return `.headers.Host` matching their own hostname. So the output should be **a mix of two distinct Host values** - not all the same.

Expected (the exact pattern depends on the weights, but you'll see both):
```
httpbin.konghq.com
httpbin.konghq.com
httpbin.org
httpbin.konghq.com
httpbin.konghq.com
httpbin.org
```

**The split should roughly match the weights.** You set `100 : 50` → expect about a **2 : 1 split** in favor of `httpbin.konghq.com`. Run the loop with more iterations if you want to see the distribution clearly:

```bash
for i in {1..30}; do
  curl -s $KONNECT_PROXY_URL/flights/get | jq -r '.headers.Host'
done | sort | uniq -c
```

::: tip Why request-by-request, not session-by-session?
`round-robin` picks per-request. Use `consistent-hashing` (later) when you want the same client to stick to the same target - useful for session affinity.
:::

**✅ Checkpoint.** You see roughly 2:1 split between the two targets across 30 requests.

---

## Step 4 - Add an Active health check (10 min)

Active = Kong proactively pings each target on a schedule. Healthy targets get traffic; sick ones get parked.

```yaml [Update flights-pool]
upstreams:
  - name: flights-pool
    algorithm: round-robin
    slots: 10000
    targets:
      - target: httpbin.konghq.com:443
        weight: 100
      - target: httpbin.org:443
        weight: 50
    healthchecks:
      active:
        type: https
        https_verify_certificate: true
        http_path: /status/200       # any 2xx response = healthy
        timeout: 3
        concurrency: 2
        healthy:
          interval: 10               # poll every 10s
          successes: 2               # 2 successes in a row → healthy
          http_statuses: [200, 201, 202, 204]
        unhealthy:
          interval: 5                # poll every 5s when suspected sick
          http_failures: 3           # 3 failures in a row → unhealthy
          tcp_failures: 3
          timeouts: 3
          http_statuses: [429, 500, 502, 503, 504]
```

Sync and wait 15s. Konnect → **Upstreams** → `flights-pool` should show both targets **healthy** with a green dot.

::: tip What you just configured, in English
Every 10 seconds, Kong sends a GET `/status/200` to each target. Two 2xx responses in a row keeps it healthy. Three failures in a row marks it unhealthy and drops it from rotation. The interval shrinks to 5s while a target is suspected sick - Kong recovers faster.
:::

---

## Step 5 - Force a target to fail (8 min) 🧪

We can't actually kill `httpbin.org` (it's run by someone else). But we can change the health check path to one that returns 5xx:

```yaml [Temporary: make ALL targets fail]
healthchecks:
  active:
    type: https
    http_path: /status/503   # ← every target will fail this
    ...
```

Sync, wait 15-30s. Then check status:

```bash
curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/upstreams/flights-pool/health" \
  | jq '.data[] | {target, health: .data.weight.unavailable}'
```

You should see both targets reporting unhealthy. Hit the gateway:

```bash
curl -s -i $KONNECT_PROXY_URL/flights/get | head -3
# HTTP/2 503
# {"message":"failure to get a peer from the ring-balancer"}
```

That `503` with `failure to get a peer from the ring-balancer` is Kong telling you it has **no healthy targets to forward to**. The Service is up, the Route matched - but the Upstream pool is empty.

Revert the health check to `/status/200` and sync - within 20s the targets recover and traffic flows again.

**✅ Checkpoint.** You forced an outage, watched Kong cut traffic, then watched recovery happen automatically.

---

## Step 6 - Passive health check (circuit breaker pattern) (8 min)

Active health checks poll on a schedule. **Passive** health checks watch live traffic - Kong observes real request failures and trips a circuit when too many pile up. Lower overhead, faster reaction.

Add a passive section alongside the active one:

```yaml [Add passive to flights-pool healthchecks]
healthchecks:
  active:
    # ... (keep what you have)
  passive:
    type: https
    healthy:
      successes: 5
      http_statuses: [200, 201, 202, 204, 301, 302]
    unhealthy:
      http_failures: 3
      tcp_failures: 3
      timeouts: 3
      http_statuses: [429, 500, 502, 503, 504]
```

Sync. Now make `/flights/status/503` fail repeatedly:

```bash
for i in {1..10}; do
  curl -s -o /dev/null -w '%{http_code} ' $KONNECT_PROXY_URL/flights/status/503
done
echo
```

You'll see `503 503 503 …`. After about 3 consecutive failures **on the same target**, Kong takes that target out of rotation. Subsequent requests should hit only the other target.

::: info Active vs passive - when to use which
- **Active** = "Are you alive?" Useful when you have rarely-hit endpoints. Costs bandwidth.
- **Passive** = "You just broke 3 times - you're out." Free, fast, but only triggers when traffic flows.

Use **both** in production. Active catches stale backends with no traffic. Passive catches problems that real users would feel first.
:::

**✅ Checkpoint.** You can describe what each health check type observes and when each fires.

---

## Step 7 - Try a different algorithm (5 min)

`round-robin` is the default. Try `least-connections` (best for variable-duration requests) or `consistent-hashing` (sticky sessions).

```yaml [Switch algorithm]
upstreams:
  - name: flights-pool
    algorithm: least-connections    # or: consistent-hashing
    # ...
```

For `consistent-hashing`, you also need a hash key - typically the client IP or a header:

```yaml
upstreams:
  - name: flights-pool
    algorithm: consistent-hashing
    hash_on: ip
    # hash_on: header
    # hash_on_header: x-user-id
```

Sync and re-run the 6-request loop from Step 3. With `consistent-hashing` + `hash_on: ip`, you should now see **all 6 requests land on the same target** (because they all come from your IP).

::: tip When each algorithm shines
- `round-robin` - equal-weight targets, short uniform requests (most APIs).
- `least-connections` - long-running requests, uneven request duration (file uploads, reports).
- `consistent-hashing` - session affinity (caching, in-memory state on the target, multi-region sticky).
- `latency` - Kong actively measures and prefers the fastest target.
:::

Revert to `round-robin` for cleanup consistency.

---

## Recap

You moved `flights-svc` from a single backend to a real production-shaped topology:

```
                                                        weight  status
flights-route ──▶ flights-svc ──▶ flights-pool ──┬──▶ httpbin.konghq.com:443   100   healthy
                                                 └──▶ httpbin.org:443           50   healthy
                                                              ▲
                                                              │ active probe every 10s
                                                              │ passive: 3 fails → out
```

Now you understand:
- **When to use an Upstream** (any time you have or might have >1 backend).
- **Health-check anatomy** (active vs passive, healthy vs unhealthy thresholds).
- **Algorithm choice** (round-robin, least-connections, consistent-hashing, latency).

---

## Exit ticket - answers

1. **Which route wins for `/api/flights/123`?** The one with `paths: ["/api/flights"]` - longer prefix wins over `/api`. (Covered in Lab 02-A.)
2. **Service `host` vs Upstream?** Service `host` can be a DNS name (one backend) OR the name of an Upstream (pool of targets). When it's an Upstream, Kong picks a target per request using your algorithm + weights + health.
3. **What made Kong mark Target A unhealthy?** Either the active health check got 3 consecutive failures from `/status/200`, OR live traffic hit 3 consecutive failures (`http_failures: 3` in the passive config).

---

## Cleanup - full M02 wipe

Module 03 starts fresh.

::: code-group

```bash [decK - wipe everything tagged module-02]
echo '_format_version: "3.0"' | deck gateway sync - \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

```bash [Admin API - delete by name]
for ENT in routes/flights-route routes/flights-premium-route routes/hotels-route routes/cars-route \
           services/flights-svc services/hotels-svc services/cars-svc \
           upstreams/flights-pool; do
  curl -s -X DELETE -H "Authorization: Bearer $KONNECT_TOKEN" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/$ENT" \
    && echo "deleted $ENT"
done
```

:::

::: tip Auto-verify with the bootcamp script
The Module 02 verification script (coming next) exercises every step here automatically and cleans up at the end.
:::

---

**Next:** [Module 03 - Easy Wins →](/module-03-authentication/) - your first four plugins: `key-auth`, `cors`, `ip-restriction`, `correlation-id`. Each takes one config block. Big payoff for low effort.
