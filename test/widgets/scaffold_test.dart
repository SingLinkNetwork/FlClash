import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer testContainer;

  setUp(() {
    testContainer = ProviderContainer();
    globalState.container = testContainer;
  });

  tearDown(() {
    testContainer.dispose();
  });

  testWidgets('search close button exits search mode after one tap', (
    tester,
  ) async {
    final searchState = AppBarSearchState(query: '', onSearch: (_) {});

    await tester.pumpWidget(
      ProviderScope(
        child: _TestApp(
          child: CommonScaffold(
            title: 'Connections',
            body: const SizedBox.shrink(),
            searchState: searchState,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Connections'), findsOneWidget);
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
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: child,
    );
  }
}
