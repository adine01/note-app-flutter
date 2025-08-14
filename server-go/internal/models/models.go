package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type User struct {
	ID           uuid.UUID `gorm:"type:char(36);primaryKey" json:"id"`
	Name         string    `gorm:"size:100;not null" json:"name"`
	Email        string    `gorm:"size:255;uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"size:255;not null" json:"-"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type Category struct {
	ID        uuid.UUID `gorm:"type:char(36);primaryKey" json:"id"`
	UserID    uuid.UUID `gorm:"type:char(36);index;not null" json:"user_id"`
	Name      string    `gorm:"size:50;not null" json:"name"`
	Color     *string   `gorm:"size:7" json:"color"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Note struct {
	ID        uuid.UUID      `gorm:"type:char(36);primaryKey" json:"id"`
	UserID    uuid.UUID      `gorm:"type:char(36);index;not null" json:"user_id"`
	Title     string         `gorm:"size:200;not null" json:"title"`
	Content   string         `gorm:"type:text" json:"content"`
	Category  *string        `gorm:"size:50" json:"category"`
	Tags      []string       `gorm:"type:json;serializer:json" json:"tags"`
	Archived  bool           `gorm:"type:tinyint(1);default:0" json:"archived"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

type Attachment struct {
	ID          uuid.UUID `gorm:"type:char(36);primaryKey" json:"id"`
	NoteID      uuid.UUID `gorm:"type:char(36);index;not null" json:"note_id"`
	FileName    string    `gorm:"size:255;not null" json:"file_name"`
	MimeType    string    `gorm:"size:100;not null" json:"mime_type"`
	Size        int64     `gorm:"not null" json:"size"`
	StoragePath string    `gorm:"size:512;not null" json:"storage_path"`
	CreatedAt   time.Time `json:"created_at"`
}
