package main

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"os"
	"os/signal"
	"time"

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
	nonce  string
	port   string
}

func (s *MockServer) handleLogin(w http.ResponseWriter, r *http.Request) {
	params := r.URL.Query()
	state := params.Get("state")
	redirect := params.Get("redirect_uri")
	s.nonce = params.Get("nonce")
	time.Sleep(time.Second / 2)
	http.Redirect(w, r, fmt.Sprintf("%s?state=%s&code=%d", redirect, state, 1234), http.StatusFound)
}

func (s *MockServer) handleToken(w http.ResponseWriter, _ *http.Request) {
	mapClaims := jwt.MapClaims{
		"nonce": s.nonce,
		"iss":   fmt.Sprintf("http://localhost:%s", s.port),
	}
	t := jwt.NewWithClaims(jwt.SigningMethodRS256, mapClaims)
	t.Header["kid"] = "1234"
	token, err := t.SignedString(s.key)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	response, err := json.Marshal(TokenResponse{
		AccessToken:  uuid.New().String(),
		IdToken:      token,
		RefreshToken: uuid.New().String(),
		TokenType:    "Bearer",
		ExpiresIn:    3600,
	})
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
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
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(response)
}

func (s *MockServer) handleLogout(w http.ResponseWriter, r *http.Request) {
	params := r.URL.Query()
	state := params.Get("state")
	redirect := params.Get("logout_uri")
	time.Sleep(time.Second / 2)
	http.Redirect(w, r, fmt.Sprintf("%s?state=%s", redirect, state), http.StatusFound)
}

type KeyResponse struct {
	E   string `json:"e"`
	N   string `json:"n"`
	Use string `json:"use"`
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Alg string `json:"alg"`
}

type JwksResponse struct {
	Keys []KeyResponse `json:"keys"`
}

func (s *MockServer) handleJwks(w http.ResponseWriter, _ *http.Request) {
	publicKey := s.key.PublicKey
	exponent := big.NewInt(int64(publicKey.E))
	response := JwksResponse{
		Keys: []KeyResponse{{
			E:   base64.RawURLEncoding.EncodeToString(exponent.Bytes()),
			N:   base64.RawURLEncoding.EncodeToString(publicKey.N.Bytes()),
			Use: "sig",
			Kty: "RSA",
			Alg: "RS256",
			Kid: "1234",
		}},
	}
	convertedResponse, err := json.Marshal(response)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(convertedResponse)
}

type OpenIdConfigResponse struct {
	Issuer string `json:"issuer"`
}

func (s *MockServer) handleOpenIdConfig(w http.ResponseWriter, _ *http.Request) {
	response := OpenIdConfigResponse{
		Issuer: fmt.Sprintf("http://localhost:%s", s.port),
	}
	convertedResponse, err := json.Marshal(response)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(convertedResponse)
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
	mux.HandleFunc("GET /login", s.handleLogin)
	mux.HandleFunc("GET /logout", s.handleLogout)
	mux.HandleFunc("POST /oauth2/token", s.handleToken)
	mux.HandleFunc("GET /oauth2/userInfo", s.handleUserInfo)
	mux.HandleFunc("GET /api/users/me/avatar", http.NotFound)
	mux.HandleFunc("GET /.well-known/jwks.json", s.handleJwks)
	mux.HandleFunc("GET /.well-known/openid-configuration", s.handleOpenIdConfig)
	port := getEnv("PORT", "9090")
	s.port = port
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
