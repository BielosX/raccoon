package main

import (
	"log/slog"
	"os"
	"raccoon/internal"
)

func main() {
	conf, err := internal.LoadConfig()
	if err != nil {
		slog.Error("Unable to load Config", "error", err.Error())
		os.Exit(1)
	}
	server, err := internal.NewServer(conf)
	if err != nil {
		slog.Error("Unable to initialize server", "error", err.Error())
		os.Exit(1)
	}
	server.Serve()
}
