# Case-study brief

## The claim

A single appointment can be offered to multiple visitors without being booked
twice, even when requests arrive concurrently or a client retries after an
uncertain response.

## The proof

One Patrol Web test opens two browser pages, fills the same slot through the
two different people, and submits both attempts together. Exactly one browser
must receive confirmation and the other an explicit conflict. A third browser
opens the admin surface and reads one persisted booking. Both visitor pages then
reload and still show the slot as booked.

The browser test may use only visible, accessible product behavior. It must not
query PostgreSQL directly or call a test-only endpoint.

## Why the result is trustworthy

| Layer | Responsibility |
|---|---|
| Flutter | Presents honest success, conflict, retry, and persisted states. |
| Axum gateway | Owns the versioned HTTP contract and stable error envelope. |
| tonic service | Validates booking intent and idempotent replay semantics. |
| PostgreSQL | Enforces one booking per slot and one result per idempotency key. |
| Patrol Web | Proves those guarantees survive the complete user journey. |

Patrol is the evidence layer, not the source of correctness. The database
constraints remain authoritative if two requests reach the service at the same
time; the end-to-end journey catches broken wiring or dishonest UI states above
that boundary.

## Acceptance criteria

- One command starts the real local stack and runs the journey.
- Test retries remain disabled.
- A green run produces an inspectable HTML report and trace.
- A failed run retains screenshot, video, trace, JUnit output, and service logs.
- The admin readback observes the same public API used by the booking surface.
- The README distinguishes implemented evidence from planned evidence.

## Deliberate scope

The case study uses synthetic data and one slot. Authentication, payments,
calendar integrations, Kubernetes, performance claims, and unrelated CRUD are
excluded. The narrow scope is what makes every layer inspectable by a reviewer.
