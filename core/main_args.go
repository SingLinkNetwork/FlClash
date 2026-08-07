//go:build !cgo

package main

import (
	"errors"
	"strings"
)

var errInvalidCoreArguments = errors.New(
	"usage: FlClashCore <ipc-socket-path>",
)

func socketPathFromArgs(args []string) (string, error) {
	if len(args) != 2 || args[1] == "" || strings.HasPrefix(args[1], "-") {
		return "", errInvalidCoreArguments
	}
	return args[1], nil
}
