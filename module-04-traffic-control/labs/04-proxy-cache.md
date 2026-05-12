# Lab 04-F - Proxy Cache

> **Goal:** Cache upstream responses inside Kong to reduce upstream load and improve latency. Covers both `proxy-cache` (free tier, memory) and `proxy-cache-advanced` (Enterprise, Redis).

## How Proxy Cache Works

```
GET /api/flights →
  Cache miss: Kong fetches from upstream, stores response
    X-Cache-Status: Miss

GET /api/flights (again) →
  Cache hit: Kong returns stored response, upstream NOT called
    X-Cache-Status: Hit
```

## Part A - proxy-cache (Free Tier)

### Step 1 - Enable proxy-cache on a route

::: code-group

```yaml [decK YAML]
routes:
  - name: flights-list
    plugins:
      - name: proxy-cache
        config:
          strategy: memory
          response_code:
            - 200
            - 301
          request_method:
            - GET
            - HEAD
          content_type:
            - application/json
            - text/plain
          cache_ttl: 300
          cache_control: false
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "proxy-cache",
    "config": {
      "strategy": "memory",
      "response_code": [200, 301],
      "request_method": ["GET", "HEAD"],
      "content_type": ["application/json"],
      "cache_ttl": 300
    }
  }' | jq '{id, name}'
```

:::

### Step 2 - Observe cache behaviour

```bash
# First request - cache miss, upstream called
curl -si http://localhost:8000/api/flights | grep -i "x-cache"
# X-Cache-Status: Miss

# Second request - cache hit, upstream NOT called
curl -si http://localhost:8000/api/flights | grep -i "x-cache"
# X-Cache-Status: Hit

# Check Age header (how long entry has been cached)
curl -si http://localhost:8000/api/flights | grep -i "age"
# Age: 12
```

### Step 3 - POST requests bypass cache

```bash
curl -si -X POST http://localhost:8000/api/bookings \
  -H "Content-Type: application/json" \
  -d '{"flight": "KA101"}' | grep -i "x-cache"
# X-Cache-Status: Bypass  (POST is never cached)
```

---

## Part B - proxy-cache-advanced (Enterprise / Konnect)

### Step 4 - Enable with Redis backend

```yaml
routes:
  - name: flights-list
    plugins:
      - name: proxy-cache-advanced
        config:
          strategy: redis
          redis:
            host: redis
            port: 6379
            timeout: 2000
          response_code:
            - 200
            - 301
          request_method:
            - GET
            - HEAD
          content_type:
            - application/json
          cache_ttl: 300
          cache_control: false
          ignore_uri_case: false
```

### Step 5 - Scope cache per consumer with vary_headers

```yaml
config:
  strategy: memory
  cache_ttl: 60
  vary_headers:
    - Authorization      # different cache per bearer token (per consumer)
    - X-API-Version      # different cache per API version header
```

### Step 6 - Purge cache entries

```bash
# Purge all cached entries for a plugin instance
curl -s -X DELETE http://localhost:8001/proxy-cache-advanced/caches \
  -H "Content-Type: application/json"

# Purge specific cache key
curl -s -X DELETE "http://localhost:8001/proxy-cache-advanced/{cache-key}"
```

## Cache Status Headers

| `X-Cache-Status` | Meaning |
|---|---|
| `Miss` | Not cached; upstream called; response now stored |
| `Hit` | Served from cache; upstream **not** called |
| `Bypass` | Request not cacheable (POST, or `Cache-Control: no-cache`) |
| `Refresh` | Cache entry expired; upstream called again |

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `strategy` | `memory` | `memory` (proxy-cache / advanced) or `redis` (advanced only) |
| `cache_ttl` | `300` | Cache entry lifetime in seconds |
| `response_code` | `[200,301,404]` | HTTP status codes to cache |
| `request_method` | `[GET,HEAD]` | HTTP methods to cache |
| `content_type` | `[text/plain, application/json]` | Content-Types to cache |
| `cache_control` | `false` | Honour `Cache-Control: no-cache` / `no-store` headers |
| `ignore_uri_case` | `false` | Treat `/Flights` and `/flights` as the same cache key |
| `vary_headers` | `[]` | Additional headers that form part of the cache key |

---

*Previous: [Lab 04-E - IP Restriction](./04-ip-restriction) · Next: [Module 05 - Transformations →](/module-05-transformations/)*
