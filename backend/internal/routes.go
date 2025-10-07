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
	//apiRouter := router.PathPrefix(config.ApiPathPrefix).Subrouter()
	wsRouter := router.PathPrefix(config.WsPathPrefix).Subrouter()
	NewChatRouter(logger, wsRouter, validator)
	return router
}
