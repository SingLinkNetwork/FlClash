import 'dart:io';

import 'package:fl_clash/common/proxy_environment.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:test/test.dart';

void main() {
  group('Tray.shouldDestroyTrayOnExit', () {
    test('keeps the macOS status item alive during app exit', () {
      expect(shouldDestroyTrayOnExit(isMacOS: true), false);
    });

    test('destroys the status item on non-macOS desktop platforms', () {
      expect(shouldDestroyTrayOnExit(isMacOS: false), true);
    });
  });

  group('Tray.getTryIcon', () {
    final tray = Tray();
    final suffix = tray.trayIconSuffix;

    test('returns idle icon when core is not started', () {
      expect(
        tray.getTryIcon(isStart: false, tunEnable: false),
        'assets/images/icon/status_1.$suffix',
      );
    });

    test('returns normal mode icon when core is started without TUN', () {
      expect(
        tray.getTryIcon(isStart: true, tunEnable: false),
        Platform.isMacOS
            ? 'assets/images/icon/status_1.$suffix'
            : 'assets/images/icon/status_2.$suffix',
      );
    });

    test('returns enhanced mode icon when core is started with TUN', () {
      expect(
        tray.getTryIcon(isStart: true, tunEnable: true),
        Platform.isMacOS
            ? 'assets/images/icon/status_1.$suffix'
            : 'assets/images/icon/status_3.$suffix',
      );
    });
  });

  test('tray start item is unchecked when the proxy is stopped', () {
    final item = buildTrayStartMenuItem(
      isStart: false,
      startLabel: 'Start',
      stopLabel: 'Stop',
      onClick: (_) {},
    );

    expect(item.label, 'Start');
    expect(item.checked, false);
  });

  test('tray start item is checked when the proxy is running', () {
    final item = buildTrayStartMenuItem(
      isStart: true,
      startLabel: 'Start',
      stopLabel: 'Stop',
      onClick: (_) {},
    );

    expect(item.label, 'Stop');
    expect(item.checked, true);
  });

  test('builds one copy item for each supported shell', () {
    final copied = <ProxyEnvironmentShell>[];
    final items = buildProxyEnvironmentMenuItems(onCopy: copied.add);

    expect(items, hasLength(4));
    expect(items.map((item) => item.label).toList(), [
      'Bash',
      'Fish',
      'Zsh',
      'PowerShell',
    ]);
    expect(items.every((item) => item.type == 'normal'), isTrue);

    items[2].onClick!(items[2]);
    expect(copied, [ProxyEnvironmentShell.zsh]);
  });

  group('handleTrayIconMouseDown', () {
    test('shows the main window by default on macOS', () async {
      var showWindowCalls = 0;
      var showMenuCalls = 0;
      var toggleProxyCalls = 0;

      await handleTrayIconMouseDown(
        isMacOS: true,
        action: TrayClickAction.showMainWindow,
        showWindow: () async => showWindowCalls++,
        showMenu: () async => showMenuCalls++,
        toggleProxy: () => toggleProxyCalls++,
      );

      expect(showWindowCalls, 1);
      expect(showMenuCalls, 0);
      expect(toggleProxyCalls, 0);
    });

    test('shows the tray menu when configured on macOS', () async {
      var showWindowCalls = 0;
      var showMenuCalls = 0;
      var toggleProxyCalls = 0;

      await handleTrayIconMouseDown(
        isMacOS: true,
        action: TrayClickAction.showTrayMenu,
        showWindow: () async => showWindowCalls++,
        showMenu: () async => showMenuCalls++,
        toggleProxy: () => toggleProxyCalls++,
      );

      expect(showWindowCalls, 0);
      expect(showMenuCalls, 1);
      expect(toggleProxyCalls, 0);
    });

    test('keeps showing the main window on non-macOS platforms', () async {
      var showWindowCalls = 0;
      var showMenuCalls = 0;
      var toggleProxyCalls = 0;

      await handleTrayIconMouseDown(
        isMacOS: false,
        action: TrayClickAction.showTrayMenu,
        showWindow: () async => showWindowCalls++,
        showMenu: () async => showMenuCalls++,
        toggleProxy: () => toggleProxyCalls++,
      );

      expect(showWindowCalls, 1);
      expect(showMenuCalls, 0);
      expect(toggleProxyCalls, 0);
    });

    test('toggles the proxy when configured on a desktop platform', () async {
      var showWindowCalls = 0;
      var showMenuCalls = 0;
      var toggleProxyCalls = 0;

      await handleTrayIconMouseDown(
        isMacOS: false,
        action: TrayClickAction.toggleProxy,
        showWindow: () async => showWindowCalls++,
        showMenu: () async => showMenuCalls++,
        toggleProxy: () => toggleProxyCalls++,
      );

      expect(showWindowCalls, 0);
      expect(showMenuCalls, 0);
      expect(toggleProxyCalls, 1);
    });
  });

  group('supportedTrayClickActions', () {
    test('includes the tray menu only on macOS', () {
      expect(supportedTrayClickActions(isMacOS: true), [
        TrayClickAction.showMainWindow,
        TrayClickAction.showTrayMenu,
        TrayClickAction.toggleProxy,
      ]);
      expect(supportedTrayClickActions(isMacOS: false), [
        TrayClickAction.showMainWindow,
        TrayClickAction.toggleProxy,
      ]);
    });
  });
}
