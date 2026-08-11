# Last Slot — technical one-pager

## The problem

Two visitors can see the same final appointment and submit at the same time.
The product must never imply that both succeeded when only one persisted
booking is valid.

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

## The proof

The Patrol Web test opens two browser pages, uses actual keyboard
input, submits both booking forms concurrently, then opens a fresh `/admin`
browser. It asserts one success, one conflict, exactly one readback, and the
same booked state after both visitors refresh. It has `retries: 0`, calls no
database or test-only endpoint, and retains a trace for every run.

Run it locally with `bash scripts/e2e.sh`. CI runs the same command and publishes
the report from successful `main` builds.

## Deliberate trade-off

The project uses one gateway and one booking service to make the public HTTP
boundary and durable domain boundary separately inspectable. This is more
structure than a single-process demo, but no extra services are introduced:
the trade-off is legibility of the reliability argument over feature breadth.

## Negative case

If the unique constraint on `bookings.slot_id` is removed, the service can
accept both concurrent requests. The browser proof then fails its `1:1`
success/conflict assertion: two success banners appear and the ledger can no
longer substantiate the invariant. This is intentionally not a runtime switch
in the public demo; it is a documented failure mode of the durable guard, not a
feature for users to trigger.

## Two-minute demo and STAR narrative

**Demo:** Open two fresh browser windows on `/book`, enter Ada and Linus, then
submit together. Point out the one confirmation and one honest conflict. Open
`/admin`, show exactly one booked name, then refresh both visitor pages. End by
opening the Patrol report: this is the same path, recorded without retries.

**Situation:** a last appointment is shown to two people at once. **Task:**
guarantee that the application never represents two bookings as valid.
**Action:** enforce the rule in PostgreSQL, make retries idempotent, expose a
stable conflict contract, and prove it through separate browser contexts.
**Result:** a fresh zero-retry browser run yields one persisted booking and an
inspectable trace; no production-scale or uptime claim is implied.

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

The lesson is the thesis of the project in miniature: a green unit layer is not
enough. The real public path, with separate browsers and a fresh readback, is
where hidden integration assumptions become observable.
