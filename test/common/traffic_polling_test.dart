import 'package:fl_clash/common/traffic_polling.dart';
import 'package:test/test.dart';

void main() {
  group('shouldPollTraffic', () {
    test('polls while the window is active', () {
      expect(
        shouldPollTraffic(renderPaused: false, showTrayTitle: false),
        isTrue,
      );
    });

    test('polls while the tray title is enabled', () {
      expect(
        shouldPollTraffic(renderPaused: true, showTrayTitle: true),
        isTrue,
      );
    });

    test('stops polling when hidden and the tray title is disabled', () {
      expect(
        shouldPollTraffic(renderPaused: true, showTrayTitle: false),
        isFalse,
      );
    });

    test('skips connection event parsing while the window is hidden', () {
      expect(shouldHandleCoreRequestEvent(renderPaused: true), isFalse);
      expect(shouldHandleCoreRequestEvent(renderPaused: false), isTrue);
    });
  });
}
