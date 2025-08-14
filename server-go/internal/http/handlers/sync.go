package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/models"
)

type SyncHandler struct {
	cfg config.Config
	db  *gorm.DB
}

func NewSyncHandler(cfg config.Config, db *gorm.DB) *SyncHandler {
	return &SyncHandler{cfg: cfg, db: db}
}

func (h *SyncHandler) Pull(c *gin.Context) {
	// Simplified: return last 100 updated notes/categories
	userID := c.GetString("user_id")
	var notes []models.Note
	var cats []models.Category
	h.db.Where("user_id = ?", userID).Order("updated_at desc").Limit(100).Find(&notes)
	h.db.Where("user_id = ?", userID).Order("updated_at desc").Limit(100).Find(&cats)
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{
		"notes":          gin.H{"created": notes, "updated": []models.Note{}, "deleted": []string{}},
		"categories":     gin.H{"created": cats, "updated": []models.Category{}, "deleted": []string{}},
		"sync_timestamp": time.Now().UTC(),
	}})
}

func (h *SyncHandler) Push(c *gin.Context) {
	userID := c.GetString("user_id")
	var body map[string]map[string][]map[string]interface{}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request", "code": "VALIDATION_ERROR"})
		return
	}
	createdNotes := map[string]string{}
	createdCats := map[string]string{}
	// Only handle notes.create minimal
	if body != nil {
		if section, ok := body["notes"]; ok {
			if notesCreate, ok := section["create"]; ok {
				for _, n := range notesCreate {
					id := uuid.New()
					title, _ := n["title"].(string)
					content, _ := n["content"].(string)
					m := models.Note{ID: id, UserID: uuid.MustParse(userID), Title: title, Content: content}
					h.db.Create(&m)
					if localID, ok := n["id"].(string); ok && localID != "" {
						createdNotes[localID] = id.String()
					}
				}
			}
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Sync completed successfully", "data": gin.H{
		"conflicts":      []string{},
		"created_ids":    gin.H{"notes": createdNotes, "categories": createdCats},
		"sync_timestamp": time.Now().UTC(),
	}})
}
