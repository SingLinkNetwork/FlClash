import 'dart:async';

import 'package:fl_clash/core/service.dart';
import 'package:test/test.dart';

void main() {
  test('removes completed core callbacks without waiting for timeout', () {
    final registry = CoreCallbackRegistry();
    final completer = Completer<String>();

    registry.add('request-1', completer);
    final completed = registry.take('request-1');

    expect(completed, same(completer));
    expect(registry.length, 0);
  });

  test('clears pending callbacks while completing them safely', () {
    final registry = CoreCallbackRegistry();
    final completer = Completer<String?>();
    registry.add('request-1', completer);

    registry.clear();

    expect(completer.isCompleted, isTrue);
    expect(registry.length, 0);
  });
}
