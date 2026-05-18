# Module 07 - Enterprise & Advanced

> **The scenario.** You're past the easy wins. The product team needs:
> - **JWT** for the partner API (stateless tokens, no Kong-side credential storage).
> - **HMAC** for the high-security data feed (signed requests, replay protection).
> - **Consumer tiers** (free / pro / enterprise) with different access - and the auditors want to see who has what.
> - **Browser SSO** with the corporate IdP.
> - **Machine-to-machine** auth where Kong injects OAuth tokens upstream so internal services don't manage credentials.
> - **Policy-as-code** so security teams can change authorization rules without touching gateway YAML.
> - **Multi-step API workflows** the upstream is too dumb to do itself.
> - **Team isolation** in Kong Manager so the payments team can't accidentally edit the bookings team's gateway.
>
> All seven, in this module. **~3.5 hours** total. Pick the labs that match your real-world needs - these are à la carte rather than a single thread.

## Who this module is for

You've completed M01–M06 (or scanned them). You're comfortable with Konnect Admin API + decK, Consumers, plugin scopes, and the differences between logs/metrics/traces. **This module is dense** - each lab introduces an Enterprise plugin with real-world configuration.

::: warning Enterprise / Konnect-only plugins
Several plugins in this module require **Kong Gateway Enterprise** or **Konnect** (free tier is fine):
- `openid-connect`, `upstream-oauth`, `opa`, `datakit`, `request-transformer-advanced`, `rate-limiting-advanced` (already used in M04).

Konnect serverless includes all of these. Self-hosted OSS Kong does not.
:::

## The seven advanced plugins / features

| # | Lab | Plugin / Feature | Time | Difficulty |
|---|---|---|---|---|
| 07-A | [Advanced Auth](./labs/07-advanced-auth) | `jwt` + `hmac-auth` | ~45 min | ★★★ |
| 07-B | [Consumer Groups & ACL](./labs/07-consumer-groups-acl) | `acl` + Consumer Groups | ~30 min | ★★ |
| 07-C | [OIDC Auth Code Flow](./labs/07-oidc-auth-code) | `openid-connect` (browser SSO) | ~45 min | ★★★★ |
| 07-D | [Upstream OAuth (M2M)](./labs/07-upstream-oauth) | `upstream-oauth` | ~30 min | ★★★ |
| 07-E | [OPA Policy-as-Code](./labs/07-opa) | `opa` | ~45 min | ★★★★ |
| 07-F | [Datakit Orchestration](./labs/07-datakit) | `datakit` | ~30 min | ★★★ |
| 07-G | [Kong Manager RBAC](./labs/07-rbac-teams) | Kong Manager workspaces + roles | ~20 min | ★★ |

## Three concepts you need today

| Concept | What it is | Why it matters |
|---|---|---|
| **Stateless vs stateful auth** | JWT and HMAC are stateless - Kong validates a signature without storing anything. `key-auth` and `openid-connect` (with sessions) store state. | Stateless scales horizontally for free. Stateful adds a sync problem across DPs. |
| **Authentication vs Authorization** | Auth*n*: "who are you?" (`key-auth`, `jwt`, `oidc`). Auth*z*: "can you do this?" (`acl`, `opa`). | Different plugins, different layers. ACL is simple lists; OPA is general policy. |
| **Identity propagation** | After Kong identifies a Consumer, it injects `X-Consumer-*` headers. After `openid-connect`, it can inject `X-Authenticated-Userid`, the raw token, or claims. | The upstream trusts these because the request reached it via the gateway. |

## Exit ticket

After completing the labs you take, answer these:

1. **JWT vs `key-auth` vs OIDC** - when would you use each? (Stateless vs stateful, who issues credentials, single-domain vs federated.)
2. **ACL vs OPA** - both authorize. When does the extra complexity of OPA pay off?
3. **OIDC Auth Code vs Upstream OAuth** - both involve OAuth tokens. Who is the *token* for in each case?

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| JWT validation fails with "invalid signature" | The `secret` on the Consumer's `jwt_secrets` doesn't match the key that signed the token. Or you're using HS256 secret + an RS256 token. |
| HMAC requests pass even when the signature is wrong | `validate_request_body: false` (the default) means Kong doesn't check the body's hash. For real security set it to `true` and include the body hash in the signed string. |
| OIDC redirects loop back to login forever | Mismatched `redirect_uri` between Konnect plugin config and the IdP's registered client. Fix in the IdP first. |
| `upstream-oauth` injects an empty Authorization header | Token cache hasn't warmed up - first request fetches the token. Or your `client_credentials` is wrong (check the IdP's token endpoint logs). |
| OPA policy evaluates but Kong ignores the decision | You enabled the plugin but didn't read `result.allow` in your policy. Kong expects a specific result shape - see the OPA lab. |
| Datakit pipeline fails halfway | One of the upstream calls in your pipeline returned non-2xx. Datakit doesn't retry by default - add `on_error` handling per step. |
| RBAC role doesn't take effect | Workspace context - the user has the role *in a workspace they're not viewing*. Kong Manager URL must include the workspace slug. |

