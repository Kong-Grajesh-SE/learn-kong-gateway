import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'Kong API Gateway Bootcamp',
  description:
    'Kong Partner Enablement - 7 hands-on modules for mastering Kong Gateway. Core → Auth → Traffic → Transform → Observe → OIDC & RBAC.',

  // ── Source & output ─────────────────────────────────────────────────────────
  // srcDir '..' means VitePress reads Markdown from the repo root,
  // so all existing module files are served without duplication.
  srcDir: '..',
  outDir: '../dist',
  cacheDir: '../.vitepress-cache',

  // GitHub Pages base path (repo name)
  base: '/learn-kong-gateway/',

  // Default to dark mode (user can still toggle)
  appearance: 'force-dark',

  cleanUrls: true,

  // Ignore dead links to non-Markdown files
  ignoreDeadLinks: [
    /\.(sh|yaml|yml|json|env|xml|png|svg)$/,
    /^http:\/\/localhost/,
  ],

  // ── Rewrites: serve README.md as each module's index page ──────────────────
  rewrites: {
    'module-01-orientation/README.md':        'module-01-orientation/index.md',
    'module-02-core-gateway/README.md':       'module-02-core-gateway/index.md',
    'module-03-authentication/README.md':     'module-03-authentication/index.md',
    'module-04-traffic-control/README.md':    'module-04-traffic-control/index.md',
    'module-05-transformations/README.md':    'module-05-transformations/index.md',
    'module-06-observability/README.md':      'module-06-observability/index.md',
    'module-07-enterprise/README.md':         'module-07-enterprise/index.md',
  },

  srcExclude: [
    'node_modules/**',
    'dist/**',
    'docs/.vitepress/**',
    '.vitepress-cache/**',
    'README.md',
    '.github/**',
  ],

  // ── Head tags ────────────────────────────────────────────────────────────────
  head: [
    ['link', { rel: 'icon',           href: '/learn-kong-gateway/favicon.png', type: 'image/png', sizes: '32x32' }],
    ['link', { rel: 'shortcut icon',  href: '/learn-kong-gateway/favicon.png', type: 'image/png' }],
    ['link', { rel: 'apple-touch-icon', href: '/learn-kong-gateway/favicon.png' }],
    ['meta', { name: 'theme-color', content: '#000F06' }],
    ['meta', { property: 'og:title', content: 'Kong API Gateway Bootcamp' }],
    ['meta', { property: 'og:description', content: '9 hands-on modules for mastering Kong Gateway on Konnect' }],
    ['meta', { property: 'og:image', content: '/learn-kong-gateway/kong-gateway-logo.svg' }],
  ],

  // ── Markdown options ─────────────────────────────────────────────────────────
  markdown: {
    theme: {
      light: 'github-light',
      dark: 'one-dark-pro',
    },
    lineNumbers: true,
  },

  // ── Theme config ─────────────────────────────────────────────────────────────
  themeConfig: {
    logo: '/kong-logomark-lime.svg',
    siteTitle: 'API Gateway Bootcamp',

    // Top navigation
    nav: [
      { text: '🏠 Home', link: '/' },
      {
        text: '🚀 Getting Started',
        items: [
          { text: '✅ Prerequisites',        link: '/prerequisites' },
          { text: '🏗️ Deployment Options',   link: '/deployment-overview' },
          { text: '📄 OpenAPI Specs',        link: '/api-specs' },
        ],
      },
      {
        text: '📚 Modules',
        items: [
          { text: '🧭 01 - Orientation & Setup',        link: '/module-01-orientation/' },
          { text: '🔀 02 - Core Gateway Concepts',      link: '/module-02-core-gateway/' },
          { text: '🔑 03 - Authentication Plugins',     link: '/module-03-authentication/' },
          { text: '🚦 04 - Traffic Control',            link: '/module-04-traffic-control/' },
          { text: '🔧 05 - Transformations',            link: '/module-05-transformations/' },
          { text: '📊 06 - Observability',              link: '/module-06-observability/' },
          { text: '🔐 07 - Enterprise Features',        link: '/module-07-enterprise/' },
        ],
      },
      {
        text: '🚀 Specialist Bootcamps',
        items: [
          { text: '🤖 AI Gateway Bootcamp',    link: 'https://kong-grajesh-se.github.io/learn-kong-ai-gateway/', target: '_blank' },
          { text: '🛠️ Agentic AI & MCP',       link: 'https://kong-grajesh-se.github.io/learn-kong-agentic-bootcamp/', target: '_blank' },
          { text: '🌐 Developer Portal',       link: 'https://kong-grajesh-se.github.io/learn-kong-dev-portal/', target: '_blank' },
          { text: '🔄 APIOps with decK',       link: 'https://kong-grajesh-se.github.io/learn-kong-apiops-bootcamp/', target: '_blank' },
          { text: '🎮 Insomnia Bootcamp',      link: 'https://kong-grajesh-se.github.io/learn-insomnia/', target: '_blank' },
        ],
      },
      {
        text: '🔗 Resources',
        items: [
          { text: '📖 Kong Docs',    link: 'https://developer.konghq.com/gateway/', target: '_blank' },
          { text: '🧩 Plugin Hub',   link: 'https://developer.konghq.com/plugins/', target: '_blank' },
          { text: '🧩 Plugin Reference', link: '/plugin-reference' },
          { text: '☁️ Konnect',      link: 'https://cloud.konghq.com', target: '_blank' },
          { text: '🎮 Insomnia',     link: 'https://insomnia.rest', target: '_blank' },
        ],
      },
    ],

    // Sidebar - one group per module, collapsed by default except first
    sidebar: [
      {
        text: '🚀 Getting Started',
        collapsed: false,
        items: [
          { text: '✅ Prerequisites',        link: '/prerequisites' },
          { text: '🏗️ Deployment Options',   link: '/deployment-overview' },
          { text: '📄 OpenAPI Specs',        link: '/api-specs' },          { text: '🧩 Plugin Reference',     link: '/plugin-reference' },        ],
      },
      {
        text: '🧭 01 - Orientation & Setup',
        collapsed: false,
        items: [
          { text: '📋 Overview',              link: '/module-01-orientation/' },
          { text: '🔧 Lab: Konnect + Data Plane', link: '/module-01-orientation/labs/01-install-verify' },
          { text: '🚀 Lab: First API Call',   link: '/module-01-orientation/labs/01-first-api-call' },
        ],
      },
      {
        text: '🔀 02 - Core Gateway Concepts',
        collapsed: true,
        items: [
          { text: '📋 Overview',                         link: '/module-02-core-gateway/' },
          { text: '🔗 Lab: Services & Routes',           link: '/module-02-core-gateway/labs/02-services-routes' },
          { text: '⚖️ Lab: Upstreams & Load Balancing',  link: '/module-02-core-gateway/labs/02-upstreams' },
          { text: '👤 Lab: Consumers',                   link: '/module-02-core-gateway/labs/02-consumers' },
        ],
      },
      {
        text: '🔑 03 - Authentication Plugins',
        collapsed: true,
        items: [
          { text: '📋 Overview',               link: '/module-03-authentication/' },
          { text: '🗝️ Lab: Key Authentication', link: '/module-03-authentication/labs/03-key-auth' },
          { text: '🎟️ Lab: JWT Auth',           link: '/module-03-authentication/labs/03-jwt-auth' },
          { text: '🔐 Lab: OIDC / Keycloak',   link: '/module-03-authentication/labs/03-oidc-keycloak' },
          { text: '🔏 Lab: HMAC Auth',          link: '/module-03-authentication/labs/03-hmac-auth' },
        ],
      },
      {
        text: '🚦 04 - Traffic Control',
        collapsed: true,
        items: [
          { text: '📋 Overview',              link: '/module-04-traffic-control/' },
          { text: '⏱️ Lab: Rate Limiting',    link: '/module-04-traffic-control/labs/04-rate-limiting' },
          { text: '⚡ Lab: Circuit Breaker',  link: '/module-04-traffic-control/labs/04-circuit-breaker' },
          { text: '👥 Lab: ACL Groups',       link: '/module-04-traffic-control/labs/04-acl' },
          { text: '🌐 Lab: CORS',             link: '/module-04-traffic-control/labs/04-cors' },
          { text: '🚫 Lab: IP Restriction',   link: '/module-04-traffic-control/labs/04-ip-restriction' },
          { text: '⚡ Lab: Proxy Cache',      link: '/module-04-traffic-control/labs/04-proxy-cache' },
        ],
      },
      {
        text: '🔧 05 - Transformations',
        collapsed: true,
        items: [
          { text: '📋 Overview',                        link: '/module-05-transformations/' },
          { text: '📥 Lab: Request Transformer',        link: '/module-05-transformations/labs/05-request-transformer' },
          { text: '📤 Lab: Response Transformer',       link: '/module-05-transformations/labs/05-response-transformer' },
          { text: '🔗 Lab: Correlation ID',             link: '/module-05-transformations/labs/05-correlation-id' },
        ],
      },
      {
        text: '📊 06 - Observability',
        collapsed: true,
        items: [
          { text: '📋 Overview',             link: '/module-06-observability/' },
          { text: '📝 Lab: HTTP Logging',    link: '/module-06-observability/labs/06-http-logging' },
          { text: '📈 Lab: Prometheus',      link: '/module-06-observability/labs/06-prometheus' },
          { text: '🔭 Lab: OpenTelemetry',   link: '/module-06-observability/labs/06-opentelemetry' },
        ],
      },
      {
        text: '🔐 07 - Enterprise Features',
        collapsed: true,
        items: [
          { text: '📋 Overview',                  link: '/module-07-enterprise/' },
          { text: '🔐 Lab: OIDC Auth Code',       link: '/module-07-enterprise/labs/07-oidc-auth-code' },
          { text: '👥 Lab: RBAC & Teams',         link: '/module-07-enterprise/labs/07-rbac-teams' },
          { text: '🔑 Lab: Upstream OAuth',       link: '/module-07-enterprise/labs/07-upstream-oauth' },
          { text: '⚖️ Lab: OPA Authorization',    link: '/module-07-enterprise/labs/07-opa' },
          { text: '🛠️ Lab: Datakit',              link: '/module-07-enterprise/labs/07-datakit' },
        ],
      },
    ],

    // Edit link pointing to GitHub
    editLink: {
      pattern: 'https://github.com/Kong-Grajesh-SE/api-gateway-bootcamp/edit/main/:path',
      text: 'Edit this page on GitHub',
    },

    // Last updated timestamp
    lastUpdated: {
      text: 'Updated',
      formatOptions: { dateStyle: 'medium' },
    },

    // Social links in nav
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Kong-Grajesh-SE/api-gateway-bootcamp' },
    ],

    // Footer
    footer: {
      message: 'Kong API Gateway Bootcamp - Partner Enablement',
      copyright: '© Kong Inc. 2026 - The AI Connectivity Company',
    },

    // Built-in local search (no Algolia needed)
    search: {
      provider: 'local',
    },
  },
})
