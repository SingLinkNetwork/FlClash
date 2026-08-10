import 'dart:async';

typedef IpForwardingOperation = Future<bool> Function(bool enabled);

class IpForwardingRequestQueue {
  final IpForwardingOperation _operation;
  Future<void> _tail = Future<void>.value();

  IpForwardingRequestQueue(this._operation);

  Future<bool> set(bool enabled) {
    final result = Completer<bool>();
    _tail = _tail.then<void>((_) async {
      try {
        result.complete(await _operation(enabled));
      } catch (_) {
        result.complete(false);
      }
    });
    return result.future;
  }
}
