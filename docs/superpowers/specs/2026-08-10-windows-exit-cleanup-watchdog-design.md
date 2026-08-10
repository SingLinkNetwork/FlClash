# Windows Exit Cleanup Watchdog Design

## Goal

Prevent the application from terminating a normal desktop exit while its proxy, tray, window, core process, and macOS IP-forwarding cleanup is still running.

## Root Cause

`SystemAction.handleExit` starts an uncancellable three-second delayed call to `system.exit()` before asynchronous cleanup.  The core-helper shutdown alone may consume two seconds, so normal Windows cleanup can exceed the remaining budget and be cut off midway.

## Chosen Design

Add a small common helper, `runExitCleanupWithWatchdog`, that starts a cancellable `Timer`, runs a supplied cleanup operation, and always cancels that timer in `finally`.  `SystemAction.handleExit` will retain its existing cleanup order and its final `system.exit()` call, but run that cleanup through the helper with a ten-second watchdog.  If the watchdog expires, it logs a warning and performs the existing forced process exit.

## Alternatives Rejected

1. Only increase the old delay from three to ten seconds.  This leaves a redundant delayed forced-exit callback alive after successful cleanup.
2. Remove forced exit entirely.  This could leave the application stuck forever if a platform cleanup call hangs.

## Behaviour and Safety

- Successful cleanup: cancel the watchdog before the final normal exit.
- Cleanup failure: cancel the watchdog before propagating to the existing final normal exit.
- Cleanup never returns: force exit after ten seconds and emit a warning suitable for logs.
- macOS IP-forwarding restoration and every existing cleanup call retain their order and conditions.

## Verification

Unit tests cover successful cleanup, failed cleanup, and a genuinely delayed cleanup.  The full Flutter suite, static analysis, and all four platform CI builds must pass before the issue is closed.
