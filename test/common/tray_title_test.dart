import 'package:fl_clash/common/tray_title.dart';
import 'package:test/test.dart';

void main() {
  group('TrayTitleCache', () {
    test('emits the first visible title and suppresses duplicates', () {
      final cache = TrayTitleCache();

      expect(
        cache.next(show: true, trafficTitle: '↓ 1 KB/s ↑ 2 KB/s'),
        '↓ 1 KB/s ↑ 2 KB/s',
      );
      expect(
        cache.next(show: true, trafficTitle: '↓ 1 KB/s ↑ 2 KB/s'),
        isNull,
      );
    });

    test('emits the hidden title once and suppresses hidden duplicates', () {
      final cache = TrayTitleCache();

      cache.next(show: true, trafficTitle: '↓ 1 KB/s ↑ 2 KB/s');

      expect(cache.next(show: false, trafficTitle: 'ignored'), '');
      expect(cache.next(show: false, trafficTitle: 'ignored'), isNull);
    });

    test('reset allows a title to be emitted again', () {
      final cache = TrayTitleCache();

      cache.next(show: true, trafficTitle: '↓ 1 KB/s ↑ 2 KB/s');
      cache.reset();

      expect(
        cache.next(show: true, trafficTitle: '↓ 1 KB/s ↑ 2 KB/s'),
        '↓ 1 KB/s ↑ 2 KB/s',
      );
    });
  });
}
