import 'package:fl_clash/views/proxies/common.dart';
import 'package:test/test.dart';

void main() {
  test('keeps delay test batches within the core concurrency limit', () {
    final batches = splitDelayTestBatches(List<int>.generate(101, (i) => i));

    expect(batches.map((batch) => batch.length).toList(), [50, 50, 1]);
  });
}
