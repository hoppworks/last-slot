# Last Slot — executable reliability case study

## The testing question

Can an automated browser test prove that a cross-layer reliability guarantee is
visible to real users, rather than merely green inside unit and API tests?

Last Slot keeps the product scenario deliberately small: two visitors see the
same final appointment, but only one booking may survive. That makes the full
evidence path understandable in minutes while still crossing Flutter, HTTP,
gRPC, PostgreSQL, and independent browser pages.

## The invariant

PostgreSQL is the final authority: a unique constraint allows at most one
booking for the slot. A separate unique idempotency-key constraint returns the
original result when the same booking intent is retried. The application layers
cannot weaken either guarantee.

## Decisions and alternatives

| Decision | Alternative declined | Consequence |
| --- | --- | --- |
| Unique database constraint | App-level “check then insert” | The database, not timing in one process, resolves the race. |
| Client idempotency key | Retrying every POST as a new intent | A timeout can safely replay one intent without a second booking. |
| Explicit `409 slot_taken` | Generic error or false success | The losing visitor receives an honest, actionable outcome. |
| Public `/admin` readback | Database assertion in the test | The proof covers the same read path available in the app. |

## Visible failure modes

| Condition | User-facing result | Contract |
| --- | --- | --- |
| First valid booking | Confirmed booking | `201 Created` |
| Same key retried | Original booking | `200 OK` |
| Competing booking | Honest conflict, no second booking | `409 slot_taken` |
| Temporary service failure | Safe retry of the same intent | `503 Retry-After` |
| Invalid customer name | Actionable validation message | `422` |

## The evidence design

The Patrol Web journey opens two browser pages one after the other, uses actual
keyboard input, visibly verifies one confirmation and one conflict, opens two fresh visitor
pages into the persisted booked state, and opens a fresh admin browser. It has
`retries: 0`, calls no database or test-only endpoint, and retains a trace for
every run.

A separate HTTP/database proof owns the part a UI test should not fake. It
releases two real HTTP clients behind a process barrier and verifies one `201`,
one `409`, and exactly one database row. It also sends one idempotency key twice
and verifies `201 → 200`, the same booking ID, and one durable row. The barrier
is best-effort: it does not prove simultaneous arrival.

The two layers meet at the public contract: one establishes the durable
invariant; the other proves that fresh users can observe the correct result
through the real interface.

Run it locally with `bash scripts/e2e.sh`. Public GitHub Actions and GitHub
Pages are not part of the evidence.

## Deliberate trade-off

The project uses one gateway and one booking service to make the public HTTP
boundary and durable domain boundary separately inspectable. This is more
structure than a single-process demo, but no extra services are introduced:
the trade-off is legibility of the reliability argument over feature breadth.

## Negative case

If the unique constraint on `bookings.slot_id` is removed, the service can
accept both competing requests. The HTTP/DB proof then fails its `201 + 409`
and one-row assertions, and the browser proof shows two success banners: the
ledger can no longer substantiate the invariant. This is intentionally not a runtime switch
in the public demo; it is a documented failure mode of the durable guard, not a
feature for users to trigger.

## Two-minute browser demo and STAR narrative

**Demo:** Open two fresh browser windows on `/book`, enter Ada and Linus, then
submit one after the other to show the same public confirmation/conflict
outcomes. Open `/admin`, show exactly one booked name, then open two fresh
visitor pages. The accompanying HTTP/DB proof releases barrier-synchronised
competing requests;
the Patrol report records the browser-visible journey without retries.

**Situation:** unit and service tests cannot establish that a real browser shows
the truth after a cross-layer race. **Task:** make the reliability guarantee
visible and independently inspectable. **Action:** enforce the rule in
PostgreSQL, expose stable error semantics, prove barrier-released HTTP requests,
then drive two browser pages one after the other through confirmation, conflict,
and fresh readback. **Result:** one command produces the durable invariant plus a
zero-retry browser report and trace; no production-scale or uptime claim is
implied.

# Postmortem — making the proof real

The initially checked-in browser journey was deliberately red because the UI
did not yet exist. Building the interface exposed three integration facts that
unit tests alone could not prove:

1. Flutter Web collapses passive text into a generic semantics group unless
   critical text receives an explicit semantic container. The fix made the
   slot, status, outcomes, and ledger individually accessible as well as
   testable.
2. Programmatic `fill()` can update Flutter Web's DOM input without reliably
   committing the value to Flutter's controller during concurrent browser work.
   The proof now uses focus plus sequential keyboard events — the actual user
   interaction it claims to verify.
3. Setting GoRouter's initial location to `/book` made deep links to `/admin`
   silently render the booking page. Production now derives the initial route
   from the browser URL, while tests can explicitly set their start route.

The lesson is the thesis of the project: a green unit layer is not enough. The
real public path, with separate browsers and a fresh readback, is where hidden
integration assumptions become observable.
