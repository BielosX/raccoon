package main

import (
	"context"
	"log/slog"
	"os"
	"raccoon/internal"

	"github.com/aws/aws-sdk-go-v2/config"
)

func main() {
	conf, err := internal.LoadConfig()
	if err != nil {
		slog.Error("Unable to load Config", "error", err.Error())
		os.Exit(1)
	}
	awsCfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(conf.Region))
	if err != nil {
		slog.Error("Unable to load AWS Config", "error", err.Error())
		os.Exit(1)
	}
	server, err := internal.NewServer(conf, &awsCfg)
	if err != nil {
		slog.Error("Unable to initialize server", "error", err.Error())
		os.Exit(1)
	}
	server.Serve()
}
