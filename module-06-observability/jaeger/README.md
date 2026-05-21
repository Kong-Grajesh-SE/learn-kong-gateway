# Local OTLP trace stack - Lab 06-C (OpenTelemetry)

Two-container stack: **OpenTelemetry Collector** in front of **Jaeger all-in-one**.

```
Kong DP  ──OTLP/HTTP──►  otelcol :4318  ──batch──►  jaeger :4317 (internal)
                                                              │
                                                      Jaeger UI :16686
```

The Collector acts as a buffer (batching, back-pressure, memory-limiting) and can fan-out to cloud backends later without changing the Kong plugin config.

---

## Quick start

```bash
cd module-06-observability/jaeger
docker compose up -d
```

Wait ~15 s for Jaeger to pass its health check, then open the UI:

```
http://localhost:16686
```

---

## Kong plugin configuration (hybrid mode)

Use `host.docker.internal` so the Kong DP container can reach ports published on your host:

```yaml
- name: opentelemetry
  config:
    endpoint: "http://host.docker.internal:4318/v1/traces"
    resource_attributes:
      service.name: "kong-bootcamp-flights"
      deployment.environment: "lab"
    sampling_rate: 1.0
    header_type: w3c
    batch_span_count: 200
    batch_flush_delay: 3
```

Or with the Admin API / decK sync - see [06-opentelemetry.md](../labs/06-opentelemetry.md).

---

## Verify spans are arriving

```bash
# Watch the collector log - prints one summary line per exported batch:
docker compose logs -f otelcol

# Confirm Jaeger has received at least one service:
curl -s "http://localhost:16686/api/services" | jq '.data[]'
```

Generate traffic through Kong (use a valid API key):

```bash
for i in {1..10}; do
  curl -s -o /dev/null -H 'X-API-Key: web-app-secret-key-001' \
    "$KONNECT_PROXY_URL/flights/anything"
done
```

In the Jaeger UI → **Search** → Service: `kong-bootcamp-flights` → **Find Traces**.

---

## Ports

| Port | Service | Purpose |
|------|---------|---------|
| `4317` | otelcol | OTLP gRPC receiver (Kong → Collector) |
| `4318` | otelcol | OTLP HTTP receiver (Kong → Collector) ← use this for labs |
| `8888` | otelcol | Collector's own Prometheus metrics |
| `16686` | jaeger  | Jaeger query UI + REST API |

---

## Adding a cloud backend (Honeycomb / Grafana Cloud)

Edit `otel-collector-config.yaml`:

1. Uncomment the relevant exporter block (`otlphttp/honeycomb` or `otlphttp/grafana`).
2. Set your API key as an environment variable:

```bash
export HONEYCOMB_API_KEY=your-key-here
docker compose up -d
```

3. Add the exporter name to the `traces.exporters` list so spans go to both Jaeger and the cloud.

No changes to Kong's plugin configuration are needed - the collector fans out.

---

## Stop and wipe

```bash
# Stop containers (traces lost - in-memory only):
docker compose down

# Stop and remove the named network too:
docker compose down --remove-orphans
```

Jaeger stores traces in memory only. All history is lost on restart - this is intentional for a lab environment. For persistent storage see [Jaeger docs → Storage Backends](https://www.jaegertracing.io/docs/latest/deployment/#storage-backends).

