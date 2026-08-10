package main

import (
	"testing"

	"github.com/metacubex/mihomo/config"
)

func TestApplyAllowLanUpdate(t *testing.T) {
	tests := []struct {
		name        string
		initial     bool
		allowLan    *bool
		expectation bool
	}{
		{
			name:        "enables LAN proxy",
			initial:     false,
			allowLan:    boolPointer(true),
			expectation: true,
		},
		{
			name:        "disables LAN proxy",
			initial:     true,
			allowLan:    boolPointer(false),
			expectation: false,
		},
		{
			name:        "keeps current value when update is omitted",
			initial:     true,
			allowLan:    nil,
			expectation: true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			general := &config.General{Inbound: config.Inbound{AllowLan: test.initial}}
			applyAllowLanUpdate(general, test.allowLan)

			if general.AllowLan != test.expectation {
				t.Fatalf("AllowLan = %t, want %t", general.AllowLan, test.expectation)
			}
		})
	}
}

func boolPointer(value bool) *bool {
	return &value
}
