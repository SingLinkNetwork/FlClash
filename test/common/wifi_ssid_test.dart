import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/wifi_ssid.dart';
import 'package:test/test.dart';

void main() {
  test('does not read the SSID without permission', () async {
    var readCount = 0;

    final ssid = await readWifiSsidIfAllowed(
      isAllowed: () async => false,
      read: () async {
        readCount++;
        return 'Should not be read';
      },
    );

    expect(ssid, isNull);
    expect(readCount, 0);
  });

  test('delivers an SSID when the reader completes', () async {
    final values = <String?>[];
    final coordinator = WifiSsidReadCoordinator(
      read: () async => 'Home Wi-Fi',
      onRead: values.add,
    );

    await coordinator.refresh();

    expect(values, ['Home Wi-Fi']);
  });

  test('falls back to null when the reader times out', () async {
    final values = <String?>[];
    final coordinator = WifiSsidReadCoordinator(
      read: () => Completer<String?>().future,
      onRead: values.add,
      timeout: const Duration(milliseconds: 10),
    );

    await coordinator.refresh();

    expect(values, [null]);
  });

  test('ignores an older read that completes after a newer read', () async {
    final values = <String?>[];
    final firstReader = Completer<String?>();
    final secondReader = Completer<String?>();
    final readers = <Future<String?>>[firstReader.future, secondReader.future];
    final coordinator = WifiSsidReadCoordinator(
      read: () => readers.removeAt(0),
      onRead: values.add,
    );

    final first = coordinator.refresh();
    final second = coordinator.refresh();
    secondReader.complete('new');
    await second;
    firstReader.complete('old');
    await first;

    expect(values, ['new']);
  });

  test('does not publish after disposal', () async {
    final values = <String?>[];
    final reader = Completer<String?>();
    final coordinator = WifiSsidReadCoordinator(
      read: () => reader.future,
      onRead: values.add,
    );

    final refresh = coordinator.refresh();
    coordinator.dispose();
    reader.complete('stale');
    await refresh;

    expect(values, isEmpty);
  });

  test(
    'reads the SSID for the connectivity already active at startup',
    () async {
      final values = <String?>[];
      final coordinator = WifiSsidConnectivityCoordinator(
        checkConnectivity: () async => [ConnectivityResult.wifi],
        read: () async => 'Office Wi-Fi',
        onRead: values.add,
      );

      await coordinator.refreshCurrentConnectivity();

      expect(values, ['Office Wi-Fi']);
    },
  );

  test('rechecks the current SSID when an excluded list changes', () async {
    var readCount = 0;
    final values = <String?>[];
    final coordinator = WifiSsidConnectivityCoordinator(
      checkConnectivity: () async => [ConnectivityResult.wifi],
      read: () async {
        readCount++;
        return 'Office Wi-Fi';
      },
      onRead: values.add,
    );

    coordinator.updateExcludedSsids(['Office Wi-Fi']);
    await Future<void>.delayed(Duration.zero);

    expect(readCount, 1);
    expect(values, ['Office Wi-Fi']);
  });

  test('does not let an old connectivity check restore a stale SSID', () async {
    final values = <String?>[];
    final check = Completer<List<ConnectivityResult>>();
    final coordinator = WifiSsidConnectivityCoordinator(
      checkConnectivity: () => check.future,
      read: () async => 'Stale Wi-Fi',
      onRead: values.add,
    );

    final refresh = coordinator.refreshCurrentConnectivity();
    coordinator.handleConnectivityChanged(const [ConnectivityResult.none]);
    check.complete(const [ConnectivityResult.wifi]);
    await refresh;

    expect(values, [null]);
  });
}
