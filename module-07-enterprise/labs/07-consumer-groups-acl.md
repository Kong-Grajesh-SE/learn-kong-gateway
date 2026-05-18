# Lab 07-B - Consumer Groups & ACL

> **Goal.** In ~30 minutes you'll organize Consumers into **groups** (`free`, `pro`, `enterprise`), then use `acl` to allow/deny by group - without listing individual Consumers. This is the standard pattern for tier-based access control.

After this lab you'll be able to:
- Add a Consumer to a Consumer Group with one API call.
- Allow a Route to be accessed only by certain groups.
- Combine `acl` with `rate-limiting` for **tier-differentiated SLOs**.

---

## Step 1 - Baseline (3 min)

We continue from Lab 07-A - `flights-svc` + `flights-route` + the Consumers `partner-api-client` and `data-feed-client` exist.

For this lab we need a few more Consumers, with simpler `key-auth` (HMAC and JWT have already been demonstrated):

```yaml [Replace plugins on flights-route with key-auth, add more Consumers]
_format_version: '3.0'

consumers:
  - username: free-user-001
    custom_id: free-001
    keyauth_credentials:
      - key: free-key-001
    tags: [module-07]

  - username: pro-user-001
    custom_id: pro-001
    keyauth_credentials:
      - key: pro-key-001
    tags: [module-07]

  - username: enterprise-user-001
    custom_id: ent-001
    keyauth_credentials:
      - key: ent-key-001
    tags: [module-07]

services:
  - name: flights-svc
    url: https://httpbin.konghq.com
    tags: [module-07]
    routes:
      - name: flights-route
        paths: [/flights]
        strip_path: true
        plugins:
          - name: key-auth
            config: { key_names: [X-API-Key], hide_credentials: true }
```

```bash
deck gateway sync kong.yaml \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name $KONNECT_CP_NAME
```

**✅ Checkpoint.** Three Consumers with `key-auth` credentials. Each can call `$KONNECT_PROXY_URL/flights/get` with their key and get 200.

---

## Step 2 - Create three Consumer Groups (5 min)

Consumer Groups are created via the Konnect Admin API. decK supports them too:

```yaml [Append to kong.yaml]
consumer_groups:
  - name: free-tier
    tags: [module-07]
  - name: pro-tier
    tags: [module-07]
  - name: enterprise-tier
    tags: [module-07]
```

Or via Admin API:

```bash
for GROUP in free-tier pro-tier enterprise-tier; do
  curl -sS -X POST \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    -H "Content-Type: application/json" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumer_groups" \
    -d "{\"name\":\"$GROUP\",\"tags\":[\"module-07\"]}" \
    | jq -r '"created group: " + .name'
done
```

**✅ Checkpoint.** Konnect → **Consumer Groups** → all three listed.

---

## Step 3 - Assign Consumers to groups (3 min)

Each Consumer joins exactly one tier:

```yaml [decK - append `groups:` to each Consumer]
consumers:
  - username: free-user-001
    groups:
      - name: free-tier
  - username: pro-user-001
    groups:
      - name: pro-tier
  - username: enterprise-user-001
    groups:
      - name: enterprise-tier
```

Or via Admin API:

```bash
for PAIR in "free-user-001:free-tier" "pro-user-001:pro-tier" "enterprise-user-001:enterprise-tier"; do
  USER=${PAIR%:*}; GROUP=${PAIR#*:}
  curl -sS -X POST \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    -H "Content-Type: application/json" \
    "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumers/$USER/consumer_groups" \
    -d "{\"group\":\"$GROUP\"}" \
    | jq -r '"added " + "'"$USER"'" + " to " + "'"$GROUP"'"'
done
```

Sync.

**✅ Checkpoint.** Konnect → click a Consumer Group → **Members** tab shows the right user.

---

## Step 4 - Attach `acl` to restrict by group (5 min) 🎯

You want **only `pro-tier` and `enterprise-tier` users** to access `flights-route`. Free users should get 403.

```yaml [Append plugin to flights-route]
- name: flights-route
  paths: [/flights]
  strip_path: true
  plugins:
    - name: key-auth
      config: { key_names: [X-API-Key], hide_credentials: true }
    - name: acl
      config:
        allow:
          - pro-tier
          - enterprise-tier
        hide_groups_header: true
```

Sync. Wait 15s.

Test:

```bash
echo "── free-user (should be 403) ──"
curl -i $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: free-key-001' | head -3

echo "── pro-user (should be 200) ──"
curl -i $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: pro-key-001' | head -3

echo "── enterprise-user (should be 200) ──"
curl -i $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: ent-key-001' | head -3
```

