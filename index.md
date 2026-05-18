---
layout: home

hero:
  name: "Kong API Gateway"
  text: "Bootcamp"
  tagline: "From your first proxied request to a production gateway behind 11+ plugins. 8 hands-on modules on Konnect, ending in a 15-step acceptance capstone."
  image:
    src: /kong-logomark-lime.svg
    alt: Kong Gateway
  actions:
    - theme: brand
      text: "🚀 Start Module 01"
      link: /module-01-orientation/
    - theme: brand
      text: "🏁 Jump to the Capstone"
      link: /module-08-capstone/
    - theme: alt
      text: "✅ Prerequisites"
      link: /prerequisites
    - theme: alt
      text: "🧩 Plugin Reference"
      link: /plugin-reference

features:
  - icon: 🧭
    title: "01 - Your First Gateway"
    details: "Create a serverless Kong gateway on Konnect. Build a Service + Route and proxy your first real request to httpbin.konghq.com. No Docker or prior Kong knowledge required - ~60 min."
    link: /module-01-orientation/
    linkText: Start here →

  - icon: 🔀
    title: "02 - Routing & Topology"
    details: "Three Services routed by path and method. Load-balance across two backend targets with weighted round-robin, then add active + passive health checks for auto-failover. No plugins yet - just routing primitives."
    link: /module-02-core-gateway/
    linkText: Build a real topology →

  - icon: 🔑
    title: "03 - Easy Wins"
    details: "Four Tier-1 plugins, one config block each: key-auth (with Consumers), cors, ip-restriction, correlation-id. Big payoff for low effort. This is also where Consumers get a real job."
    link: /module-03-authentication/
    linkText: Get quick wins →

  - icon: 🚦
    title: "04 - Traffic & Resilience"
    details: "Per-Consumer rate limits with X-RateLimit headers + Retry-After contract. Then cache GETs in Kong's memory and watch latency drop from 200ms to <10ms. Two plugins, ~60 min."
    link: /module-04-traffic-control/
    linkText: Add guardrails →

  - icon: 🔧
    title: "05 - Transformations"
    details: "Rewrite requests and responses on the fly. Inject per-Consumer headers via templates, rename query params for v2→v3 migrations, strip sensitive fields, conditional transforms by status code."
    link: /module-05-transformations/
    linkText: Reshape traffic →

  - icon: 📊
    title: "06 - Observability"
    details: "Three pillars wired up: http-log (push), prometheus (pull), opentelemetry (push). The four RED queries (rate, errors, p95 upstream, p95 Kong). Why per-Consumer labels are a cardinality bomb."
    link: /module-06-observability/
    linkText: See your traffic →

  - icon: 🔐
    title: "07 - Enterprise & Advanced"
    details: "Seven advanced plugins/features: JWT, HMAC, ACL with Consumer Groups, OIDC Auth Code Flow, Upstream OAuth (M2M), OPA policy-as-code, Datakit orchestration, Kong Manager RBAC. ~3.5h, à la carte."
    link: /module-07-enterprise/
    linkText: Go advanced →

  - icon: 🏁
    title: "08 - Capstone"
    details: "Design and build the full production gateway. 11+ plugins working together, three Consumer tiers, two auth methods, full observability - proved by a 15-step acceptance test. ~3 hours. No more hand-holding."
    link: /module-08-capstone/
    linkText: Take the capstone →

---

<div class="kong-version-banner">
  <span class="kong-version-pill">⚙️ Kong Gateway 3.14+</span>
  <span class="kong-version-text">This bootcamp targets <strong>Kong Gateway 3.14</strong> on Konnect (free tier works). Plugin schemas, header behavior, and decK syntax assume 3.14 or newer.</span>
</div>

