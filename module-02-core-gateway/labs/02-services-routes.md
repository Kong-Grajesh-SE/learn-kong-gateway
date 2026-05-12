# Lab 02-A - Services & Routes

> **Goal:** Configure the kong-air API as a Kong Service with multiple routes using declarative YAML. Test with both curl and Insomnia.

## The Backend Options

This lab works in two modes:

| Mode | Backend | Requirements |
|---|---|---|
| **Quick start** | `httpbin.konghq.com` | None - works immediately |
| **Full demo** | `kong-air` (local Express) | Node.js 20+ |

### Option A - Quick start with httpbin.konghq.com

```bash
# No setup needed - verify it's reachable
curl -s https://httpbin.konghq.com/get | jq '{url}'
```

### Option B - Start the kong-air backend

```bash
git clone https://github.com/Kong-Grajesh-SE/get-started-guide
cd get-started-guide
npm install
npm run dev   # starts on :3001
```

```bash
# Verify kong-air is running
curl -s http://localhost:3001/api/flights | jq '.[0]'
curl -s http://localhost:3001/health
```

## Step 1 - Declarative YAML

Create `kong-air.yaml`:

```yaml
_format_version: '3.0'

services:
  - name: kong-air
    host: host.docker.internal
    port: 3001
    protocol: http
    connect_timeout: 60000
    read_timeout: 60000
    retries: 5
    tags: [bootcamp, kong-air]
    routes:

      # ── Flights ──────────────────────────────────────────────────────
      - name: flights-list
        paths: [~/api/flights$]
        methods: [GET, OPTIONS]
        strip_path: false

      - name: flights-by-id
        paths: [~/api/flights/(?P<id>\d+)$]
        methods: [GET]
        strip_path: false

      # ── Bookings ─────────────────────────────────────────────────────
      - name: bookings-create
        paths: [~/api/bookings$]
        methods: [POST, OPTIONS]
        strip_path: false

      # ── Hotels ───────────────────────────────────────────────────────
      - name: hotels-list
        paths: [~/api/hotels$]
        methods: [GET, OPTIONS]
        strip_path: false

      - name: hotels-by-id
        paths: [~/api/hotels/(?P<id>\d+)$]
        methods: [GET]
        strip_path: false

      - name: hotels-reserve
        paths: [~/api/hotels/reserve$]
        methods: [POST, OPTIONS]
        strip_path: false

      # ── Cars ─────────────────────────────────────────────────────────
      - name: cars-list
        paths: [~/api/cars$]
        methods: [GET, OPTIONS]
        strip_path: false

      - name: cars-by-id
        paths: [~/api/cars/(?P<id>\d+)$]
        methods: [GET]
        strip_path: false

      - name: cars-reserve
        paths: [~/api/cars/reserve$]
        methods: [POST, OPTIONS]
        strip_path: false

      # ── Weather ──────────────────────────────────────────────────────
      - name: weather-by-airport
        paths: [~/api/weather/(?P<airport>[A-Z]{3})$]
        methods: [GET]
        strip_path: false

      # ── Health ───────────────────────────────────────────────────────
      - name: health-check
        paths: [~/health$]
        methods: [GET]
        strip_path: false
```

## Step 2 - Validate & sync

```bash
# Validate the YAML without connecting to Kong
deck file validate kong-air.yaml

# Preview what will change (Konnect)
deck gateway diff \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp \
  kong-air.yaml

# Apply to Konnect
deck gateway sync \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-control-plane-name bootcamp-cp \
  kong-air.yaml
```

## Step 3 - Test all routes

::: code-group

```bash [curl - Terminal]
BASE="http://localhost:8000"

# Flights
curl -s $BASE/api/flights | jq 'length'
curl -s $BASE/api/flights/1 | jq '{id, airline, destination}'
curl -s $BASE/api/weather/LHR | jq '{airport, temperature}'

# Hotels
curl -s $BASE/api/hotels | jq 'length'

# Cars
curl -s $BASE/api/cars | jq 'length'

# Health
curl -s $BASE/health
```

```text [Insomnia - GUI]
1. In Insomnia, create a new Collection: "Kong Air"
2. Add requests:
   GET http://localhost:8000/api/flights
   GET http://localhost:8000/api/flights/1
   GET http://localhost:8000/api/hotels
   GET http://localhost:8000/api/cars
   GET http://localhost:8000/api/weather/LHR
   GET http://localhost:8000/health
3. Send each and verify 200 responses
4. Check the "Timeline" tab for Kong headers (X-Kong-Request-Id)
```

:::

## Step 4 - Route matching inspection

Use Konnect UI to inspect route matching:

1. Konnect → bootcamp-cp → **Routes**
2. Click on **flights-list**
3. Review: Paths, Methods, Strip Path, Protocols

Or test route matching directly via the proxy:

```bash
# Should match flights-list route
curl -i http://localhost:8000/api/flights
grep -i 'X-Kong-Request-Id\|X-Kong-Upstream-Latency' <<< "$(
curl -si http://localhost:8000/api/flights
)"
```

## Step 5 - Strip path vs preserve path

Test the difference:

```bash
# Route with strip_path: true
curl -s -X POST http://localhost:8001/services/httpbin-service/routes \
  -H "Content-Type: application/json" \
  -d '{"name":"strip-test","paths":["/v1"],"strip_path":true}'

# /v1/get → /get (prefix stripped)
curl -s http://localhost:8000/v1/get | jq '.url'

# Clean up
curl -s -X DELETE http://localhost:8001/routes/strip-test
```

## Challenge

Add a route for `GET /api/users/profile` that requires the `X-Auth-Source: kong` header. Use the `headers` field in the route definition.

---

*Next: [Lab 02-B - Upstreams & Load Balancing →](./02-upstreams)*
