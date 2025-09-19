package internal

import (
	"fmt"
	"net"
	"net/http"
	"os"

	"go.uber.org/zap"
)

type Server struct {
	Port     int
	LogLevel string
	logger   *zap.Logger
}

func (s *Server) Serve() {
	cfg := zap.NewProductionConfig()
	level, err := zap.ParseAtomicLevel(s.LogLevel)
	ExpectNil(err)
	cfg.Level = level
	logger, err := cfg.Build()
	ExpectNil(err)
	s.logger = logger
	defer ignore(logger.Sync)
	http.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		WriteString(w, "OK", http.StatusOK)
	})
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", s.Port))
	if err != nil {
		logger.Error("Failed to listen", zap.Error(err))
		os.Exit(1)
	}
	fmt.Printf("Listening on port %d\n", s.Port)
	err = http.Serve(listener, nil)
	if err != nil {
		logger.Error("Failed to start server", zap.Error(err))
		os.Exit(1)
	}
}
