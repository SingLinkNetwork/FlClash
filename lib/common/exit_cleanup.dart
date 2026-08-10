import 'dart:async';

Future<void> runExitCleanupWithWatchdog({
  required Future<void> Function() cleanup,
  required Duration timeout,
  required void Function() onTimeout,
}) async {
  final timer = Timer(timeout, onTimeout);
  try {
    await cleanup();
  } finally {
    timer.cancel();
  }
}
