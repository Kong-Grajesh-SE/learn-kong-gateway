# Verification Scripts

Per-module verification scripts that exercise every concept in each lab against a **real Konnect gateway** (serverless or hybrid). Each script:

- Walks every step from the corresponding module's labs.
- Inspects the CP first and only wipes it after confirming with you.
- Pauses at meaningful checkpoints to let you verify in the Konnect UI.
- Cleans up at the end (optional) so the next module starts clean.
- Works in **both** deployment modes (`serverless` | `hybrid`).
- Works with **both** configuration methods (decK | Konnect Admin API) - you pick at runtime.

## Quick start

```bash
# From the repo root
./scripts/verify-module-01.sh                     # asks for everything
./scripts/verify-module-02.sh serverless          # locks mode via arg
./scripts/verify-module-04.sh hybrid              # uses local Docker DP
./scripts/verify-module-08.sh serverless test     # capstone - grade your own work
./scripts/verify-module-08.sh serverless apply    # capstone - build reference then grade
```

## What you need before running any script

| Tool | Why | Verify |
|---|---|---|
| `curl`         | All HTTP calls            | `curl --version` |
| `jq`           | JSON parsing              | `jq --version`   |
| `openssl`      | JWT minting, HMAC signing | `openssl version` |
| `deck` (optional) | Only if you pick decK config method | `deck version` (≥ 1.43 for Kong 3.14) |
| `docker` (optional) | Only if you pick `DEPLOY_MODE=hybrid` | `docker --version` |
| **Konnect PAT** | Auth for Admin API + decK            | Token starts with `kpat_…` |
| **Konnect CP**  | An empty (or wipeable) Control Plane | Free tier is fine; **Kong 3.14+** |

### Automatic prerequisites check

Every script starts with **`check_prerequisites`** - a self-diagnosis that prints the version of each installed tool, warns about missing optional ones, and **aborts loudly** if a required tool isn't found:

```
Prerequisites
────────────────────────────────────────────────────────────────────────────

▶ Required tools
✓   curl 8.7.1
✓   jq 1.7.1
✓   openssl 3.3.6
✓   bash 3.2.57(1)-release

▶ Optional tools (needed only if you pick certain modes)
✓   deck v1.59.1
✓   docker 29.4.3
✓   python3 3.14.4
✓ Prerequisites check passed
```

If something's missing:
- **Required missing** → script exits with install hints (`brew install jq`, etc.)
- **Optional missing** → script continues, but warns that certain modes won't be available (e.g. "Without docker → you cannot use DEPLOY_MODE=hybrid")
- **Bash 3.x detected** → soft warning (macOS default; usually works)

### Kong version check

Right after **`ping_konnect`** confirms reachability, **`check_kong_version`** verifies the runtime:

- **Serverless mode** - reports that Konnect manages the runtime (always 3.14+ on tip).
- **Hybrid mode** - queries `/dataplanes`, parses each DP's reported Kong version, and **aborts** if any are below 3.14 (telling you to bump the image tag).

## How the scripts get configured

Each script accepts inputs three ways, in this order of precedence:

1. **CLI argument** - e.g. `./verify-module-04.sh serverless`
2. **Environment variables** - exported in your shell or in `scripts/.env`
3. **Interactive prompts** - for anything missing

The first time you run any script, it'll prompt for the values below and save them (chmod 600) to `scripts/.env` so subsequent runs are silent:

| Variable | Example | Notes |
|---|---|---|
| `DEPLOY_MODE`        | `serverless` or `hybrid`                                       | Locks for the entire run |
| `CFG_METHOD`         | `deck` or `api`                                                | decK vs Admin API |
| `KONNECT_TOKEN`      | `kpat_xxxxxxxxx`                                               | **Secret.** Saved to gitignored `scripts/.env` |
| `KONNECT_REGION`     | `us` / `eu` / `au`                                             | Must match your CP's region |
| `KONNECT_CP_ID`      | UUID from your Control Plane URL                               | |
| `KONNECT_CP_NAME`    | `bootcamp-cp`                                                  | decK uses the name, not the UUID |
| `KONNECT_PROXY_URL`  | `https://abc.kongcloud.dev` (serverless) or `http://localhost:8000` (hybrid) | |
| `KONG_DP_CONTAINER`  | `kong-dp`                                                      | Hybrid only |

You can also set them explicitly:

```bash
KONNECT_TOKEN=kpat_xxxxxxx \
KONNECT_REGION=us \
KONNECT_CP_ID=<uuid> \
KONNECT_PROXY_URL=https://abc.kongcloud.dev \
  ./scripts/verify-module-04.sh serverless
```

## What each script verifies

