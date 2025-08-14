package config

import (
	"os"
)

type Config struct {
	AppPort          string
	AppEnv           string
	JWTSecret        string
	MySQLHost        string
	MySQLPort        string
	MySQLDB          string
	MySQLUser        string
	MySQLPass        string
	CORSAllowOrigins string
	StorageDir       string
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func Load() Config {
	return Config{
		AppPort:          getenv("APP_PORT", "8080"),
		AppEnv:           getenv("APP_ENV", "dev"),
		JWTSecret:        getenv("JWT_SECRET", "change-me"),
		MySQLHost:        getenv("MYSQL_HOST", "mysql"),
		MySQLPort:        getenv("MYSQL_PORT", "3306"),
		MySQLDB:          getenv("MYSQL_DB", "notes"),
		MySQLUser:        getenv("MYSQL_USER", "notes"),
		MySQLPass:        getenv("MYSQL_PASS", "notes"),
		CORSAllowOrigins: getenv("CORS_ALLOW_ORIGINS", "*"),
		StorageDir:       getenv("STORAGE_DIR", "/var/app/storage"),
	}
}
