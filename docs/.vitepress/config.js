import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'Kong API Gateway Bootcamp',
  description:
    'Kong Partner Enablement - 9 hands-on modules for mastering Kong Gateway. Core → Auth → Traffic → AI → Enterprise.',

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
    'module-07-ai-gateway/README.md':         'module-07-ai-gateway/index.md',
    'module-08-agentic-mcp/README.md':        'module-08-agentic-mcp/index.md',
    'module-09-enterprise/README.md':         'module-09-enterprise/index.md',
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
    ['link', { rel: 'icon', href: '/api-gateway-bootcamp/favicon.png', type: 'image/png' }],
    ['meta', { name: 'theme-color', content: '#001408' }],
    ['meta', { property: 'og:title', content: 'Kong API Gateway Bootcamp' }],
    ['meta', { property: 'og:description', content: '9 hands-on modules for mastering Kong Gateway' }],
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
    logo: '/logomark.svg',
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
          { text: '🤖 07 - AI Gateway',                 link: '/module-07-ai-gateway/' },
          { text: '🛠️ 08 - Agentic AI & MCP',           link: '/module-08-agentic-mcp/' },
          { text: '🏢 09 - Enterprise & CI/CD',         link: '/module-09-enterprise/' },
        ],
      },
      {
        text: '🔗 Resources',
        items: [
          { text: '📖 Kong Docs',    link: 'https://developer.konghq.com/gateway/', target: '_blank' },
          { text: '🧩 Plugin Hub',   link: 'https://developer.konghq.com/plugins/', target: '_blank' },
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
          { text: '📄 OpenAPI Specs',        link: '/api-specs' },
        ],
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
        text: '🤖 07 - AI Gateway',
        collapsed: true,
        items: [
          { text: '📋 Overview',                    link: '/module-07-ai-gateway/' },
          { text: '🧠 Lab: AI Proxy Advanced',      link: '/module-07-ai-gateway/labs/07-ai-proxy' },
          { text: '🛡️ Lab: Prompt Guard',           link: '/module-07-ai-gateway/labs/07-prompt-guard' },
          { text: '⚡ Lab: Semantic Cache',          link: '/module-07-ai-gateway/labs/07-semantic-cache' },
          { text: '📄 Lab: Prompt Templates',       link: '/module-07-ai-gateway/labs/07-prompt-templates' },
          { text: '🔒 Lab: PII Sanitizer',          link: '/module-07-ai-gateway/labs/07-pii-sanitizer' },
        ],
      },
      {
        text: '🛠️ 08 - Agentic AI & MCP',
        collapsed: true,
        items: [
          { text: '📋 Overview',               link: '/module-08-agentic-mcp/' },
          { text: '🔌 Lab: MCP Proxy',         link: '/module-08-agentic-mcp/labs/08-mcp-proxy' },
          { text: '🔐 Lab: MCP + OAuth2',      link: '/module-08-agentic-mcp/labs/08-mcp-oauth2' },
          { text: '🤝 Lab: A2A Agents',        link: '/module-08-agentic-mcp/labs/08-a2a-agents' },
        ],
      },
      {
        text: '🏢 09 - Enterprise & CI/CD',
        collapsed: true,
        items: [
          { text: '📋 Overview',               link: '/module-09-enterprise/' },
          { text: '🔐 Lab: OIDC Auth Code',    link: '/module-09-enterprise/labs/09-oidc-auth-code' },
          { text: '🌐 Lab: Developer Portal',  link: '/module-09-enterprise/labs/09-dev-portal' },
          { text: '🔄 Lab: decK & CI/CD',      link: '/module-09-enterprise/labs/09-deck-cicd' },
          { text: '👥 Lab: RBAC & Teams',      link: '/module-09-enterprise/labs/09-rbac-teams' },
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
