# Plan: subscription direct/proxy sync

1. Add failing request transport tests with injected HTTP clients.
2. Implement explicit direct transport and thread the route through profile
   update actions while preserving proxy as the default.
3. Add the sync submenu and localized labels.
4. Add static CI wiring verification and regression tests.
5. Run local verification, push, and wait for every platform plus `CI complete`.
6. Create and close the downstream record for upstream #2225 only after the
   full CI run is green.
