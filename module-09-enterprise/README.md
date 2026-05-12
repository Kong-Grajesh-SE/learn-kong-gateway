# Module 09 - Enterprise & CI/CD

> Bring it all together: enterprise-grade identity with OIDC auth code flow, a public Developer Portal for API discovery, and a fully automated GitOps pipeline with decK and GitHub Actions.

## Overview

| | |
|---|---|
| **Duration** | ~2.5 hours |
| **Level** | Advanced |
| **Stack** | Kong Gateway Enterprise, Keycloak, Konnect, decK, GitHub Actions |
| **Outcome** | Production-ready gateway with SSO, Developer Portal, and automated CI/CD |

## Learning Objectives

- Configure OIDC Authorization Code Flow end-to-end
- Publish APIs to Kong's Developer Portal
- Implement decK-based GitOps for Kong configuration
- Set up GitHub Actions CI/CD with quality gates

## Enterprise Feature Highlights

| Feature | Description |
|---|---|
| **OIDC / OpenID Connect** | Enterprise SSO with any OIDC-compliant IdP |
| **RBAC** | Role-based access control for Kong Manager |
| **Developer Portal** | Self-service API catalog for external developers |
| **Kong Konnect** | Managed control plane + analytics dashboard |
| **decK GitOps** | Declarative config management, CI/CD integration |
| **Audit Logs** | Full audit trail of all admin operations |
| **Secrets Manager** | HashiCorp Vault, AWS Secrets Manager integration |

## Labs

| Lab | Topic |
|---|---|
| [09-A: OIDC Auth Code Flow](/module-09-enterprise/labs/09-oidc-auth-code) | Full browser-based SSO with Keycloak |
| [09-B: Developer Portal](/module-09-enterprise/labs/09-dev-portal) | Publish APIs, manage teams, customise portal |
| [09-C: decK & CI/CD](/module-09-enterprise/labs/09-deck-cicd) | GitHub Actions pipeline with quality gates |
| [09-D: RBAC & Teams](/module-09-enterprise/labs/09-rbac-teams) | Kong Manager RBAC, consumer groups, team isolation |

## decK GitOps Architecture

```
GitHub Repository (source of truth)
    ├── kong-config/
    │   ├── services/
    │   │   ├── mytravel-api.yaml
    │   │   ├── ai-gateway.yaml
    │   │   └── mcp-services.yaml
    │   ├── global/
    │   │   ├── plugins.yaml
    │   │   └── consumers.yaml
    │   └── environments/
    │       ├── dev.env
    │       ├── staging.env
    │       └── prod.env
    └── .github/workflows/
        ├── validate.yml       ← PR: lint + diff
        └── deploy.yml         ← merge: sync to Kong
```

## Resources

- [Kong Konnect](https://cloud.konghq.com/)
- [Developer Portal docs](https://developer.konghq.com/dev-portal/)
- [decK GitOps guide](https://developer.konghq.com/deck/)
- [Kong RBAC](https://developer.konghq.com/gateway/kong-manager/rbac/)

---

*Previous: [Module 08](/module-08-agentic-mcp/) · You've completed the bootcamp! 🎉*
