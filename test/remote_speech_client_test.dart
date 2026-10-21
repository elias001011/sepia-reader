import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sepia_reader/services/tts/remote_speech_client.dart';
import 'package:sepia_reader/services/tts/remote_speech_config.dart';

Uint8List testWav([int mark = 0]) {
  final bytes = Uint8List(48);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.last = mark;
  return bytes;
}

void main() {
  test(
    'Azure sends escaped prose in SSML with fixed origin and speed',
    () async {
      final client = RemoteSpeechClient(
        const RemoteSpeechConfig(apiKey: 'private-key', consent: true),
        client: MockClient((request) async {
          expect(request.url.host, 'brazilsouth.tts.speech.microsoft.com');
          expect(request.followRedirects, isFalse);
          expect(request.headers['Ocp-Apim-Subscription-Key'], 'private-key');
          expect(request.body, contains('A &amp; B &lt;tag&gt;'));
          expect(request.body, contains('rate="25%"'));
          expect(request.headers['Content-Type'], 'application/ssml+xml');
          return http.Response.bytes(testWav(), 200);
        }),
      );
      expect(
        (await client.synthesize('A & B <tag>', 1.25)).mimeType,
        'audio/wav',
      );
    },
  );
  test('ElevenLabs uses header auth, explicit model and API speed', () async {
    final client = RemoteSpeechClient(
      const RemoteSpeechConfig(
        provider: 'elevenlabs',
        voice: 'voice-id',
        apiKey: 'eleven-secret',
        consent: true,
      ),
      client: MockClient((request) async {
        expect(request.url.host, 'api.elevenlabs.io');
        expect(request.url.path, '/v1/text-to-speech/voice-id');
        expect(request.headers['xi-api-key'], 'eleven-secret');
        expect(request.url.toString(), isNot(contains('secret')));
        expect(jsonDecode(request.body), {
          'text': 'Olá…',
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {'speed': 1.1},
        });
        return http.Response.bytes(testWav(), 200);
      }),
    );
    await client.synthesize('Olá…', 1.1);
  });
  test('ElevenLabs models without explicit language support omit it', () async {
    final client = RemoteSpeechClient(
      const RemoteSpeechConfig(
        provider: 'elevenlabs',
        voice: 'voice-id',
        model: 'eleven_flash_v2',
        apiKey: 'key',
        consent: true,
        language: 'pt-BR',
      ),
      client: MockClient((request) async {
        expect(jsonDecode(request.body), isNot(contains('language_code')));
        return http.Response.bytes(testWav(), 200);
      }),
    );
    await client.synthesize('Texto', 1);
  });
  test('ElevenLabs supported models receive language without inventing voice locales', () async {
    final client = RemoteSpeechClient(
      const RemoteSpeechConfig(
        provider: 'elevenlabs',
        voice: 'voice-id',
        model: 'eleven_flash_v2_5',
        apiKey: 'key',
        consent: true,
        language: 'pt-BR',
      ),
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'voices': [
                {'voice_id': 'voice-id', 'name': 'Voice', 'labels': {}},
              ],
            }),
            200,
          );
        }
        expect(jsonDecode(request.body)['language_code'], 'pt');
        return http.Response.bytes(testWav(), 200);
      }),
    );
    await client.synthesize('Texto', 1);
    expect((await client.voices()).single.locale, isEmpty);
  });
  test(
    'custom server never inherits credentials belonging to the sync origin',
    () async {
      final client = RemoteSpeechClient(
        const RemoteSpeechConfig(
          provider: 'sepia',
          serverUrl: 'https://tts.example.org',
          voice: 'M2',
          consent: true,
        ),
        syncUrl: 'https://library.example.org',
        syncToken: 'sync-secret',
        client: MockClient((request) async {
          expect(request.url.host, 'tts.example.org');
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response.bytes(testWav(), 200);
        }),
      );
      await client.synthesize('Texto', 1);
    },
  );
  test(
    'inherited server uses current sync token without enabling sync',
    () async {
      final client = RemoteSpeechClient(
        const RemoteSpeechConfig(provider: 'sepia', voice: 'M2', consent: true),
        syncUrl: 'https://library.example.org/base',
        syncToken: 'sync-secret',
        client: MockClient((request) async {
          expect(request.url.path, '/base/api/tts/speech');
          expect(request.headers['Authorization'], 'Bearer sync-secret');
          expect(jsonDecode(request.body)['voice'], 'M2');
          return http.Response.bytes(testWav(), 200);
        }),
      );
      await client.synthesize('Texto', 1);
    },
  );
  test('no consent means no network request', () async {
    var requests = 0;
    final client = RemoteSpeechClient(
      const RemoteSpeechConfig(apiKey: 'key'),
      client: MockClient((_) async {
        requests++;
        return http.Response('', 200);
      }),
    );
    await expectLater(
      client.synthesize('Texto', 1),
      throwsA(isA<RemoteSpeechException>()),
    );
    await expectLater(client.voices(), throwsA(isA<RemoteSpeechException>()));
    expect(requests, 0);
  });
  test('quota, redirects, unexpected formats and huge bodies fail without provider text', () async {
    for (final status in [401, 403, 429, 302, 503, 200]) {
      final client = RemoteSpeechClient(
        const RemoteSpeechConfig(apiKey: 'key', consent: true),
        client: MockClient(
          (_) async => http.Response(
            'private-key and private passage',
            status,
            headers: {'location': 'https://other.example/'},
          ),
        ),
      );
      await expectLater(
        client.synthesize('Private text', 1),
        throwsA(
          isA<RemoteSpeechException>().having(
            (e) => e.toString(),
            'redacted error',
            isNot(contains('private')),
          ),
        ),
      );
    }
    final huge = RemoteSpeechClient(
      const RemoteSpeechConfig(apiKey: 'key', consent: true),
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          const Stream.empty(),
          200,
          contentLength: RemoteSpeechClient.maxAudioBytes + 1,
        ),
      ),
    );
    await expectLater(
      huge.synthesize('Text', 1),
      throwsA(isA<RemoteSpeechException>()),
    );
  });
  test(
    'provider voice lists are fetched explicitly and retain stable ids',
    () async {
      final client = RemoteSpeechClient(
        const RemoteSpeechConfig(apiKey: 'key', consent: true),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/cognitiveservices/voices/list');
          return http.Response(
            jsonEncode([
              {
                'ShortName': 'pt-BR-AntonioNeural',
                'DisplayName': 'Antonio',
                'Locale': 'pt-BR',
              },
            ]),
            200,
          );
        }),
      );
      expect((await client.voices()).single.id, 'pt-BR-AntonioNeural');
    },
  );
}
