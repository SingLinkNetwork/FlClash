//go:build !cgo

package main

import (
	"fmt"
	"os"
)

func main() {
	socketPath, err := socketPathFromArgs(os.Args)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	startServer(socketPath)
}
