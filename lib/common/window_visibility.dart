typedef WindowVisibilityOperation = Future<void> Function();

/// Serializes native window visibility operations.
///
/// Startup and tray callbacks can request opposite visibility changes at the
/// same time. Keeping the tail future successful lets a later user request
/// continue even if an earlier native operation fails.
class WindowVisibilityQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(WindowVisibilityOperation operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
