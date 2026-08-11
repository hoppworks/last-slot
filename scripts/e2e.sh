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

bash scripts/http_integration.sh "http://127.0.0.1:8081"
rm -rf "$repository_root/build/playwright"

(
  cd apps/web
  dart run patrol_cli:main test \
    --device chrome \
    --target patrol_test/last_slot_test.dart \
    --dart-define=E2E_APP_URL=http://127.0.0.1:8081 \
    --test-server-port 8083 \
    --app-server-port 8084 \
    --web-port 8082 \
    --web-headless \
    --web-retries 0 \
    --web-timeout 60000 \
    --web-global-timeout 180000 \
    --web-results-dir "$repository_root/build/playwright/results" \
    --web-report-dir "$repository_root/build/playwright/html" \
    --web-traces-dir "$repository_root/build/playwright/traces" \
    --web-reporter='["html","junit","list"]' \
    --web-video retain-on-failure \
    --web-trace on \
    --web-screenshot only-on-failure \
    --no-check-compatibility
)
