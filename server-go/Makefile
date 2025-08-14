include .env

.PHONY: run build docker-up docker-down migrate-up migrate-down

run:
	go run ./cmd/api

build:
	go build -o bin/api ./cmd/api

docker-up:
	docker compose up --build

docker-down:
	docker compose down -v
