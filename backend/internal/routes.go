package internal

import (
	"net/http"

	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

func SetupRoutes(config *Config, logger *zap.Logger, validator *TokenValidator) *mux.Router {
	router := mux.NewRouter()
	requestLogger := &RequestLogger{logger}
	router.Use(requestLogger.loggingMiddleware)
	router.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		WriteString(w, "OK", http.StatusOK)
	})
	NewChatRouter(logger, router, config.WsPathPrefix, validator)
	return router
}
