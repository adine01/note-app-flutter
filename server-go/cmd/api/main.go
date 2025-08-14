package main

import (
	"log"
	"os"

	"github.com/joho/godotenv"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/db"
	"github.com/your-org/notes-api/internal/http/router"
)

func main() {
	_ = godotenv.Load()

	cfg := config.Load()

	// Init DB
	gormDB, err := db.Init(cfg)
	if err != nil {
		log.Fatalf("failed to init db: %v", err)
	}

	r := router.New(cfg, gormDB)

	addr := ":" + cfg.AppPort
	if v := os.Getenv("PORT"); v != "" {
		addr = ":" + v
	}
	if err := r.Run(addr); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
