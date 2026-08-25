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
/// Deliberately narrow, and deliberately not the `flutter_tts` API: the
/// system voice is the engine that ships today, but a locally-run neural
/// model (Kokoro on sherpa-onnx) is the one actually wanted, and it has a
/// very different shape — it synthesises audio it then has to play, and it
/// holds hundreds of megabytes while it is loaded. Everything above this
/// interface (the player, the chapter picker, the reader) is written once
/// against these six methods so adding that engine is a new file rather
/// than a rewrite.
abstract class TtsEngine {
  /// Human-readable name of the backend, for the settings screen.
  String get label;

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

  Future<void> stop();

  /// Releases whatever the engine was holding. Playback must be startable
  /// again afterwards via [prepare].
  Future<void> release();
}
