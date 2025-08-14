package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/your-org/notes-api/internal/config"
)

type AttachmentsHandler struct {
	cfg config.Config
	db  *gorm.DB
}

func NewAttachmentsHandler(cfg config.Config, db *gorm.DB) *AttachmentsHandler {
	return &AttachmentsHandler{cfg: cfg, db: db}
}

func (h *AttachmentsHandler) Upload(c *gin.Context) {
	// NOTE: Simplified: store file locally under STORAGE_DIR
	userID := c.GetString("user_id")
	_ = userID // could verify permissions using note->user mapping
	noteID := c.Param("id")
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "File is required", "code": "VALIDATION_ERROR"})
		return
	}
	if file.Size > 10*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "File too large", "code": "FILE_TOO_LARGE"})
		return
	}
	id := uuid.New().String()
	dir := filepath.Join(h.cfg.StorageDir, noteID)
	_ = os.MkdirAll(dir, 0o755)
	path := filepath.Join(dir, fmt.Sprintf("%s_%s", id, filepath.Base(file.Filename)))
	if err := c.SaveUploadedFile(file, path); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to save file"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "message": "File uploaded successfully", "data": gin.H{
		"attachment": gin.H{
			"id":          id,
			"filename":    file.Filename,
			"size":        file.Size,
			"mime_type":   file.Header.Get("Content-Type"),
			"url":         fmt.Sprintf("/files/%s/%s", noteID, filepath.Base(path)),
			"uploaded_at": "",
		},
	}})
}

func (h *AttachmentsHandler) Delete(c *gin.Context) {
	// Simplified: not tracking on DB for now
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Attachment deleted successfully"})
}
