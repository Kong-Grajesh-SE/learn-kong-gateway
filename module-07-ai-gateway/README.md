# Module 07 - AI Gateway

> Kong AI Gateway is a purpose-built set of plugins that brings enterprise-grade controls to LLM traffic: routing, prompt security, caching, cost management, and PII protection - all in a unified gateway.

## Overview

| | |
|---|---|
| **Duration** | ~2.5 hours |
| **Level** | Advanced |
| **Stack** | Kong Gateway, Ollama (local LLM), Redis, Docker |
| **Outcome** | AI proxy with guards, semantic cache, prompt templates, PII sanitizer |

## Learning Objectives

- Route LLM traffic through Kong with multi-provider support
- Block prompt injection and jailbreak attempts with ai-prompt-guard
- Reduce LLM costs with semantic caching via Redis
- Sanitize PII from prompts and responses with ai-sanitizer
- Create reusable named prompt templates

## AI Gateway Architecture

```
Client → POST /ai/proxy/chat
              ↓
        Kong AI Plugin Chain:
        ┌─────────────────────────────────┐
        │ 1. ai-prompt-template           │ ← resolve named templates
        │ 2. ai-prompt-guard              │ ← block malicious prompts
        │ 3. ai-semantic-prompt-guard     │ ← semantic similarity checks
        │ 4. ai-rate-limiting-advanced    │ ← token-based rate limiting
        │ 5. ai-sanitizer (pre-request)   │ ← redact PII in prompt
        │ 6. ai-semantic-cache            │ ← return cached response if match
        │ 7. ai-prompt-compressor         │ ← compress long prompts
        │ 8. ai-proxy-advanced            │ ← forward to LLM provider
        │ 9. ai-sanitizer (post-response) │ ← redact PII in response
        └─────────────────────────────────┘
              ↓
     LLM Provider (Ollama / OpenAI / Azure / Anthropic)
```

## Supported LLM Providers

| Provider | Model Examples |
|---|---|
| **OpenAI** | `gpt-4o`, `gpt-4-turbo`, `gpt-3.5-turbo` |
| **Azure OpenAI** | `gpt-4`, `gpt-35-turbo` |
| **Anthropic** | `claude-3-5-sonnet`, `claude-3-opus` |
| **Mistral** | `mistral-large`, `mistral-small` |
| **Cohere** | `command-r-plus` |
| **Ollama** | `llama3.2`, `mistral`, `qwen2.5` (local) |
| **Hugging Face** | Any inference endpoint |
| **Bedrock** | AWS Bedrock models |

## AI Plugins Summary

| Plugin | Status | Purpose |
|---|---|---|
| `ai-proxy-advanced` | ✅ Core | Multi-provider routing, audit logging |
| `ai-prompt-decorator` | ✅ Core | Inject system prompts on every request |
| `ai-prompt-guard` | 🛡️ Security | Block regex-matched prompt patterns |
| `ai-semantic-prompt-guard` | 🛡️ Security | Semantic similarity blocking |
| `ai-semantic-response-guard` | 🛡️ Security | Block harmful responses |
| `ai-rate-limiting-advanced` | 🚦 Traffic | Token-aware rate limiting |
| `ai-semantic-cache` | ⚡ Performance | Redis-based semantic response caching |
| `ai-prompt-compressor` | ⚡ Performance | Reduce prompt tokens with LLMLingua |
| `ai-sanitizer` | 🔒 Compliance | PII detection and redaction |
| `ai-prompt-template` | 🎨 UX | Named reusable prompt templates |

## Labs

| Lab | Topic |
|---|---|
| [07-A: AI Proxy Advanced](/module-07-ai-gateway/labs/07-ai-proxy) | Set up the AI service with Ollama, configure ai-proxy-advanced |
| [07-B: Prompt Guard](/module-07-ai-gateway/labs/07-prompt-guard) | Block injection attacks and jailbreaks |
| [07-C: Semantic Cache](/module-07-ai-gateway/labs/07-semantic-cache) | Cut LLM costs with Redis vector caching |
| [07-D: Prompt Templates](/module-07-ai-gateway/labs/07-prompt-templates) | Build reusable named prompt templates |
| [07-E: PII Sanitizer](/module-07-ai-gateway/labs/07-pii-sanitizer) | Detect and redact PII with ai-sanitizer |

## decK Reference: ai-gateway.yaml

The full AI gateway config from the demo repo:

```yaml
_format_version: '3.0'
services:
  - name: AIManagerModelService
    host: ollama             # or OpenAI API
    port: 11434
    protocol: http
    routes:
      - name: AIManagerModelService_chat
        paths: [/ai/proxy/chat]
        methods: [POST]
        plugins:
          - name: ai-proxy-advanced    # see labs/07-ai-proxy
          - name: ai-prompt-decorator  # inject system prompt
          - name: ai-prompt-guard      # see labs/07-prompt-guard
          - name: ai-semantic-cache    # see labs/07-semantic-cache
          - name: ai-prompt-template   # see labs/07-prompt-templates
          - name: ai-sanitizer         # see labs/07-pii-sanitizer
```

## Resources

- [AI Gateway overview](https://developer.konghq.com/ai-gateway/)
- [ai-proxy-advanced plugin](https://developer.konghq.com/plugins/ai-proxy-advanced/)
- [ai-prompt-guard plugin](https://developer.konghq.com/plugins/ai-prompt-guard/)
- [ai-semantic-cache plugin](https://developer.konghq.com/plugins/ai-semantic-cache/)

---

*Previous: [Module 06](/module-06-observability/) · Next: [Module 08 - Agentic AI & MCP →](/module-08-agentic-mcp/)*
