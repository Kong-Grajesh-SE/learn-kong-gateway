---
layout: home

hero:
  name: "Kong API Gateway"
  text: "Bootcamp"
  tagline: "Core → Auth → Traffic → Transform → Observe → Enterprise. Six hands-on modules on Konnect. Then go deep with our specialist bootcamps."
  image:
    src: /kong-logomark-lime.svg
    alt: Kong Gateway
  actions:
    - theme: brand
      text: "✅ Prerequisites"
      link: /prerequisites
    - theme: brand
      text: "Start Module 01 →"
      link: /module-01-orientation/
    - theme: alt
      text: "🏗️ Deployment Options"
      link: /deployment-overview
    - theme: alt
      text: "☁️ Konnect ↗"
      link: https://cloud.konghq.com

features:
  - icon: 🧭
    title: "01 - Orientation & Setup"
    details: "Connect a local Data Plane to Konnect (Hybrid mode). Explore Kong Manager, verify ports, and make your first proxied request to httpbin.konghq.com."
    link: /module-01-orientation/
    linkText: Start here →

  - icon: 🔀
    title: "02 - Core Gateway Concepts"
    details: "Services, Routes, Upstreams, and Consumers. Load balance across httpbin.konghq.com and kong-air. Manage everything declaratively with decK."
    link: /module-02-core-gateway/
    linkText: Learn the core →

  - icon: 🔑
    title: "03 - Authentication Plugins"
    details: "Protect APIs with Key Auth, JWT, HMAC, and OIDC. Configure consumers with credentials and integrate Keycloak for enterprise identity."
    link: /module-03-authentication/
    linkText: Secure APIs →

  - icon: 🚦
    title: "04 - Traffic Control"
    details: "Rate limit by consumer tier, IP, or header. Configure ACL groups, circuit breakers, CORS, IP restriction, and proxy caching."
    link: /module-04-traffic-control/
    linkText: Control traffic →

  - icon: 🔧
    title: "05 - Transformations"
    details: "Reshape requests and responses in-flight. Inject headers, rewrite bodies, add correlation IDs, and chain multiple transformers."
    link: /module-05-transformations/
    linkText: Transform payloads →

  - icon: 📊
    title: "06 - Observability"
    details: "Stream structured logs via HTTP, scrape Prometheus metrics, and send distributed traces via OpenTelemetry to Jaeger."
    link: /module-06-observability/
    linkText: Observe everything →

  - icon: 🔐
    title: "07 - Enterprise Features"
    details: "OIDC Auth Code Flow, RBAC workspaces, Upstream OAuth (M2M token injection), OPA policy-based authorization, and Datakit multi-step workflow orchestration."
    link: /module-07-enterprise/
    linkText: Go enterprise →

  - icon: 🤖
    title: "AI Gateway Bootcamp ↗"
    details: "Deep-dive: LLM proxy, prompt injection guards, semantic caching, PII sanitization, and prompt templates. Ollama, OpenAI, Azure, Anthropic."
    link: https://kong-grajesh-se.github.io/learn-kong-ai-gateway/
    linkText: Go to AI Gateway →

  - icon: 🛠️
    title: "Agentic AI & MCP Bootcamp ↗"
    details: "MCP proxy, OAuth2/PKCE for agents, Agent-to-Agent routing. Connect VS Code Copilot and Claude Desktop to Kong-protected MCP servers."
    link: https://kong-grajesh-se.github.io/learn-kong-agentic-bootcamp/
    linkText: Go to Agentic AI →

  - icon: 🌐
    title: "Developer Portal Bootcamp ↗"
    details: "Publish APIs to the Konnect Developer Portal. OIDC SSO with Keycloak, self-service app registration, RBAC teams and namespaces."
    link: https://kong-grajesh-se.github.io/learn-kong-dev-portal/
    linkText: Go to Dev Portal →

  - icon: 🔄
    title: "APIOps Bootcamp ↗"
    details: "GitOps with decK - Git as source of truth. GitHub Actions CI/CD: validate on PR, diff preview, sync to Konnect on merge."
    link: https://kong-grajesh-se.github.io/learn-kong-apiops-bootcamp/
    linkText: Go to APIOps →

  - icon: 🎮
    title: "Insomnia Bootcamp ↗"
    details: "Master API testing with Insomnia - design, debug, and test REST, GraphQL, and gRPC APIs."
    link: https://kong-grajesh-se.github.io/learn-insomnia/
    linkText: Go to Insomnia →

  - icon: 🤝
    title: "Bring Your Own Agent Bootcamp ↗"
    details: "9 modules · 2 days · LLM · MCP · A2A · OAuth 2.1 · OPA. Govern every AI agent at enterprise scale — without changing a line of agent code."
    link: https://kong-grajesh-se.github.io/bring-your-own-agent/
    linkText: Go to BYOA →
---

<style>
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
</style>
