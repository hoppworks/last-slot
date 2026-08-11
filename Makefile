.PHONY: check down e2e format up

format:
	cargo fmt --all
	dart format apps/web/lib apps/web/test

check:
	cargo fmt --all -- --check
	cargo clippy --workspace --all-targets -- -D warnings
	cd apps/web && flutter analyze
	cd apps/web && flutter test
	pnpm typecheck

e2e:
	bash scripts/e2e.sh

up:
	cd apps/web && flutter build web --release --wasm-dry-run
	docker compose up --detach --build

down:
	docker compose down --remove-orphans
