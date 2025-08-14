package handlers

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/models"
)

type NotesHandler struct {
	cfg config.Config
	db  *gorm.DB
}

func NewNotesHandler(cfg config.Config, db *gorm.DB) *NotesHandler {
	return &NotesHandler{cfg: cfg, db: db}
}

type noteReq struct {
	Title    string   `json:"title"`
	Content  string   `json:"content"`
	Category *string  `json:"category"`
	Tags     []string `json:"tags"`
}

func (h *NotesHandler) List(c *gin.Context) {
	userID := c.GetString("user_id")
	var notes []models.Note
	q := h.db.Where("user_id = ?", userID)
	if s := c.Query("search"); s != "" {
		like := "%" + strings.ToLower(s) + "%"
		q = q.Where("LOWER(title) LIKE ? OR LOWER(content) LIKE ?", like, like)
	}
	if c.Query("archived") == "true" {
		q = q.Where("archived = 1")
	} else {
		q = q.Where("archived = 0")
	}
	var total int64
	q.Model(&models.Note{}).Count(&total)
	page := 1
	limit := 20
	if v := c.Query("page"); v != "" {
		fmt.Sscanf(v, "%d", &page)
	}
	if v := c.Query("limit"); v != "" {
		fmt.Sscanf(v, "%d", &limit)
	}
	offset := (page - 1) * limit
	if err := q.Limit(limit).Offset(offset).Order("updated_at desc").Find(&notes).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to fetch notes"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{
		"notes": notes,
		"pagination": gin.H{
			"current_page":   page,
			"total_pages":    (total + int64(limit) - 1) / int64(limit),
			"total_items":    total,
			"items_per_page": limit,
		},
	}})
}

func (h *NotesHandler) Get(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")
	var note models.Note
	if err := h.db.Where("user_id = ? AND id = ?", userID, id).First(&note).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Note not found", "code": "NOTE_NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"note": note}})
}

func (h *NotesHandler) Create(c *gin.Context) {
	userID := c.GetString("user_id")
	if strings.TrimSpace(userID) == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Missing user", "code": "TOKEN_INVALID"})
		return
	}
	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Invalid user id", "code": "TOKEN_INVALID"})
		return
	}
	var req noteReq
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Title) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Validation failed", "code": "VALIDATION_ERROR", "details": gin.H{"title": "Title cannot be empty"}})
		return
	}
	note := models.Note{
		ID:       uuid.New(),
		UserID:   uid,
		Title:    req.Title,
		Content:  req.Content,
		Category: req.Category,
		Tags:     append([]string{}, req.Tags...),
		Archived: false,
	}
	if err := h.db.Create(&note).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": fmt.Sprintf("Failed to create note: %v", err)})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "message": "Note created successfully", "data": gin.H{"note": note}})
}

func (h *NotesHandler) Update(c *gin.Context) {
	userID := c.GetString("user_id")
	if strings.TrimSpace(userID) == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Missing user", "code": "TOKEN_INVALID"})
		return
	}
	id := c.Param("id")
	var note models.Note
	if err := h.db.Where("user_id = ? AND id = ?", userID, id).First(&note).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Note not found", "code": "NOTE_NOT_FOUND"})
		return
	}
	var req noteReq
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Title) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Validation failed", "code": "VALIDATION_ERROR", "details": gin.H{"title": "Title cannot be empty"}})
		return
	}
	note.Title = req.Title
	note.Content = req.Content
	note.Category = req.Category
	note.Tags = append([]string{}, req.Tags...)
	if err := h.db.Save(&note).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": fmt.Sprintf("Failed to update note: %v", err)})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Note updated successfully", "data": gin.H{"note": note}})
}

func (h *NotesHandler) Delete(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")
	if err := h.db.Where("user_id = ? AND id = ?", userID, id).Delete(&models.Note{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to delete note"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Note deleted successfully"})
}

func (h *NotesHandler) Archive(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")
	var payload struct {
		Archived bool `json:"archived"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request"})
		return
	}
	if err := h.db.Model(&models.Note{}).Where("user_id = ? AND id = ?", userID, id).Update("archived", payload.Archived).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to archive note"})
		return
	}
	var note models.Note
	h.db.Where("user_id = ? AND id = ?", userID, id).First(&note)
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Note archived successfully", "data": gin.H{"note": note}})
}

func (h *NotesHandler) BulkDelete(c *gin.Context) {
	userID := c.GetString("user_id")
	var payload struct {
		NoteIDs []string `json:"note_ids"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil || len(payload.NoteIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request", "code": "VALIDATION_ERROR"})
		return
	}
	res := h.db.Where("user_id = ? AND id IN ?", userID, payload.NoteIDs).Delete(&models.Note{})
	failed := []string{}
	if res.Error != nil {
		failed = payload.NoteIDs
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "bulk delete", "data": gin.H{"deleted_count": res.RowsAffected, "failed_ids": failed}})
}
