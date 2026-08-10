# TUN IPv6 Config Round-Trip Design

## Goal

Avoid returning a contradictory generated configuration that declares `ipv6: false` while retaining `tun.inet6-address`.

## Root Cause

`handleGetConfig` parses a raw Mihomo configuration and returns it unchanged.  The Flutter client round-trips that raw configuration to YAML before Mihomo's later runtime normalization removes inactive TUN IPv6 addresses.

## Design

After parsing, `handleGetConfig` clears `prof.Tun.Inet6Address` only when top-level `prof.IPv6` is false.  The change remains at the raw-config boundary; it does not alter TUN runtime creation or any configuration with IPv6 enabled.

## Verification

Go tests use real temporary YAML files.  One asserts disabled IPv6 returns no TUN IPv6 address, even when input provides one.  A second asserts enabled IPv6 retains the user-provided address.  The full cross-platform CI must pass before merging.
