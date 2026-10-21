import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-only configuration. Never included in AppSettings, exports or sync.
class RemoteSpeechConfig {
  const RemoteSpeechConfig({
    this.provider = 'azure',
    this.apiKey = '',
    this.region = 'brazilsouth',
    this.voice = 'pt-BR-AntonioNeural',
    this.model = 'eleven_multilingual_v2',
    this.language = 'pt-BR',
    this.serverUrl = '',
    this.prefetch = false,
    this.consent = false,
  });
  final String provider, apiKey, region, voice, model, language, serverUrl;
  final bool prefetch, consent;

  Map<String, Object> toJson() => {
    'provider': provider,
    'apiKey': apiKey,
    'region': region,
    'voice': voice,
    'model': model,
    'language': language,
    'serverUrl': serverUrl,
    'prefetch': prefetch,
    'consent': consent,
  };
  factory RemoteSpeechConfig.fromJson(Map<String, dynamic> json) =>
      RemoteSpeechConfig(
        provider: json['provider'] as String? ?? 'azure',
        apiKey: json['apiKey'] as String? ?? '',
        region: json['region'] as String? ?? 'brazilsouth',
        voice: json['voice'] as String? ?? '',
        model: json['model'] as String? ?? 'eleven_multilingual_v2',
        language: json['language'] as String? ?? 'pt-BR',
        serverUrl: json['serverUrl'] as String? ?? '',
        prefetch: json['prefetch'] == true,
        consent: json['consent'] == true,
      );
}

class RemoteSpeechStore {
  RemoteSpeechStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'sepia_remote_speech'),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'sepia.remote-speech.v1';
  RemoteSpeechConfig? _cached;
  int revision = 0;

  Future<RemoteSpeechConfig> load() async {
    if (_cached != null) return _cached!;
    // Browser credentials last only for this session; they never enter localStorage.
    if (kIsWeb) return _cached = const RemoteSpeechConfig();
    final raw = await _storage.read(key: _key);
    return _cached = raw == null
        ? const RemoteSpeechConfig()
        : RemoteSpeechConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(RemoteSpeechConfig config) async {
    if (!kIsWeb) {
      await _storage.write(key: _key, value: jsonEncode(config.toJson()));
    }
    _cached = config;
    revision++;
  }

  Future<void> clear() async {
    if (!kIsWeb) await _storage.delete(key: _key);
    _cached = const RemoteSpeechConfig();
    revision++;
  }
}