Expected:
```
── free-user (should be 403) ──
HTTP/2 403
{"message":"You cannot consume this service"}

── pro-user (should be 200) ──
HTTP/2 200

── enterprise-user (should be 200) ──
HTTP/2 200
```

🎯 The free-tier consumer was identified (`key-auth` passed → 200 was possible) but **authorized** out by `acl` → 403.

::: tip 401 vs 403 - see the pattern emerge
- `key-auth` returns **401** when it doesn't know who you are.
- `acl` returns **403** when it knows who you are but won't let you in.

If you add `acl` before `key-auth` runs, `acl` doesn't yet know the Consumer → it would 403 *everyone*. Always put auth*n* before auth*z*.
:::

---

## Step 5 - Combine ACL with per-group rate limiting (8 min) 🎯

Free tier should get 10 req/min, pro 100, enterprise 1000. Per-Consumer-Group rate limiting is a Konnect Enterprise feature using `rate-limiting-advanced`:

```yaml [Add Consumer-Group-scoped rate limits]
- name: flights-route
  paths: [/flights]
  strip_path: true
  plugins:
    - name: key-auth
      config: { key_names: [X-API-Key], hide_credentials: true }
    - name: acl
      config:
        allow: [free-tier, pro-tier, enterprise-tier]   # ← now allow all 3
        hide_groups_header: true
    # Per-group rate limits via consumer_groups override
    - name: rate-limiting-advanced
      config:
        limit: [10]
        window_size: [60]
        identifier: consumer
      consumer_group: free-tier
    - name: rate-limiting-advanced
      config:
        limit: [100]
        window_size: [60]
        identifier: consumer
      consumer_group: pro-tier
    - name: rate-limiting-advanced
      config:
        limit: [1000]
        window_size: [60]
        identifier: consumer
      consumer_group: enterprise-tier
```

Sync. Wait 15s.

```bash
echo "── free-user limit (should be 10) ──"
curl -sI $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: free-key-001' \
  | grep -i 'ratelimit-limit'

echo "── pro-user limit (should be 100) ──"
curl -sI $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: pro-key-001' \
  | grep -i 'ratelimit-limit'

echo "── enterprise-user limit (should be 1000) ──"
curl -sI $KONNECT_PROXY_URL/flights/get -H 'X-API-Key: ent-key-001' \
  | grep -i 'ratelimit-limit'
```

Expected:
```
── free-user limit (should be 10) ──
ratelimit-limit: 10
── pro-user limit (should be 100) ──
ratelimit-limit: 100
── enterprise-user limit (should be 1000) ──
ratelimit-limit: 1000
```

🎯 The same plugin, three different configs, applied by Consumer Group membership. **This is the canonical tier-based-SLO pattern** - one place to change the contract per tier.

::: tip Authoritative source of group membership
For most teams, *which group* a Consumer belongs to should be driven by your billing system (or your IdP via OIDC claim mapping), **not** by manual Konnect edits. Use the Admin API in a CI pipeline that syncs from your billing DB nightly.
:::

---

## Step 6 - Group-aware ACL with `deny:` (3 min) 🧪

Sometimes it's easier to denylist abusers than allowlist everyone. Create a `blocked` group, add a Consumer to it:

```bash
# Create the group
curl -sS -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumer_groups" \
  -d '{"name":"blocked","tags":["module-07"]}' | jq -r '.name'

# Block one user
curl -sS -X POST \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://${KONNECT_REGION}.api.konghq.com/v2/control-planes/${KONNECT_CP_ID}/core-entities/consumers/free-user-001/consumer_groups" \
  -d '{"group":"blocked"}'
```

Update ACL to a `deny` list:

```yaml
- name: acl
  config:
    deny: [blocked]            # any other group is allowed
    hide_groups_header: true
```

Sync. Test that `free-user-001` is now 403 (member of `blocked`), but other users still 200.

::: warning Don't mix `allow` and `deny` in one plugin instance
Pick one. Mixing them produces "guess which one wins" surprises - `allow` does. Use two plugin instances if you really need both, but it's a smell.
:::

---

## Recap

You now have:
- **Three tier groups** (`free`, `pro`, `enterprise`) + a `blocked` group.
- An **`acl`** plugin enforcing group-level access - 403 if not in an allowed group.
- **Three `rate-limiting-advanced` plugin instances** scoped to each group, producing differentiated SLOs from one Route.
- A `deny:` example showing how to denylist abusers without rewriting allowlists.

**This pattern scales to thousands of Consumers** because group membership changes don't require gateway config changes - only the membership record itself.

---

## Cleanup

We continue with the same Service in 07-C (OIDC). **Don't clean up yet.**

---

**Next:** [Lab 07-C - OIDC Authorization Code Flow →](./07-oidc-auth-code)
