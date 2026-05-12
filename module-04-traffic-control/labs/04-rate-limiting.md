# Lab 04-A - Rate Limiting

> **Goal:** Apply rate limiting at global, service, and consumer levels. Compare strategies and observe rate limit headers.

## Step 1 - Global rate limit (all services)

Apply a baseline rate limit to every API passing through Kong:

```bash
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "second": null,
      "minute": 100,
      "hour": 1000,
      "day": null,
      "policy": "local",
      "fault_tolerant": true,
      "hide_client_headers": false,
      "error_code": 429,
      "error_message": "API rate limit exceeded. Please slow down."
    }
  }' | jq '{id, name}'
```

## Step 2 - Service-level rate limit

Override the global limit for the flights service - it's compute-heavy:

```bash
curl -s -X POST http://localhost:8001/services/mytravel-com-api/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 30,
      "policy": "local"
    }
  }' | jq '{id, name}'
```

## Step 3 - Observe rate limit headers

```bash
curl -si -H "X-API-Key: web-app-key-abc123" \
  http://localhost:8000/api/flights | grep "X-RateLimit"
```

Expected headers:
```
X-RateLimit-Limit-Minute: 30
X-RateLimit-Remaining-Minute: 29
```

## Step 4 - Trigger the rate limit

```bash
# Blast 35 requests quickly
for i in {1..35}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-API-Key: web-app-key-abc123" \
    http://localhost:8000/api/flights)
  echo "Request $i: $STATUS"
done
```

You should see `200` for the first 30, then `429` for the rest.

## Step 5 - Consumer-level rate limiting

Give premium consumers a higher limit using `rate-limiting-advanced`:

::: code-group

```bash [Admin API]
# First, add rate-limiting-advanced plugin globally
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting-advanced",
    "config": {
      "limit": [100],
      "window_size": [60],
      "window_type": "sliding",
      "identifier": "consumer",
      "strategy": "local",
      "sync_rate": -1,
      "namespace": "travel-api",
      "consumer_groups": [
        {
          "consumer_group": "premium-tier",
          "config": {
            "limit": [1000],
            "window_size": [60]
          }
        }
      ]
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
plugins:
  - name: rate-limiting-advanced
    config:
      limit: [100]
      window_size: [60]
      window_type: sliding
      identifier: consumer
      strategy: local
      namespace: travel-api
      consumer_groups:
        - consumer_group: premium-tier
          config:
            limit: [1000]
            window_size: [60]
```

:::

## Step 6 - Redis-backed rate limiting (production-ready)

For multi-node Kong deployments, use Redis for shared counters:

```bash
# Start Redis
docker run -d --name redis --network kong-net -p 6379:6379 redis:7-alpine

# Apply rate limiting with Redis strategy
curl -s -X POST http://localhost:8001/services/mytravel-com-api/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 50,
      "policy": "redis",
      "redis": {
        "host": "redis",
        "port": 6379,
        "timeout": 2000,
        "database": 0
      },
      "fault_tolerant": true
    }
  }' | jq '{id, name}'
```

## Step 7 - Request Size Limiting

Block large payloads on the bookings endpoint to prevent abuse:

```bash
curl -s -X POST http://localhost:8001/routes/bookings-create/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-size-limiting",
    "config": {
      "allowed_payload_size": 1,
      "size_unit": "megabytes",
      "require_content_length": false
    }
  }' | jq '{id, name}'

# Test with a large body (>1MB)
dd if=/dev/urandom bs=1024 count=1100 2>/dev/null | base64 > /tmp/bigpayload.txt
curl -si -X POST http://localhost:8000/api/bookings \
  -H "Content-Type: application/json" \
  -d "{\"data\": \"$(cat /tmp/bigpayload.txt)\"}" | head -5
# Expected: 413 Request Entity Too Large
```

## Rate Limiting Configuration Reference

| Config | Type | Description |
|---|---|---|
| `second` | integer | Max requests per second |
| `minute` | integer | Max requests per minute |
| `hour` | integer | Max requests per hour |
| `day` | integer | Max requests per day |
| `policy` | string | `local` \| `cluster` \| `redis` |
| `limit_by` | string | `ip` \| `consumer` \| `credential` \| `header` |
| `fault_tolerant` | boolean | Allow requests if rate limit store is down |
| `hide_client_headers` | boolean | Don't expose rate limit headers to clients |

---

*Next: [Lab 04-B - Circuit Breaker →](./04-circuit-breaker)*
