package internal

import (
	"net/http"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

func SetupRoutes(config *Config,
	awsCfg *aws.Config,
	logger *zap.Logger,
	validator *TokenValidator) *mux.Router {
	router := mux.NewRouter()
	requestLogger := &RequestLogger{logger}
	router.Use(requestLogger.loggingMiddleware)
	router.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		WriteString(w, "OK", http.StatusOK)
	})
	apiRouter := router.PathPrefix(config.ApiPathPrefix).Subrouter()
	wsRouter := router.PathPrefix(config.WsPathPrefix).Subrouter()
	NewChatRouter(logger, wsRouter, validator)
	NewUsersRouter(config, logger, apiRouter, awsCfg, validator)
	return router
}
