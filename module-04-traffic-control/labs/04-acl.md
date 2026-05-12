# Lab 04-C - ACL (Access Control Lists)

> **Goal:** Implement group-based access control so only authorised consumers can access specific routes.

## How ACL Works

```
Consumer authenticated (key-auth / jwt) →
  ACL plugin checks consumer's group membership →
    ✅ Consumer in allowed group → request forwarded
    ❌ Consumer not in group → 403 Forbidden
```

## Step 1 - Create consumer groups

```bash
# Create groups
for group in "free-tier" "premium-tier" "admin-tier"; do
  curl -s -X PUT "http://localhost:8001/consumer_groups/$group" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$group\"}"
done

# Add consumers to groups
curl -s -X POST http://localhost:8001/consumer_groups/free-tier/consumers \
  -H "Content-Type: application/json" \
  -d '{"consumer": "dev-tester"}'

curl -s -X POST http://localhost:8001/consumer_groups/premium-tier/consumers \
  -H "Content-Type: application/json" \
  -d '{"consumer": "travel-web-app"}'

curl -s -X POST http://localhost:8001/consumer_groups/admin-tier/consumers \
  -H "Content-Type: application/json" \
  -d '{"consumer": "travel-mobile-app"}'
```

## Step 2 - Apply ACL to a route

Restrict the `/api/users/profile` route to premium and admin tiers only:

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/users-profile/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "acl",
    "config": {
      "allow": ["premium-tier", "admin-tier"],
      "hide_groups_header": true
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
routes:
  - name: users-profile
    plugins:
      - name: acl
        config:
          allow:
            - premium-tier
            - admin-tier
          hide_groups_header: true
```

:::

## Step 3 - Test access control

```bash
# travel-web-app (premium-tier) - should succeed
curl -si -H "X-API-Key: web-app-key-abc123" \
  http://localhost:8000/api/users/profile | head -3
# HTTP/1.1 200 OK

# dev-tester (free-tier) - should be denied
DEV_KEY=$(curl -s http://localhost:8001/consumers/dev-tester/key-auth | \
  jq -r '.data[0].key')
curl -si -H "X-API-Key: $DEV_KEY" \
  http://localhost:8000/api/users/profile | head -3
# HTTP/1.1 403 Forbidden
# {"message":"You cannot consume this service"}
```

## Step 4 - Deny list (blocklist)

Instead of allow, use deny to block specific groups:

```bash
curl -s -X POST http://localhost:8001/routes/flights-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "acl",
    "config": {
      "deny": ["blocked-users"],
      "hide_groups_header": true
    }
  }' | jq '{id, name}'
```

## Step 5 - IP Restriction Plugin

Combine ACL with IP restrictions for extra security:

```bash
curl -s -X POST http://localhost:8001/routes/users-profile/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ip-restriction",
    "config": {
      "allow": ["127.0.0.1", "10.0.0.0/8", "192.168.0.0/16"],
      "status": 403,
      "message": "Your IP is not allowed to access this endpoint."
    }
  }' | jq '{id, name}'
```

## Step 6 - decK YAML: Full traffic control config

```yaml
_format_version: '3.0'

consumer_groups:
  - name: free-tier
  - name: premium-tier
  - name: admin-tier

consumers:
  - username: dev-tester
    groups:
      - name: free-tier
    keyauth_credentials:
      - key: dev-tester-key-xyz

  - username: travel-web-app
    groups:
      - name: premium-tier
    keyauth_credentials:
      - key: web-app-key-abc123

  - username: travel-mobile-app
    groups:
      - name: admin-tier
    keyauth_credentials:
      - key: mobile-app-key-def456

services:
  - name: mytravel-com-api
    routes:
      - name: users-profile
        paths: [~/api/users/profile$]
        plugins:
          - name: key-auth
            config:
              key_names: [X-API-Key]
              hide_credentials: true
          - name: acl
            config:
              allow: [premium-tier, admin-tier]
              hide_groups_header: true
```

## ACL Configuration Reference

| Config | Description |
|---|---|
| `allow` | List of group names that ARE allowed |
| `deny` | List of group names that are BLOCKED |
| `hide_groups_header` | Don't send `X-Consumer-Groups` to backend |

::: warning
You must specify either `allow` OR `deny`, not both.
:::

---

*Next: [Module 05 - Transformations →](/module-05-transformations/)*
