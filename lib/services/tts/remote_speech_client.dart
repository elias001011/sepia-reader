import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../server_connection.dart';
import 'remote_speech_config.dart';
import 'tts_engine.dart';

class RemoteSpeechException implements Exception {
  const RemoteSpeechException(this.code, [this.status]);
  final String code;
  final int? status;
  @override
  String toString() => 'TTS: $code${status == null ? '' : ' (HTTP $status)'}';
}

class SpeechRecording {
  const SpeechRecording(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// Providers have fixed HTTPS origins; only the explicitly selected Sépia
/// server is user-addressable. Redirects never receive credentials.
class RemoteSpeechClient {
  RemoteSpeechClient(
    this.config, {
    http.Client? client,
    this.syncUrl = '',
    this.syncToken = '',
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;
  final RemoteSpeechConfig config;
  final String syncUrl, syncToken;
  final http.Client _client;
  final bool _ownsClient;
  static const maxAudioBytes = 12 * 1024 * 1024;

  Uri _azure(String path) {
    if (!RegExp(r'^[a-z0-9-]{2,40}$').hasMatch(config.region)) {
      throw const RemoteSpeechException('invalid-region');
    }
    return Uri.https('${config.region}.tts.speech.microsoft.com', path);
  }

  Uri _server(String path) {
    final uri = serverUri(
      config.serverUrl.isEmpty ? syncUrl : config.serverUrl,
      path,
    );
    if (uri == null || uri.hasQuery || uri.hasFragment) {
      throw const RemoteSpeechException('invalid-server');
    }
    return uri;
  }

  String get _serverToken => config.apiKey.isNotEmpty
      ? config.apiKey
      : config.serverUrl.isEmpty
      ? syncToken
      : '';
  Map<String, String> get _headers => switch (config.provider) {
    'azure' => {'Ocp-Apim-Subscription-Key': config.apiKey},
    'elevenlabs' => {'xi-api-key': config.apiKey},
    'sepia' => {
      if (_serverToken.isNotEmpty) 'Authorization': 'Bearer $_serverToken',
    },
    _ => throw const RemoteSpeechException('unknown-provider'),
  };

  void validate() {
    if (!config.consent) {
      throw const RemoteSpeechException('configure-remote-speech');
    }
    if (!{'azure', 'elevenlabs', 'sepia'}.contains(config.provider)) {
      throw const RemoteSpeechException('unknown-provider');
    }
    if (config.provider != 'sepia' && config.apiKey.trim().isEmpty) {
      throw const RemoteSpeechException('missing-api-key');
    }
    if (config.voice.isEmpty) {
      throw const RemoteSpeechException('missing-voice');
    }
    if (config.provider == 'azure') _azure('/');
    if (config.provider == 'sepia') _server('/api/tts/voices');
  }

  Future<Uint8List> _request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
    Future<void>? abort,
    int limit = maxAudioBytes,
  }) async {
    final cancel = Completer<void>();
    var timedOut = false;
    final timer = Timer(const Duration(seconds: 90), () {
      timedOut = true;
      if (!cancel.isCompleted) cancel.complete();
    });
    final trigger = Future.any<void>([cancel.future, ?abort]);
    final request = http.AbortableRequest(method, uri, abortTrigger: trigger)
      ..followRedirects = false
      ..headers.addAll({..._headers, ...headers});
    if (body != null) request.bodyBytes = utf8.encode(body);
    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        // Drain no provider error text: it may echo a private passage or key.
        await response.stream.listen((_) {}).cancel();
        throw RemoteSpeechException(switch (response.statusCode) {
          401 || 403 => 'authentication',
          429 => 'quota-or-busy',
          404 || 503 => 'unavailable',
          _ => 'request-failed',
        }, response.statusCode);
      }
      if ((response.contentLength ?? 0) > limit) {
        await response.stream.listen((_) {}).cancel();
        throw const RemoteSpeechException('response-too-large');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 90),
      )) {
        if (bytes.length + chunk.length > limit) {
          throw const RemoteSpeechException('response-too-large');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } on TimeoutException {
      throw const RemoteSpeechException('timeout');
    } on http.RequestAbortedException {
      if (timedOut) throw const RemoteSpeechException('timeout');
      rethrow;
    } on http.ClientException {
      throw const RemoteSpeechException('connection');
    } finally {
      timer.cancel();
      if (!cancel.isCompleted) cancel.complete();
    }
  }

