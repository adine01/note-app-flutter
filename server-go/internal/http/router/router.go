package router

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"github.com/your-org/notes-api/internal/config"
	"github.com/your-org/notes-api/internal/http/handlers"
	"github.com/your-org/notes-api/internal/http/middleware"
)

func New(cfg config.Config, db *gorm.DB) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.Logger())
	r.Use(middleware.CORS(cfg.CORSAllowOrigins))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now().UTC()})
	})

	r.Static("/files", cfg.StorageDir)

	api := r.Group("/v1")
	{
		api.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now().UTC()})
		})

		auth := handlers.NewAuthHandler(cfg, db)
		notes := handlers.NewNotesHandler(cfg, db)
		cats := handlers.NewCategoriesHandler(cfg, db)
		search := handlers.NewSearchHandler(cfg, db)
		sync := handlers.NewSyncHandler(cfg, db)
		attach := handlers.NewAttachmentsHandler(cfg, db)

		api.POST("/auth/register", auth.Register)
		api.POST("/auth/login", auth.Login)

		api.Use(middleware.JWTAuth(cfg.JWTSecret))
		{
			api.POST("/auth/logout", auth.Logout)

			api.GET("/notes", notes.List)
			api.GET("/notes/:id", notes.Get)
			api.POST("/notes", notes.Create)
			api.PUT("/notes/:id", notes.Update)
			api.DELETE("/notes/:id", notes.Delete)
			api.POST("/notes/:id/archive", notes.Archive)
			api.POST("/notes/bulk-delete", notes.BulkDelete)

			api.GET("/categories", cats.List)
			api.POST("/categories", cats.Create)
			api.PUT("/categories/:id", cats.Update)
			api.DELETE("/categories/:id", cats.Delete)

			api.GET("/search", search.Search)

			api.GET("/sync", sync.Pull)
			api.POST("/sync", sync.Push)

			api.POST("/notes/:id/attachments", attach.Upload)
			api.DELETE("/attachments/:id", attach.Delete)
		}
	}
	return r
}
