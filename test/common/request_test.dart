import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:test/test.dart';

void main() {
  late _RecordingAdapter proxiedAdapter;
  late _RecordingAdapter directAdapter;
  late Request requestUnderTest;

  setUp(() {
    proxiedAdapter = _RecordingAdapter();
    directAdapter = _RecordingAdapter();
    requestUnderTest = Request(
      proxiedDio: _dioWith(proxiedAdapter),
      directDio: _dioWith(directAdapter),
    );
  });

  test('uses the direct client when proxying is explicitly disabled', () async {
    final response = await requestUnderTest.getFileResponseForUrl(
      'https://subscription.example/profile.yaml',
      useProxy: false,
    );

    expect(response.data, [1, 2, 3]);
    expect(directAdapter.paths, ['https://subscription.example/profile.yaml']);
    expect(proxiedAdapter.paths, isEmpty);
  });

  test('uses the proxied client by default', () async {
    await requestUnderTest.getFileResponseForUrl(
      'https://subscription.example/profile.yaml',
    );

    expect(proxiedAdapter.paths, ['https://subscription.example/profile.yaml']);
    expect(directAdapter.paths, isEmpty);
  });
}

Dio _dioWith(_RecordingAdapter adapter) {
  return Dio()..httpClientAdapter = adapter;
}

class _RecordingAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.toString());
    return ResponseBody.fromBytes(Uint8List.fromList([1, 2, 3]), 200);
  }

  @override
  void close({bool force = false}) {}
}