| Script | Module | Plugins / Concepts Tested |
|---|---|---|
| [verify-module-01.sh](verify-module-01.sh) | M01 - Your First Gateway | First Service + Route, proxied request, Kong-injected headers, status codes, `strip_path` |
| [verify-module-02.sh](verify-module-02.sh) | M02 - Routing & Topology | 3 Services, route-match priority, `strip_path` mistake drill, Upstream + 2 weighted targets, active + passive health checks, **forced-outage drill** |
| [verify-module-03.sh](verify-module-03.sh) | M03 - Easy Wins | Consumers + key-auth (anonymous fallback, hidden creds), CORS (allowed vs disallowed origin), IP restriction (allow → deny flip), correlation-id (new + client-supplied preserved) |
| [verify-module-04.sh](verify-module-04.sh) | M04 - Traffic & Resilience | 3 per-Consumer rate-limit instances (`X-RateLimit-Limit-Minute`), 429 + `Retry-After`, proxy-cache (`X-Cache-Status: Miss → Hit`, POST → Bypass) |
| [verify-module-05.sh](verify-module-05.sh) | M05 - Transformations | request-transformer-advanced: add/replace/rename/remove/append + `$(consumer.custom_id)` template. response-transformer-advanced: add `_meta.version`, strip internal fields, conditional on `2XX` |
| [verify-module-06.sh](verify-module-06.sh) | M06 - Observability | http-log (with redaction), prometheus enable + Konnect Analytics check, opentelemetry (`traceparent` forwarding + trace continuation) |
| [verify-module-07.sh](verify-module-07.sh) | M07 - Enterprise & Advanced | JWT (HS256 mint + verify + tamper), HMAC (signed POST), Consumer Groups + ACL (3-tier access), OIDC Auth Code (Keycloak), Upstream OAuth (M2M), OPA, Datakit, RBAC (informational) |
| [verify-module-08.sh](verify-module-08.sh) | M08 - Capstone | The 15-step acceptance test from the Capstone lab. Two modes: `apply` (build reference solution first), `test` (grade your own config) |

## Mode flags

### Deployment mode (`serverless` | `hybrid`)

```bash
./scripts/verify-module-04.sh serverless        # CLI arg
./scripts/verify-module-04.sh hybrid

# Or as env var
DEPLOY_MODE=serverless ./scripts/verify-module-04.sh
```

- **serverless**: gateway runs in Konnect cloud, proxy URL is `*.kongcloud.dev`. No Docker required.
- **hybrid**: gateway runs locally via Docker, proxy URL is `http://localhost:8000`. The script also verifies the DP container is healthy and reports as connected in Konnect.

### Configuration method (decK | Admin API)

Asked interactively the first time. Both produce the same result; the difference is *imperative* (Admin API) vs *declarative* (decK):

| | decK | Admin API |
|---|---|---|
| **How it works** | One `kong.yaml` declared per script section, synced atomically. | Individual `POST/PATCH/DELETE` calls. |
| **Output style** | Less noisy, "n created" summaries. | One line per request. |
| **Skip if missing** | Falls back to Admin API if `deck` isn't installed. | Always works. |
| **What you'll use in prod** | This one. GitOps. | Useful for one-off scripts and CI. |

## The cleanup gate

Every script (M02–M08) starts with **`cleanup_if_needed`** - an interactive pre-flight that inspects the CP first:

```
▶ Pre-flight: checking CP state
! Control Plane is not empty. Current contents:
  Services:        3
  Routes:          5
  Consumers:       2
  Consumer Groups: 0
  Upstreams:       0
  Plugins:         4

! Continuing without cleanup may cause spurious failures or leftover plugin chains.

Wipe everything on the CP before proceeding? [Y/n/inspect]:
```

Three responses:

- **Y** (default) - wipes the CP and proceeds.
- **n** - keeps existing state. Script will continue but may fail in unpredictable ways.
- **inspect** - prints a detailed inventory of every entity, then asks again.

If the CP is already empty, the gate says so and continues silently - no wasted time.

## External services for specific scripts

Some sub-sections need external infrastructure. The scripts prompt for endpoints; if you leave them blank, the section is skipped (with a warning).

