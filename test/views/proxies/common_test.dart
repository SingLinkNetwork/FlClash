import 'package:fl_clash/views/proxies/common.dart';
import 'package:test/test.dart';

void main() {
  test('keeps delay test batches within the core concurrency limit', () {
    final batches = splitDelayTestBatches(List<int>.generate(101, (i) => i));

    expect(batches.map((batch) => batch.length).toList(), [50, 50, 1]);
  });

  test('runs website delay tests one URL at a time', () async {
    final events = <String>[];

    await runTestUrlsSequentially(['https://one.test', 'https://two.test'], (
      url,
    ) async {
      events.add('start:$url');
      await Future<void>.delayed(Duration.zero);
      events.add('end:$url');
    });

    expect(events, [
      'start:https://one.test',
      'end:https://one.test',
      'start:https://two.test',
      'end:https://two.test',
    ]);
  });
}
