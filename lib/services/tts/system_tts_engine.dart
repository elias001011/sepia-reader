import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Speech through whatever the platform already has: Android's TextToSpeech,
/// iOS/macOS AVSpeechSynthesizer, and `speechSynthesis` in the browser.
///
/// Costs nothing, needs no network and no download, and works on every
/// target this app builds for — including the web build served from the
/// Termux server, where a bundled neural model would have to be fetched over
/// the network first. The trade-off is voice quality, which is the platform's
/// to decide, not ours.
class SystemTtsEngine extends TtsEngine {
  FlutterTts? _tts;
  Completer<void>? _utterance;

  @override
  String get label => 'system';

  @override
  Future<bool> isAvailable() async {
    try {
      final voices = await availableVoices();
      return voices.isNotEmpty;
    } catch (error) {
      debugPrint('sepia: system TTS unavailable: $error');
      return false;
    }
  }

  @override
  Future<void> prepare() async {
    if (_tts != null) return;
    final tts = FlutterTts();
    // iOS/macOS only — it routes speech through the shared audio session so
    // it mixes properly with whatever else is playing. Every other platform
    // has no such method and throws, which is why the failure is swallowed
    // rather than handled.
    await tts.setSharedInstance(true).catchError((_) => 1);
    tts.setCompletionHandler(_finishUtterance);
    tts.setCancelHandler(_finishUtterance);
    tts.setErrorHandler((message) {
      debugPrint('sepia: TTS error: $message');
      _finishUtterance();
    });
    _tts = tts;
  }

  void _finishUtterance() {
    final pending = _utterance;
    _utterance = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<List<TtsVoice>> availableVoices() async {
    await prepare();
    final raw = await _tts!.getVoices;
    if (raw is! List) return const [];
    final voices = <TtsVoice>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name']?.toString();
      final locale = item['locale']?.toString();
      if (name == null || name.isEmpty || locale == null || locale.isEmpty) {
        continue;
      }
      voices.add(TtsVoice(id: '$name::$locale', name: name, locale: locale));
    }
    // Same voice can be reported more than once by the platform.
    final seen = <String>{};
    final unique = voices.where((voice) => seen.add(voice.id)).toList()
      ..sort((a, b) {
        final byLocale = a.locale.compareTo(b.locale);
        return byLocale != 0 ? byLocale : a.name.compareTo(b.name);
      });
    return unique;
  }

  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async {
    await prepare();
    final tts = _tts!;
    var selected = false;
    if (voiceId != null && voiceId.contains('::')) {
      final parts = voiceId.split('::');
      try {
        await tts.setVoice({'name': parts[0], 'locale': parts[1]});
        await tts.setLanguage(parts[1]);
        selected = true;
      } catch (error) {
        debugPrint('sepia: could not select voice $voiceId: $error');
      }
    }
    if (!selected) {
      // Without a language the engine has nothing to speak with, and
      // "nothing happened" is what that looks like from the outside. Ask for
      // the device's own, and fall back to whatever the engine will accept.
      final wanted = PlatformDispatcher.instance.locale.toLanguageTag();
      for (final candidate in [wanted, 'pt-BR', 'en-US']) {
        try {
          final available = await tts.isLanguageAvailable(candidate);
          if (available == true) {
            await tts.setLanguage(candidate);
            break;
          }
        } catch (error) {
          debugPrint('sepia: language $candidate unavailable: $error');
        }
      }
    }
    // Android's own scale is 0.0-1.0 with 0.5 as normal speed, while iOS,
    // macOS and the browser take a multiplier where 1.0 is normal. Mapping
    // here keeps "1.0x" meaning the same thing to the user everywhere.
    final platformRate = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
        ? (rate / 2).clamp(0.0, 1.0)
        : rate;
    await tts.setSpeechRate(platformRate);
    await tts.setPitch(pitch);
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await prepare();
    _finishUtterance();
    // Android's engine drops an utterance handed to it in the same beat as
    // a stop. A tick is enough for it to have settled, and is imperceptible.
    if (_stoppedAt != null &&
        DateTime.now().difference(_stoppedAt!) < const Duration(milliseconds: 60)) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    final completer = Completer<void>();
    _utterance = completer;
    await _tts!.speak(text);
    // The completion callback is the platform's to fire, and some engines
    // never do — a browser voice that fails to start, an Android engine
    // that was swapped out mid-utterance. Without a bound, one silent
    // failure stops playback forever and leaves the pause button doing
    // nothing. The bound is generous: far longer than any sentence takes to
    // say, so a slow voice is never cut off.
    await completer.future.timeout(
      _budgetFor(text),
      onTimeout: () {
        debugPrint('sepia: no completion callback for an utterance');
      },
    );
  }

  /// Time to allow one utterance, from a deliberately slow reading pace.
  static Duration _budgetFor(String text) => Duration(
    milliseconds: 4000 + text.length * 220,
  );

  DateTime? _stoppedAt;

  @override
  Future<void> stop() async {
    await _tts?.stop();
    _stoppedAt = DateTime.now();
    _finishUtterance();
  }

  @override
  Future<void> release() async {
    await stop();
    _tts = null;
  }
}
