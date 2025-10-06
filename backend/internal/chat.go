package internal

import (
	"net/http"

	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

type ChatRouter struct {
	logger *zap.Logger
	router *mux.Router
}

func NewChatRouter(logger *zap.Logger,
	rootRouter *mux.Router,
	pathPrefix string,
	validator *TokenValidator) *ChatRouter {
	router := rootRouter.PathPrefix(pathPrefix).Subrouter()
	router.Use(validator.ValidatingMiddleware)
	chatRouter := &ChatRouter{logger: logger,
		router: router}
	chatRouter.registerRoutes()
	return chatRouter
}

func (r *ChatRouter) registerRoutes() {
	r.router.HandleFunc("/chat", r.Chat)
}

func (r *ChatRouter) Chat(w http.ResponseWriter, _ *http.Request) {
	WriteString(w, "Hello", http.StatusOK)
}
