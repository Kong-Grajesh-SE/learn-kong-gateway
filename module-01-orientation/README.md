# Module 01 — Your First Gateway

> **The scenario.** You're a developer at a travel startup. Your team built an API. It works — but:
> - You have no idea who's calling it.
> - There's no way to throttle abusive clients.
> - When the backend hiccups, callers get raw 502s.
>
> In the next ~60 minutes you'll put one piece in front of your API — **Kong Gateway** — and route your first real request through it. No prior Kong knowledge needed.

## What you'll have at the end

A serverless gateway on Konnect, sitting in front of `httpbin.konghq.com`. You'll send a request to your gateway URL and get back a response from httpbin, plus Kong's own forwarding headers:

```bash
$ curl https://<your-gateway>.kongcloud.dev/demo/get | jq
{
  "url": "https://<your-gateway>.kongcloud.dev/get",
  "headers": {
    "Host": "httpbin.konghq.com",
    "X-Kong-Request-Id": "...",
    "X-Forwarded-Prefix": "/demo"
  }
}
```

One gateway, one Service, one Route, one real proxied request. Every later module builds on this.

## Who this module is for

- **You know:** what HTTP is, what a REST API is, how to use `curl` from a terminal.
- **You don't need to know:** anything about Kong, decK, Konnect, or API gateways yet.

## What you'll need

| Tool | Why | Check |
|---|---|---|
| Konnect account (free) | Hosts the gateway control plane | [Sign up at cloud.konghq.com](https://cloud.konghq.com) |
| `curl` | Send requests to your gateway | `curl --version` |
| `jq` | Pretty-print JSON | `jq --version` · macOS: `brew install jq` |
| `decK` (optional) | Manage config as YAML files | `deck version` · macOS: `brew install kong/tap/deck` |

No Docker. No certs. No local services. (If you'd rather run the gateway on your laptop in Docker — see the optional [hybrid Docker setup](./labs/01-hybrid-docker-setup) at the end.)

## Three concepts you need today

| Concept | What it is | Today's value |
|---|---|---|
| **Gateway** | The proxy that sits between clients and your APIs | We'll create one on Konnect |
| **Service** | A named upstream API Kong forwards to | `httpbin-service` → `https://httpbin.konghq.com` |
| **Route** | A URL pattern that matches client requests and sends them to a Service | `/demo` → `httpbin-service` |

The request flow you're building:

```
Client → Kong Gateway (/demo/get) → httpbin.konghq.com (/get)
                                  ← response with X-Kong-* headers
```

Everything else Kong does — authentication, rate limiting, transformations, logging — is a **plugin** you attach to a Service, Route, or Consumer. We'll cover plugins from Module 03 onwards. **No plugins today.**

## Lab

| # | Lab | Time | What you'll do |
|---|---|---|---|
| 01 | [Quick Start (serverless)](./labs/01-quick-start) | 45 min | Create a serverless gateway, a Service, a Route, send your first proxied request |
| 01-alt | [Hybrid Docker setup](./labs/01-hybrid-docker-setup) | +30 min | *Optional.* Run a local Docker Data Plane connected to Konnect. Pick this if you want to see all the moving parts. |

Start with **01 (Quick Start)**. Come back to the hybrid setup later if you're curious.

## Exit ticket

After the lab, can you answer these without looking? (Answers at the bottom of the lab.)

1. What's the difference between a **Service** and a **Route**?
2. What does `strip_path: true` do, and what would change if it were `false`?
3. Why is `X-Kong-Request-Id` worth caring about?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| `no Route matched with those values` after creating a Route | Route hasn't propagated yet — serverless Data Planes poll every ~10s. Wait 30s and retry. |
| Konnect API returns `403 Forbidden` | Your PAT is for a different region than your Control Plane (e.g. EU token, US endpoint). |
| `decK can't find the control plane` | You used the **UUID** instead of the **name**, or vice versa. `decK` uses the name. |
| Service appears with `port=80` even though you said `https://...` | You set `host: httpbin.konghq.com` instead of `url: https://httpbin.konghq.com`. The `url` field is parsed; the `host` field isn't. |

## What's next

In **[Module 02 — Routing & Topology](/module-02-core-gateway/)** you'll go beyond a single Service: handle multiple endpoints, understand how Kong picks a Route when several could match, and load-balance across multiple backends with **Upstreams**.

---

*Up next: [Module 02 — Routing & Topology →](/module-02-core-gateway/)*
