import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tray click action is visible and persists a new selection', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(1200, 1000)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: TrayClickActionItem()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menu bar icon click'), findsOneWidget);
    expect(find.text('Show main window'), findsOneWidget);

    await tester.tap(find.text('Menu bar icon click'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show tray menu'));
    await tester.pumpAndSettle();

    expect(
      container.read(appSettingProvider).trayClickAction.name,
      'showTrayMenu',
    );
    expect(find.text('Show tray menu'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: Material(child: child!),
        );
      },
      home: Scaffold(body: child),
    );
  }
}
