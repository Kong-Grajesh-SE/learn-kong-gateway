# Lab 04-B - Circuit Breaker & Health Checks

> **Goal:** Configure passive and active health checks on an Upstream. Watch Kong automatically remove unhealthy targets and re-add them when they recover.

## Step 1 - Configure active health checks

Active health checks poll backends proactively at a configured interval:

```yaml
_format_version: '3.0'

upstreams:
  - name: mytravel-upstream
    algorithm: round-robin

    healthchecks:
      active:
        type: http
        http_path: /health
        timeout: 1
        concurrency: 10

        healthy:
          interval: 5          # poll every 5s
          successes: 2         # 2 successes = healthy
          http_statuses: [200]

        unhealthy:
          interval: 5          # poll every 5s
          http_failures: 3     # 3 failures = unhealthy
          http_statuses: [429, 500, 503]
          tcp_failures: 2
          timeouts: 3

      passive:
        type: http

        healthy:
          successes: 5
          http_statuses: [200, 201, 202, 204]

        unhealthy:
          http_failures: 5     # 5 consecutive failures → circuit open
          http_statuses: [429, 500, 503]
          tcp_failures: 3
          timeouts: 5

    targets:
      - target: host.docker.internal:3001
        weight: 100
      - target: host.docker.internal:3002
        weight: 100
```

```bash
deck gateway sync --kong-addr http://localhost:8001 upstream-health.yaml
```

## Step 2 - Watch health status

```bash
# Continuously watch health
watch -n 2 'curl -s http://localhost:8001/upstreams/mytravel-upstream/health \
  | jq ".data[] | {target: .target, health: .health}"'
```

## Step 3 - Simulate a backend failure

Stop the second backend:

```bash
# Stop backend-2
kill $(lsof -ti:3002)

# Watch Kong detect the failure within ~5 seconds
# You'll see backend-2 flip to "UNHEALTHY"
```

## Step 4 - Observe traffic shift

```bash
# All requests should now go to backend-1 only
for i in {1..10}; do
  curl -si http://localhost:8000/api/flights | grep -i "x-served-by"
done
```

## Step 5 - Manual circuit control

You can manually toggle target health for maintenance:

```bash
# Mark target as unhealthy (e.g., for maintenance)
curl -s -X POST \
  "http://localhost:8001/upstreams/mytravel-upstream/targets/host.docker.internal:3001/unhealthy" \
  | jq '{message}'

# Mark target as healthy (e.g., after maintenance)
curl -s -X POST \
  "http://localhost:8001/upstreams/mytravel-upstream/targets/host.docker.internal:3001/healthy" \
  | jq '{message}'
```

## Step 6 - Simulate recovery

```bash
# Restart backend-2
PORT=3002 node server/index.js &

# Kong's active health check will detect recovery
# and flip backend-2 back to "HEALTHY" after 2 successes
```

## Health Check States

| State | Meaning |
|---|---|
| `HEALTHY` | Target is receiving traffic normally |
| `UNHEALTHY` | Circuit open - Kong stops sending traffic |
| `HEALTHCHECKS_OFF` | Health checks disabled for this target |
| `DNS_ERROR` | Cannot resolve target hostname |

## Passive vs Active Health Checks

| | Passive | Active |
|---|---|---|
| **How it works** | Observes live traffic | Sends probe requests |
| **Latency** | Low (no extra requests) | Higher (probe requests) |
| **Detects** | Failures in live traffic | Failures AND recovery |
| **Recovery** | Manual reset required | Automatic |
| **Best For** | Quick failure detection | Full circuit breaker |

::: tip
Use **both** passive (for fast failure detection) and active (for automatic recovery) in production.
:::

## Challenge

Implement a **weighted failover** pattern: backend-1 has weight 90 (primary), backend-2 has weight 10 (standby). When backend-1 goes down, all traffic shifts to backend-2. Restore backend-1 and verify Kong redistributes.

---

*Next: [Lab 04-C - ACL Groups →](./04-acl)*
