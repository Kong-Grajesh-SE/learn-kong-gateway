# Lab 02-B - Upstreams & Load Balancing

> **Goal:** Configure a Kong Upstream with multiple targets, health checks, and load balancing algorithms. Observe traffic distribution and failover behaviour.

## What is an Upstream?

In Kong, an **Upstream** is a named virtual hostname that points to one or more **Targets** (backend servers). When a Service uses an Upstream as its host, Kong automatically load balances across all healthy targets.

```
Client request
    ↓
Kong Route (/api/flights)
    ↓
Kong Service (host: kong-air-upstream)
    ↓
Upstream: kong-air-upstream
    ├── Target: httpbin.konghq.com:443  (weight: 100)
    └── Target: httpbin.org:443         (weight: 50)
```

---

## Architecture for this Lab

We'll use two well-known httpbin instances as our "backend fleet":

| Target | URL | Weight |
|---|---|---|
| Primary | `httpbin.konghq.com:443` | 100 |
| Secondary | `httpbin.org:443` | 50 |

::: info Why httpbin for upstreams?
Both instances serve identical API responses. This lets us verify load balancing without running local backend servers. In production, these would be your actual service instances.
:::

---

## Step 1 - Create the Upstream with Targets

::: code-group

```yaml [kong-air-upstream.yaml]
_format_version: '3.0'

upstreams:
  - name: kong-air-upstream
    algorithm: round-robin
    slots: 10000
    hash_on: none

    # Active health checks - Kong probes targets periodically
    healthchecks:
      active:
        concurrency: 5
        healthy:
          http_statuses: [200, 301, 302]
          interval: 10           # probe every 10s
          successes: 2           # 2 successes = healthy
        http_path: /status/200   # httpbin returns 200 for this path
        https_verify_certificate: false
        timeout: 3
        type: https
        unhealthy:
          http_failures: 3
          http_statuses: [429, 500, 503]
          interval: 5
          tcp_failures: 2
          timeouts: 3

      # Passive health checks - based on live traffic
      passive:
        healthy:
          http_statuses: [200, 201, 202, 204, 301, 302]
          successes: 3
        type: https
        unhealthy:
          http_failures: 5
          http_statuses: [500, 502, 503, 504]
          tcp_failures: 2
          timeouts: 5

    tags: [bootcamp, lab-02]

  # Targets belong to the upstream by name reference
  # (Use deck sync, or add via Konnect UI)
```

```bash [Sync to Konnect]
deck gateway sync kong-air-upstream.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

:::

### Add Targets via decK

Targets are added as a separate resource:

```yaml
# targets.yaml - append to or merge with your config
_format_version: '3.0'

upstreams:
  - name: kong-air-upstream
    algorithm: round-robin
    slots: 10000
    targets:
      - target: httpbin.konghq.com:443
        weight: 100
        tags: [bootcamp, primary]
      - target: httpbin.org:443
        weight: 50
        tags: [bootcamp, secondary]
```

```bash
deck gateway sync targets.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

---

## Step 2 - Create a Service using the Upstream

::: code-group

```yaml [upstream-service.yaml]
_format_version: '3.0'

services:
  - name: kong-air-lb-service
    # Use the upstream name as the host
    host: kong-air-upstream
    port: 443
    protocol: https
    path: /
    tags: [bootcamp, lab-02]

    routes:
      - name: kong-air-lb-route
        paths: [/lb-test]
        strip_path: true
        tags: [bootcamp, lab-02]
```

:::

```bash
deck gateway sync upstream-service.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp
```

---

## Step 3 - Verify Load Balancing

Send 10 requests and observe which backend responds:

::: code-group

```bash [curl - Terminal]
# Send 10 requests - observe "origin" field changing between backends
for i in $(seq 1 10); do
  echo "Request $i:"
  curl -s http://localhost:8000/lb-test/get | jq -r '.headers.Host'
done
```

```text [Insomnia - GUI]
1. New Request → GET
2. URL: http://localhost:8000/lb-test/get
3. Send multiple times (click Send 5-10 times)
4. In each response, check:
   - "headers" → "Host" - alternates between backends
   - "url" - shows which upstream served the request
5. In Insomnia Timeline tab, check response time variability
```

:::

Expected output pattern (round-robin 2:1 ratio):
```
Request 1: httpbin.konghq.com
Request 2: httpbin.konghq.com
Request 3: httpbin.org
Request 4: httpbin.konghq.com
Request 5: httpbin.konghq.com
Request 6: httpbin.org
...
```

