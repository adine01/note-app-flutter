package handlers

import "../../../../test_note_add_app/server-go/internal/http/handlers/github.com/gin-gonic/gin"

func ok(c *gin.Context, data gin.H) {
	c.JSON(200, gin.H{"success": true, "data": data})
}

func fail(c *gin.Context, status int, msg, code string) {
	c.JSON(status, gin.H{"success": false, "error": msg, "code": code})
}
