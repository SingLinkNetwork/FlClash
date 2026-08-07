import 'package:fl_clash/views/proxies/test_url_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects a configured website for result viewing', (
    tester,
  ) async {
    String? selectedUrl = 'https://default.test/health';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestUrlSelector(
            urls: const ['https://default.test/health', 'https://github.com'],
            selectedUrl: selectedUrl,
            onChanged: (value) => selectedUrl = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('github.com'));
    expect(selectedUrl, 'https://github.com');
  });
}
