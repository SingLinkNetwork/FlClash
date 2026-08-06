import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:test/test.dart';

void main() {
  test('does not log high-frequency traffic calls', () {
    expect(shouldLogCoreCall(ActionMethod.getTraffic), isFalse);
    expect(shouldLogCoreCall(ActionMethod.getTotalTraffic), isFalse);
  });

  test('continues logging non-polling core calls', () {
    expect(shouldLogCoreCall(ActionMethod.getMemory), isTrue);
  });
}
