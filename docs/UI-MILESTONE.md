# UI milestone — complete

The visual constraint in `DESIGN.md` and behavioral constraint in
`apps/web/patrol_test/last_slot_test.dart` is implemented.

## Delivered

1. `/book` presents loading, available, submitting, confirmed, conflict,
   validation, and temporary-failure states.
2. `/admin` is a read-only public-API view of the persisted booking.
3. Critical labels, slot state, outcome banners, and ledger values have
   explicit Flutter semantics; the form is keyboard-operable.
4. A barrier-synchronised HTTP/DB proof and a zero-retry two-page Patrol
   journey run against a fresh Docker Compose stack. Together they verify one
   `201`, one `409`, one durable row, visible success/conflict, fresh visitor
   readback, and admin readback.
5. CI uploads evidence on every run and publishes the successful HTML report
   from `main` to GitHub Pages.

## Definition of done

- The database remains the final double-booking authority.
- A temporary booking failure can retry with the same idempotency key.
- Success and conflict are visible as text and accessible semantics.
- The admin view reports exactly one persisted booking after the race.
- Fresh visitor pages show the same persisted booked state.
- Rust checks, Flutter analysis/tests, TypeScript checks, Docker build, and the
  full Patrol journey all pass from a clean checkout.
- README claims match the evidence produced by that run.
