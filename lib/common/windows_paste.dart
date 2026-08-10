import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';

/// Normalizes the malformed key sequence emitted by Windows clipboard history.
///
/// Windows 11 can synthesize a Ctrl+V sequence for Win+V that Flutter receives
/// as Ctrl down, Ctrl up, V down, V up, Ctrl down, Ctrl up. The first Ctrl up
/// happens too early, so Flutter never sees a paste shortcut. The normalizer
/// recognizes only that exact sequence and forwards a standard Ctrl+V sequence
/// while preserving the native key-data/raw-event pairing.
class WindowsPasteKeyNormalizer {
  /// The invalid physical key value observed in the Windows/Flutter sequence.
  static const int malformedPhysicalKey = 0x1600000000;

  /// Maximum time to wait for the remaining synthetic events.
  static const sequenceTimeout = Duration(milliseconds: 250);

  var _step = 0;
  KeyData? _lastData;

  /// Whether a malformed sequence is currently being recognized.
  bool get hasPendingSequence => _step != 0;

  /// Processes one raw key event.
  WindowsPasteKeyResult process(KeyData data) {
    if (_step == 0) {
      if (!_matches(0, data)) {
        return WindowsPasteKeyResult.forward([data]);
      }

      _step = 1;
      _lastData = data;
      return WindowsPasteKeyResult.forward([
        _copy(
          data,
          type: KeyEventType.down,
          physical: PhysicalKeyboardKey.controlLeft.usbHidUsage,
          logical: LogicalKeyboardKey.controlLeft.keyId,
          synthesized: false,
        ),
      ]);
    }

    if (!_matches(_step, data)) {
      final forwardCurrentBeforeRecovery =
          _step == 3 && _isKeyUp(data, PhysicalKeyboardKey.keyV.usbHidUsage);
      final recovery = _recoveryEvents(data);
      _reset();
      if (forwardCurrentBeforeRecovery) {
        return WindowsPasteKeyResult.forward([data, ...recovery]);
      }
      return WindowsPasteKeyResult.forward([...recovery, data]);
    }

    switch (_step) {
      case 1:
        _step = 2;
        _lastData = data;
        return const WindowsPasteKeyResult.consumed();
      case 2:
        _step = 3;
        _lastData = data;
        return WindowsPasteKeyResult.forward([
          _copy(
            data,
            type: KeyEventType.down,
            physical: PhysicalKeyboardKey.keyV.usbHidUsage,
            logical: LogicalKeyboardKey.keyV.keyId,
            synthesized: false,
          ),
        ]);
      case 3:
        _step = 4;
        _lastData = data;
        return WindowsPasteKeyResult.forward([
          _copy(
            data,
            type: KeyEventType.up,
            physical: PhysicalKeyboardKey.keyV.usbHidUsage,
            logical: LogicalKeyboardKey.keyV.keyId,
            synthesized: false,
          ),
        ]);
      case 4:
        _step = 5;
        _lastData = data;
        return const WindowsPasteKeyResult.consumed();
      case 5:
        _reset();
        return WindowsPasteKeyResult.forward([
          _copy(
            data,
            type: KeyEventType.up,
            physical: PhysicalKeyboardKey.controlLeft.usbHidUsage,
            logical: LogicalKeyboardKey.controlLeft.keyId,
            synthesized: false,
          ),
        ]);
      default:
        _reset();
        return WindowsPasteKeyResult.forward([data]);
    }
  }

  /// Releases any normalized keys if the malformed sequence stops midway.
  WindowsPasteKeyResult flush() {
    if (!hasPendingSequence) {
      return WindowsPasteKeyResult.forward(const <KeyData>[]);
    }

    final recovery = _recoveryEvents(_lastData!);
    _reset();
    return WindowsPasteKeyResult.forward(recovery);
  }

  void _reset() {
    _step = 0;
    _lastData = null;
  }

