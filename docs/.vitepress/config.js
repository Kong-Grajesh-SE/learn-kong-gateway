import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'Kong API Gateway Bootcamp',
  description:
    'Kong Partner Enablement - 8 hands-on modules for mastering Kong Gateway, ending in a 15-step production capstone.',

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

  // Dead-link checker doesn't understand the README.md → index.md rewrite combined
  // with cleanUrls - it resolves /module-NN-foo/ to /module-NN-foo/index and fails to
  // find the file even though the page renders fine at runtime. Disabling the check.
  ignoreDeadLinks: true,

  // ── Rewrites: serve README.md as each module's index page ──────────────────
  rewrites: {
    'module-01-orientation/README.md':        'module-01-orientation/index.md',
    'module-02-core-gateway/README.md':       'module-02-core-gateway/index.md',
    'module-03-authentication/README.md':     'module-03-authentication/index.md',
    'module-04-traffic-control/README.md':    'module-04-traffic-control/index.md',
    'module-05-transformations/README.md':    'module-05-transformations/index.md',
    'module-06-observability/README.md':      'module-06-observability/index.md',
    'module-07-enterprise/README.md':         'module-07-enterprise/index.md',
    'module-08-capstone/README.md':           'module-08-capstone/index.md',
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
          { text: '🧭 01 - Your First Gateway',         link: '/module-01-orientation/' },
          { text: '🔀 02 - Routing & Topology',         link: '/module-02-core-gateway/' },
          { text: '🔑 03 - Easy Wins',                  link: '/module-03-authentication/' },
          { text: '🚦 04 - Traffic & Resilience',       link: '/module-04-traffic-control/' },
          { text: '🔧 05 - Transformations',            link: '/module-05-transformations/' },
          { text: '📊 06 - Observability',              link: '/module-06-observability/' },
          { text: '🔐 07 - Enterprise & Advanced',      link: '/module-07-enterprise/' },
          { text: '🏁 08 - Capstone',                   link: '/module-08-capstone/' },
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
          { text: '🤝 Bring Your Own Agent',   link: 'https://kong-grajesh-se.github.io/bring-your-own-agent/', target: '_blank' },
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
          { text: '📋 Overview',                              link: '/module-01-orientation/' },
          { text: '🚀 Lab: Quick Start (Serverless)',         link: '/module-01-orientation/labs/01-quick-start' },
          { text: '🐳 Lab: Hybrid Docker Setup (optional)',   link: '/module-01-orientation/labs/01-hybrid-docker-setup' },
        ],
      },
      {
        text: '🔀 02 - Routing & Topology',
        collapsed: true,
        items: [
          { text: '📋 Overview',                              link: '/module-02-core-gateway/' },
          { text: '🔗 Lab: Multi-Service Routing',            link: '/module-02-core-gateway/labs/02-services-routes' },
          { text: '⚖️ Lab: Upstreams & Health Checks',        link: '/module-02-core-gateway/labs/02-upstreams' },
        ],
      },
      {
        text: '🔑 03 - Easy Wins',
        collapsed: true,
        items: [
          { text: '📋 Overview',                                   link: '/module-03-authentication/' },
          { text: '🗝️ Lab: Consumers & key-auth',                   link: '/module-03-authentication/labs/03-key-auth' },
          { text: '⚡ Lab: CORS, IP Restriction, Correlation ID',  link: '/module-03-authentication/labs/03-easy-wins' },
        ],
      },
      {
        text: '🚦 04 - Traffic & Resilience',
        collapsed: true,
        items: [
          { text: '📋 Overview',              link: '/module-04-traffic-control/' },
          { text: '⏱️ Lab: Rate Limiting',    link: '/module-04-traffic-control/labs/04-rate-limiting' },
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
        text: '🔐 07 - Enterprise & Advanced',
        collapsed: true,
        items: [
          { text: '📋 Overview',                              link: '/module-07-enterprise/' },
          { text: '🔏 Lab: Advanced Auth (JWT + HMAC)',       link: '/module-07-enterprise/labs/07-advanced-auth' },
          { text: '👥 Lab: Consumer Groups & ACL',            link: '/module-07-enterprise/labs/07-consumer-groups-acl' },
          { text: '🔐 Lab: OIDC Auth Code Flow',              link: '/module-07-enterprise/labs/07-oidc-auth-code' },
          { text: '🔑 Lab: Upstream OAuth (M2M)',             link: '/module-07-enterprise/labs/07-upstream-oauth' },
          { text: '⚖️ Lab: OPA Policy-as-Code',              link: '/module-07-enterprise/labs/07-opa' },
          { text: '🛠️ Lab: Datakit Orchestration',           link: '/module-07-enterprise/labs/07-datakit' },
          { text: '🏛️ Lab: Kong Manager RBAC',                link: '/module-07-enterprise/labs/07-rbac-teams' },
        ],
      },
      {
        text: '🏁 08 - Capstone',
        collapsed: true,
        items: [
          { text: '📋 Overview',                              link: '/module-08-capstone/' },
          { text: '🏆 Capstone: Production Gateway',          link: '/module-08-capstone/labs/08-capstone' },
        ],
      },
    ],

    // Edit link pointing to GitHub
    editLink: {
      pattern: 'https://github.com/Kong-Grajesh-SE/learn-kong-gateway/edit/main/:path',
      text: 'Edit this page on GitHub',
    },

    // Last updated timestamp
    lastUpdated: {
      text: 'Updated',
      formatOptions: { dateStyle: 'medium' },
    },

    // Social links in nav
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Kong-Grajesh-SE/learn-kong-gateway' },
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
