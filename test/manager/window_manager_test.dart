import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  const channel = MethodChannel('window_manager');
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getBounds') {
            return <String, Object>{
              'x': 80.0,
              'y': 120.0,
              'width': 1024.0,
              'height': 768.0,
            };
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    container.dispose();
  });

  testWidgets('persists window size from native resize events', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WindowManager(child: SizedBox.shrink()),
      ),
    );

    const codec = StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            const MethodCall('onEvent', {'eventName': 'resize'}),
          ),
          (_) {},
        );
    await tester.pump();

    expect(
      container.read(windowSettingProvider),
      const WindowProps(width: 1024, height: 768),
    );
  });
}
