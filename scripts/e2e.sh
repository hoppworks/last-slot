#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

mkdir -p build

cleanup() {
  exit_code=$?
  docker compose logs --no-color >build/compose.log 2>&1 || true
  docker compose down --remove-orphans || true
  exit "$exit_code"
}
trap cleanup EXIT

wait_for_url() {
  url="$1"
  label="$2"
  attempt=1
  while (( attempt <= 90 )); do
    if curl --fail --silent --show-error "$url" >/dev/null; then
      return 0
    fi
    sleep 1
    ((attempt += 1))
  done
  echo "$label did not become ready: $url" >&2
  docker compose ps >&2
  docker compose logs --tail=120 >&2
  return 1
}

docker compose down --remove-orphans

(
  cd apps/web
flutter build web \
  --release \
  --wasm-dry-run
)

docker compose up --detach --build

wait_for_url \
  "http://127.0.0.1:8081/v1/slots/11111111-1111-4111-8111-111111111111" \
  "Public API"
wait_for_url "http://127.0.0.1:8081/healthz" "Flutter web"

APP_URL=http://127.0.0.1:8081 pnpm e2e
