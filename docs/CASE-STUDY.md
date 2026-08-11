# Case-study brief

## The claim

A single appointment can be offered to multiple visitors without being booked
twice, even when requests arrive concurrently or a client retries after an
uncertain response.

## The proof

The HTTP/DB integration proof releases two real HTTP clients through a process
barrier for a dedicated synthetic fixture slot. It verifies one `201`, one
`409`, and one database row. It also verifies that sending one idempotency key
twice produces `201 → 200`, the same booking ID, and one database row.

One Patrol Web test then opens two browser pages, fills the public slot for two
different people, and visibly verifies one confirmation and one explicit
conflict. A third browser opens the admin surface and reads one persisted
booking. Two fresh visitor pages then load the public API state and visibly show
that the slot is booked.

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

Patrol is the visible evidence layer, not the source of correctness. The
barrier-synchronised HTTP/DB proof establishes the concurrency and idempotency
invariants; the browser journey catches broken wiring or dishonest UI states
above that boundary.

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