  bool _matches(int index, KeyData data) {
    if (data.physical != malformedPhysicalKey) {
      return false;
    }

    return switch (index) {
      0 =>
        data.logical == LogicalKeyboardKey.controlLeft.keyId &&
            data.type == KeyEventType.down &&
            !data.synthesized,
      1 =>
        data.logical == LogicalKeyboardKey.controlLeft.keyId &&
            data.type == KeyEventType.up &&
            data.synthesized,
      2 =>
        data.logical == LogicalKeyboardKey.keyV.keyId &&
            data.type == KeyEventType.down &&
            !data.synthesized,
      3 =>
        data.logical == LogicalKeyboardKey.keyV.keyId &&
            data.type == KeyEventType.up &&
            !data.synthesized,
      4 =>
        data.logical == LogicalKeyboardKey.controlLeft.keyId &&
            data.type == KeyEventType.down &&
            data.synthesized,
      5 =>
        data.logical == LogicalKeyboardKey.controlLeft.keyId &&
            data.type == KeyEventType.up &&
            data.synthesized,
      _ => false,
    };
  }

  List<KeyData> _recoveryEvents(KeyData current) {
    final events = <KeyData>[];
    if (_step == 3 &&
        !_isKeyUp(current, PhysicalKeyboardKey.keyV.usbHidUsage)) {
      events.add(
        _copy(
          current,
          type: KeyEventType.up,
          physical: PhysicalKeyboardKey.keyV.usbHidUsage,
          logical: LogicalKeyboardKey.keyV.keyId,
          synthesized: true,
        ),
      );
    }
    if (!_isKeyUp(current, PhysicalKeyboardKey.controlLeft.usbHidUsage)) {
      events.add(
        _copy(
          current,
          type: KeyEventType.up,
          physical: PhysicalKeyboardKey.controlLeft.usbHidUsage,
          logical: LogicalKeyboardKey.controlLeft.keyId,
          synthesized: true,
        ),
      );
    }
    return events;
  }

  bool _isKeyUp(KeyData data, int physical) {
    return data.type == KeyEventType.up && data.physical == physical;
  }

  KeyData _copy(
    KeyData data, {
    required KeyEventType type,
    required int physical,
    required int logical,
    required bool synthesized,
  }) {
    return KeyData(
      timeStamp: data.timeStamp,
      type: type,
      physical: physical,
      logical: logical,
      character: type == KeyEventType.down ? data.character : null,
      synthesized: synthesized,
      deviceType: data.deviceType,
    );
  }
}

/// The events that should be delivered for one input event.
class WindowsPasteKeyResult {
  const WindowsPasteKeyResult._(this.events, this.consumed);

  const WindowsPasteKeyResult.consumed() : this._(const <KeyData>[], true);

  WindowsPasteKeyResult.forward(Iterable<KeyData> events)
    : this._(List.unmodifiable(events), false);

  final List<KeyData> events;
  final bool consumed;
}

/// Installs the Windows-only key data adapter after Flutter initializes it.
class WindowsPasteFix {
  WindowsPasteFix._();

  static final WindowsPasteFix instance = WindowsPasteFix._();

  static const _retryInterval = Duration(milliseconds: 100);

  Timer? _retryTimer;
  Timer? _sequenceTimer;
  var _installed = false;

  /// Installs the adapter on Windows. Other platforms are left untouched.
  void install() {
    if (!Platform.isWindows || _installed || _retryTimer != null) {
      return;
    }
    _tryInstall();
  }

  void _tryInstall() {
    if (_installed) {
      return;
    }

    final dispatcher = PlatformDispatcher.instance;
    final callback = dispatcher.onKeyData;
    if (callback != null) {
      _installed = true;
      final normalizer = WindowsPasteKeyNormalizer();
      dispatcher.onKeyData = (data) {
        final result = normalizer.process(data);
        _sequenceTimer?.cancel();
        _sequenceTimer = null;
        if (normalizer.hasPendingSequence) {
          _sequenceTimer = Timer(WindowsPasteKeyNormalizer.sequenceTimeout, () {
            _sequenceTimer = null;
            _dispatch(normalizer.flush(), callback);
          });
        }
        return _dispatch(result, callback);
      };
      return;
    }

    _retryTimer = Timer(_retryInterval, () {
      _retryTimer = null;
      _tryInstall();
    });
  }

  bool _dispatch(WindowsPasteKeyResult result, KeyDataCallback callback) {
    var handled = result.consumed;
    for (final event in result.events) {
      handled = callback(event) || handled;
    }
    return handled;
  }
}
