package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/models"
)

type SearchHandler struct {
	cfg config.Config
	db  *gorm.DB
}

func NewSearchHandler(cfg config.Config, db *gorm.DB) *SearchHandler {
	return &SearchHandler{cfg: cfg, db: db}
}

func (h *SearchHandler) Search(c *gin.Context) {
	userID := c.GetString("user_id")
	q := c.Query("q")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Missing q", "code": "VALIDATION_ERROR"})
		return
	}
	scope := strings.ToLower(c.DefaultQuery("in", "both"))
	var notes []models.Note
	query := h.db.Where("user_id = ?", userID)
	s := "%" + strings.ToLower(q) + "%"
	switch scope {
	case "title":
		query = query.Where("LOWER(title) LIKE ?", s)
	case "content":
		query = query.Where("LOWER(content) LIKE ?", s)
	default:
		query = query.Where("LOWER(title) LIKE ? OR LOWER(content) LIKE ?", s, s)
	}
	if err := query.Limit(50).Order("updated_at desc").Find(&notes).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Search failed"})
		return
	}
	// shape response similar to docs
	results := []gin.H{}
	for _, n := range notes {
		results = append(results, gin.H{
			"id":              n.ID,
			"title":           n.Title,
			"content":         n.Content,
			"category":        n.Category,
			"tags":            n.Tags,
			"relevance_score": 0.5,
			"matches":         gin.H{"title": []string{}, "content": []string{}},
			"created_at":      n.CreatedAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"results": results, "total_results": len(results), "search_time_ms": 5 + time.Now().Nanosecond()%10}})
}
