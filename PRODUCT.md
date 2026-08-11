# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Flutter Web with Riverpod and GoRouter; a Rust Axum gateway calling a tonic
booking service; PostgreSQL through SQLx; Docker Compose for local orchestration;
and Patrol Web in GitHub Actions.

## Users

The project should be understandable without prior context and demonstrate
software that remains correct under retries and concurrent use.

## Product Purpose

Last Slot is a small, executable reliability case study. It lets two visitors
compete for the same final appointment and proves that exactly one booking is
created. Success means the invariant is easy to understand, the system can run
locally, and the Patrol evidence traces behavior across the browser, API,
service, and database.

## Positioning

The project does not claim reliability through a testing-tool badge. It exposes
one meaningful invariant — one slot can have at most one booking — implements
that invariant at the database boundary, and proves it through two real browser
sessions and a visible admin readback.

## Operating Context

The repository should start with Docker Compose, run one deterministic
end-to-end journey, and retain traces, screenshots, video on failure, and an
HTML report. The live demo and repository use synthetic people and appointment
data.

## Capabilities and Constraints

- Two independent browser sessions can attempt the same booking concurrently.
- Exactly one booking succeeds; the other receives an honest conflict state.
- Refreshes and retried requests cannot create duplicate bookings.
- An admin surface reads the persisted result through the same public API.
- The public HTTP contract is versioned under `/v1` and uses idempotency keys.
- The repository remains intentionally small: one gateway, one domain service,
  one database, and one Flutter application.
- Authentication, payments, Kubernetes, and unrelated business features are out
  of scope.

## Brand Commitments

The product name is **Last Slot**. The primary line is **“One slot. Two
browsers. One correct result.”** Product and repository copy are English-first
for a broad technical audience. Claims must be backed by executable evidence;
synthetic demonstration data is labeled as such.

## Evidence on Hand

The confirmed evidence target is the Patrol journey, its trace and report,
the database constraints, and CI output. There are no customer testimonials,
performance benchmarks, uptime claims, or commercial deployment claims, and
future work must not invent them.

## Approved Design Direction

The approved direction is implemented as a clean engineering case study:
warm editorial canvas, restrained forest-green identity, Manrope and mono
type contrast, booking and ledger surfaces, a compact architecture flow, and a
factual proof strip. The paired browser experience is supplied by the
executable Patrol journey rather than by decorative screenshots.

## Product Principles

1. Prove behavior instead of describing intent.
2. Put correctness at the lowest durable boundary and verify it from the top.
3. Prefer one complete vertical slice over broad scaffolding.
4. Make failures observable, reproducible, and understandable to a cold reader.
5. Keep the architecture proportional to the invariant being demonstrated.

## Accessibility & Inclusion

The booking and admin surfaces target WCAG 2.2 AA. All critical states have
semantic labels, keyboard access, visible focus, and text in addition to color.
