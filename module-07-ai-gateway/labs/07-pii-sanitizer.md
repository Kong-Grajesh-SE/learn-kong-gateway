# Lab 07-E - PII Sanitizer

> **Goal:** Detect and redact personally identifiable information (PII) from AI prompts and responses before they reach or return from LLM providers.

## Why PII Sanitization?

When users interact with AI, they often inadvertently include sensitive data:
- "My SSN is 123-45-6789, help me file a tax form"
- "Email john.doe@company.com about the contract"
- "My card ending in 4242..."

The `ai-sanitizer` plugin intercepts these at the gateway before the data leaves your control.

## Step 1 - Start the PII sanitizer service

The ai-sanitizer requires an external PII detection microservice. A Kong-provided image is available:

```bash
# Start the AI PII sanitizer service
docker run -d --name ai-pii-service \
  --network kong-net \
  -p 8085:8085 \
  kong/ai-pii-service:latest

# Verify it's running
curl -s http://localhost:8085/health
```

## Step 2 - Enable ai-sanitizer plugin

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/ai-chat-route/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-sanitizer",
    "config": {
      "pii_service": {
        "url": "http://ai-pii-service:8085",
        "timeout": 5000
      },
      "entities": [
        "PERSON",
        "EMAIL_ADDRESS",
        "PHONE_NUMBER",
        "CREDIT_CARD",
        "US_SSN",
        "IP_ADDRESS",
        "URL",
        "LOCATION"
      ],
      "replace_with": "[REDACTED]",
      "sanitize_request": true,
      "sanitize_response": false,
      "log_original_request": false
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML]
plugins:
  - name: ai-sanitizer
    enabled: true
    config:
      pii_service:
        url: "http://ai-pii-service:8085"
        timeout: 5000
      entities:
        - PERSON
        - EMAIL_ADDRESS
        - PHONE_NUMBER
        - CREDIT_CARD
        - US_SSN
        - IP_ADDRESS
        - LOCATION
      replace_with: "[REDACTED]"
      sanitize_request: true
      sanitize_response: false
      log_original_request: false
```

:::

## Step 3 - Test PII redaction in prompts

```bash
# Prompt with PII
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{
      "role": "user",
      "content": "My name is John Smith and my email is john.smith@example.com. My phone is 555-867-5309. Please help me draft a professional bio."
    }]
  }' | jq '{
    content: .choices[0].message.content,
    sanitized: .meta.sanitized
  }'
```

The LLM receives: `"My name is [REDACTED] and my email is [REDACTED]. My phone is [REDACTED]. Please help me draft a professional bio."`

## Step 4 - Test with credit card numbers

```bash
curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{
      "role": "user",
      "content": "I paid with my Visa card 4532015112830366 on 12/28. Can you help me write a dispute letter?"
    }]
  }' | jq '.choices[0].message.content'
```

## Step 5 - Sanitize responses too

Enable response sanitization to catch PII in LLM output:

```bash
curl -s -X PATCH http://localhost:8001/plugins/<plugin-id> \
  -H "Content-Type: application/json" \
  -d '{"config": {"sanitize_response": true}}'
```

## Step 6 - Custom entity types

Add organisation-specific PII patterns:

```yaml
config:
  entities:
    - PERSON
    - EMAIL_ADDRESS
    - CREDIT_CARD
    - US_SSN
    - EMPLOYEE_ID      # custom
    - PROJECT_CODE     # custom
  custom_patterns:
    - name: EMPLOYEE_ID
      regex: "EMP-[0-9]{6}"
      replace_with: "[EMPLOYEE-REDACTED]"
    - name: PROJECT_CODE
      regex: "PRJ-[A-Z]{3}-[0-9]{4}"
      replace_with: "[PROJECT-REDACTED]"
```

## Supported PII Entity Types

| Entity | Examples |
|---|---|
| `PERSON` | Names: "John Smith", "Dr. Jane Doe" |
| `EMAIL_ADDRESS` | john@example.com |
| `PHONE_NUMBER` | +1-555-867-5309, (555) 867-5309 |
| `CREDIT_CARD` | 4532-0151-1283-0366 |
| `US_SSN` | 123-45-6789 |
| `US_BANK_NUMBER` | Bank account numbers |
| `IP_ADDRESS` | 192.168.1.1 |
| `URL` | https://internal.company.com |
| `LOCATION` | "San Francisco", "123 Main St" |
| `DATE_TIME` | Dates that could identify individuals |
| `NRP` | Nationalities, religions, political groups |
| `MEDICAL_LICENSE` | Medical license numbers |

## Compliance Use Cases

| Regulation | Required Entities |
|---|---|
| **GDPR** | PERSON, EMAIL, LOCATION, IP_ADDRESS |
| **HIPAA** | All + MEDICAL data, dates, locations |
| **PCI-DSS** | CREDIT_CARD, US_BANK_NUMBER |
| **CCPA** | PERSON, EMAIL, PHONE, LOCATION |

---

*Next: [Module 08 - Agentic AI & MCP →](/module-08-agentic-mcp/)*