| Script | Sub-section | External service needed |
|---|---|---|
| `verify-module-06.sh` | http-log     | Webhook receiver - use [webhook.site](https://webhook.site) for free |
| `verify-module-06.sh` | opentelemetry | OTLP HTTP endpoint - Jaeger (local), Honeycomb, Grafana Cloud Traces |
| `verify-module-07.sh` | OIDC (07-C) + Upstream OAuth (07-D) | **Keycloak** - `cd module-07-enterprise/keycloak && docker compose up -d`, then `KEYCLOAK_BASE=http://localhost:8080` |
| `verify-module-07.sh` | OPA (07-E)   | OPA server - run [OPA](https://www.openpolicyagent.org) and pass `OPA_URL` |

### Quick Keycloak setup

```bash
cd module-07-enterprise/keycloak
docker compose up -d
docker logs -f kc-bootcamp 2>&1 | grep -m1 'Imported realm'

# Confirm reachability
curl -s http://localhost:8080/realms/kong-bootcamp/.well-known/openid-configuration | jq '.issuer'

cd -
KEYCLOAK_BASE=http://localhost:8080 ./scripts/verify-module-07.sh serverless
```

See [module-07-enterprise/keycloak/README.md](../module-07-enterprise/keycloak/README.md) for full details on users, clients, and tokens.

## Architecture (how the scripts share code)

```
scripts/
├── README.md                  ← you are here
├── .env                       ← gitignored, chmod 600, holds your KONNECT_TOKEN
├── lib/
│   └── common.sh              ← shared helpers (output, env, API, decK, cleanup, hybrid checks)
├── verify-module-01.sh        ← Module 01 (older, standalone - does not yet source lib/)
├── verify-module-02.sh        ← Module 02
├── verify-module-03.sh        ← Module 03
├── verify-module-04.sh        ← Module 04
├── verify-module-05.sh        ← Module 05
├── verify-module-06.sh        ← Module 06
├── verify-module-07.sh        ← Module 07
└── verify-module-08.sh        ← Module 08 capstone (apply | test modes)
```

`lib/common.sh` exposes:

| Helper | Purpose |
|---|---|
| `hdr`, `step`, `ok`, `warn`, `err`, `info`, `hr` | Colored output |
| `pause_verify "..."` | "VERIFY IN KONNECT:" prompt that waits for Enter |
| `check_prerequisites`         | Required + optional tool check with install hints |
| `check_kong_version`          | Confirms registered DPs run Kong ≥ 3.14 (hybrid); reports serverless |
| `load_env`, `save_env`        | Read/write `scripts/.env` |
| `prompt_var VAR "label" "default"` | Env-first, prompt-fallback |
| `pick_deploy_mode "${1-}"`    | serverless / hybrid |
| `pick_cfg_method`             | deck / api |
| `collect_konnect_inputs`      | token / region / cp-id / proxy URL |
| `ping_konnect`                | Confirms `/v2/control-planes/{id}` reachable |
| `verify_hybrid_dp`            | Hybrid only: `docker ps`, `kong health` |
| `api_curl METHOD PATH [BODY]` | Read-only HTTP call to Konnect Admin API |
| `api_write METHOD PATH BODY`  | Write call that **fails loudly** on non-2xx |
| `deck_sync_stdin`             | Pipe YAML to `deck gateway sync -` |
| `wait_for_route URL [TIMEOUT]` | Polls until route propagates (handles serverless ~10s delay) |
| `list_services` / `list_routes` / `list_consumers` | Quick inventory |
| `inspect_cp_state` / `cp_is_empty` / `print_cp_state` | Used by the cleanup gate |
| `cleanup_if_needed`           | Inspect-then-confirm pre-flight wipe |
| `cleanup_everything`          | Unconditional wipe of every entity |

## Common pitfalls and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `Konnect Admin API … → HTTP 401` | PAT region mismatch - your token was created in a different region's tenant | Regenerate the token in the same region's Konnect UI |
| `Konnect Admin API … → HTTP 403` | PAT lacks permission, or scoped to a different org | Use a token from your user's profile (org admin) |
| Script hangs at "Waiting up to 30s for route to propagate" | Wrong `KONNECT_PROXY_URL` - points to the wrong CP, or DNS cached | Re-check the proxy URL from Konnect UI; for hybrid, `curl http://localhost:8000/` directly |
| `deck` errors with `Schema violation` | decK version older than 1.43 | `brew upgrade kong/tap/deck` |
| Hybrid lab fails - "Container 'kong-dp' is not running" | DP not started, or different name | `docker compose up -d` from your hybrid setup dir, or set `KONG_DP_CONTAINER` |
| M03 "Wrong key → 401" actually returns 200 | A previous run left `anonymous` fallback on. Cleanup didn't run. | Re-run with the cleanup gate. Reply `Y` to wipe. |
| M07 OIDC section: "Could not fetch OIDC discovery" | Keycloak not running, or wrong realm imported | `cd module-07-enterprise/keycloak && docker compose up -d`; wait for "Imported realm" in logs |

## Re-runnability

Every script is **idempotent** - re-running it produces the same result:

- The cleanup gate handles leftover state.
- Inputs are cached in `scripts/.env`, so you only type them once.
- The CLI mode arg (`serverless`/`hybrid`) lets you script runs in CI.

```bash
# In CI / automation
KONNECT_TOKEN=kpat_xxx \
KONNECT_REGION=us \
KONNECT_CP_ID=<uuid> \
KONNECT_PROXY_URL=https://abc.kongcloud.dev \
DEPLOY_MODE=serverless \
CFG_METHOD=api \
  ./scripts/verify-module-02.sh
```

(The cleanup gate still prompts interactively. For non-interactive CI, pre-empty the CP and the gate proceeds silently.)

## Adding a new module's script

The recipe is short - source the lib, do your steps:

```bash
#!/usr/bin/env bash
# verify-module-09.sh - Verify Module 09 (whatever)

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

hdr "Kong Bootcamp - Module 09 Verification"

check_prerequisites
load_env
pick_deploy_mode "${1-}"
collect_konnect_inputs
pick_cfg_method
save_env

ping_konnect
check_kong_version
verify_hybrid_dp
cleanup_if_needed

# … your module-specific tests, using api_curl, api_write, wait_for_route, etc.

hdr "Module 09 verification complete ✓"
```

## License

These scripts are part of the [Kong API Gateway Bootcamp](../README.md) - same license as the parent repo.
