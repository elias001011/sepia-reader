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
  SystemTtsEngine({this.preferredLanguage});

  /// Language to fall back on when no specific voice was chosen — the app's
  /// own setting, so a reader who set the interface to English is not read
  /// to in Portuguese because that is what the device is set to.
  final String? preferredLanguage;

  FlutterTts? _tts;
  Completer<void>? _utterance;
  Future<void>? _preparing;
  int _epoch = 0;

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
    return _preparing ??= _prepare().whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
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
      final pending = _utterance;
      _utterance = null;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(StateError('system speech failed: $message'));
      }
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
        // Setting the language AFTER the voice can restore Android's default
        // voice for that locale and silently undo the user's selection.
        await tts.setLanguage(parts[1]);
        selected =
            await tts.setVoice({'name': parts[0], 'locale': parts[1]}) == 1;
      } catch (error) {
        debugPrint('sepia: could not select voice $voiceId: $error');
      }
    }
    if (!selected) {
      // Without a language the engine has nothing to speak with, and
      // "nothing happened" is what that looks like from the outside. The
      // app's own choice comes first, then the device's, then whatever the
      // engine will accept.
      final candidates = <String>[
        ?preferredLanguage,
        PlatformDispatcher.instance.locale.toLanguageTag(),
        'en-US',
      ];
      for (final candidate in candidates) {
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
    // flutter_tts maps Android's 0.5 to its native 1.0; Apple uses a
    // normalized rate with 0.5 as default. Web uses a direct multiplier.
    final normalizedRate =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    await tts.setSpeechRate(
      normalizedRate ? rate.clamp(.5, 2) / 2 : rate.clamp(.5, 2),
    );
    await tts.setPitch(pitch);
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    final epoch = _epoch;
    await prepare();
    if (epoch != _epoch) return;
    _finishUtterance();
    // Android's engine drops an utterance handed to it in the same beat as
    // a stop. A tick is enough for it to have settled, and is imperceptible.
    if (_stoppedAt != null &&
        DateTime.now().difference(_stoppedAt!) <
            const Duration(milliseconds: 60)) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (epoch != _epoch) return;
    final completer = Completer<void>();
    _utterance = completer;
    // The completion callback is the platform's to fire, and some engines
    // never do — a browser voice that fails to start, an Android engine
    // that was swapped out mid-utterance. Without a bound, one silent
    // failure stops playback forever and leaves the pause button doing
    // nothing. The bound is generous: far longer than any sentence takes to
    // say, so a slow voice is never cut off.
    try {
      await Future.wait<void>([
        _tts!.speak(text).then((status) {
          if (status == 0 && epoch == _epoch) {
            throw StateError('system speech did not start');
          }
        }),
        completer.future.timeout(_budgetFor(text)),
      ], eagerError: true);
    } on TimeoutException {
      // The platform never reported the utterance finishing. Silence the
      // engine before giving up, or a callback that was merely slow lets
      // the next sentence start over the top of this one.
      debugPrint('sepia: no completion callback for an utterance');
      // Through stop(), not the plugin directly: a timeout is exactly a stop
      // followed immediately by a speak, which is the case the settle window
      // exists for, and it is keyed off stop() recording when it happened.
      if (epoch != _epoch) return;
      await stop();
      throw StateError('system speech did not complete');
    } finally {
      if (identical(_utterance, completer)) _finishUtterance();
    }
  }

  /// Time to allow one utterance, from a deliberately slow reading pace.
  static Duration _budgetFor(String text) =>
      Duration(milliseconds: 4000 + text.length * 220);

  DateTime? _stoppedAt;

  @override
  Future<void> stop() async {
    _epoch++;
    _stoppedAt = DateTime.now();
    _finishUtterance();
    await _tts?.stop();
  }

  @override
  Future<void> release() async {
    await stop();
    await _preparing;
    _tts = null;
  }
}
