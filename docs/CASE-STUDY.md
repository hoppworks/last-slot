# Case-study brief

## The claim

A single appointment can be offered to multiple visitors without being booked
twice, even under competing requests or client retries. The evidence is
executable and split: PostgreSQL enforces the invariant; an HTTP/DB proof and a
zero-retry browser journey verify it. The browser journey does not prove
simultaneous arrival.

## The browser proof

One zero-retry Patrol Web journey opens two browser pages one after the other,
types through the real input path, and visibly verifies one confirmation and
one explicit conflict. Two fresh visitor pages then load the persisted booked state, and a
fresh admin page reads exactly one confirmed booking.

The browser test uses only visible, accessible product behavior. It never
queries PostgreSQL and never calls a test-only endpoint.

## The durable proof

The HTTP/DB integration proof releases two real HTTP clients through a process
barrier for a dedicated synthetic fixture slot. It verifies one `201`, one
`409`, and one database row. It also verifies that sending one idempotency key
twice produces `201 → 200`, the same booking ID, and one database row.

## Why the result is trustworthy

| Layer | Responsibility |
|---|---|
| Flutter | Presents honest success, conflict, retry, and persisted states. |
| Axum gateway | Owns the versioned HTTP contract and stable error envelope. |
| tonic service | Validates booking intent and idempotent replay semantics. |
| PostgreSQL | Enforces one booking per slot and one result per idempotency key. |
| Patrol Web | Proves those guarantees survive the complete user journey. |

Patrol is the visible evidence layer, not the source of correctness. The
barrier-synchronised HTTP/DB proof checks that competing requests produce one
winner and one conflict, plus idempotent replay. It does not prove simultaneous
arrival. The browser journey catches broken wiring or dishonest UI states above
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
excluded. The narrow scope is what makes every layer inspectable.