<div class="kong-stats-strip">
  <div class="stat">
    <div class="stat-num">8</div>
    <div class="stat-label">Modules</div>
  </div>
  <div class="stat">
    <div class="stat-num">17</div>
    <div class="stat-label">Hands-on labs</div>
  </div>
  <div class="stat">
    <div class="stat-num">20+</div>
    <div class="stat-label">Plugins covered</div>
  </div>
  <div class="stat">
    <div class="stat-num">15</div>
    <div class="stat-label">Acceptance steps</div>
  </div>
  <div class="stat">
    <div class="stat-num">~10h</div>
    <div class="stat-label">End-to-end</div>
  </div>
</div>

## What makes this different

::: tip Every concept is a curl you can run
No slides. No theory dumps. Each module gives you a real Konnect gateway, real upstream APIs (httpbin.konghq.com + httpbin.org), and real `curl` you paste into a terminal. The "you" in every lab is *you* - typing, watching, fixing.
:::

::: tip Built around problems, not features
Each module opens with a scenario - "your API just got hammered by a scraper," "the frontend can't call your gateway from a browser," "a user reports a silent failure." Plugins arrive as the *fix*, not as a feature list to memorize. You leave knowing **when** to reach for each plugin, not just **how**.
:::

::: tip Difficulty ramps deliberately
M01-M02 introduce zero plugins - just routing. M03 gives you four "easy wins" (Tier 1: one config block each). M04-M06 raise the bar. M07 is dense, advanced, à la carte. M08 is a capstone that **only passes if your acceptance script is green** - no other signal that you've got it right.
:::

---

## Where to start

Pick the path that matches you:

<div class="kong-paths">
  <a class="kong-path" href="/learn-kong-gateway/module-01-orientation/">
    <div class="kong-path-emoji">🌱</div>
    <div class="kong-path-title">New to Kong</div>
    <div class="kong-path-body">Start at <strong>Module 01</strong>. You'll have a working gateway in 60 minutes. The first three modules assume only basic HTTP knowledge.</div>
    <div class="kong-path-cta">Start at M01 →</div>
  </a>
  <a class="kong-path" href="/learn-kong-gateway/module-04-traffic-control/">
    <div class="kong-path-emoji">⚡</div>
    <div class="kong-path-title">Know Kong, want the meat</div>
    <div class="kong-path-body">Skim <strong>M01–M03</strong> for the new template, then drop into <strong>M04</strong> for rate-limiting + caching, and <strong>M07</strong> for advanced auth + policy.</div>
    <div class="kong-path-cta">Jump to M04 →</div>
  </a>
  <a class="kong-path" href="/learn-kong-gateway/module-08-capstone/">
    <div class="kong-path-emoji">🏁</div>
    <div class="kong-path-title">Want to prove you can build it</div>
    <div class="kong-path-body">Try the <strong>Capstone</strong> first. Read the brief, take the 15-step acceptance test, and let the failures tell you which modules to revisit.</div>
    <div class="kong-path-cta">Take M08 →</div>
  </a>
  <a class="kong-path" href="/learn-kong-gateway/plugin-reference">
    <div class="kong-path-emoji">🧩</div>
    <div class="kong-path-title">Just need a plugin config</div>
    <div class="kong-path-body">The <strong>Plugin Reference</strong> has condensed configs for every plugin in the bootcamp - searchable, with a link back to the lab that introduces it.</div>
    <div class="kong-path-cta">Open the reference →</div>
  </a>
</div>

---

## Specialist deep-dives

After the core bootcamp, go deep on the use cases you actually ship:

