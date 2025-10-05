package main

import (
	"raccoon/internal"
)

func main() {
	conf, err := internal.LoadConfig()
	if err != nil {
		panic(err)
	}
	server := internal.Server{Config: conf}
	server.Serve()
}
