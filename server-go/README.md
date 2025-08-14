# Notes API (Go + Gin + GORM + MySQL)

Quickstart (Docker):
1. Copy .env.example to .env (optional)
2. docker compose up --build
3. API at http://localhost:8080; Adminer at http://localhost:8081

Health: GET http://localhost:8080/health
Base path: /v1

Default users table is empty. Register via POST /v1/auth/register.

