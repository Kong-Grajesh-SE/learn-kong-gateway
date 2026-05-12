# Lab 04-E - IP Restriction

> **Goal:** Allow or block client IP addresses and CIDR ranges from accessing Kong-proxied routes.

## How IP Restriction Works

```
Incoming request →
  Kong reads client IP (from X-Real-IP or X-Forwarded-For) →
    IP checked against allow / deny lists →
      ✅ Allowed → request proxied
      ❌ Denied  → 403 Forbidden (or configured status)
```

## Step 1 - Allow only specific IPs/CIDRs

::: code-group

```yaml [decK YAML]
routes:
  - name: admin-route
    plugins:
      - name: ip-restriction
        config:
          allow:
            - 10.0.0.0/8          # internal network
            - 192.168.1.100        # trusted workstation
          status: 403
          message: "Your IP address is not permitted."
```

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/admin-route/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ip-restriction",
    "config": {
      "allow": ["10.0.0.0/8", "192.168.1.100"],
      "status": 403,
      "message": "Your IP address is not permitted."
    }
  }' | jq '{id, name, config}'
```

:::

## Step 2 - Test access from allowed IP

```bash
# Simulate request from allowed IP using X-Real-IP (for testing behind proxy)
curl -si http://localhost:8000/api/admin \
  -H "X-Real-IP: 10.0.0.5" | head -3
# Expected: HTTP/1.1 200 OK

# From blocked IP
curl -si http://localhost:8000/api/admin \
  -H "X-Real-IP: 203.0.113.99" | head -3
# Expected: HTTP/1.1 403 Forbidden
```

## Step 3 - Denylist approach (block specific IPs, allow all others)

```yaml
plugins:
  - name: ip-restriction
    config:
      deny:
        - 198.51.100.0/24    # known bad CIDR
        - 203.0.113.42       # specific blocked IP
      status: 403
      message: "Access denied."
```

::: warning
Specify either `allow` **or** `deny`, not both at the same time.
:::

## Step 4 - Configure for load balancer deployments

When Kong is behind a load balancer, the client IP arrives in `X-Forwarded-For`. Update `kong.conf`:

```ini
real_ip_header = X-Forwarded-For
trusted_ips    = 10.0.0.0/8, 172.16.0.0/12
```

Or apply globally:

```bash
curl -s -X PATCH http://localhost:8001/configs \
  -d 'real_ip_header=X-Forwarded-For'
```

## Step 5 - Global vs route-level restriction

```bash
# Apply globally (all routes)
curl -s -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ip-restriction",
    "config": {
      "allow": ["10.0.0.0/8"],
      "status": 403
    }
  }' | jq '{id, name}'

# Apply only to a specific service
curl -s -X POST http://localhost:8001/services/kong-air/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ip-restriction",
    "config": {
      "allow": ["192.168.0.0/16"],
      "status": 403
    }
  }' | jq '{id, name}'
```

## Configuration Reference

| Parameter | Default | Description |
|---|---|---|
| `allow` | `[]` | Allowlist of IPs/CIDRs - all others blocked. Use **or** `deny`, not both |
| `deny` | `[]` | Denylist of IPs/CIDRs - all others allowed |
| `status` | `403` | HTTP status code returned when access is denied |
| `message` | `"Your IP address is not allowed"` | Response body when denied |

---

*Previous: [Lab 04-D - CORS](./04-cors) · Next: [Lab 04-F - Proxy Cache →](./04-proxy-cache)*
