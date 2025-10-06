package internal

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"

	"go.uber.org/zap"
)

type Server struct {
	Config         *Config
	logger         *zap.Logger
	tokenValidator *TokenValidator
}

func NewServer(config *Config) (*Server, error) {
	cfg := zap.NewProductionConfig()
	level, err := zap.ParseAtomicLevel(config.LogLevel)
	if err != nil {
		return nil, err
	}
	cfg.Level = level
	logger, err := cfg.Build()
	if err != nil {
		return nil, err
	}
	defer ignore(logger.Sync)
	tokenValidator := NewTokenValidator(config, logger)
	err = tokenValidator.LoadOpenIdConfig(context.Background())
	if err != nil {
		return nil, err
	}
	err = tokenValidator.LoadJwks(context.Background())
	if err != nil {
		return nil, err
	}
	return &Server{
		Config:         config,
		logger:         logger,
		tokenValidator: tokenValidator,
	}, nil
}

func (s *Server) Serve() {
	defer ignore(s.logger.Sync)
	router := SetupRoutes(s.Config, s.logger, s.tokenValidator)
	http.Handle("/", router)
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", s.Config.Port))
	if err != nil {
		s.logger.Error("Failed to listen", zap.Error(err))
		os.Exit(1)
	}
	fmt.Printf("Listening on port %d\n", s.Config.Port)
	err = http.Serve(listener, nil)
	if err != nil {
		s.logger.Error("Failed to start server", zap.Error(err))
		os.Exit(1)
	}
}
