package internal

import (
	"context"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"
	"golang.org/x/sync/singleflight"
)

type OpenIdConfig struct {
	Issuer string `json:"issuer"`
}

type TokenValidator struct {
	Config          *Config
	client          *http.Client
	openIdConfig    *OpenIdConfig
	jwksHash        string
	jwks            map[string]*rsa.PublicKey
	group           singleflight.Group
	logger          *zap.Logger
	lastJwksRefresh time.Time
	parser          *jwt.Parser
}

func NewTokenValidator(config *Config, logger *zap.Logger) *TokenValidator {
	return &TokenValidator{
		Config: config,
		client: &http.Client{},
		logger: logger,
		parser: jwt.NewParser(),
	}
}

func (t *TokenValidator) LoadOpenIdConfig(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, "GET", t.Config.OpenIdConfigurationUrl, nil)
	if err != nil {
		return err
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return err
	}
	defer ignore(resp.Body.Close)
	var config OpenIdConfig
	if err = json.NewDecoder(resp.Body).Decode(&config); err != nil {
		return err
	}
	t.openIdConfig = &config
	issuerOpt := jwt.WithIssuer(t.openIdConfig.Issuer)
	issuerOpt(t.parser)
	t.logger.Info("OpenId configuration loaded")
	return nil
}

func (t *TokenValidator) LoadJwks(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, "GET", t.Config.JwksUrl, nil)
	if err != nil {
		return err
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return err
	}
	defer ignore(resp.Body.Close)
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	hash := sha256.Sum256(data)
	t.jwksHash = hex.EncodeToString(hash[:])
	var jwks JWKS
	if err = json.Unmarshal(data, &jwks); err != nil {
		return err
	}
	rsaMap, err := jwks.ToRSAMap()
	if err != nil {
		return err
	}
	t.jwks = rsaMap
	t.lastJwksRefresh = time.Now()
	t.logger.Info("JWKS refreshed")
	return nil
}

type parsedTokenKey struct{}

var ParsedContextTokenKey = parsedTokenKey{}

const (
	JwtKid = "kid"
	Bearer = "Bearer"
)

func (t *TokenValidator) ValidateToken(
	c context.Context,
	tokenStr string,
) (bool, *jwt.Token, error) {
	token, err := t.parser.Parse(tokenStr, func(tkn *jwt.Token) (any, error) {
		kid, ok := tkn.Header[JwtKid]
		if !ok {
			return false, nil
		}
		keyId := kid.(string)
		key, ok := t.jwks[keyId]
		if !ok {
			// Last JWKS refresh was more than 1 hour ago
			if time.Now().After(t.lastJwksRefresh.Add(time.Hour)) {
				t.logger.Info("jwk not found for token, refreshing", zap.String(JwtKid, keyId))
				_, err, _ := t.group.Do(t.jwksHash, func() (any, error) {
					ctx, cancel := context.WithTimeout(c, time.Second*10)
					defer cancel()
					return nil, t.LoadJwks(ctx)
				})
				if err != nil {
					return nil, err
				}
			} else {
				t.logger.Info("JWKS refreshed recently. No need to do it")
			}
		} else {
			return key, nil
		}
		key, ok = t.jwks[keyId]
		if !ok {
			return false, nil
		}
		return key, nil
	})
	if err != nil {
		return false, nil, err
	}
	return token.Valid, token, nil
}

func (t *TokenValidator) ValidatingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get(HeaderAuthorization)
		if auth == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		fields := strings.Fields(auth)
		if len(fields) != 2 || fields[0] != Bearer {
			w.WriteHeader(http.StatusUnauthorized)
		}
		tokenStr := fields[1]
		valid, token, err := t.ValidateToken(r.Context(), tokenStr)
		if err != nil {
			t.logger.Error("Error validating token", zap.Error(err))
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		if !valid {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		newRequest := r.WithContext(context.WithValue(r.Context(), ParsedContextTokenKey, token))
		next.ServeHTTP(w, newRequest)
	})
}

func GetParsedToken(r *http.Request) *jwt.Token {
	val := r.Context().Value(ParsedContextTokenKey)
	if token, ok := val.(*jwt.Token); ok {
		return token
	}
	return nil
}
