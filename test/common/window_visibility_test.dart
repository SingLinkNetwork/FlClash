import 'dart:async';

import 'package:fl_clash/common/window_visibility.dart';
import 'package:test/test.dart';

void main() {
  test('serializes startup hide and tray show operations', () async {
    final queue = WindowVisibilityQueue();
    final events = <String>[];
    final hideStarted = Completer<void>();
    final releaseHide = Completer<void>();

    final hide = queue.enqueue(() async {
      events.add('hide-start');
      hideStarted.complete();
      await releaseHide.future;
      events.add('hide-end');
    });
    await hideStarted.future;

    final show = queue.enqueue(() async {
      events.add('show');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['hide-start']);

    releaseHide.complete();
    await Future.wait<void>([hide, show]);

    expect(events, ['hide-start', 'hide-end', 'show']);
  });
}
