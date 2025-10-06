package internal

import (
	"fmt"
	"net/http"
	"time"

	"go.uber.org/zap"
)

type RequestLogger struct {
	logger *zap.Logger
}

func (l *RequestLogger) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		forwardedFor := r.Header.Get("X-Forwarded-For")
		var from string
		if forwardedFor != "" {
			from = forwardedFor
		} else {
			from = r.RemoteAddr
		}
		now := time.Now()
		iso := now.Format(time.RFC3339)
		l.logger.Info(fmt.Sprintf("%s - - [%s] \"%s %s %s\"", from, iso, r.Method, r.URL, r.Proto))
		next.ServeHTTP(w, r)
	})
}
