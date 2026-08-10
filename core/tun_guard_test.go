package main

import (
	"testing"
	"unsafe"
)

func TestTunCallbackAvailableRequiresListenerAndCallback(t *testing.T) {
	var callback unsafe.Pointer
	marker := new(byte)

	tests := []struct {
		name            string
		listenerPresent bool
		callback        unsafe.Pointer
		want            bool
	}{
		{
			name:            "missing listener",
			listenerPresent: false,
			callback:        unsafe.Pointer(marker),
			want:            false,
		},
		{
			name:            "missing callback",
			listenerPresent: true,
			callback:        callback,
			want:            false,
		},
		{
			name:            "listener and callback are ready",
			listenerPresent: true,
			callback:        unsafe.Pointer(marker),
			want:            true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tunCallbackAvailable(tt.listenerPresent, tt.callback); got != tt.want {
				t.Fatalf("tunCallbackAvailable() = %v, want %v", got, tt.want)
			}
		})
	}
}