  Future<List<TtsVoice>> voices({Future<void>? abort}) async {
    if (!config.consent) {
      throw const RemoteSpeechException('configure-remote-speech');
    }
    final uri = switch (config.provider) {
      'azure' => _azure('/cognitiveservices/voices/list'),
      'elevenlabs' => Uri.https('api.elevenlabs.io', '/v2/voices', {
        'page_size': '100',
      }),
      'sepia' => _server('/api/tts/voices'),
      _ => throw const RemoteSpeechException('unknown-provider'),
    };
    try {
      final decoded = jsonDecode(
        utf8.decode(
          await _request('GET', uri, abort: abort, limit: 2 * 1024 * 1024),
        ),
      );
      if (config.provider == 'azure') {
        return [
          for (final voice in decoded as List)
            TtsVoice(
              id: voice['ShortName'] as String,
              name:
                  voice['DisplayName'] as String? ??
                  voice['ShortName'] as String,
              locale: voice['Locale'] as String,
            ),
        ];
      }
      if (config.provider == 'sepia' && (decoded as Map)['enabled'] != true) {
        throw const RemoteSpeechException('server-tts-disabled');
      }
      return [
        for (final voice in (decoded as Map)['voices'] as List)
          TtsVoice(
            id: (voice['voice_id'] ?? voice['id']) as String,
            name: voice['name'] as String,
            locale: config.provider == 'elevenlabs'
                ? (voice['labels']?['language'] ?? '') as String
                : (voice['locale'] ?? config.language) as String,
          ),
      ];
    } on RemoteSpeechException {
      rethrow;
    } catch (_) {
      throw const RemoteSpeechException('invalid-voice-list');
    }
  }

  Future<void> enableServer() async {
    if (config.provider != 'sepia' || !config.consent) {
      throw const RemoteSpeechException('configure-remote-speech');
    }
    await _request(
      'PUT',
      _server('/api/server-config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ttsEnabled': true}),
      limit: 8192,
    );
  }

  Future<SpeechRecording> synthesize(
    String text,
    double speed, {
    Future<void>? abort,
  }) async {
    validate();
    if (text.trim().isEmpty || text.length > 2000) {
      throw const RemoteSpeechException('invalid-text');
    }
    final Uri uri;
    final Map<String, String> headers;
    final String body;
    if (config.provider == 'azure') {
      uri = _azure('/cognitiveservices/v1');
      headers = {
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        'User-Agent': 'SepiaReader',
      };
      String xml(String value) =>
          const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
      body =
          '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="${xml(config.language)}"><voice name="${xml(config.voice)}"><prosody rate="${((speed - 1) * 100).round()}%">${xml(text)}</prosody></voice></speak>';
    } else if (config.provider == 'elevenlabs') {
      uri = Uri.https(
        'api.elevenlabs.io',
        '/v1/text-to-speech/${Uri.encodeComponent(config.voice)}',
        {'output_format': 'mp3_44100_128'},
      );
      headers = {'Content-Type': 'application/json', 'Accept': 'audio/mpeg'};
      body = jsonEncode({
        'text': text,
        'model_id': config.model,
        // Only models that document an explicit language accept this field;
        // Multilingual v2 detects it from the text and others reject it.
        if (config.model.contains('v2_5') || config.model.contains('v3'))
          'language_code': config.language.split('-').first,
        'voice_settings': {'speed': speed},
      });
    } else {
      uri = _server('/api/tts/speech');
      headers = {'Content-Type': 'application/json', 'Accept': 'audio/wav'};
      body = jsonEncode({
        'text': text,
        'voice': config.voice,
        'language': config.language.split('-').first,
        'speed': speed,
      });
    }
    final bytes = await _request(
      'POST',
      uri,
      headers: headers,
      body: body,
      abort: abort,
    );
    final wav =
        bytes.length > 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE';
    final mp3 =
        bytes.length > 3 &&
        (ascii.decode(bytes.sublist(0, 3), allowInvalid: true) == 'ID3' ||
            (bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0));
    if (!wav && !mp3) throw const RemoteSpeechException('invalid-audio');
    return SpeechRecording(bytes, wav ? 'audio/wav' : 'audio/mpeg');
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
