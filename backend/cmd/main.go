package main

import (
	"os"
	"raccoon/internal"
	"strconv"
)

const maxPort = 65535

func main() {
	portStr := internal.GetEnvOrDefault("PORT", "8080")
	port, err := strconv.Atoi(portStr)
	internal.ExpectNil(err)
	if port > maxPort {
		internal.PrintfStderr("port must be less than %d\n", maxPort)
		os.Exit(1)
	}
	logLevel := internal.GetEnvOrDefault("LOG_LEVEL", "info")
	server := internal.Server{Port: port, LogLevel: logLevel}
	server.Serve()
}
