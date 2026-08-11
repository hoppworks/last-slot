# Last Slot HTTP API

## Scope

The API serves the same-repository Flutter client. It exposes one synthetic slot,
accepts an idempotent booking attempt, and returns the persisted state used by
the admin readback.

## Endpoints

- `GET /healthz` reports gateway readiness.
- `GET /v1/slots/{slotId}` returns the slot and its optional booking. It returns
  `404` for an unknown slot and sets `Cache-Control: no-store` so read-after-write
  behavior stays explicit.
- `POST /v1/slots/{slotId}/bookings` requires an `Idempotency-Key` header and a
  `{ "customerName": string }` body. A new booking returns `201` and a
  `Location` header. Replaying the same key returns the original result with
  `200`. A competing booking returns `409` with code `slot_taken`. Invalid input
  returns `400`, `415`, or `422`; an unknown slot returns `404`. A temporarily
  unavailable service returns `503` with `Retry-After: 1`.

## Authentication

There is no authentication in this portfolio case study. The absence is
deliberate and documented; the API must not be presented as production-ready for
untrusted public booking data.

## Pagination

The first slice has no collection endpoint. Any future collection must use an
opaque cursor, accept a bounded `limit`, and return `nextCursor` when more data
exists.

## Error shape

Every documented API failure uses one envelope:

```json
{
  "error": {
    "code": "slot_taken",
    "message": "Another visitor booked this slot first.",
    "details": { "slotId": "..." },
    "requestId": "..."
  }
}
```

Codes are stable and machine-readable. Messages may improve without breaking
clients. Internal stack traces and SQL details are never returned.

## Idempotency and concurrency

The browser supplies a UUID idempotency key for each booking intent. The service
stores it under a unique constraint and returns the original booking when the
same intent is retried. A separate unique constraint on the slot identifier is
the final authority that prevents double booking under concurrency.

## Consistency and versioning

Successful writes provide read-your-writes behavior. The API is path-versioned
under `/v1`. Additive optional fields are allowed; breaking changes require a
new version. The checked-in OpenAPI document is the executable contract.
