package db

import (
	"fmt"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/models"
)

func Init(cfg config.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		cfg.MySQLUser, cfg.MySQLPass, cfg.MySQLHost, cfg.MySQLPort, cfg.MySQLDB,
	)
	gormCfg := &gorm.Config{Logger: logger.Default.LogMode(logger.Info)}
	db, err := gorm.Open(mysql.Open(dsn), gormCfg)
	if err != nil {
		return nil, err
	}
	// Auto-migrate schema
	if err := db.AutoMigrate(&models.User{}, &models.Category{}, &models.Note{}, &models.Attachment{}); err != nil {
		return nil, err
	}
	return db, nil
}
