---
layout: home

hero:
  name: "Kong API Gateway"
  text: "Bootcamp"
  tagline: "Core → Auth → Traffic → Transform → Observe → AI → Agents → Enterprise. Nine hands-on modules on Konnect with real workloads."
  image:
    src: /kong-gateway-logo.svg
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
    details: "Protect APIs with Key Auth, JWT, and OIDC. Configure consumers with credentials and integrate Keycloak for enterprise identity."
    link: /module-03-authentication/
    linkText: Secure APIs →

  - icon: 🚦
    title: "04 - Traffic Control"
    details: "Rate limit by consumer tier, IP, or header. Configure ACL groups, circuit breakers, and health-check based routing."
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

  - icon: 🤖
    title: "07 - AI Gateway"
    details: "Route LLM traffic across Ollama and OpenAI. Add semantic caching with Redis, prompt injection guards, PII sanitization, and named templates."
    link: /module-07-ai-gateway/
    linkText: Build AI APIs →

  - icon: 🛠️
    title: "08 - Agentic AI & MCP"
    details: "Proxy MCP tool calls without touching upstream code. Secure AI agents with OAuth2 + PKCE. Build A2A multi-agent pipelines with OTel tracing."
    link: /module-08-agentic-mcp/
    linkText: Enable agents →

  - icon: 🏢
    title: "09 - Enterprise & CI/CD"
    details: "OIDC auth-code flow, Developer Portal with self-service app registration, decK GitOps pipeline in GitHub Actions, RBAC workspaces."
    link: /module-09-enterprise/
    linkText: Go enterprise →
---

<style>
.VPHome .VPHero + .VPFeatures { padding-top: 48px; }
</style>
