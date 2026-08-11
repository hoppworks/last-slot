#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_base_url="${1:-http://127.0.0.1:8081}"
evidence_dir="$repository_root/build/http-integration"
race_slot_id='22222222-2222-4222-8222-222222222222'
idempotency_slot_id='33333333-3333-4333-8333-333333333333'

mkdir -p "$evidence_dir"

fail() {
  echo "HTTP integration proof failed: $*" >&2
  exit 1
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected $expected, got $actual)"
}

post_booking() {
  local slot_id="$1"
  local name="$2"
  local idempotency_key="$3"
  local body_file="$4"

  curl \
    --silent \
    --show-error \
    --output "$body_file" \
    --write-out '%{http_code}' \
    --header 'Content-Type: application/json' \
    --header "Idempotency-Key: $idempotency_key" \
    --data "{\"customerName\":\"$name\"}" \
    "$api_base_url/v1/slots/$slot_id/bookings"
}

booking_id_from() {
  sed -nE 's/.*"booking":\{"id":"([^"]+)".*/\1/p' "$1"
}

database_count_for_slot() {
  docker compose exec -T postgres \
    psql -U lastslot -d lastslot -tA \
    -c "SELECT count(*) FROM bookings WHERE slot_id = '$1';" \
    | tr -d '[:space:]'
}

first_gate="$evidence_dir/first.gate"
second_gate="$evidence_dir/second.gate"
rm -f "$first_gate" "$second_gate"
mkfifo "$first_gate" "$second_gate"
trap 'rm -f "$first_gate" "$second_gate"' EXIT

first_body="$evidence_dir/race-first.json"
second_body="$evidence_dir/race-second.json"
first_code="$evidence_dir/race-first.status"
second_code="$evidence_dir/race-second.status"

# Each worker blocks at its own gate. Opening both gates from background
# writers releases the two HTTP requests together instead of serialising them
# in the shell that orchestrates the proof.
(
  read -r _ <"$first_gate"
  post_booking "$race_slot_id" 'Ada' "$(uuidgen)" "$first_body" >"$first_code"
) &
first_worker=$!
(
  read -r _ <"$second_gate"
  post_booking "$race_slot_id" 'Linus' "$(uuidgen)" "$second_body" >"$second_code"
) &
second_worker=$!
(
  printf 'go\n' >"$first_gate"
) &
first_release=$!
(
  printf 'go\n' >"$second_gate"
) &
second_release=$!

wait "$first_release"
wait "$second_release"
wait "$first_worker"
wait "$second_worker"

race_codes="$(sort "$first_code" "$second_code" | tr '\n' ' ')"
assert_equal "$race_codes" '201 409 ' 'concurrent requests must produce one create and one conflict'
assert_equal "$(database_count_for_slot "$race_slot_id")" '1' 'the concurrent slot must have exactly one persisted booking'

idempotency_key="$(uuidgen)"
first_idempotency_body="$evidence_dir/idempotency-first.json"
second_idempotency_body="$evidence_dir/idempotency-second.json"
first_idempotency_code="$(post_booking "$idempotency_slot_id" 'Grace' "$idempotency_key" "$first_idempotency_body")"
second_idempotency_code="$(post_booking "$idempotency_slot_id" 'Grace' "$idempotency_key" "$second_idempotency_body")"
assert_equal "$first_idempotency_code" '201' 'the first idempotent request must create a booking'
assert_equal "$second_idempotency_code" '200' 'the replayed idempotent request must return the original booking'

first_booking_id="$(booking_id_from "$first_idempotency_body")"
second_booking_id="$(booking_id_from "$second_idempotency_body")"
[[ -n "$first_booking_id" ]] || fail 'first idempotency response did not contain a booking ID'
assert_equal "$second_booking_id" "$first_booking_id" 'idempotent replay must return the same booking ID'
assert_equal "$(database_count_for_slot "$idempotency_slot_id")" '1' 'the idempotency fixture must have exactly one persisted booking'

{
  echo 'HTTP/DB integration proof passed'
  echo "race HTTP statuses: $race_codes"
  echo 'race persisted bookings: 1'
  echo "idempotency HTTP statuses: $first_idempotency_code -> $second_idempotency_code"
  echo "idempotency booking ID: $first_booking_id"
  echo 'idempotency persisted bookings: 1'
} | tee "$evidence_dir/summary.txt"
