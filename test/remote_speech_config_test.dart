import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/tts/remote_speech_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'remote secrets live only in secure device storage and can be forgotten',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = RemoteSpeechStore();
      await store.save(
        const RemoteSpeechConfig(apiKey: 'private-key', consent: true),
      );
      expect((await RemoteSpeechStore().load()).apiKey, 'private-key');
      final librarySettings = jsonEncode(
        const AppSettings(ttsEngine: 'remote').toJson(),
      );
      expect(librarySettings, isNot(contains('private-key')));
      expect(librarySettings, isNot(contains('apiKey')));
      await store.clear();
      expect((await RemoteSpeechStore().load()).apiKey, isEmpty);
      expect((await store.load()).consent, isFalse);
    },
  );
}
