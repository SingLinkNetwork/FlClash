import 'dart:async';

import 'package:fl_clash/common/ip_forwarding.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:test/test.dart';

void main() {
  test('serializes forwarding transitions in request order', () async {
    final firstRequestStarted = Completer<void>();
    final releaseFirstRequest = Completer<void>();
    final calls = <bool>[];
    final queue = IpForwardingRequestQueue((enabled) async {
      calls.add(enabled);
      if (!firstRequestStarted.isCompleted) {
        firstRequestStarted.complete();
        await releaseFirstRequest.future;
      }
      return true;
    });

    final first = queue.set(true);
    await firstRequestStarted.future;
    final second = queue.set(false);
    expect(calls, [true]);

    releaseFirstRequest.complete();
    await Future.wait([first, second]);
    expect(calls, [true, false]);
  });

  test('continues processing after a failed forwarding request', () async {
    var attempts = 0;
    final queue = IpForwardingRequestQueue((_) async {
      attempts++;
      return attempts > 1;
    });

    expect(await queue.set(true), isFalse);
    expect(await queue.set(false), isTrue);
  });

  test('serializes the forwarding action with the desktop IPC name', () {
    const action = Action(
      method: ActionMethod.setIpForwarding,
      data: true,
      id: 'setIpForwarding#test',
    );

    final json = action.toJson();
    expect(json['method'], 'setIpForwarding');
    expect(Action.fromJson(json).method, ActionMethod.setIpForwarding);
  });
}
