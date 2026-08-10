import 'dart:ui';

import 'package:fl_clash/common/windows_paste.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';

void main() {
  test('passes ordinary keyboard events through immediately', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final event = _event(
      type: KeyEventType.down,
      physical: PhysicalKeyboardKey.keyV.usbHidUsage,
      logical: LogicalKeyboardKey.keyV.keyId,
      character: 'v',
    );

    final result = normalizer.process(event);

    expect(result.consumed, isFalse);
    expect(result.events, [same(event)]);
  });

  test('rewrites the malformed Windows clipboard history sequence', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final events = [
      _event(
        type: KeyEventType.down,
        logical: LogicalKeyboardKey.controlLeft.keyId,
      ),
      _event(
        type: KeyEventType.up,
        logical: LogicalKeyboardKey.controlLeft.keyId,
        synthesized: true,
      ),
      _event(
        type: KeyEventType.down,
        logical: LogicalKeyboardKey.keyV.keyId,
        character: 'v',
      ),
      _event(type: KeyEventType.up, logical: LogicalKeyboardKey.keyV.keyId),
      _event(
        type: KeyEventType.down,
        logical: LogicalKeyboardKey.controlLeft.keyId,
        synthesized: true,
      ),
      _event(
        type: KeyEventType.up,
        logical: LogicalKeyboardKey.controlLeft.keyId,
        synthesized: true,
      ),
    ];

    final results = events.map(normalizer.process).toList();

    expect(results.map((result) => result.consumed).toList(), [
      false,
      true,
      false,
      false,
      true,
      false,
    ]);
    final resultEvents = results.expand((result) => result.events).toList();
    expect(
      resultEvents
          .map(
            (event) =>
                (event.type, event.physical, event.logical, event.synthesized),
          )
          .toList(),
      [
        (
          KeyEventType.down,
          PhysicalKeyboardKey.controlLeft.usbHidUsage,
          LogicalKeyboardKey.controlLeft.keyId,
          false,
        ),
        (
          KeyEventType.down,
          PhysicalKeyboardKey.keyV.usbHidUsage,
          LogicalKeyboardKey.keyV.keyId,
          false,
        ),
        (
          KeyEventType.up,
          PhysicalKeyboardKey.keyV.usbHidUsage,
          LogicalKeyboardKey.keyV.keyId,
          false,
        ),
        (
          KeyEventType.up,
          PhysicalKeyboardKey.controlLeft.usbHidUsage,
          LogicalKeyboardKey.controlLeft.keyId,
          false,
        ),
      ],
    );
    expect(resultEvents[1].character, 'v');
    expect(normalizer.hasPendingSequence, isFalse);
  });

  test('replays an incomplete sequence instead of swallowing input', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final first = _event(
      type: KeyEventType.down,
      logical: LogicalKeyboardKey.controlLeft.keyId,
    );
    final mismatch = _event(
      type: KeyEventType.up,
      logical: LogicalKeyboardKey.controlLeft.keyId,
    );

    final firstResult = normalizer.process(first);
    expect(firstResult.consumed, isFalse);
    expect(
      firstResult.events.single.physical,
      PhysicalKeyboardKey.controlLeft.usbHidUsage,
    );
    final result = normalizer.process(mismatch);

    expect(result.consumed, isFalse);
    expect(result.events, hasLength(2));
    expect(result.events.first.type, KeyEventType.up);
    expect(
      result.events.first.physical,
      PhysicalKeyboardKey.controlLeft.usbHidUsage,
    );
    expect(result.events.first.synthesized, isTrue);
    expect(result.events.last, same(mismatch));
    expect(normalizer.hasPendingSequence, isFalse);
  });

  test('flushes a stalled sequence and releases the normalized Ctrl key', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final first = _event(
      type: KeyEventType.down,
      logical: LogicalKeyboardKey.controlLeft.keyId,
    );

    normalizer.process(first);
    expect(normalizer.hasPendingSequence, isTrue);

    final result = normalizer.flush();

    expect(result.consumed, isFalse);
    expect(result.events, hasLength(1));
    expect(result.events.single.type, KeyEventType.up);
    expect(
      result.events.single.physical,
      PhysicalKeyboardKey.controlLeft.usbHidUsage,
    );
    expect(result.events.single.synthesized, isTrue);
    expect(normalizer.hasPendingSequence, isFalse);
  });

  test('releases V before Ctrl when recovery sees a real V-up', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final ctrlDown = _event(
      type: KeyEventType.down,
      logical: LogicalKeyboardKey.controlLeft.keyId,
    );
    final ctrlUp = _event(
      type: KeyEventType.up,
      logical: LogicalKeyboardKey.controlLeft.keyId,
      synthesized: true,
    );
    final vDown = _event(
      type: KeyEventType.down,
      logical: LogicalKeyboardKey.keyV.keyId,
      character: 'v',
    );
    final realVUp = _event(
      type: KeyEventType.up,
      physical: PhysicalKeyboardKey.keyV.usbHidUsage,
      logical: LogicalKeyboardKey.keyV.keyId,
    );

    normalizer.process(ctrlDown);
    normalizer.process(ctrlUp);
    normalizer.process(vDown);
    final result = normalizer.process(realVUp);

    expect(result.events, hasLength(2));
    expect(result.events.first, same(realVUp));
    expect(result.events.last.type, KeyEventType.up);
    expect(
      result.events.last.physical,
      PhysicalKeyboardKey.controlLeft.usbHidUsage,
    );
    expect(result.events.last.synthesized, isTrue);
  });

  test('requires real V events in the reported sequence', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final ctrlDown = _event(
      type: KeyEventType.down,
      logical: LogicalKeyboardKey.controlLeft.keyId,
    );
    final ctrlUp = _event(
      type: KeyEventType.up,
      logical: LogicalKeyboardKey.controlLeft.keyId,
      synthesized: true,
    );
    final synthesizedVDown = _event(
      type: KeyEventType.down,
      logical: LogicalKeyboardKey.keyV.keyId,
      synthesized: true,
    );

    normalizer.process(ctrlDown);
    normalizer.process(ctrlUp);
    final result = normalizer.process(synthesizedVDown);

    expect(result.consumed, isFalse);
    expect(result.events.last, same(synthesizedVDown));
    expect(result.events.first.type, KeyEventType.up);
    expect(result.events.first.synthesized, isTrue);
    expect(normalizer.hasPendingSequence, isFalse);
  });

  test('does not intercept a normal physical Ctrl+V sequence', () {
    final normalizer = WindowsPasteKeyNormalizer();
    final ctrlDown = _event(
      type: KeyEventType.down,
      physical: PhysicalKeyboardKey.controlLeft.usbHidUsage,
      logical: LogicalKeyboardKey.controlLeft.keyId,
    );
    final vDown = _event(
      type: KeyEventType.down,
      physical: PhysicalKeyboardKey.keyV.usbHidUsage,
      logical: LogicalKeyboardKey.keyV.keyId,
      character: 'v',
    );

    expect(normalizer.process(ctrlDown).events, [same(ctrlDown)]);
    expect(normalizer.process(vDown).events, [same(vDown)]);
  });
}

KeyData _event({
  required KeyEventType type,
  int? physical,
  required int logical,
  String? character,
  bool synthesized = false,
}) {
  return KeyData(
    timeStamp: Duration.zero,
    type: type,
    physical: physical ?? WindowsPasteKeyNormalizer.malformedPhysicalKey,
    logical: logical,
    character: character,
    synthesized: synthesized,
  );
}
