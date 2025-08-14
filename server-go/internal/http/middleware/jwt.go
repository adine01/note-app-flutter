package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func JWTAuth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		parts := strings.SplitN(auth, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Missing token", "code": "TOKEN_INVALID"})
			return
		}
		tokenStr := parts[1]
		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Invalid token", "code": "TOKEN_INVALID"})
			return
		}
		// exp check
		if expVal, ok := claims["exp"]; ok {
			switch v := expVal.(type) {
			case float64:
				if time.Now().Unix() > int64(v) {
					c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Token expired", "code": "TOKEN_EXPIRED"})
					return
				}
			}
		}
		uid, _ := claims["user_id"].(string)
		if uid == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Token missing user", "code": "TOKEN_INVALID"})
			return
		}
		c.Set("user_id", uid)
		c.Next()
	}
}
