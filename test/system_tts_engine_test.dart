import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/tts/system_tts_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'isLanguageAvailable') return true;
          return 1;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> event(String method, [dynamic args]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) {},
        );
  }

  test(
    'sets language before voice so Android does not reset the selection',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final engine = SystemTtsEngine();
      await engine.configure(voiceId: 'chosen::pt-BR', rate: 1.4, pitch: .8);
      final methods = calls.map((call) => call.method).toList();
      expect(
        methods.indexOf('setLanguage'),
        lessThan(methods.indexOf('setVoice')),
      );
      expect(
        calls.firstWhere((call) => call.method == 'setSpeechRate').arguments,
        .7,
      );
      expect(
        calls.firstWhere((call) => call.method == 'setPitch').arguments,
        .8,
      );
      await engine.release();
    },
  );

  test('Apple normal speed is normalized rather than maximum', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final engine = SystemTtsEngine(preferredLanguage: 'pt-BR');
    await engine.configure(rate: 1, pitch: 1);
    expect(
      calls.firstWhere((call) => call.method == 'setSpeechRate').arguments,
      .5,
    );
    await engine.release();
  });

  test(
    'cancel during the post-stop settle window cannot start late speech',
    () async {
      final engine = SystemTtsEngine();
      await engine.prepare();
      await engine.stop();
      final spoken = engine.speak('Não deve tocar.');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await engine.stop();
      await spoken;
      expect(calls.where((call) => call.method == 'speak'), isEmpty);
      await engine.release();
    },
  );

  test(
    'platform failures reach the controller instead of skipping silently',
    () async {
      final engine = SystemTtsEngine();
      final spoken = engine.speak('Teste de erro.');
      final assertion = expectLater(spoken, throwsStateError);
      while (!calls.any((call) => call.method == 'speak')) {
        await Future<void>.delayed(Duration.zero);
      }
      await event('speak.onError', 'audio route lost');
      await assertion;
      await engine.release();
    },
  );
}