<div class="kong-specialists">
  <a class="kong-specialist" href="https://kong-grajesh-se.github.io/learn-kong-ai-gateway/" target="_blank" rel="noopener">
    <div class="kong-specialist-emoji">🤖</div>
    <div class="kong-specialist-title">AI Gateway</div>
    <div class="kong-specialist-body">LLM proxying, prompt-injection guards, semantic caching, PII sanitisation.</div>
  </a>
  <a class="kong-specialist" href="https://kong-grajesh-se.github.io/learn-kong-agentic-bootcamp/" target="_blank" rel="noopener">
    <div class="kong-specialist-emoji">🛠️</div>
    <div class="kong-specialist-title">Agentic AI & MCP</div>
    <div class="kong-specialist-body">MCP proxy patterns, OAuth2/PKCE for agents, agent-to-agent routing.</div>
  </a>
  <a class="kong-specialist" href="https://kong-grajesh-se.github.io/learn-kong-dev-portal/" target="_blank" rel="noopener">
    <div class="kong-specialist-emoji">🌐</div>
    <div class="kong-specialist-title">Developer Portal</div>
    <div class="kong-specialist-body">Publish APIs, OIDC SSO for portal users, self-service app registration, RBAC.</div>
  </a>
  <a class="kong-specialist" href="https://kong-grajesh-se.github.io/learn-kong-apiops-bootcamp/" target="_blank" rel="noopener">
    <div class="kong-specialist-emoji">🔄</div>
    <div class="kong-specialist-title">APIOps with decK</div>
    <div class="kong-specialist-body">GitOps for Kong config - GitHub Actions, quality gates, drift detection.</div>
  </a>
  <a class="kong-specialist" href="https://kong-grajesh-se.github.io/learn-insomnia/" target="_blank" rel="noopener">
    <div class="kong-specialist-emoji">🎮</div>
    <div class="kong-specialist-title">Insomnia</div>
    <div class="kong-specialist-body">API design, testing, and debugging with Insomnia.</div>
  </a>
  <a class="kong-specialist" href="https://kong-grajesh-se.github.io/bring-your-own-agent/" target="_blank" rel="noopener">
    <div class="kong-specialist-emoji">🤝</div>
    <div class="kong-specialist-title">Bring Your Own Agent</div>
    <div class="kong-specialist-body">Plug your own agent into Kong's MCP/AI infrastructure.</div>
  </a>
</div>

<style>
/* ───────────────────────────────────────────────────────────────────────────
   Home page - extensions to the Kong Design System.
   Uses tokens defined in docs/.vitepress/theme/style.css; no new hex codes.
   ─────────────────────────────────────────────────────────────────────────── */

.VPHome .VPHero + .VPFeatures { padding-top: 48px; }
.VPHero .image-container {
  width: 400px !important;
  height: 400px !important;
  border-radius: 0 !important;
  overflow: visible !important;
}
.VPHero .image-src {
  max-width: 400px !important;
  width: 400px !important;
}
@media (min-width: 960px) {
  .VPHero .image-container {
    width: 480px !important;
    height: 480px !important;
  }
  .VPHero .image-src {
    max-width: 480px !important;
    width: 480px !important;
  }
}

/* ── Kong version banner ─────────────────────────────────────────────────── */
.kong-version-banner {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 14px;
  max-width: 1100px;
  margin: 48px auto 0;
  padding: 14px 20px;
  background: linear-gradient(135deg, rgba(204, 255, 0, 0.07) 0%, rgba(204, 255, 0, 0.02) 100%);
  border: 1px solid rgba(204, 255, 0, 0.22);
  border-radius: 10px;
}
.kong-version-pill {
  display: inline-flex;
  align-items: center;
  padding: 6px 14px;
  background: var(--kong-lime);
  color: var(--kong-dark);
  font-family: 'Space Grotesk', sans-serif;
  font-weight: 700;
  font-size: 0.82rem;
  letter-spacing: 0.04em;
  border-radius: 999px;
  white-space: nowrap;
  flex-shrink: 0;
}
.kong-version-text {
  font-size: 0.9rem;
  line-height: 1.55;
  color: var(--kong-bay);
  flex: 1;
  min-width: 280px;
}
.kong-version-text strong { color: var(--kong-lime); font-weight: 700; }

