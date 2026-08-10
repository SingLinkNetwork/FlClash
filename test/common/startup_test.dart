import 'package:fl_clash/common/startup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Linux command-line startup', () {
    test('recognizes the --start argument', () {
      expect(shouldStartProxyFromArguments(['--start']), isTrue);
      expect(
        shouldStartProxyFromArguments(['--start', '--some-other-option']),
        isTrue,
      );
    });

    test('ignores unrelated arguments', () {
      expect(shouldStartProxyFromArguments(const []), isFalse);
      expect(shouldStartProxyFromArguments(['--help']), isFalse);
      expect(shouldStartProxyFromArguments(['--start-proxy']), isFalse);
    });
  });
}
