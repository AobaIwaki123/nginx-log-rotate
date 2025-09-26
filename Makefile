clean:
	rm -rf nginx/logs

build:
	@docker compose build --no-cache

up:
	@docker compose up -d

exec:
	@docker compose exec -it nginx bash

down:
	@docker compose down

curl:
	@echo "curl -I localhost:80"
	@docker compose exec -it nginx curl -I localhost:80
	@docker compose exec -it nginx curl -I localhost:80
	@docker compose exec -it nginx curl -I localhost:80
