package main

import (
	"net"
	"strconv"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/listener"
)

func TestUpdateConfigRecreatesMixedListenerForAllowLan(t *testing.T) {
	port := reserveTCPPort(t)
	previousConfig := currentConfig
	previousRunning := isRunning
	previousAllowLan := listener.AllowLan()
	previousBindAddress := listener.BindAddress()
	listener.StopListener()
	geoUpdater.stop()
	t.Cleanup(func() {
		listener.StopListener()
		geoUpdater.stop()
		listener.SetAllowLan(previousAllowLan)
		listener.SetBindAddress(previousBindAddress)
		currentConfig = previousConfig
		isRunning = previousRunning
	})

	currentConfig = &config.Config{
		General: &config.General{
			Inbound: config.Inbound{
				AllowLan:    false,
				BindAddress: "*",
				MixedPort:   port,
			},
		},
	}
	isRunning = true
	updateListeners()

	if canConnectToAnyHost(port, "::1", "127.0.0.2") {
		t.Fatal("LAN address unexpectedly reached a listener while allow-lan was disabled")
	}

	allowLan := true
	updateConfig(&UpdateParams{AllowLan: &allowLan})

	if !canConnectToAnyHost(port, "::1", "127.0.0.2") {
		t.Fatal("LAN address could not reach the recreated mixed listener")
	}

	allowLan = false
	updateConfig(&UpdateParams{AllowLan: &allowLan})

	if canConnectToAnyHost(port, "::1", "127.0.0.2") {
		t.Fatal("LAN address remained reachable after allow-lan was disabled")
	}
}

func TestUpdateConfigRejectsMissingConfigWithoutPanicking(t *testing.T) {
	previousConfig := currentConfig
	previousRunning := isRunning
	currentConfig = nil
	isRunning = false
	t.Cleanup(func() {
		currentConfig = previousConfig
		isRunning = previousRunning
	})

	err := updateConfig(&UpdateParams{})
	if err == nil {
		t.Fatal("expected an error when the core config is not loaded")
	}
}

func TestHandleUpdateConfigReturnsMissingConfigError(t *testing.T) {
	previousConfig := currentConfig
	currentConfig = nil
	t.Cleanup(func() {
		currentConfig = previousConfig
	})

	if got := handleUpdateConfig([]byte(`{}`)); got != "core config is not loaded" {
		t.Fatalf("unexpected update config error: %q", got)
	}
}

func TestUpdateConfigAcceptsPartialTunParams(t *testing.T) {
	previousConfig := currentConfig
	previousRunning := isRunning
	currentConfig = &config.Config{
		General: &config.General{},
	}
	isRunning = false
	t.Cleanup(func() {
		currentConfig = previousConfig
		isRunning = previousRunning
	})

	err := updateConfig(&UpdateParams{
		Tun: &tunSchema{Enable: true},
	})
	if err != nil {
		t.Fatalf("partial TUN update returned an error: %v", err)
	}
	if !currentConfig.General.Tun.Enable {
		t.Fatal("partial TUN update did not apply the enable flag")
	}
}

func reserveTCPPort(t *testing.T) int {
	t.Helper()

	probe, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve TCP port: %v", err)
	}
	defer probe.Close()

	return probe.Addr().(*net.TCPAddr).Port
}

func canConnectToAnyHost(port int, hosts ...string) bool {
	for _, host := range hosts {
		conn, err := net.DialTimeout(
			"tcp",
			net.JoinHostPort(host, strconv.Itoa(port)),
			500*time.Millisecond,
		)
		if err == nil {
			_ = conn.Close()
			return true
		}
	}

	return false
}
