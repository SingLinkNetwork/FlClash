package main

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestHandleGetConfigOmitsTunIPv6WhenIPv6IsDisabled(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.yaml")
	contents := "ipv6: false\ntun:\n  inet6-address: [fdfe:dcba:9876::1/126]\n"
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}

	config, err := handleGetConfig(path)
	if err != nil {
		t.Fatalf("get config: %v", err)
	}
	if got := len(config.Tun.Inet6Address); got != 0 {
		t.Fatalf("tun inet6-address count = %d, want 0", got)
	}
}

func TestHandleGetConfigPreservesTunIPv6WhenIPv6IsEnabled(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.yaml")
	contents := "ipv6: true\ntun:\n  inet6-address: [fdfe:dcba:9876::1/126]\n"
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}

	config, err := handleGetConfig(path)
	if err != nil {
		t.Fatalf("get config: %v", err)
	}
	if got := fmt.Sprint(config.Tun.Inet6Address); got != "[fdfe:dcba:9876::1/126]" {
		t.Fatalf("tun inet6-address = %s, want supplied address", got)
	}
}