---

## Step 4 - Load Balancing Algorithms

Kong supports four algorithms:

| Algorithm | Behaviour | Use case |
|---|---|---|
| `round-robin` | Weighted rotation | General purpose (default) |
| `least-connections` | Fewest active connections | Long-running requests |
| `consistent-hashing` | Same client → same target | Session affinity |
| `latency` | Lowest response time | Latency-sensitive APIs |

### Consistent Hashing (sticky sessions by consumer)

```yaml
upstreams:
  - name: kong-air-upstream
    algorithm: consistent-hashing
    hash_on: consumer    # same consumer → same backend
    hash_fallback: ip
```

### Consistent Hashing by IP

```yaml
upstreams:
  - name: kong-air-upstream
    algorithm: consistent-hashing
    hash_on: ip          # same client IP → same backend
    hash_fallback: none
```

### Least Connections

```yaml
upstreams:
  - name: kong-air-upstream
    algorithm: least-connections
```

---

## Step 5 - Weighted Traffic Distribution

Useful for blue/green deployments and canary releases:

```yaml
# 90% to stable, 10% to canary
upstreams:
  - name: kong-air-upstream
    algorithm: round-robin
    targets:
      - target: httpbin.konghq.com:443
        weight: 90    # stable/production
      - target: httpbin.org:443
        weight: 10    # canary/new version
```

**Canary deployment pattern:**
```
Week 1:  weight 90 / 10  - 10% canary
Week 2:  weight 70 / 30  - 30% canary
Week 3:  weight 50 / 50  - 50/50 split
Week 4:  weight 0  / 100 - full cutover, remove old
```

---

## Step 6 - Health Checks in Action

### Simulate a target failure

::: code-group

```bash [curl - Terminal]
# Manually mark a target as unhealthy
curl -s -X POST http://localhost:8001/upstreams/kong-air-upstream/targets/httpbin.org:443/unhealthy

# Watch Kong stop sending traffic there
for i in $(seq 1 5); do
  curl -s http://localhost:8000/lb-test/get | jq -r '.headers.Host'
done
# All requests should now go to httpbin.konghq.com

# Restore the target
curl -s -X POST http://localhost:8001/upstreams/kong-air-upstream/targets/httpbin.org:443/healthy
```

```text [Insomnia - GUI / Konnect UI]
Via Konnect UI:
1. Open bootcamp-cp → Upstreams → kong-air-upstream
2. Click Targets tab
3. Click the ⋮ menu on httpbin.org → Mark Unhealthy
4. Send a few requests to /lb-test/get
5. All responses come from httpbin.konghq.com
6. Restore: Mark Healthy
```

:::

::: warning Local Admin API
The `POST /upstreams/...` Admin API commands above work in **Traditional mode**.  
In **Hybrid/Konnect mode**, use the **Konnect UI** (Upstreams → Targets → Mark Unhealthy) to control health state.
:::

---

## Step 7 - Check Upstream Health Status

::: code-group

```bash [curl - Traditional mode]
# View target health from Admin API
curl -s http://localhost:8001/upstreams/kong-air-upstream/health | \
  jq '.data[] | {target: .target, health: .health}'
```

```text [Konnect UI]
bootcamp-cp → Upstreams → kong-air-upstream → Targets
Each target shows:  ● HEALTHY  or  ● UNHEALTHY
```

:::

---

## Step 8 - Add kong-air Backend as a Target (Optional)

If you have the local kong-air backend running on `:3001`:

```yaml
upstreams:
  - name: kong-air-upstream
    targets:
      - target: httpbin.konghq.com:443
        weight: 80
      - target: host.docker.internal:3001
        weight: 20
```

::: tip Mixing HTTPS and HTTP targets
When mixing HTTP and HTTPS targets, set the service `protocol` to `http` and configure HTTPS-specific targets individually, or use two separate upstreams.
:::

---

## Health Check Reference

| Parameter | Default | Description |
|---|---|---|
| `active.interval` | 0 (disabled) | Seconds between probes |
| `active.successes` | 0 | Successes needed to mark healthy |
| `active.http_path` | `/` | Path to probe |
| `active.timeout` | 1 | Probe timeout in seconds |
| `active.unhealthy.http_failures` | 0 | Failures to mark unhealthy |
| `passive.unhealthy.http_failures` | 0 | Failures from live traffic |

---

**Next:** [👤 Lab 02-C - Consumers →](./02-consumers)
