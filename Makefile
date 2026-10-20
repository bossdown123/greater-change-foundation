.PHONY: up down check migrate verify
up:
	docker compose up -d --build
down:
	docker compose down
migrate:
	docker compose run --rm migrate deploy --verify
verify:
	docker compose run --rm migrate verify
check:
	docker compose run --rm migrate verify
	curl --fail http://localhost:4000/healthz
	curl --fail http://localhost:4000/readyz
