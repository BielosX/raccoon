package internal

import (
	"github.com/go-playground/validator/v10"
	"github.com/knadh/koanf/providers/env"
	"github.com/knadh/koanf/v2"
)

type Config struct {
	Port                   int    `koanf:"port"                     validate:"min=1,max=65535"`
	LogLevel               string `koanf:"log_level"                validate:"oneof=debug info warn error"`
	ApiPathPrefix          string `koanf:"api_path_prefix"          validate:"required"`
	WsPathPrefix           string `koanf:"ws_path_prefix"           validate:"required"`
	OpenIdConfigurationUrl string `koanf:"openid_configuration_url" validate:"required"`
	JwksUrl                string `koanf:"jwks_url"                 validate:"required"`
	Region                 string `koanf:"region"                   validate:"required"`
	UserPoolId             string `koanf:"user_pool_id"             validate:"required"`
	AvatarsBucketName      string `koanf:"avatars_bucket_name"      validate:"required"`
}

func (c *Config) SetDefaults() {
	c.Port = 8080
	c.LogLevel = "info"
	c.ApiPathPrefix = "/api"
	c.WsPathPrefix = "/ws"
}

func (c *Config) Validate() error {
	v := validator.New()
	return v.Struct(c)
}

func LoadConfig() (*Config, error) {
	cfg := &Config{}
	cfg.SetDefaults()
	k := koanf.New(".")
	if err := k.Load(env.Provider("", ".", nil), nil); err != nil {
		return nil, err
	}
	if err := k.Unmarshal("", &cfg); err != nil {
		return nil, err
	}
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}