/* ── Stats strip ─────────────────────────────────────────────────────────── */
.kong-stats-strip {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 16px;
  max-width: 1100px;
  margin: 56px auto 24px;
  padding: 24px;
  background: linear-gradient(135deg, rgba(204, 255, 0, 0.04) 0%, rgba(204, 255, 0, 0.01) 100%);
  border: 1px solid var(--kong-border-lime);
  border-radius: 12px;
}
.kong-stats-strip .stat { text-align: center; }
.kong-stats-strip .stat-num {
  font-family: 'Funnel Sans', sans-serif;
  font-size: clamp(1.8rem, 3vw, 2.4rem);
  font-weight: 800;
  letter-spacing: -0.03em;
  color: var(--kong-lime);
  line-height: 1.1;
}
.kong-stats-strip .stat-label {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 0.78rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--kong-bay);
  margin-top: 6px;
}
@media (max-width: 768px) {
  .kong-stats-strip { grid-template-columns: repeat(2, 1fr); }
}

/* ── Section spacing ─────────────────────────────────────────────────────── */
.VPHome .vp-doc h2 {
  font-family: 'Funnel Sans', sans-serif;
  font-size: clamp(1.5rem, 3vw, 1.9rem);
  font-weight: 800;
  letter-spacing: -0.02em;
  margin-top: 72px;
  margin-bottom: 24px;
  text-align: center;
  border-top: none;
  padding-top: 0;
}
.VPHome .vp-doc { max-width: 1152px; margin: 0 auto; padding: 0 24px; }
.VPHome .vp-doc hr { display: none; }

/* ── "Where to start" path cards ─────────────────────────────────────────── */
.kong-paths {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 16px;
  max-width: 1100px;
  margin: 0 auto;
}
.kong-path {
  display: block;
  padding: 24px;
  background: var(--kong-surface);
  border: 1px solid var(--kong-border-lime);
  border-radius: 10px;
  text-decoration: none !important;
  color: inherit;
  transition: transform 0.2s, border-color 0.2s, box-shadow 0.2s;
}
.kong-path:hover {
  transform: translateY(-3px);
  border-color: rgba(204, 255, 0, 0.30);
  box-shadow: 0 12px 40px rgba(204, 255, 0, 0.06);
}
.kong-path-emoji {
  font-size: 1.8rem;
  margin-bottom: 8px;
}
.kong-path-title {
  font-family: 'Funnel Sans', sans-serif;
  font-size: 1rem;
  font-weight: 700;
  color: var(--kong-lime);
  margin-bottom: 8px;
}
.kong-path-body {
  font-size: 0.88rem;
  line-height: 1.6;
  color: var(--kong-bay);
  margin-bottom: 12px;
}
.kong-path-body a {
  color: var(--kong-lime);
  border-bottom: 1px dashed rgba(204, 255, 0, 0.35);
  text-decoration: none;
}
.kong-path-cta {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 0.82rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  color: var(--kong-bay);
}
.kong-path:hover .kong-path-cta { color: var(--kong-lime); }

/* ── Specialist bootcamp cards ───────────────────────────────────────────── */
.kong-specialists {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 14px;
  max-width: 1100px;
  margin: 0 auto 80px;
}
.kong-specialist {
  display: block;
  padding: 18px;
  background: var(--kong-surface-3);
  border: 1px solid var(--kong-border-muted);
  border-radius: 10px;
  text-decoration: none !important;
  color: inherit;
  transition: transform 0.2s, border-color 0.2s, background 0.2s;
}
.kong-specialist:hover {
  transform: translateY(-2px);
  border-color: rgba(204, 255, 0, 0.25);
  background: var(--kong-surface);
}
.kong-specialist-emoji { font-size: 1.4rem; margin-bottom: 6px; }
.kong-specialist-title {
  font-family: 'Funnel Sans', sans-serif;
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--kong-lime);
  margin-bottom: 6px;
}
.kong-specialist-body {
  font-size: 0.82rem;
  line-height: 1.55;
  color: var(--kong-bay);
}
</style>
