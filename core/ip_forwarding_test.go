package main

import (
	"errors"
	"reflect"
	"testing"
)

func TestSetIPForwardingRestoresOriginalValue(t *testing.T) {
	restoreIPForwardingTestState(t)
	ipForwardingPlatform = "darwin"

	var calls [][]string
	runSysctl = func(args ...string) (string, error) {
		calls = append(calls, append([]string(nil), args...))
		if len(args) == 2 && args[0] == "-n" {
			return "0\n", nil
		}
		return "", nil
	}

	if !setIPForwarding(true) {
		t.Fatal("setIPForwarding(true) returned false")
	}
	if !setIPForwarding(true) {
		t.Fatal("repeated setIPForwarding(true) returned false")
	}
	if !setIPForwarding(false) {
		t.Fatal("setIPForwarding(false) returned false")
	}

	want := [][]string{
		{"-n", "net.inet.ip.forwarding"},
		{"-w", "net.inet.ip.forwarding=1"},
		{"-w", "net.inet.ip.forwarding=0"},
	}
	if !reflect.DeepEqual(calls, want) {
		t.Fatalf("sysctl calls = %#v, want %#v", calls, want)
	}
}

func TestSetIPForwardingDoesNotRunOnNonDarwin(t *testing.T) {
	restoreIPForwardingTestState(t)
	ipForwardingPlatform = "linux"
	runSysctl = func(args ...string) (string, error) {
		t.Fatalf("sysctl should not run on non-Darwin: %#v", args)
		return "", nil
	}

	if !setIPForwarding(true) || !setIPForwarding(false) {
		t.Fatal("non-Darwin forwarding operation should be a successful no-op")
	}
}

func TestSetIPForwardingRejectsUnknownOriginalValue(t *testing.T) {
	restoreIPForwardingTestState(t)
	ipForwardingPlatform = "darwin"
	var writes int
	runSysctl = func(args ...string) (string, error) {
		if args[0] == "-w" {
			writes++
		}
		return "2\n", nil
	}

	if setIPForwarding(true) {
		t.Fatal("unknown forwarding value should be rejected")
	}
	if writes != 0 {
		t.Fatalf("writes = %d, want 0", writes)
	}
}

func TestSetIPForwardingKeepsOriginalValueWhenRestoreFails(t *testing.T) {
	restoreIPForwardingTestState(t)
	ipForwardingPlatform = "darwin"
	restoreFailed := true
	runSysctl = func(args ...string) (string, error) {
		if args[0] == "-n" {
			return "1", nil
		}
		if restoreFailed {
			return "", errors.New("restore failed")
		}
		return "", nil
	}

	if !setIPForwarding(true) {
		t.Fatal("setIPForwarding(true) returned false")
	}
	if setIPForwarding(false) {
		t.Fatal("failed restore should return false")
	}
	restoreFailed = false
	if !setIPForwarding(false) {
		t.Fatal("retrying restore should return true")
	}
}

func restoreIPForwardingTestState(t *testing.T) {
	t.Helper()
	resetIPForwardingState()
	oldPlatform := ipForwardingPlatform
	oldRunner := runSysctl
	t.Cleanup(func() {
		ipForwardingPlatform = oldPlatform
		runSysctl = oldRunner
		resetIPForwardingState()
	})
}
