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
