# Lab 09-B - Developer Portal

> **Goal:** Publish the mytravel.com API to Kong's Developer Portal. Configure teams, upload an OpenAPI spec, and enable developer self-service app registration.

## Prerequisites

| Tool | Install |
|---|---|
| [kongctl](https://docs.konghq.com/kongctl/) | `brew install kong/kongctl/kongctl` |
| Konnect account | [cloud.konghq.com](https://cloud.konghq.com) (free) |
| Konnect PAT | [Account → Tokens](https://cloud.konghq.com/global/account/tokens) |

```bash
# Set your PAT
export KONNECT_PAT="kpat_..."

# Login
kongctl login
```

## Step 1 - Adopt or create a portal

```bash
# List existing portals
kongctl list portals

# Create a new portal
kongctl create portal \
  --name "mytravel-developer-portal" \
  --display-name "mytravel.com Developer Portal" \
  --description "APIs for the mytravel.com travel platform"

# Or adopt an existing portal
kongctl adopt portal "mytravel-developer-portal" --namespace default
```

## Step 2 - Create the API product

```bash
# Create API product
kongctl create api \
  --name "mytravel-api" \
  --display-name "mytravel.com API" \
  --description "REST API for flights, hotels, cars, and weather data"

# Create a version
kongctl create api-version \
  --api "mytravel-api" \
  --name "v1" \
  --display-name "Version 1.0"
```

## Step 3 - Upload OpenAPI spec

First, create the spec file `mytravel-openapi.yaml`:

```yaml
openapi: 3.1.0
info:
  title: mytravel.com API
  version: 1.0.0
  description: Travel booking platform API - flights, hotels, cars, and weather

servers:
  - url: https://api.mytravel.com
    description: Production
  - url: http://localhost:8000
    description: Local Kong Gateway

paths:
  /api/flights:
    get:
      summary: List all available flights
      operationId: listFlights
      tags: [Flights]
      security: [ApiKeyAuth: []]
      responses:
        '200':
          description: Array of flight objects
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Flight'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '429':
          $ref: '#/components/responses/RateLimited'

  /api/flights/{id}:
    get:
      summary: Get flight by ID
      operationId: getFlightById
      tags: [Flights]
      security: [ApiKeyAuth: []]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Flight object
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Flight'

  /api/bookings:
    post:
      summary: Book a flight
      operationId: createBooking
      tags: [Bookings]
      security: [ApiKeyAuth: []]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BookingRequest'
      responses:
        '201':
          description: Booking confirmed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BookingResponse'

  /api/hotels:
    get:
      summary: List hotels
      operationId: listHotels
      tags: [Hotels]
      security: [ApiKeyAuth: []]
      responses:
        '200':
          description: Array of hotel objects

  /api/weather/{airport}:
    get:
      summary: Weather by IATA airport code
      operationId: getWeather
      tags: [Weather]
      parameters:
        - name: airport
          in: path
          required: true
          schema:
            type: string
            pattern: '^[A-Z]{3}$'
            example: LHR
      responses:
        '200':
          description: Weather data

components:
  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key

  schemas:
    Flight:
      type: object
      properties:
        id:    { type: integer }
        airline: { type: string }
        origin: { type: string }
        destination: { type: string }
        departure: { type: string, format: date-time }
        price: { type: number }

    BookingRequest:
      type: object
      required: [flight_id, seats]
      properties:
        flight_id: { type: string }
        seats: { type: integer, minimum: 1 }
        passenger_name: { type: string }

    BookingResponse:
      type: object
      properties:
        booking_id: { type: string }
        status: { type: string, enum: [confirmed, pending] }
        flight: { $ref: '#/components/schemas/Flight' }

  responses:
    Unauthorized:
      description: Missing or invalid API key
    RateLimited:
      description: Rate limit exceeded
      headers:
        Retry-After:
          schema: { type: integer }
```

```bash
# Upload spec
kongctl create api-spec \
  --api "mytravel-api" \
  --version "v1" \
  --spec ./mytravel-openapi.yaml
```

## Step 4 - Link Gateway Service

```bash
# Link the Konnect Control Plane service to this API product
kongctl create api-link \
  --api "mytravel-api" \
  --version "v1" \
  --control-plane "default" \
  --service "mytravel-com-api"
```

## Step 5 - Publish to portal

```bash
# Publish the API to the portal
kongctl publish api \
  --api "mytravel-api" \
  --portal "mytravel-developer-portal" \
  --auto-approve-registration true
```

## Step 6 - Configure Teams & Roles

```bash
# Create a team
kongctl create team \
  --name "API Consumers" \
  --description "External developers consuming the mytravel API"

# Assign portal roles to team
kongctl assign role \
  --team "API Consumers" \
  --portal "mytravel-developer-portal" \
  --role "Viewer"
```

## Step 7 - Customise portal appearance

```bash
# Upload portal logo
kongctl update portal appearance \
  --portal "mytravel-developer-portal" \
  --logo ./public/kong-gateway-logo.svg \
  --primary-color "#001408" \
  --accent-color "#00E88F"

# Set portal theme
kongctl update portal appearance \
  --portal "mytravel-developer-portal" \
  --theme dark
```

## Developer Self-Service Flow

Once published, external developers can:
1. Browse the portal at your custom domain
2. Sign up / sign in
3. Explore the API spec (interactive Swagger UI)
4. Create an application
5. Request access (auto-approve or manual)
6. Receive API credentials
7. Start making API calls

## Portal RBAC Roles

| Role | Permissions |
|---|---|
| Portal Admin | Full admin access |
| Portal Content Editor | Edit pages, docs |
| API Publisher | Publish APIs, manage versions |
| API Approver | Approve developer app registrations |
| Viewer | Read-only access |

---

*Next: [Lab 09-C - decK & CI/CD →](./09-deck-cicd)*
