# Subscription direct/proxy sync design

## Context

Upstream issue #2225 reports that a subscription cannot be refreshed when the
currently selected proxy node is unavailable. The app currently routes profile
downloads through the FlClash proxy whenever the core is running, so a broken
node also blocks the action that could recover the subscription.

## Goal

Allow a user to choose either of these routes for a manual URL-profile sync:

- Sync via proxy: preserve the current behavior and default.
- Sync directly: bypass FlClash's in-app proxy for this HTTP request.

The existing default must remain unchanged, and the direct route must be an
explicit `DIRECT` HTTP client rather than relying on global `HttpOverrides`.

## Scope

- Add a transport choice to `Request.getFileResponseForUrl`.
- Thread that choice through `Profile.update` and the profile action.
- Expose the two choices in the URL profile's sync submenu.
- Keep bulk sync and automatic sync on the current proxy route.
- Add localized labels for both choices.

## Non-goals

- Do not change the system proxy, VPN, or core configuration.
- Do not silently retry through a second route; the selected route must be
  observable and deterministic.
- Do not change how imported files are validated or saved.

## Verification

- Unit-test that the explicit direct route selects the direct HTTP client and
  the default route selects the proxied client.
- Unit-test the profile action's route forwarding.
- Static-check the UI and CI wiring.
- Run the full local Flutter/Go checks and the complete cross-platform CI; the
  issue is not complete until `CI complete` is successful.
