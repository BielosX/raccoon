package main

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/rs/cors"
)

func getEnv(key, fallback string) string {
	value, ok := os.LookupEnv(key)
	if !ok {
		return fallback
	}
	return value
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	IdToken      string `json:"id_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
}

type UserInfoResponse struct {
	Sub      string `json:"sub"`
	Name     string `json:"name"`
	Username string `json:"username"`
}

type MockServer struct {
	key    *rsa.PrivateKey
	server *http.Server
}

func (s *MockServer) handleLogin(w http.ResponseWriter, r *http.Request) {
	params := r.URL.Query()
	state := params.Get("state")
	redirect := params.Get("redirect_uri")
	http.Redirect(w, r, fmt.Sprintf("%s?state=%s&code=%d", redirect, state, 1234), http.StatusFound)
}

func (s *MockServer) handleToken(w http.ResponseWriter, _ *http.Request) {
	t := jwt.New(jwt.SigningMethodRS256)
	token, err := t.SignedString(s.key)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	response, err := json.Marshal(TokenResponse{
		AccessToken:  token,
		IdToken:      token,
		RefreshToken: token,
		TokenType:    "Bearer",
		ExpiresIn:    3600,
	})
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(response)
}

func (s *MockServer) handleUserInfo(w http.ResponseWriter, _ *http.Request) {
	response, err := json.Marshal(UserInfoResponse{
		Sub:      uuid.NewString(),
		Name:     "John Doe",
		Username: "JohnDoe",
	})
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(response)
}

func (s *MockServer) handleLogout(w http.ResponseWriter, r *http.Request) {
	params := r.URL.Query()
	state := params.Get("state")
	redirect := params.Get("logout_uri")
	http.Redirect(w, r, fmt.Sprintf("%s?state=%s", redirect, state), http.StatusFound)
}

func (s *MockServer) Serve() {
	mux := http.NewServeMux()
	frontendPort := getEnv("FRONTEND_PORT", "4173")
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{fmt.Sprintf("http://localhost:%s", frontendPort)},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization"},
		AllowCredentials: true,
	})
	mux.HandleFunc("/login", s.handleLogin)
	mux.HandleFunc("/logout", s.handleLogout)
	mux.HandleFunc("/oauth2/token", s.handleToken)
	mux.HandleFunc("/oauth2/userInfo", s.handleUserInfo)
	port := getEnv("PORT", "9090")
	s.server = &http.Server{Addr: fmt.Sprintf(":%s", port), Handler: c.Handler(mux)}
	err := s.server.ListenAndServe()
	if err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error(fmt.Sprintf("Unable to listen on port %s", port), "error", err.Error())
		os.Exit(1)
	}
}

func (s *MockServer) Shutdown() error {
	return s.server.Shutdown(context.Background())
}

func main() {
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, os.Kill)
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		slog.Error("Unable to generate key", "error", err.Error())
		os.Exit(1)
	}
	server := &MockServer{key: key}
	go server.Serve()
	<-quit
	slog.Info("Shutting down mock server")
	if err = server.Shutdown(); err != nil {
		slog.Error("Unable to shutdown mock server", "error", err.Error())
		os.Exit(1)
	}
}
