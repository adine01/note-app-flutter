package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
)

func CORS(allowOrigins string) gin.HandlerFunc {
	allowed := strings.Split(allowOrigins, ",")
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		allow := "*"
		for _, a := range allowed {
			if a == "*" || strings.TrimSpace(a) == origin {
				allow = strings.TrimSpace(a)
				break
			}
		}
		c.Header("Access-Control-Allow-Origin", allow)
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Credentials", "true")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}
