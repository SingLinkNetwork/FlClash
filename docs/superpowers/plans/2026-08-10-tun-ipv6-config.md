# TUN IPv6 Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent disabled IPv6 configurations from being returned with a TUN IPv6 address.

**Architecture:** Normalize only the raw configuration returned by `handleGetConfig`; preserve enabled IPv6 values and leave runtime TUN behavior untouched.

**Tech Stack:** Go, Mihomo raw configuration parser, Go testing.

## Global Constraints

- Modify only the raw-config return path and its focused Go regression tests.
- `ipv6: false` must produce no `tun.inet6-address`.
- `ipv6: true` must preserve a supplied TUN IPv6 address.
- Do not initialize or alter the user-owned core submodule in the original worktree.

---

### Task 1: Cover and normalize raw TUN IPv6 configuration

**Files:**
- Modify: `core/hub.go:461-470`
- Create: `core/hub_test.go`

**Interfaces:**
- Consumes: `handleGetConfig(path string) (*config.RawConfig, error)`.
- Produces: normalized `RawConfig.Tun.Inet6Address` for the Flutter config round-trip.

- [ ] **Step 1: Write failing Go tests**

```go
func TestHandleGetConfigOmitsTunIPv6WhenIPv6IsDisabled(t *testing.T) {
    config := loadTestConfig(t, "ipv6: false\\ntun:\\n  inet6-address: [fdfe:dcba:9876::1/126]\\n")
    if got := len(config.Tun.Inet6Address); got != 0 {
        t.Fatalf("tun inet6-address count = %d, want 0", got)
    }
}

func TestHandleGetConfigPreservesTunIPv6WhenIPv6IsEnabled(t *testing.T) {
    config := loadTestConfig(t, "ipv6: true\\ntun:\\n  inet6-address: [fdfe:dcba:9876::1/126]\\n")
    if got := fmt.Sprint(config.Tun.Inet6Address); got != "[fdfe:dcba:9876::1/126]" {
        t.Fatalf("tun inet6-address = %s, want supplied address", got)
    }
}
```

- [ ] **Step 2: Run test and confirm the disabled-IPv6 assertion fails on the old code**

Run: `go test . -run TestHandleGetConfig`
Expected: FAIL before the normalization because the disabled input still returns its TUN IPv6 address.

- [ ] **Step 3: Add minimal normalization**

```go
if !prof.IPv6 {
    prof.Tun.Inet6Address = nil
}
```

- [ ] **Step 4: Run focused and full core Go tests**

Run: `go test . -run TestHandleGetConfig && go test .`
Expected: PASS.

### Task 2: Cross-platform verification and review

**Files:**
- No additional source files.

- [ ] **Step 1: Run diff and source formatting checks**

Run: `gofmt -d core/hub.go core/hub_test.go && git diff --check origin/main...HEAD`
Expected: no output from `gofmt`, exit 0 from diff check.

- [ ] **Step 2: Create a draft PR and wait for complete CI**

Expected: all Android, Linux, macOS, and Windows checks pass before merge.
