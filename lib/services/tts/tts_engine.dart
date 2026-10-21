/// One voice a speech engine can use.
class TtsVoice {
  const TtsVoice({required this.id, required this.name, required this.locale});

  /// Stable identifier stored in settings. For the system engine this is
  /// "name::locale", the pair `flutter_tts` needs to select a voice again.
  final String id;
  final String name;
  final String locale;

  /// Language part of the locale ("pt" out of "pt-BR"), used to group the
  /// voice list by language in the picker.
  String get languageCode => locale.split(RegExp('[-_]')).first.toLowerCase();
}

/// A speech backend.
///
/// Shared by the platform voice (including Lite) and optional local neural
/// models. Synthesis and audio ownership stay inside the selected backend.
abstract class TtsEngine {
  /// Human-readable name of the backend, for the settings screen.
  String get label;

  /// Neural text frontends may interpret typographic pauses themselves.
  bool get preserveSpeechPunctuation => false;
  int get utteranceLimit => 240;

  /// Whether this engine can be used on the current device at all.
  Future<bool> isAvailable();

  /// Brings the engine up. Called when playback starts, not at app launch:
  /// an engine that costs memory to hold should not be holding it while the
  /// user is only reading.
  Future<void> prepare();

  Future<List<TtsVoice>> availableVoices();

  /// [rate] and [pitch] are normalised to 0.5–2.0 and 0.5–2.0, with 1.0
  /// meaning "as the voice was recorded". Engines map that onto whatever
  /// scale they actually use.
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  });

  /// Speaks [text], completing when the utterance has finished playing (or
  /// was interrupted by [stop]).
  Future<void> speak(String text);

  /// Neural engines override this to give the current synthesis priority,
  /// starting look-ahead only after its audio is ready to play.
  Future<void> speakWithLookAhead(String text, String? nextText) async {
    final current = speak(text);
    if (nextText != null) unawaitedPrime(nextText);
    await current;
  }

  void unawaitedPrime(String text) {
    // A speculative failure must never abort current playback.
    prime(text).catchError((Object _) {});
  }

  /// Optional hint that [text] is likely to be spoken next.
  ///
  /// A backend that synthesises audio before it can play it — every neural
  /// one — uses this to work ahead while the current sentence is still
  /// playing, which is the difference between continuous reading and a gap
  /// before every sentence. Backends that speak directly ignore it.
  Future<void> prime(String text) async {}

  /// Whether [configure]'s `pitch` means anything to this engine. Neural
  /// models render a voice as it was trained; only the platform voices can
  /// be re-pitched.
  bool get supportsPitch => true;

  Future<void> stop();

  /// Releases whatever the engine was holding. Playback must be startable
  /// again afterwards via [prepare].
  Future<void> release();
}
