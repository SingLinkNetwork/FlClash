package main

import (
	"os/exec"
	"runtime"
	"strings"
)

const ipForwardingSysctlKey = "net.inet.ip.forwarding"

var (
	ipForwardingPlatform = runtime.GOOS
	ipForwardingOriginal *string
	ipForwardingActive   bool
	runSysctl            = defaultSysctlRunner
)

func defaultSysctlRunner(args ...string) (string, error) {
	output, err := exec.Command("/usr/sbin/sysctl", args...).CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

func setIPForwarding(enabled bool) bool {
	if ipForwardingPlatform != "darwin" {
		return true
	}

	if !enabled {
		if ipForwardingOriginal == nil {
			return true
		}
		if _, err := runSysctl(
			"-w",
			ipForwardingSysctlKey+"="+*ipForwardingOriginal,
		); err != nil {
			return false
		}
		resetIPForwardingState()
		return true
	}

	if ipForwardingOriginal == nil {
		value, err := runSysctl("-n", ipForwardingSysctlKey)
		if err != nil {
			return false
		}
		value = strings.TrimSpace(value)
		if value != "0" && value != "1" {
			return false
		}
		ipForwardingOriginal = &value
	}
	if ipForwardingActive {
		return true
	}
	if *ipForwardingOriginal == "0" {
		if _, err := runSysctl(
			"-w",
			ipForwardingSysctlKey+"=1",
		); err != nil {
			return false
		}
	}
	ipForwardingActive = true
	return true
}

func resetIPForwardingState() {
	ipForwardingOriginal = nil
	ipForwardingActive = false
}
