# Module 02 - Routing & Topology

> **The scenario.** Your travel startup just closed a great quarter. Two new APIs joined the platform - **hotels** and **car rentals** - and the original mytravel API now runs on **three servers** because traffic doubled.
>
> The single Service + single Route you built in Module 01 isn't enough anymore. In the next ~90 minutes you'll extend your gateway to handle **multiple Services with smart route matching**, then **load-balance across multiple backends with health checks**. Still no plugins - just the routing primitives that everything else builds on.

## What you'll have at the end

A gateway that:
- Routes **three different URL paths** (`/flights`, `/hotels`, `/cars`) to **three different upstream APIs**.
- Load-balances `flights` across **two backend targets** with weights.
- **Auto-removes** a target from rotation when its health check fails - and puts it back when it recovers.

```bash
$ curl -s $KONNECT_PROXY_URL/flights/get | jq '.headers.Host'
"httpbin.konghq.com"
$ curl -s $KONNECT_PROXY_URL/hotels/get  | jq '.headers.Host'
"httpbin.konghq.com"

$ for i in {1..6}; do
    curl -s $KONNECT_PROXY_URL/flights/get | jq -r '.headers.Host + "  origin=" + .origin'
  done
# Two distinct origins across the 6 requests - load balancing in action
```

## Who this module is for

You finished **[Module 01](/module-01-orientation/)** (or read it carefully). You can:
- Create a Service and Route on Konnect (Admin API or decK - either works).
- Send a request to your gateway and read the response.

That's it. Same prereqs as M01 - `curl`, `jq`, a Konnect PAT, the same Control Plane.

## Three concepts you need today

| Concept | What it is | Why it matters today |
|---|---|---|
| **Route matching priority** | When two routes both match, Kong picks one by rules | Long path beats short path; specific method beats `ANY`; regex priority is explicit |
| **Upstream** | A named virtual host that points to a *pool* of real targets | Lets you load-balance and fail over without touching the Service |
| **Health check** | Kong polls each target and removes the sick ones | Free auto-failover - no extra infrastructure |

The shape you're building:

```
                                                       ┌── httpbin.konghq.com:443   weight 100
Client ──▶ Kong Gateway ──▶ /flights ──▶ Upstream "flights-pool" ──┤
                       └──▶ /hotels  ──▶ Service "hotels-svc"      └── httpbin.org:443         weight  50
                       └──▶ /cars    ──▶ Service "cars-svc"
```

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 02-A | [Multi-Service Routing](./labs/02-services-routes) | ~40 min | Three Services, route by path, see what happens when paths overlap and methods conflict |
| 02-B | [Upstreams & Health Checks](./labs/02-upstreams) | ~50 min | One Upstream, two targets, weighted load balancing, active + passive health checks |

::: tip Consumers come in Module 03
The previous version of this module covered Consumers here. We moved them to **Module 03** - they're hard to motivate until you have a plugin that actually uses them (`key-auth` does, in M03).
:::

## Exit ticket

After the labs, can you answer these without looking?

1. You have two routes: one with `paths: ["/api"]` and one with `paths: ["/api/flights"]`. A request hits `/api/flights/123`. Which route wins, and why?
2. What's the difference between a Service's `host` field and an **Upstream**? When do you use which?
3. Your passive health check just marked Target A unhealthy. What sequence of events did Kong observe to make that decision?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| New route doesn't seem to match | A more specific route already matched. Check `paths`, `methods`, `hosts` priority. |
| Service can't be updated via decK to point at an Upstream | You're using both `host:` *and* an upstream of the same name - the upstream silently shadows. Pick one. |
| Targets keep flapping (up → down → up) | Active health check path is `/` but the upstream returns 404 there. Use a real health path or relax `healthy.http_statuses`. |
| "Round-robin" doesn't look round-robin | You have only one healthy target, weights are uneven, or sticky-hash is on. Check `algorithm` and `weight`. |
| `host.docker.internal` doesn't resolve from a Konnect serverless DP | Correct - serverless DPs run in Konnect's cloud and can't reach your laptop. Use public targets, or switch to the [hybrid Docker lab](/module-01-orientation/labs/01-hybrid-docker-setup). |

## What's next

**[Module 03 - Easy Wins](/module-03-authentication/)** introduces your first four plugins in difficulty order: `key-auth`, `cors`, `ip-restriction`, `correlation-id`. **Tier 1** plugins - zero external infrastructure, one config block each. Big payoff for low effort. Consumers finally get a job to do.

---

*Previous: [Module 01 - Your First Gateway](/module-01-orientation/) · Next: [Module 03 - Easy Wins →](/module-03-authentication/)*

---

> **Found an issue with this page?**  
> [Open a GitHub issue](https://github.com/Kong-Grajesh-SE/learn-kong-gateway/issues/new) - all reports are monitored and fixed promptly.
