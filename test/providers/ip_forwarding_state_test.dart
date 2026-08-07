import 'package:fl_clash/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS IP forwarding requires every runtime condition', () {
    bool eligible({
      bool isMacOS = true,
      bool configured = true,
      bool tunEnabled = true,
      bool isStarted = true,
      bool coreConnected = true,
    }) {
      return isMacOSIpForwardingEligible(
        isMacOS: isMacOS,
        configured: configured,
        tunEnabled: tunEnabled,
        isStarted: isStarted,
        coreConnected: coreConnected,
      );
    }

    expect(eligible(), isTrue);
    expect(eligible(isMacOS: false), isFalse);
    expect(eligible(configured: false), isFalse);
    expect(eligible(tunEnabled: false), isFalse);
    expect(eligible(isStarted: false), isFalse);
    expect(eligible(coreConnected: false), isFalse);
  });
}
