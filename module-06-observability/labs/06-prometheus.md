# Lab 06-B - Prometheus Metrics & Grafana

> **Goal:** Expose Kong metrics in Prometheus format and visualise them in a Grafana dashboard.

## Step 1 - Enable the Prometheus plugin

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "prometheus",
    "config": {
      "status_code_metrics": true,
      "latency_metrics": true,
      "bandwidth_metrics": true,
      "upstream_health_metrics": true
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
plugins:
  - name: prometheus
    config:
      status_code_metrics: true
      latency_metrics: true
      bandwidth_metrics: true
      upstream_health_metrics: true
```

:::

## Step 2 - View raw Prometheus metrics

```bash
# Metrics are exposed on the Admin API port
curl -s http://localhost:8001/metrics | head -50

# Or if you exposed the metrics on the proxy port
curl -s http://localhost:8000/metrics | head -20
```

Expected output:
```
# HELP kong_http_requests_total HTTP requests total
# TYPE kong_http_requests_total counter
kong_http_requests_total{service="mytravel-com-api",route="flights-list",code="200",source="service",workspace="default"} 42
...
```

## Step 3 - Start Prometheus and Grafana

Create `docker-compose.observability.yml`:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - kong-net

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: kong
      GF_USERS_ALLOW_SIGN_UP: "false"
    ports:
      - "3000:3000"
    networks:
      - kong-net

networks:
  kong-net:
    external: true
```

Create `prometheus.yml`:

```yaml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: kong
    static_configs:
      - targets:
          - kong:8001        # Kong Admin API exposes /metrics
    metrics_path: /metrics
```

```bash
docker compose -f docker-compose.observability.yml up -d
```

## Step 4 - Configure Grafana

1. Open [http://localhost:3000](http://localhost:3000) - login: `admin` / `kong`
2. **Add data source**: Configuration → Data Sources → Prometheus
   - URL: `http://prometheus:9090`
3. **Import Kong dashboard**:
   - Dashboards → Import → Enter ID `7424` (official Kong Grafana dashboard)
   - Or import `https://grafana.com/grafana/dashboards/7424`

## Step 5 - Generate traffic for metrics

```bash
# Generate varied traffic
for i in {1..50}; do
  curl -s -H "X-API-Key: web-app-key-abc123" http://localhost:8000/api/flights &
  curl -s -H "X-API-Key: mobile-app-key-def456" http://localhost:8000/api/hotels &
  curl -s http://localhost:8000/api/flights &   # no auth → 401
done
wait
```

## Step 6 - Key Prometheus queries

Use these in Grafana or Prometheus UI:

```promql
# Total requests per second (rate over last 5 minutes)
rate(kong_http_requests_total[5m])

# Error rate (4xx + 5xx)
sum(rate(kong_http_requests_total{code=~"4..|5.."}[5m]))
  / sum(rate(kong_http_requests_total[5m]))

# P95 latency by service
histogram_quantile(0.95,
  sum(rate(kong_request_latency_ms_bucket[5m])) by (service, le))

# Upstream health
kong_upstream_target_health{state="healthchecks_off"} == 0

# Bandwidth by service
sum(rate(kong_bandwidth_bytes{direction="ingress"}[5m])) by (service)
```

## Step 7 - Alerts

Create a Prometheus alert rule (`alert-rules.yml`):

```yaml
groups:
  - name: kong-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(kong_http_requests_total{code=~"5.."}[5m])) /
          sum(rate(kong_http_requests_total[5m])) > 0.05
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Kong error rate above 5%"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(kong_request_latency_ms_bucket[5m])) by (le)
          ) > 500
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Kong P95 latency above 500ms"
```

---

*Next: [Lab 06-C - OpenTelemetry →](./06-opentelemetry)*
