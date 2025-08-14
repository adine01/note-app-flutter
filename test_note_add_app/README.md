# Test Note Add App

Flutter offline-first notes app with optional sync to a Go + MySQL REST API.

## Run the app

- Dev API URL (default): http://localhost:8080/v1
- Android emulator uses host loopback: http://10.0.2.2:8080/v1

Launch with a custom API URL:

- flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/v1

You can also change the URL at runtime in Settings > API Server (stored in SharedPreferences).

## Postman

A minimal collection is in `postman/Notes API.postman_collection.json`.

## Backend (Go)

- Exposed at http://localhost:8080
- Endpoints: /v1/health, /v1/auth/*, /v1/notes, etc.
- See TODO for the full backend plan and deliverables.
