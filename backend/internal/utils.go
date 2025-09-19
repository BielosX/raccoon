package internal

import (
	"fmt"
	"net/http"
	"os"
)

func ignore(f func() error) {
	_ = f()
}

func PrintfStderr(format string, a ...interface{}) {
	_, _ = fmt.Fprintf(os.Stderr, format, a...)
}

func ExpectNil(err error) {
	if err != nil {
		PrintfStderr("%s\n", err.Error())
		os.Exit(1)
	}
}

func GetEnvOrDefault(key, defaultValue string) string {
	value, set := os.LookupEnv(key)
	if !set {
		return defaultValue
	}
	return value
}

func WriteString(w http.ResponseWriter, s string, code int) {
	w.WriteHeader(code)
	_, _ = w.Write([]byte(s))
}
