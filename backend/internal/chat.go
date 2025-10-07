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
	validator *TokenValidator) *ChatRouter {
	router := rootRouter.PathPrefix("/chat").Subrouter()
	router.Use(validator.ValidatingMiddleware)
	chatRouter := &ChatRouter{logger: logger,
		router: router}
	chatRouter.registerRoutes()
	return chatRouter
}

func (r *ChatRouter) registerRoutes() {
	r.router.HandleFunc("/", r.Chat)
}

func (r *ChatRouter) Chat(w http.ResponseWriter, _ *http.Request) {
	WriteString(w, "Hello", http.StatusOK)
}
