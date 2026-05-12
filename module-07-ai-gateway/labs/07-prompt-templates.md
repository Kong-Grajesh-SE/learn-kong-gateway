# Lab 07-D - Prompt Templates

> **Goal:** Create reusable named prompt templates with variable substitution. Clients send a template name instead of a raw prompt.

## How Prompt Templates Work

Instead of clients crafting prompts, they reference named templates:

```json
// Without templates (raw prompt - risky):
{"messages": [{"role": "user", "content": "Summarize this: <user input>"}]}

// With templates (controlled prompt):
{"messages": "{template://summarizer}", "properties": {"text": "<user input>"}}
```

Benefits:
- Clients can't override your system prompt
- Consistent, auditable prompts
- Easy to update without client changes

## Step 1 - Enable ai-prompt-template

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/ai-chat-route/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-prompt-template",
    "config": {
      "allow_untemplated_requests": true,
      "log_original_request": false,
      "templates": [
        {
          "name": "summarizer",
          "template": "Summarize the following text in 3 bullet points:\n\n{{text}}"
        },
        {
          "name": "code-explainer",
          "template": "Explain this {{language}} code clearly and concisely:\n\n```{{language}}\n{{code}}\n```"
        },
        {
          "name": "email-drafter",
          "template": "Draft a professional email with subject \"{{subject}}\" to {{recipient}}.\n\nContext: {{context}}\n\nTone: {{tone}}"
        },
        {
          "name": "api-designer",
          "template": "Design a RESTful API for {{resource}}. Include:\n- Resource name\n- 5 key endpoints (method + path)\n- Request/response schema for each\n- Authentication strategy"
        },
        {
          "name": "qna",
          "template": "Answer the following question concisely and accurately:\n\nQuestion: {{question}}\n\nContext (if provided): {{context}}"
        }
      ]
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
plugins:
  - name: ai-prompt-template
    enabled: true
    config:
      allow_untemplated_requests: true
      log_original_request: false
      templates:
        - name: summarizer
          template: "Summarize the following text in 3 bullet points:\n\n{{text}}"
        - name: code-explainer
          template: "Explain this {{language}} code:\n\n```{{language}}\n{{code}}\n```"
        - name: email-drafter
          template: "Draft a professional email: subject={{subject}}, to={{recipient}}, context={{context}}, tone={{tone}}"
        - name: api-designer
          template: "Design a RESTful API for {{resource}} with 5 endpoints."
        - name: qna
          template: "Answer concisely: {{question}}\n\nContext: {{context}}"
```

:::

## Step 2 - Use the summarizer template

```bash
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": "{template://summarizer}",
    "properties": {
      "text": "Kong Gateway is an open-source, cloud-native API gateway built on top of Nginx and OpenResty. It provides a lightweight, fast, and flexible platform for managing, securing, and scaling APIs. Kong uses a plugin architecture to extend functionality, with hundreds of plugins available for authentication, rate limiting, logging, transformations, and more."
    }
  }' | jq '.choices[0].message.content'
```

## Step 3 - Use the code-explainer template

```bash
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": "{template://code-explainer}",
    "properties": {
      "language": "yaml",
      "code": "_format_version: \"3.0\"\nservices:\n  - name: my-api\n    url: https://api.example.com\n    routes:\n      - name: api-route\n        paths: [\"/api\"]\n        plugins:\n          - name: rate-limiting\n            config:\n              minute: 100"
    }
  }' | jq '.choices[0].message.content'
```

## Step 4 - Use the api-designer template

```bash
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": "{template://api-designer}",
    "properties": {
      "resource": "flight booking system"
    }
  }' | jq '.choices[0].message.content'
```

## Step 5 - Test allow_untemplated_requests

```bash
# With allow_untemplated_requests: true
# Raw messages arrays still pass through unchanged
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello, what time is it?"}]
  }' | jq '.choices[0].message.content'

# Set allow_untemplated_requests: false to block raw prompts
# Then only template://name format is allowed
```

## Step 6 - Template variable validation

```bash
# Missing required variable - Kong will substitute empty string
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": "{template://email-drafter}",
    "properties": {
      "subject": "API Integration",
      "recipient": "DevOps Team"
    }
  }' | jq '.choices[0].message.content'
# context and tone will be empty - still works
```

## Template Design Best Practices

| Practice | Why |
|---|---|
| Use `allow_untemplated_requests: false` in production | Prevents raw prompt injection |
| Keep templates in decK YAML | Version-controlled, auditable |
| Use descriptive variable names | `{{recipient}}` not `{{var1}}` |
| Provide default context in template text | Reduces incomplete outputs |
| Combine with `ai-prompt-guard` | Belt-and-suspenders security |

---

*Next: [Lab 07-E - PII Sanitizer →](./07-pii-sanitizer)*
