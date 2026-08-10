import 'dart:async';

import 'package:fl_clash/common/exit_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runExitCleanupWithWatchdog', () {
    test('cancels the fallback after cleanup succeeds', () async {
      var timeoutCalls = 0;

      await runExitCleanupWithWatchdog(
        cleanup: () async {},
        timeout: const Duration(milliseconds: 20),
        onTimeout: () => timeoutCalls++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(timeoutCalls, 0);
    });

    test('cancels the fallback after cleanup fails', () async {
      var timeoutCalls = 0;

      await expectLater(
        runExitCleanupWithWatchdog(
          cleanup: () async => throw StateError('cleanup failed'),
          timeout: const Duration(milliseconds: 20),
          onTimeout: () => timeoutCalls++,
        ),
        throwsStateError,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(timeoutCalls, 0);
    });

    test('runs the fallback once when cleanup does not finish', () async {
      var timeoutCalls = 0;
      final cleanupCompleter = Completer<void>();

      final cleanup = runExitCleanupWithWatchdog(
        cleanup: () => cleanupCompleter.future,
        timeout: const Duration(milliseconds: 20),
        onTimeout: () => timeoutCalls++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(timeoutCalls, 1);

      cleanupCompleter.complete();
      await cleanup;
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(timeoutCalls, 1);
    });
  });
}
