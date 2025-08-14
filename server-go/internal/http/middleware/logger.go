package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

func Logger() gin.HandlerFunc {
	log := logrus.New()
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		dur := time.Since(start)
		status := c.Writer.Status()
		log.WithFields(logrus.Fields{
			"method":  c.Request.Method,
			"path":    c.Request.URL.Path,
			"status":  status,
			"latency": dur.String(),
		}).Info("request")
	}
}
