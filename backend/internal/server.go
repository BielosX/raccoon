package internal

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

type Server struct {
	Config         *Config
	logger         *zap.Logger
	tokenValidator *TokenValidator
}

func (s *Server) loggingMiddleware(next http.Handler) http.Handler {
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
		s.logger.Info(fmt.Sprintf("%s - - [%s] \"%s %s %s\"", from, iso, r.Method, r.URL, r.Proto))
		next.ServeHTTP(w, r)
	})
}

func (s *Server) Serve() {
	cfg := zap.NewProductionConfig()
	level, err := zap.ParseAtomicLevel(s.Config.LogLevel)
	ExpectNil(err)
	cfg.Level = level
	logger, err := cfg.Build()
	ExpectNil(err)
	s.logger = logger
	s.tokenValidator = NewTokenValidator(s.Config, logger)
	defer ignore(logger.Sync)
	err = s.tokenValidator.LoadOpenIdConfig(context.Background())
	ExpectNil(err)
	err = s.tokenValidator.LoadJwks(context.Background())
	ExpectNil(err)
	router := mux.NewRouter()
	router.Use(s.loggingMiddleware)
	router.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		WriteString(w, "OK", http.StatusOK)
	})
	http.Handle("/", router)
	wsRouter := router.PathPrefix(s.Config.WsPathPrefix).Subrouter()
	wsRouter.Use(s.tokenValidator.ValidatingMiddleware)
	wsRouter.HandleFunc("/chat", func(w http.ResponseWriter, _ *http.Request) {
		WriteString(w, "Hello", http.StatusOK)
	})
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", s.Config.Port))
	if err != nil {
		logger.Error("Failed to listen", zap.Error(err))
		os.Exit(1)
	}
	fmt.Printf("Listening on port %d\n", s.Config.Port)
	err = http.Serve(listener, nil)
	if err != nil {
		logger.Error("Failed to start server", zap.Error(err))
		os.Exit(1)
	}
}
