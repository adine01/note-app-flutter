package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/models"
)

type CategoriesHandler struct {
	cfg config.Config
	db  *gorm.DB
	v   *validator.Validate
}

func NewCategoriesHandler(cfg config.Config, db *gorm.DB) *CategoriesHandler {
	return &CategoriesHandler{cfg: cfg, db: db, v: validator.New()}
}

type categoryReq struct {
	Name  string  `json:"name" validate:"required,max=50"`
	Color *string `json:"color"`
}

func (h *CategoriesHandler) List(c *gin.Context) {
	userID := c.GetString("user_id")
	var cats []models.Category
	if err := h.db.Where("user_id = ?", userID).Find(&cats).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to fetch categories"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"categories": cats}})
}

func (h *CategoriesHandler) Create(c *gin.Context) {
	userID := c.GetString("user_id")
	var req categoryReq
	if err := c.ShouldBindJSON(&req); err != nil || h.v.Struct(req) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Validation failed", "code": "VALIDATION_ERROR"})
		return
	}
	cat := models.Category{ID: uuid.New(), UserID: uuid.MustParse(userID), Name: req.Name, Color: req.Color}
	if err := h.db.Create(&cat).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to create category"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "message": "Category created successfully", "data": gin.H{"category": cat}})
}

func (h *CategoriesHandler) Update(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")
	var req categoryReq
	if err := c.ShouldBindJSON(&req); err != nil || h.v.Struct(req) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Validation failed", "code": "VALIDATION_ERROR"})
		return
	}
	res := h.db.Model(&models.Category{}).Where("user_id = ? AND id = ?", userID, id).Updates(map[string]interface{}{"name": req.Name, "color": req.Color})
	if res.Error != nil || res.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Category not found", "code": "CATEGORY_NOT_FOUND"})
		return
	}
	var cat models.Category
	h.db.Where("user_id = ? AND id = ?", userID, id).First(&cat)
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"category": cat}})
}

func (h *CategoriesHandler) Delete(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")
	res := h.db.Where("user_id = ? AND id = ?", userID, id).Delete(&models.Category{})
	if res.Error != nil || res.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Category not found", "code": "CATEGORY_NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Category deleted successfully"})
}
