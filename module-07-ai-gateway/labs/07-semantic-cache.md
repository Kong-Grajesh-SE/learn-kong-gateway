# Lab 07-C - Semantic Cache

> **Goal:** Reduce LLM token costs and latency by caching semantically similar responses in Redis using vector embeddings.

## How Semantic Cache Works

```
Request: "How does Kong rate limiting work?"
              ↓
     Kong ai-semantic-cache:
     1. Embed the prompt → vector [0.12, -0.45, ...]
     2. Search Redis vector store
     3a. Cache HIT (similarity > threshold):
           Return cached response immediately (0 tokens!)
     3b. Cache MISS:
           Forward to LLM, cache response + vector
```

**Cost example:** If 30% of your AI requests are semantically similar questions, you save 30% of token costs instantly.

## Step 1 - Start Redis with vector support

```bash
docker run -d --name redis \
  --network kong-net \
  -p 6379:6379 \
  redis/redis-stack:latest     # Redis Stack includes vector search

# Verify
docker exec redis redis-cli PING
```

## Step 2 - Enable ai-semantic-cache

::: code-group

```bash [Admin API]
curl -s -X POST http://localhost:8001/routes/ai-chat-route/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ai-semantic-cache",
    "config": {
      "embeddings": {
        "model": {
          "provider": "openai",
          "name": "text-embedding-3-small"
        },
        "auth": {
          "header_name": "Authorization",
          "header_value": "Bearer '"${OPENAI_API_KEY}"'"
        }
      },
      "vectordb": {
        "strategy": "redis",
        "redis": {
          "host": "redis",
          "port": 6379,
          "timeout": 2000,
          "database": 1
        },
        "dimensions": 1536,
        "distance_metric": "cosine",
        "threshold": 0.1
      },
      "cache_control": true
    }
  }' | jq '{id, name}'
```

```yaml [decK YAML - Ollama embeddings]
plugins:
  - name: ai-semantic-cache
    enabled: true
    config:
      embeddings:
        model:
          provider: ollama
          name: nomic-embed-text    # local embedding model
          options:
            ollama:
              upstream_url: "http://ollama:11434"
        auth:
          allow_override: false
      vectordb:
        strategy: redis
        redis:
          host: redis
          port: 6379
          timeout: 2000
          database: 1
        dimensions: 768
        distance_metric: cosine
        threshold: 0.1              # lower = more permissive matching
      cache_control: true
```

:::

## Step 3 - Pull an embedding model (Ollama)

```bash
docker exec ollama ollama pull nomic-embed-text
```

## Step 4 - Test cache behavior

```bash
# First request - cache MISS → calls LLM
time curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"What is Kong Gateway?"}]}' \
  | jq '{content: .choices[0].message.content, cached: .headers["X-Cache-Status"]}'

# Second request - semantically identical → cache HIT (near-instant)
time curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"What is Kong Gateway?"}]}' \
  | jq '.choices[0].message.content'

# Third request - semantically similar → should also hit cache
time curl -s -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Can you explain what Kong Gateway is?"}]}' \
  | jq '.choices[0].message.content'
```

## Step 5 - Check cache status headers

```bash
curl -si -X POST http://localhost:8000/ai/proxy/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"What is Kong Gateway?"}]}' \
  | grep -i "x-cache"

# X-Cache-Status: Hit    ← served from cache
# X-Cache-Status: Miss   ← forwarded to LLM
```

## Step 6 - Monitor cache efficiency in Redis

```bash
# Check what's stored in Redis
docker exec redis redis-cli -n 1 KEYS "*"

# Check vector index info
docker exec redis redis-cli -n 1 FT.INFO kong_ai_semantic_cache

# Cache statistics
docker exec redis redis-cli -n 1 INFO stats | grep -E "keyspace_hits|keyspace_misses"
```

## Step 7 - Tune the similarity threshold

```
threshold: 0.1  → Very permissive  (near-exact matches only)
threshold: 0.3  → Moderate         (semantically similar)
threshold: 0.5  → Aggressive       (topic-level matching)
```

```bash
# Test threshold sensitivity
QUESTIONS=(
  "What is Kong Gateway?"
  "Can you explain Kong Gateway?"
  "Tell me about Kong's API gateway"
  "What does Kong do?"
  "What is an API gateway?"     # this may not match at threshold 0.1
)

for q in "${QUESTIONS[@]}"; do
  STATUS=$(curl -s -X POST http://localhost:8000/ai/proxy/chat \
    -H "Content-Type: application/json" \
    -w "\n%{http_code}" \
    -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$q\"}]}" \
    | tail -1)
  echo "$q → HTTP $STATUS"
done
```

## Semantic Cache Config Reference

| Config | Description |
|---|---|
| `embeddings.model.provider` | Embedding model provider: `openai`, `ollama`, `mistral` |
| `embeddings.model.name` | Embedding model (e.g. `text-embedding-3-small`) |
| `vectordb.strategy` | Only `redis` is currently supported |
| `vectordb.dimensions` | Vector dimensions (must match embedding model) |
| `vectordb.distance_metric` | `cosine` (recommended) or `euclidean` |
| `vectordb.threshold` | Similarity score to consider a cache hit (0–1) |
| `cache_control` | Respect HTTP `Cache-Control: no-cache` headers |

---

*Next: [Lab 07-D - Prompt Templates →](./07-prompt-templates)*
