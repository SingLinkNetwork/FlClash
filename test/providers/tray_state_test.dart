import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  test('disabled tray title does not follow traffic updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: false));

    expect(
      container.read(trayTitleStateProvider),
      const TrayTitleState(showTrayTitle: false, traffic: Traffic()),
    );

    container
        .read(trafficsProvider.notifier)
        .addTraffic(const Traffic(up: 10, down: 20));

    expect(
      container.read(trayTitleStateProvider),
      const TrayTitleState(showTrayTitle: false, traffic: Traffic()),
    );
  });

  test('enabled tray title follows the latest traffic update', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(trafficsProvider.notifier)
        .addTraffic(const Traffic(up: 10, down: 20));

    expect(
      container.read(trayTitleStateProvider),
      const TrayTitleState(
        showTrayTitle: true,
        traffic: Traffic(up: 10, down: 20),
      ),
    );
  });
}
