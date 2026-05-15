---
title: OpenAPI Specifications
description: Copy-ready OpenAPI 3.1 specs for all demo APIs used in the Kong Bootcamp labs.
---

# 📄 OpenAPI Specifications

::: danger You do NOT need to run a backend server
All bootcamp labs use **[httpbin.konghq.com](https://httpbin.konghq.com)** as the upstream - Kong proxies requests to it. No custom server required.

The specs on this page have **two separate jobs**:
- **httpbin spec** → import into Insomnia so your requests are pre-configured. Traffic flows: `you → Kong (:8000) → httpbin.konghq.com`
- **kong-air spec** → a design document. Use it only when publishing to the Kong Developer Portal (Module 09). It describes what the API *would* look like in production.
:::

## What actually happens in the labs

```
Your machine
    │
    ├─ Insomnia / curl  ──→  http://localhost:8000/demo/get
    │                                      │
    │                               Kong Data Plane (Docker)
    │                                      │
    │                               [plugins run here]
    │                                      │
    │                               https://httpbin.konghq.com/get
    │                                      │
    └──────────────────────────────  response echoed back
```

**httpbin.konghq.com echoes your request back.** This is perfect for testing every Kong plugin because:
- Key Auth → test 401 vs 200
- Rate Limiting → test 429
- Request Transformer → see injected headers in the echo
- Correlation ID → see the `X-Correlation-Id` header in the response
- JWT / OIDC → test 401 vs 200 with tokens

---

## When is each spec used?

| Spec | When to use it | Needs a server? |
|---|---|---|
| **httpbin** | Every lab - import into Insomnia, send through Kong | ❌ No - Kong calls `httpbin.konghq.com` |
| **kong-air** | Module 09 only - upload to Developer Portal as API docs | ❌ No - it's just a YAML doc |

---

## 1. httpbin - Import into Insomnia

This is the spec you'll actually use for testing. Import it into Insomnia once and you'll have all httpbin endpoints pre-configured pointing at Kong (`localhost:8000/demo`).

::: details Full OpenAPI 3.1 Spec - httpbin (import this into Insomnia)

```yaml
openapi: 3.1.0
info:
  title: httpbin via Kong
  version: 1.0.0
  description: |
    HTTP echo/testing service - routed through your Kong Data Plane.
    
    Setup: Create a Kong Service pointing to https://httpbin.konghq.com
    and a Route with path /demo (strip_path: true).
    Then all requests to localhost:8000/demo/* reach httpbin.

servers:
  - url: http://localhost:8000/demo
    description: Via Kong proxy ← use this for all labs
  - url: https://httpbin.konghq.com
    description: Direct (bypasses Kong - use only to verify upstream)

tags:
  - name: HTTP Methods
    description: Test GET, POST, PUT, PATCH, DELETE through Kong
  - name: Request Inspection
    description: Inspect headers and request data Kong forwards
  - name: Status Codes
    description: Simulate error responses (429, 503, etc.)
  - name: Dynamic Data
    description: UUIDs, random bytes
  - name: Delays
    description: Simulate slow upstreams for timeout testing

paths:
  /get:
    get:
      summary: Echo a GET request - inspect Kong-added headers
      operationId: getRequest
      tags: [HTTP Methods]
      responses:
        "200":
          description: |
            Returns your request headers, URL, and origin IP.
            Look for Kong-injected headers:
            - X-Kong-Request-Id
            - X-Forwarded-For
            - X-Forwarded-Host
            - X-Forwarded-Proto
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/EchoResponse"
              example:
                url: "https://httpbin.konghq.com/get"
                origin: "172.17.0.1"
                headers:
                  Host: httpbin.konghq.com
                  X-Kong-Request-Id: "abc-123-def"
                  X-Forwarded-For: "172.17.0.1"
                  X-Forwarded-Host: "localhost"
                  X-Forwarded-Port: "8000"
                  X-Forwarded-Proto: "http"

  /post:
    post:
      summary: Echo a POST body - verify Kong transformations
      operationId: postRequest
      tags: [HTTP Methods]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              example:
                booking: "NYC-LON"
                seats: 2
      responses:
        "200":
          description: |
            Returns the body Kong forwarded. Use this to verify
            Request Transformer plugin is injecting/modifying fields.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/EchoResponse"

  /put:
    put:
      summary: Echo a PUT request
      operationId: putRequest
      tags: [HTTP Methods]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        "200":
          description: Echoed PUT data

  /patch:
    patch:
      summary: Echo a PATCH request
      operationId: patchRequest
      tags: [HTTP Methods]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        "200":
          description: Echoed PATCH data

  /delete:
    delete:
      summary: Echo a DELETE request
      operationId: deleteRequest
      tags: [HTTP Methods]
      responses:
        "200":
          description: Echoed DELETE data

  /headers:
    get:
      summary: Returns only the request headers
      operationId: getHeaders
      tags: [Request Inspection]
      responses:
        "200":
          description: |
            Returns all headers Kong forwarded upstream.
            Useful for verifying Request Transformer plugin output.
          content:
            application/json:
              schema:
                type: object
                properties:
                  headers:
                    type: object
                    additionalProperties:
                      type: string
              example:
                headers:
                  Host: httpbin.konghq.com
                  X-Kong-Request-Id: abc123
                  X-Audit-User: jane@example.com
                  X-Request-Source: kong-bootcamp

  /ip:
    get:
      summary: Returns the requester IP as seen by httpbin
      operationId: getIp
      tags: [Request Inspection]
      responses:
        "200":
          description: Origin IP address
          content:
            application/json:
              schema:
                type: object
                properties:
                  origin:
                    type: string
                    example: "172.17.0.1"

  /uuid:
    get:
      summary: Returns a random UUID - good for correlation ID lab
      operationId: getUuid
      tags: [Dynamic Data]
      responses:
        "200":
          description: Random UUID v4
          content:
            application/json:
              schema:
                type: object
                properties:
                  uuid:
                    type: string
                    format: uuid

  /anything:
    get:
      summary: Full request dump - use this to inspect everything Kong sends
      operationId: anythingGet
      tags: [Request Inspection]
      responses:
        "200":
          description: |
            Complete dump of: method, url, headers, args, body.
            The most useful endpoint for verifying plugin behaviour.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/EchoResponse"
    post:
      summary: POST full request dump
      operationId: anythingPost
      tags: [Request Inspection]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        "200":
          description: Complete request dump including body

  /status/{code}:
    get:
      summary: Returns the given HTTP status code
      operationId: getStatus
      tags: [Status Codes]
      description: |
        Use this to simulate error responses from the upstream.
        
        Useful values:
        - 200 → normal
        - 401 → simulate upstream auth failure  
        - 429 → simulate rate limit (to test Kong rate-limiting plugin)
        - 500 → simulate server error (to test circuit breaker)
        - 503 → simulate service unavailable (health check testing)
      parameters:
        - name: code
          in: path
          required: true
          schema:
            type: integer
            example: 429
      responses:
        default:
          description: Response with the requested status code

  /delay/{seconds}:
    get:
      summary: Delays the response - use for timeout and circuit breaker testing
      operationId: getDelay
      tags: [Delays]
      parameters:
        - name: seconds
          in: path
          required: true
          schema:
            type: integer
            minimum: 0
            maximum: 10
            example: 3
      responses:
        "200":
          description: Response after N seconds delay

  /bearer:
    get:
      summary: Returns 200 only if a Bearer token is present
      operationId: bearerCheck
      tags: [Request Inspection]
      security:
        - BearerAuth: []
      responses:
        "200":
          description: Bearer token was present
          content:
            application/json:
              schema:
                type: object
                properties:
                  authenticated:
                    type: boolean
                  token:
                    type: string
        "401":
          description: Missing or invalid Bearer token

  /json:
    get:
      summary: Returns a hardcoded JSON sample
      operationId: getJson
      tags: [Dynamic Data]
      responses:
        "200":
          description: Sample JSON document

  /bytes/{n}:
    get:
      summary: Returns N random bytes
      operationId: getBytes
      tags: [Dynamic Data]
      parameters:
        - name: n
          in: path
          required: true
          schema:
            type: integer
            example: 1024
      responses:
        "200":
          description: N random bytes

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      description: |
        For /bearer endpoint. In Kong labs, the JWT or OIDC plugin
        validates the token before it reaches httpbin.

  schemas:
    EchoResponse:
      type: object
      description: httpbin echoes back everything Kong forwards to it
      properties:
        url:
          type: string
          example: "https://httpbin.konghq.com/get"
        origin:
          type: string
          example: "172.17.0.1"
        method:
          type: string
          example: "GET"
        headers:
          type: object
          description: All headers Kong forwarded - look for X-Kong-* headers here
          additionalProperties:
            type: string
        args:
          type: object
          description: Query string parameters
          additionalProperties:
            type: string
        json:
          description: Parsed JSON body (if Content-Type was application/json)
          nullable: true
        data:
          type: string
          description: Raw body string
        form:
          type: object
          additionalProperties:
            type: string
```

:::

---

## 2. kong-air API - for Developer Portal only

This spec describes a fictional travel API. **You don't run this server.** It exists so that in the [Developer Portal Bootcamp](https://kong-grajesh-se.github.io/learn-kong-dev-portal/), you have a realistic API spec to publish.

::: details Full OpenAPI 3.1 Spec - kong-air (Developer Portal upload)

```yaml
openapi: 3.1.0
info:
  title: kong-air Travel API
  version: 1.0.0
  description: |
    Fictional travel booking API - used as a Developer Portal demo in
    Module 09. You do NOT need to run a backend for this spec.
    Upload this YAML to the Konnect Developer Portal as API documentation.
  contact:
    name: Kong Bootcamp
    url: https://github.com/Kong-Grajesh-SE/learn-kong-gateway
  license:
    name: Apache 2.0
    url: https://www.apache.org/licenses/LICENSE-2.0

servers:
  - url: https://api.kong-air.example.com
    description: Production (fictional - for portal documentation only)
  - url: http://localhost:8000
    description: Via Kong proxy (if you build a kong-air backend locally)

tags:
  - name: Flights
    description: Search and retrieve flight information
  - name: Bookings
    description: Create and manage flight bookings
  - name: Hotels
    description: Search and reserve hotels
  - name: Cars
    description: Search and reserve rental cars
  - name: Weather
    description: Airport weather information
  - name: Health
    description: Service health checks

paths:
  /api/flights:
    get:
      summary: List all available flights
      operationId: listFlights
      tags: [Flights]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: origin
          in: query
          required: false
          schema:
            type: string
            example: LHR
          description: Filter by IATA origin airport code
        - name: destination
          in: query
          required: false
          schema:
            type: string
            example: JFK
        - name: date
          in: query
          required: false
          schema:
            type: string
            format: date
            example: "2026-06-15"
      responses:
        "200":
          description: List of available flights
          headers:
            X-Kong-Request-Id:
              description: Unique Kong request identifier
              schema:
                type: string
            X-RateLimit-Remaining-Minute:
              description: Remaining requests this minute
              schema:
                type: integer
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "#/components/schemas/Flight"
              example:
                - id: 1
                  airline: "Kong Air"
                  flight_number: "KA-101"
                  origin: "LHR"
                  destination: "JFK"
                  departure: "2026-06-15T08:00:00Z"
                  arrival: "2026-06-15T11:00:00Z"
                  price: 420.00
                  seats_available: 42
        "401":
          $ref: "#/components/responses/Unauthorized"
        "429":
          $ref: "#/components/responses/RateLimited"

  /api/flights/{id}:
    get:
      summary: Get flight by ID
      operationId: getFlightById
      tags: [Flights]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
            example: 1
      responses:
        "200":
          description: Flight details
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Flight"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "404":
          $ref: "#/components/responses/NotFound"

  /api/bookings:
    post:
      summary: Create a flight booking
      operationId: createBooking
      tags: [Bookings]
      security:
        - ApiKeyAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/BookingRequest"
            example:
              flight_id: "1"
              seats: 2
              passenger_name: "Jane Doe"
              passenger_email: "jane@example.com"
      responses:
        "201":
          description: Booking confirmed
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/BookingResponse"
        "400":
          $ref: "#/components/responses/BadRequest"
        "401":
          $ref: "#/components/responses/Unauthorized"

    get:
      summary: List bookings for the authenticated consumer
      operationId: listBookings
      tags: [Bookings]
      security:
        - ApiKeyAuth: []
      responses:
        "200":
          description: List of bookings
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "#/components/schemas/BookingResponse"
        "401":
          $ref: "#/components/responses/Unauthorized"

  /api/bookings/{id}:
    get:
      summary: Get booking by ID
      operationId: getBookingById
      tags: [Bookings]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: Booking details
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/BookingResponse"
        "404":
          $ref: "#/components/responses/NotFound"

    delete:
      summary: Cancel a booking
      operationId: cancelBooking
      tags: [Bookings]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "204":
          description: Booking cancelled
        "404":
          $ref: "#/components/responses/NotFound"

  /api/hotels:
    get:
      summary: Search hotels
      operationId: listHotels
      tags: [Hotels]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: city
          in: query
          schema:
            type: string
            example: London
        - name: check_in
          in: query
          schema:
            type: string
            format: date
            example: "2026-06-15"
        - name: check_out
          in: query
          schema:
            type: string
            format: date
            example: "2026-06-20"
        - name: guests
          in: query
          schema:
            type: integer
            minimum: 1
            example: 2
      responses:
        "200":
          description: List of hotels
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "#/components/schemas/Hotel"
        "401":
          $ref: "#/components/responses/Unauthorized"

  /api/hotels/{id}:
    get:
      summary: Get hotel by ID
      operationId: getHotelById
      tags: [Hotels]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        "200":
          description: Hotel details
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Hotel"
        "404":
          $ref: "#/components/responses/NotFound"

  /api/hotels/reserve:
    post:
      summary: Reserve a hotel room
      operationId: reserveHotel
      tags: [Hotels]
      security:
        - ApiKeyAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/HotelReservationRequest"
      responses:
        "201":
          description: Reservation confirmed
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/HotelReservationResponse"
        "401":
          $ref: "#/components/responses/Unauthorized"

  /api/cars:
    get:
      summary: Search rental cars
      operationId: listCars
      tags: [Cars]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: location
          in: query
          schema:
            type: string
            example: LHR
        - name: pickup_date
          in: query
          schema:
            type: string
            format: date
        - name: return_date
          in: query
          schema:
            type: string
            format: date
        - name: category
          in: query
          schema:
            type: string
            enum: [economy, compact, suv, luxury]
      responses:
        "200":
          description: List of available cars
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "#/components/schemas/Car"
        "401":
          $ref: "#/components/responses/Unauthorized"

  /api/cars/{id}:
    get:
      summary: Get car by ID
      operationId: getCarById
      tags: [Cars]
      security:
        - ApiKeyAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        "200":
          description: Car details
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Car"
        "404":
          $ref: "#/components/responses/NotFound"

  /api/cars/reserve:
    post:
      summary: Reserve a rental car
      operationId: reserveCar
      tags: [Cars]
      security:
        - ApiKeyAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CarReservationRequest"
      responses:
        "201":
          description: Car reservation confirmed
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/CarReservationResponse"
        "401":
          $ref: "#/components/responses/Unauthorized"

  /api/weather/{airport}:
    get:
      summary: Get weather by airport code
      operationId: getWeatherByAirport
      tags: [Weather]
      parameters:
        - name: airport
          in: path
          required: true
          description: IATA 3-letter airport code
          schema:
            type: string
            pattern: '^[A-Z]{3}$'
            example: LHR
      responses:
        "200":
          description: Weather data for the airport
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Weather"
              example:
                airport: LHR
                city: London
                temperature_c: 14
                condition: Overcast
                wind_kph: 22
                visibility_km: 8
        "400":
          $ref: "#/components/responses/BadRequest"

  /health:
    get:
      summary: Service health check
      operationId: healthCheck
      tags: [Health]
      responses:
        "200":
          description: Service is healthy
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: string
                    example: ok
                  version:
                    type: string
                    example: "1.0.0"
                  uptime_seconds:
                    type: number

components:
  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key
      description: API key issued by Kong key-auth plugin
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: JWT token issued by Keycloak / OIDC provider

  schemas:
    Flight:
      type: object
      properties:
        id:
          type: integer
          example: 1
        airline:
          type: string
          example: "Kong Air"
        flight_number:
          type: string
          example: "KA-101"
        origin:
          type: string
          example: "LHR"
        destination:
          type: string
          example: "JFK"
        departure:
          type: string
          format: date-time
          example: "2026-06-15T08:00:00Z"
        arrival:
          type: string
          format: date-time
          example: "2026-06-15T11:00:00Z"
        duration_minutes:
          type: integer
          example: 420
        price:
          type: number
          format: float
          example: 420.00
        currency:
          type: string
          example: USD
        seats_available:
          type: integer
          example: 42
        class:
          type: string
          enum: [economy, business, first]
          example: economy

    BookingRequest:
      type: object
      required: [flight_id, seats, passenger_name, passenger_email]
      properties:
        flight_id:
          type: string
          example: "1"
        seats:
          type: integer
          minimum: 1
          maximum: 9
          example: 2
        passenger_name:
          type: string
          example: "Jane Doe"
        passenger_email:
          type: string
          format: email
          example: "jane@example.com"
        seat_preference:
          type: string
          enum: [window, aisle, any]
          default: any

    BookingResponse:
      type: object
      properties:
        booking_id:
          type: string
          example: "BK-2026-001"
        status:
          type: string
          enum: [confirmed, pending, cancelled]
          example: confirmed
        flight:
          $ref: "#/components/schemas/Flight"
        seats:
          type: integer
          example: 2
        total_price:
          type: number
          example: 840.00
        currency:
          type: string
          example: USD
        created_at:
          type: string
          format: date-time

    Hotel:
      type: object
      properties:
        id:
          type: integer
          example: 1
        name:
          type: string
          example: "Kong Grand Hotel"
        city:
          type: string
          example: "London"
        stars:
          type: integer
          minimum: 1
          maximum: 5
          example: 4
        price_per_night:
          type: number
          example: 180.00
        currency:
          type: string
          example: USD
        amenities:
          type: array
          items:
            type: string
          example: [wifi, pool, gym, restaurant]
        rooms_available:
          type: integer
          example: 12

    HotelReservationRequest:
      type: object
      required: [hotel_id, check_in, check_out, guests]
      properties:
        hotel_id:
          type: integer
          example: 1
        check_in:
          type: string
          format: date
          example: "2026-06-15"
        check_out:
          type: string
          format: date
          example: "2026-06-20"
        guests:
          type: integer
          minimum: 1
          example: 2
        room_type:
          type: string
          enum: [standard, deluxe, suite]
          default: standard

    HotelReservationResponse:
      type: object
      properties:
        reservation_id:
          type: string
          example: "HR-2026-001"
        status:
          type: string
          example: confirmed
        hotel:
          $ref: "#/components/schemas/Hotel"
        check_in:
          type: string
          format: date
        check_out:
          type: string
          format: date
        total_price:
          type: number
          example: 900.00

    Car:
      type: object
      properties:
        id:
          type: integer
          example: 1
        make:
          type: string
          example: "Toyota"
        model:
          type: string
          example: "Corolla"
        category:
          type: string
          enum: [economy, compact, suv, luxury]
          example: compact
        price_per_day:
          type: number
          example: 55.00
        currency:
          type: string
          example: USD
        seats:
          type: integer
          example: 5
        available:
          type: boolean
          example: true

    CarReservationRequest:
      type: object
      required: [car_id, pickup_date, return_date, pickup_location]
      properties:
        car_id:
          type: integer
          example: 1
        pickup_date:
          type: string
          format: date
          example: "2026-06-15"
        return_date:
          type: string
          format: date
          example: "2026-06-20"
        pickup_location:
          type: string
          example: "LHR Terminal 2"

    CarReservationResponse:
      type: object
      properties:
        reservation_id:
          type: string
          example: "CR-2026-001"
        status:
          type: string
          example: confirmed
        car:
          $ref: "#/components/schemas/Car"
        total_price:
          type: number
          example: 275.00

    Weather:
      type: object
      properties:
        airport:
          type: string
          example: LHR
        city:
          type: string
          example: London
        temperature_c:
          type: number
          example: 14
        temperature_f:
          type: number
          example: 57.2
        condition:
          type: string
          example: Overcast
        wind_kph:
          type: number
          example: 22
        humidity_pct:
          type: integer
          example: 78
        visibility_km:
          type: number
          example: 8
        updated_at:
          type: string
          format: date-time

    Error:
      type: object
      required: [message]
      properties:
        message:
          type: string
          example: "Unauthorized"
        code:
          type: integer
          example: 401

  responses:
    Unauthorized:
      description: Missing or invalid API key / token
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"
          example:
            message: "No API key found in request"
    RateLimited:
      description: Rate limit exceeded
      headers:
        Retry-After:
          description: Seconds until the rate limit resets
          schema:
            type: integer
        X-RateLimit-Limit-Minute:
          schema:
            type: integer
        X-RateLimit-Remaining-Minute:
          schema:
            type: integer
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"
          example:
            message: "API rate limit exceeded"
    BadRequest:
      description: Invalid request parameters
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"
    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"
          example:
            message: "Not found"
```

:::

---

## 2. httpbin Test API

Use this spec to import **httpbin.konghq.com** or **httpbin.org** into Insomnia for hands-on testing of Kong plugins without a custom backend.

::: details Full OpenAPI 3.1 Spec - httpbin

```yaml
openapi: 3.1.0
info:
  title: httpbin
  version: 1.0.0
  description: |
    HTTP testing service. Used in all bootcamp labs as the upstream behind Kong.
    Route through Kong on localhost:8000/demo/* (strip_path: true → /*)

servers:
  - url: http://localhost:8000/demo
    description: Via Kong proxy (after creating httpbin Service + Route)
  - url: https://httpbin.konghq.com
    description: Kong-hosted httpbin (direct)
  - url: https://httpbin.org
    description: Public httpbin (direct)

tags:
  - name: HTTP Methods
  - name: Request Inspection
  - name: Response Formats
  - name: Status Codes
  - name: Dynamic Data
  - name: Delays

paths:
  /get:
    get:
      summary: Returns GET request data
      operationId: getRequest
      tags: [HTTP Methods]
      parameters:
        - name: any_param
          in: query
          schema:
            type: string
          description: Any query parameter - echoed back in response
      responses:
        "200":
          description: Request metadata including headers, origin, URL
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/RequestData"
              example:
                url: "https://httpbin.konghq.com/get"
                origin: "1.2.3.4"
                headers:
                  Host: httpbin.konghq.com
                  X-Kong-Request-Id: abc123
                  X-Forwarded-For: 1.2.3.4
                  X-Forwarded-Proto: http

  /post:
    post:
      summary: Returns POST request data
      operationId: postRequest
      tags: [HTTP Methods]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              example:
                name: test
                value: 42
          application/x-www-form-urlencoded:
            schema:
              type: object
      responses:
        "200":
          description: Echoed POST body + metadata
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/RequestData"

  /put:
    put:
      summary: Returns PUT request data
      operationId: putRequest
      tags: [HTTP Methods]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        "200":
          description: Echoed request data

  /patch:
    patch:
      summary: Returns PATCH request data
      operationId: patchRequest
      tags: [HTTP Methods]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        "200":
          description: Echoed request data

  /delete:
    delete:
      summary: Returns DELETE request data
      operationId: deleteRequest
      tags: [HTTP Methods]
      responses:
        "200":
          description: Echoed request data

  /headers:
    get:
      summary: Returns the request headers
      operationId: getHeaders
      tags: [Request Inspection]
      responses:
        "200":
          description: All request headers as JSON
          content:
            application/json:
              schema:
                type: object
                properties:
                  headers:
                    type: object
                    additionalProperties:
                      type: string

  /ip:
    get:
      summary: Returns the requester's IP
      operationId: getIp
      tags: [Request Inspection]
      responses:
        "200":
          description: Originating IP address
          content:
            application/json:
              schema:
                type: object
                properties:
                  origin:
                    type: string
                    example: "1.2.3.4"

  /uuid:
    get:
      summary: Returns a random UUID
      operationId: getUuid
      tags: [Dynamic Data]
      responses:
        "200":
          description: A randomly generated UUID v4
          content:
            application/json:
              schema:
                type: object
                properties:
                  uuid:
                    type: string
                    format: uuid

  /json:
    get:
      summary: Returns sample JSON
      operationId: getSampleJson
      tags: [Response Formats]
      responses:
        "200":
          description: Hardcoded JSON sample

  /xml:
    get:
      summary: Returns sample XML
      operationId: getSampleXml
      tags: [Response Formats]
      responses:
        "200":
          description: Hardcoded XML document
          content:
            application/xml:
              schema:
                type: string

  /html:
    get:
      summary: Returns a sample HTML page
      operationId: getSampleHtml
      tags: [Response Formats]
      responses:
        "200":
          description: HTML document

  /status/{code}:
    get:
      summary: Returns response with the given HTTP status code
      operationId: getStatus
      tags: [Status Codes]
      parameters:
        - name: code
          in: path
          required: true
          description: HTTP status code to return (e.g. 200, 404, 500)
          schema:
            type: integer
            example: 429
      responses:
        "default":
          description: Response with the requested status code

  /delay/{seconds}:
    get:
      summary: Delays responding for the given number of seconds
      operationId: getDelay
      tags: [Delays]
      parameters:
        - name: seconds
          in: path
          required: true
          description: Number of seconds to delay (max 10)
          schema:
            type: integer
            minimum: 0
            maximum: 10
            example: 2
      responses:
        "200":
          description: Response after delay

  /anything:
    get:
      summary: Returns anything - all request data
      operationId: getAnything
      tags: [Request Inspection]
      responses:
        "200":
          description: Complete request dump
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/RequestData"
    post:
      summary: POST anything - echoes the full request
      operationId: postAnything
      tags: [Request Inspection]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        "200":
          description: Complete request dump

  /bearer:
    get:
      summary: Returns 200 only if Authorization Bearer token is present
      operationId: bearerCheck
      tags: [Request Inspection]
      security:
        - BearerAuth: []
      responses:
        "200":
          description: Token was present
          content:
            application/json:
              schema:
                type: object
                properties:
                  authenticated:
                    type: boolean
                  token:
                    type: string
        "401":
          description: No bearer token

  /bytes/{n}:
    get:
      summary: Returns N random bytes
      operationId: getBytes
      tags: [Dynamic Data]
      parameters:
        - name: n
          in: path
          required: true
          schema:
            type: integer
            example: 1024
      responses:
        "200":
          description: N bytes of random binary data

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer

  schemas:
    RequestData:
      type: object
      properties:
        url:
          type: string
          example: "https://httpbin.konghq.com/get"
        origin:
          type: string
          example: "1.2.3.4"
        method:
          type: string
          example: GET
        headers:
          type: object
          additionalProperties:
            type: string
        args:
          type: object
          additionalProperties:
            type: string
        json:
          nullable: true
        data:
          type: string
        form:
          type: object
          additionalProperties:
            type: string
        files:
          type: object
```

:::

---

## How to use these specs

### Import httpbin into Insomnia (for labs)

1. Expand the **httpbin** spec above and click the copy icon
2. In Insomnia → **New Collection** → **Import** → **From Clipboard**
3. Set the base URL to `http://localhost:8000/demo` (via Kong)
4. Send any request - Kong proxies it to `httpbin.konghq.com` and echoes the response back

### Direct httpbin URL import

```
https://httpbin.konghq.com/spec.json
```

Insomnia → **Import** → **From URL** → paste the URL above.  
Then change the base URL to `http://localhost:8000/demo` to route through Kong.

### Upload kong-air spec to Developer Portal (Module 09 only)

```bash
# Save the kong-air YAML to a file, then:
kongctl create api-spec \
  --api "kong-air" \
  --version "v1" \
  --spec ./kong-air-openapi.yaml
```

Or in Konnect UI: **API Products** → your product → **Versions** → **Upload Spec**

---

## Quick curl reference

All commands go through Kong on `:8000`. No backend needed.

```bash
# Inspect Kong-added headers on every request
curl -s http://localhost:8000/demo/get | jq .headers

# Test Key Auth - without key (should 401)
curl -si http://localhost:8000/demo/get | head -3

# Test Key Auth - with key (should 200)
curl -s http://localhost:8000/demo/get -H "X-API-Key: my-key" | jq .

# POST through Kong - see transformed body in echo
curl -s -X POST http://localhost:8000/demo/post \
  -H "Content-Type: application/json" \
  -d '{"booking": "NYC-LON", "seats": 2}' | jq .json

# Simulate upstream 429 - test rate limiting response handling
curl -si http://localhost:8000/demo/status/429 | head -5

# Simulate upstream 503 - test circuit breaker
curl -si http://localhost:8000/demo/status/503 | head -5

# Slow upstream (3 seconds) - test timeouts
curl -w "\nTotal time: %{time_total}s\n" \
  http://localhost:8000/demo/delay/3

# Random UUID - verify Correlation ID plugin
curl -s http://localhost:8000/demo/uuid | jq .uuid

# See everything Kong forwarded to the upstream
curl -s http://localhost:8000/demo/anything | jq '{method, headers, json}'
```

---

*← [🏗️ Deployment Options](/deployment-overview) · [🧭 Start Module 01 →](/module-01-orientation/)*
