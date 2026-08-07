//go:build !cgo

package main

import "testing"

func TestSocketPathFromArgs(t *testing.T) {
	tests := []struct {
		name    string
		args    []string
		want    string
		wantErr bool
	}{
		{
			name: "accepts the ipc socket path",
			args: []string{"FlClashCore", "/tmp/flclash.sock"},
			want: "/tmp/flclash.sock",
		},
		{
			name:    "rejects missing socket path",
			args:    []string{"FlClashCore"},
			wantErr: true,
		},
		{
			name:    "rejects version shorthand instead of dialing it",
			args:    []string{"FlClashCore", "-v"},
			wantErr: true,
		},
		{
			name:    "rejects version flag instead of dialing it",
			args:    []string{"FlClashCore", "--version"},
			wantErr: true,
		},
		{
			name:    "rejects extra arguments",
			args:    []string{"FlClashCore", "/tmp/flclash.sock", "unexpected"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := socketPathFromArgs(tt.args)
			if (err != nil) != tt.wantErr {
				t.Fatalf("socketPathFromArgs() error = %v, wantErr %v", err, tt.wantErr)
			}
			if err == nil && got != tt.want {
				t.Fatalf("socketPathFromArgs() = %q, want %q", got, tt.want)
			}
		})
	}
}
