# Lab 03-B - JWT Authentication

> **Goal:** Implement stateless JWT authentication. Consumers hold a secret; Kong validates the signature without a database lookup on every request.

## How Kong JWT Works

```
Client signs a JWT with consumer's secret
       ↓
Client sends: Authorization: Bearer <jwt>
       ↓
Kong JWT plugin → validates signature using stored secret
       ↓
✅ Valid → injects X-Consumer-* headers → forwards
❌ Invalid → 401 Unauthorized
```

## Step 1 - Enable JWT plugin on the hotels route

```bash
curl -s -X POST http://localhost:8001/routes/hotels-list/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "uri_param_names": ["jwt"],
      "cookie_names": [],
      "header_names": ["authorization"],
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss",
      "secret_is_base64": false,
      "run_on_preflight": true,
      "maximum_expiration": 3600
    }
  }' | jq '{id, name}'
```

## Step 2 - Create JWT credentials for a consumer

```bash
# Create a JWT credential for travel-web-app
curl -s -X POST http://localhost:8001/consumers/travel-web-app/jwt \
  -H "Content-Type: application/json" \
  -d '{
    "algorithm": "HS256",
    "secret": "my-super-secret-key-min-32-chars-long"
  }' | jq '{key, secret, algorithm}'
```

Note the `key` value - this is the **issuer** (`iss` claim) of your JWT.

## Step 3 - Generate a JWT token

::: code-group

```bash [Using jwt-cli]
# Install jwt-cli (macOS)
brew install mike-engel/jwt-cli/jwt-cli

# Replace KEY and SECRET with values from Step 2
JWT=$(jwt encode \
  --alg HS256 \
  --secret "my-super-secret-key-min-32-chars-long" \
  --iss "<KEY from Step 2>" \
  --exp "+1h" \
  '{"sub": "travel-web-app", "role": "user"}')

echo $JWT
```

```python [Python script]
#!/usr/bin/env python3
import jwt, time

ISS = "<KEY from Step 2>"
SECRET = "my-super-secret-key-min-32-chars-long"

payload = {
    "iss": ISS,
    "sub": "travel-web-app",
    "role": "user",
    "iat": int(time.time()),
    "exp": int(time.time()) + 3600,
}

token = jwt.encode(payload, SECRET, algorithm="HS256")
print(token)
```

```javascript [Node.js script]
const jwt = require('jsonwebtoken');

const ISS = '<KEY from Step 2>';
const SECRET = 'my-super-secret-key-min-32-chars-long';

const token = jwt.sign(
  { iss: ISS, sub: 'travel-web-app', role: 'user' },
  SECRET,
  { algorithm: 'HS256', expiresIn: '1h' }
);

console.log(token);
```

:::

## Step 4 - Call the API with the JWT

```bash
# Using Authorization: Bearer header
curl -s -H "Authorization: Bearer $JWT" \
  http://localhost:8000/api/hotels | jq 'length'

# Using query parameter
curl -s "http://localhost:8000/api/hotels?jwt=$JWT" | jq 'length'
```

## Step 5 - Test invalid tokens

```bash
# No token → 401
curl -si http://localhost:8000/api/hotels | head -3

# Tampered token → 401
TAMPERED="${JWT::-5}AAAAA"
curl -si -H "Authorization: Bearer $TAMPERED" \
  http://localhost:8000/api/hotels | head -3

# Expired token (maximum_expiration check)
EXPIRED=$(jwt encode --alg HS256 --secret "my-super-secret-key-min-32-chars-long" \
  --iss "<KEY>" --exp "1970-01-01T00:00:01Z" '{}')
curl -si -H "Authorization: Bearer $EXPIRED" \
  http://localhost:8000/api/hotels | head -3
```

## Step 6 - RS256 with public/private key pair

For production, use asymmetric keys (RS256) so you can distribute the public key:

```bash
# Generate key pair
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

# Create RS256 credential
curl -s -X POST http://localhost:8001/consumers/travel-web-app/jwt \
  -H "Content-Type: application/json" \
  -d "{
    \"algorithm\": \"RS256\",
    \"rsa_public_key\": \"$(cat public.pem | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')\"
  }" | jq '{key, algorithm}'
```

## JWT Claims Reference

| Claim | Required | Description |
|---|---|---|
| `iss` | ✅ Required | Must match consumer credential `key` |
| `exp` | ✅ (if `claims_to_verify` includes it) | Expiration timestamp (Unix) |
| `nbf` | Optional | Not-before timestamp |
| `iat` | Optional | Issued-at timestamp |
| `sub` | Optional | Subject (for your backend) |

## decK YAML

```yaml
consumers:
  - username: travel-web-app
    jwt_secrets:
      - algorithm: HS256
        key: "<issuer-key>"
        secret: "${JWT_SECRET}"   # use env var in production
```

## Challenge

Implement **JWT with RS256** and configure a second consumer `travel-mobile-app` that uses the same public key but a different private key. Demonstrate that Kong validates both independently.

---

*Next: [Lab 03-C - OIDC / Keycloak →](./03-oidc-keycloak)*