## Verify your work

```bash
# From the repo root
./scripts/verify-module-07.sh [serverless|hybrid]

# Skip Konnect portal review pauses (useful for CI / re-runs)
SKIP_REVIEW=1 ./scripts/verify-module-07.sh
```

The script walks all seven labs in sequence against a live Konnect gateway. Each lab:

1. Creates the required plugin on `flights-route`
2. Runs HTTP assertions (status codes, response headers, token validation)
3. **Pauses** so you can inspect the plugin config in the Konnect portal
4. Removes the plugin after you press Enter, leaving the route clean for the next lab

### What each lab verifies

| Lab | Runs | What the script tests |
|---|---|---|
| **07-A** JWT + HMAC | ✅ Always | JWT plugin with `key_claim_name=iss`; HS256 token minted via `openssl`; Consumer mapped via `X-Consumer-Username`; tampered token → 401; missing → 401. HMAC `hmac-auth` with `date+request-line+content-md5`; correctly signed POST → 200; bad signature → 401. |
| **07-B** Consumer Groups | ✅ Always | `key-auth` + `acl`: `free-tier` → 403, `pro`/`enterprise` → 200. `rate-limiting-advanced` per group (10/100/1000 rpm); gracefully skipped with a warning if the Enterprise plugin isn't available on your CP tier. |
| **07-C** OIDC Auth Code | ⚙️ Needs Keycloak | Interactive menu: **A** hybrid (localhost:8080) / **B** ngrok public URL / **S** skip. Verifies realm discovery; `openid-connect` plugin; `alice` password-grant token → 200; unauthenticated → 401. |
| **07-D** Upstream OAuth | ⚙️ Needs Keycloak | `kong-m2m` client-credentials token verified directly; `upstream-oauth` plugin attached; upstream receives `Authorization: Bearer <token>` injected by Kong. |
| **07-E** OPA | ⚙️ Needs OPA | Prompts for `OPA_URL` (or press Enter to skip). `opa` plugin attached with consumer + service context; route called; HTTP status logged (outcome depends on your Rego policy). |
| **07-F** Datakit | ⚡ Config-only | Attaches a 1-node pipeline; gracefully skipped with a warning if the plugin isn't available on your CP tier. |
| **07-G** RBAC | ℹ️ Informational | Self-hosted Kong Manager only. Script prints guidance referencing `cloud.konghq.com → Organization → Teams` and exits. |

### Keycloak for Labs 07-C and 07-D

**Option A — hybrid mode** (local Docker DP, Keycloak on the same host):
```bash
cd module-07-enterprise/keycloak && docker compose up -d
# Then select A at the script's interactive menu
```

**Option B — serverless mode** (Keycloak exposed via ngrok):
```bash
./scripts/setup-keycloak.sh ngrok   # starts Keycloak, opens tunnel, prints public URL
# Then select B at the script's interactive menu and paste the URL
```

Pre-built users: `alice` / `alice-password` · `bob-admin` / `bob-password`  
Clients: `kong` (password + auth-code) · `kong-m2m` (client_credentials)

### Environment variables

| Variable | Purpose |
|---|---|
| `KEYCLOAK_BASE` | Pre-set to skip the interactive 07-C/D menu (e.g. `http://localhost:8080`) |
| `OPA_URL` | Pre-set to skip the 07-E prompt (e.g. `http://host.docker.internal:8181/v1/data/myapp/authz/allow`) |
| `SKIP_REVIEW=1` | Bypass all `pause_for_review` prompts (useful in CI or on re-runs) |

---

## What's next

If you've completed M01–M07 - **you've covered every plugin a typical Kong deployment uses**. The final step is putting it all together: **[Module 08 - Capstone →](/module-08-capstone/)** is one ~3-hour lab where you design and build the full production gateway with 11+ plugins working together, then prove it works with a 15-step acceptance test.

After the capstone, specialist deep-dives:
- **AI Gateway Bootcamp ↗** - LLM proxying, prompt injection guards, semantic caching.
- **Agentic AI & MCP Bootcamp ↗** - MCP proxy patterns, agent-to-agent routing.
- **Developer Portal Bootcamp ↗** - Publishing APIs to external developers with self-service.
- **APIOps Bootcamp ↗** - Production-grade GitHub Actions pipelines for Kong config.

---

*Previous: [Module 06 - Observability](/module-06-observability/) · Next: [Module 08 - Capstone →](/module-08-capstone/)*
