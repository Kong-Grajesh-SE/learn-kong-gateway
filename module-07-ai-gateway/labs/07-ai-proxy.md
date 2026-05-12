# Lab 07-A - AI Proxy Advanced

> **Goal:** Configure Kong as an AI gateway proxy using `ai-proxy-advanced`. Route requests to a local Ollama instance, with audit logging and multi-provider failover.

## Step 1 - Start Ollama (local LLM)

```bash
# Pull and run Ollama
docker run -d --name ollama \
  --network kong-net \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  ollama/ollama:latest

# Pull a model
docker exec ollama ollama pull llama3.2

# Test Ollama directly
curl -s http://localhost:11434/api/chat \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"Hello!"}],"stream":false}' \
  | jq '.message.content'
```

## Step 2 - Create the AI service

```bash
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AIManagerModelService",
    "host": "ollama",
    "port": 11434,
    "protocol": "http"
  }' | jq '{id, name}'

# Create the AI route
curl -s -X POST http://localhost:8001/services/AIManagerModelService/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-chat-route",
    "paths": ["/ai/proxy/chat"],
    "methods": ["POST"],
    "strip_path": false
  }' | jq '{id, name}'
```

## Step 3 - Configure ai-proxy-advanced

::: code-group

```bash [Admin API - Ollama]
curl -s -X POST http://localhost:8001/routes/ai-chat-route/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-proxy-advanced",
    "config": {
      "targets": [
        {
          "route_type": "llm/v1/chat",
          "auth": {
            "allow_override": false
          },
          "model": {
            "provider": "ollama",
            "name": "llama3.2",
            "options": {
              "ollama": {
                "upstream_url": "http://ollama:11434"
              }
            }
          }
        }
      ],
      "logging": {
        "log_statistics": true,
        "log_payloads": false
      }
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML - OpenAI]
plugins:
  - name: ai-proxy-advanced
    config:
      targets:
        - route_type: llm/v1/chat
          auth:
            header_name: Authorization
            header_value: "Bearer ${OPENAI_API_KEY}"
            allow_override: false
          model:
            provider: openai
            name: gpt-4o-mini
            options:
              max_tokens: 1024
              temperature: 0.7
      logging:
        log_statistics: true
        log_payloads: false
```

:::

## Step 4 - Test the AI proxy

```bash
# Basic chat request
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "What is Kong Gateway in one sentence?"}
    ]
  }' | jq '.choices[0].message.content'

# With system context
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "role": "system",
        "content": "You are a Kong Gateway expert. Answer concisely."
      },
      {
        "role": "user",
        "content": "Explain the difference between a Service and an Upstream."
      }
    ],
    "temperature": 0.3
  }' | jq '.choices[0].message.content'
```

## Step 5 - ai-prompt-decorator (always inject system prompt)

```bash
curl -s -X POST http://localhost:8001/routes/ai-chat-route/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-prompt-decorator",
    "config": {
      "prompts": {
        "prepend": [
          {
            "role": "system",
            "content": "You are a helpful Kong Gateway assistant. Always mention that Kong is the AI Connectivity Company. Be concise and accurate."
          }
        ],
        "append": []
      }
    }
  }' | jq '{id, name}'

# Test - system prompt is injected even without one in the request
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"What is Kong?"}]}' \
  | jq '.choices[0].message.content'
```

## Step 6 - Multi-provider failover

```yaml
# ai-proxy-advanced with OpenAI primary + Ollama fallback
config:
  targets:
    - route_type: llm/v1/chat
      auth:
        header_name: Authorization
        header_value: "Bearer ${OPENAI_API_KEY}"
      model:
        provider: openai
        name: gpt-4o-mini
    - route_type: llm/v1/chat      # fallback
      auth:
        allow_override: false
      model:
        provider: ollama
        name: llama3.2
        options:
          ollama:
            upstream_url: "http://ollama:11434"
  balancer:
    algorithm: lowest-usage       # or: round-robin, lowest-latency
```

## Step 7 - Check AI statistics in logs

```bash
curl -s http://localhost:8001/logs | jq '.[] | select(.ai != null) | {
  model: .ai.proxy.model,
  input_tokens: .ai.usage.prompt_tokens,
  output_tokens: .ai.usage.completion_tokens,
  total_tokens: .ai.usage.total_tokens,
  latency_ms: .latencies.request
}'
```

## AI Proxy Config Reference

| Config | Description |
|---|---|
| `targets[].route_type` | `llm/v1/chat`, `llm/v1/completions` |
| `targets[].model.provider` | `openai`, `ollama`, `anthropic`, `azure`, `mistral` |
| `targets[].model.name` | Model identifier (e.g. `gpt-4o`) |
| `targets[].auth.header_name` | Auth header name |
| `targets[].auth.header_value` | API key value |
| `logging.log_statistics` | Log token counts and model info |
| `logging.log_payloads` | Log full prompt/response (⚠️ PII risk) |

---

*Next: [Lab 07-B - Prompt Guard →](./07-prompt-guard)*
