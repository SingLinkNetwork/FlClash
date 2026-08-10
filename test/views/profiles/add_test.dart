import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('URL import defaults to proxy routing', (tester) async {
    final result = await _openImportDialog(tester);

    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com/sub',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect((await result.future)?.url, 'https://example.com/sub');
    expect((await result.future)?.useProxy, true);
  });

  testWidgets('URL import returns direct routing only after selection', (
    tester,
  ) async {
    final result = await _openImportDialog(tester);

    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com/sub',
    );
    await tester.tap(find.text('Sync directly'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect((await result.future)?.useProxy, false);
  });
}

Future<Completer<URLImportResult?>> _openImportDialog(
  WidgetTester tester,
) async {
  final completer = Completer<URLImportResult?>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(1200, 1000)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await showDialog<URLImportResult>(
                  context: context,
                  builder: (_) => const URLFormDialog(),
                );
                completer.complete(result);
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return completer;
}
