package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/google/uuid"
	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/models"
)

type AuthHandler struct {
	cfg config.Config
	db  *gorm.DB
	v   *validator.Validate
}

func NewAuthHandler(cfg config.Config, db *gorm.DB) *AuthHandler {
	return &AuthHandler{cfg: cfg, db: db, v: validator.New()}
}

type registerReq struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=6"`
	Name     string `json:"name" validate:"required,max=100"`
}

type loginReq struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req registerReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request", "code": "VALIDATION_ERROR"})
		return
	}
	if err := h.v.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Validation failed", "code": "VALIDATION_ERROR"})
		return
	}
	var existing models.User
	if err := h.db.Where("email = ?", req.Email).First(&existing).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Email already exists", "code": "EMAIL_EXISTS"})
		return
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	user := models.User{
		ID:           uuid.New(),
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: string(hash),
	}
	if err := h.db.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to create user"})
		return
	}
	token := h.signToken(user.ID.String())
	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "User registered successfully",
		"data": gin.H{
			"user": gin.H{
				"id":         user.ID,
				"email":      user.Email,
				"name":       user.Name,
				"created_at": user.CreatedAt,
			},
			"token": token,
		},
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request", "code": "VALIDATION_ERROR"})
		return
	}
	if err := h.v.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Validation failed", "code": "VALIDATION_ERROR"})
		return
	}
	var user models.User
	if err := h.db.Where("email = ?", req.Email).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Invalid credentials", "code": "INVALID_CREDENTIALS"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Invalid credentials", "code": "INVALID_CREDENTIALS"})
		return
	}
	token := h.signToken(user.ID.String())
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Login successful",
		"data": gin.H{
			"user":  gin.H{"id": user.ID, "email": user.Email, "name": user.Name},
			"token": token,
		},
	})
}

func (h *AuthHandler) Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Logout successful"})
}

func (h *AuthHandler) signToken(userID string) string {
	claims := jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(24 * time.Hour).Unix(),
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	s, _ := t.SignedString([]byte(h.cfg.JWTSecret))
	return s
}
