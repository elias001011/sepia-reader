/// How heavy a voice pack is to download and to run.
///
/// Three steps, and the app is meant to be usable at every one: the platform
/// voice needs nothing at all, Piper is a small download that runs
/// comfortably on a modest phone, and Kokoro is a much larger one that
/// sounds better where there is room for it.
enum NeuralVoiceTier {
  /// A small, single-language model. Tens of megabytes, quick to load.
  light,

  /// A large multilingual model. Better voice, several hundred megabytes of
  /// download and a matching appetite for memory while it runs.
  best,
}

/// Which sherpa-onnx model family a pack belongs to.
///
/// The distinction is not cosmetic: a Piper pack *is* one voice, while a
/// Kokoro pack is one model containing many speakers. Modelling that here is
/// what stops the interface from offering to download the same 400 MB model
/// once per speaker.
enum NeuralVoiceKind { piper, kokoro }

/// One speaker. For Piper there is exactly one per pack; for Kokoro there
/// are many, all served by the same downloaded model.
class NeuralVoice {
  const NeuralVoice({
    required this.id,
    required this.label,
    required this.language,
    required this.speakerId,
  });

  /// Stable identifier stored in settings, e.g. `piper/pt_BR-faber-medium`
  /// or `kokoro/pf_dora`.
  final String id;

  /// Name shown in the picker.
  final String label;

  /// BCP-47-ish tag.
  final String language;

  /// Which speaker inside the pack's model this is.
  final int speakerId;

  String get languageLabel => languageLabelFor(language);

  /// espeak-ng language for grapheme-to-phoneme conversion.
  ///
  /// Per voice, not per pack. Kokoro is one model holding speakers of eight
  /// languages, and it was handing every one of them the pack's single
  /// setting — so an English or Chinese voice was phonemised with Brazilian
  /// Portuguese rules and mispronounced everything it said.
  String get espeakLanguage => switch (language) {
    'pt-BR' => 'pt-br',
    'pt-PT' => 'pt',
    'en-US' => 'en-us',
    'en-GB' => 'en-gb',
    'es-ES' || 'es-MX' => 'es',
    'fr-FR' => 'fr-fr',
    'de-DE' => 'de',
    'it-IT' => 'it',
    'nl-NL' => 'nl',
    'pl-PL' => 'pl',
    'ru-RU' => 'ru',
    'sv-SE' => 'sv',
    'tr-TR' => 'tr',
    'zh-CN' => 'cmn',
    'ja-JP' => 'ja',
    'ko-KR' => 'ko',
    'hi-IN' => 'hi',
    _ => language.split('-').first.toLowerCase(),
  };
}

/// A single downloadable unit: one Hugging Face repository, one model on
/// disk, and the speakers it provides.
class VoicePack {
  const VoicePack({
    required this.id,
    required this.label,
    required this.kind,
    required this.repo,
    required this.approxBytes,
    required this.modelFile,
    required this.voices,
    this.tokensFile = 'tokens.txt',
    this.voicesFile,
    this.dataDir = 'espeak-ng-data',
    this.dictDir,
    this.lexicon = const [],
  });

  /// Stable identifier, e.g. `piper/pt_BR-faber-medium`.
  final String id;
  final String label;
  final NeuralVoiceKind kind;

  /// Hugging Face repository the files come from.
  ///
  /// Files are fetched individually rather than as the project's published
  /// `.tar.bz2`: decompressing bzip2 in Dart runs at roughly 175 ms per
  /// megabyte (measured), and it needs the archive plus its expansion in
  /// memory at once — which for a 400 MB model is not a slow path but an
  /// impossible one. Streaming each file straight to disk costs neither.
  final String repo;

  /// Download size, for the picker — measured from each repository's own
  /// listing rather than assumed, because it is the figure a phone with
  /// little room left is deciding on. The exact total is read again at
  /// install time.
  final int approxBytes;

  final String modelFile;
  final String tokensFile;

  /// Kokoro only: the speaker embedding table.
  final String? voicesFile;

  /// espeak-ng data directory, used for grapheme-to-phoneme conversion.
  final String dataDir;

  /// Kokoro only: Chinese word-segmentation dictionaries.
  final String? dictDir;

  /// Kokoro only: lexicon files, in the order sherpa-onnx expects.
  final List<String> lexicon;

  final List<NeuralVoice> voices;

  bool get isKokoro => kind == NeuralVoiceKind.kokoro;

  NeuralVoiceTier get tier =>
      isKokoro ? NeuralVoiceTier.best : NeuralVoiceTier.light;

  /// Languages this pack can speak, in the order its speakers are listed.
  List<String> get languages {
    final seen = <String>{};
    return [
      for (final voice in voices)
        if (seen.add(voice.language)) voice.language,
    ];
  }
}

String languageLabelFor(String language) => switch (language) {
  'pt-BR' => 'Português (Brasil)',
  'pt-PT' => 'Português (Portugal)',
  'en-US' => 'English (US)',
  'en-GB' => 'English (UK)',
  'es-ES' => 'Español (España)',
  'es-MX' => 'Español (México)',
  'fr-FR' => 'Français',
  'de-DE' => 'Deutsch',
  'it-IT' => 'Italiano',
  'nl-NL' => 'Nederlands',
  'pl-PL' => 'Polski',
  'ru-RU' => 'Русский',
  'sv-SE' => 'Svenska',
  'tr-TR' => 'Türkçe',
  'zh-CN' => '中文',
  'ja-JP' => '日本語',
  'ko-KR' => '한국어',
  'hi-IN' => 'हिन्दी',
  _ => language,
};

VoicePack _piper({
  required String slug,
  required String label,
  required String language,
  int approxMegabytes = 77,
}) => VoicePack(
  id: 'piper/$slug',
  label: label,
  kind: NeuralVoiceKind.piper,
  repo: 'csukuangfj/vits-piper-$slug',
  approxBytes: approxMegabytes * 1024 * 1024,
  modelFile: '$slug.onnx',
  voices: [
    NeuralVoice(
      id: 'piper/$slug',
      label: label,
      language: language,
      speakerId: 0,
    ),
  ],
);

/// Packs offered for download.
///
/// Piper leads the list deliberately. Its voices are trained one per
/// language, and a ~80 MB download that loads in a moment beats a ~400 MB
/// one needing several hundred megabytes of RAM — on the phone this is
/// actually read on, that is the difference between a feature and a demo.
final voicePacks = <VoicePack>[
  _piper(slug: 'pt_BR-faber-medium', label: 'Faber', language: 'pt-BR'),
  _piper(slug: 'pt_BR-cadu-medium', label: 'Cadu', language: 'pt-BR'),
  _piper(slug: 'pt_BR-jeff-medium', label: 'Jeff', language: 'pt-BR'),
  _piper(slug: 'pt_PT-tugao-medium', label: 'Tugão', language: 'pt-PT'),
  _piper(slug: 'en_US-amy-medium', label: 'Amy', language: 'en-US'),
  _piper(approxMegabytes: 132, slug: 'en_US-ryan-high', label: 'Ryan', language: 'en-US'),
  _piper(slug: 'en_GB-alba-medium', label: 'Alba', language: 'en-GB'),
  _piper(approxMegabytes: 126, slug: 'en_GB-cori-high', label: 'Cori', language: 'en-GB'),
  _piper(slug: 'es_ES-davefx-medium', label: 'Davefx', language: 'es-ES'),
  _piper(slug: 'es_MX-claude-high', label: 'Claude', language: 'es-MX'),
  _piper(slug: 'fr_FR-siwis-medium', label: 'Siwis', language: 'fr-FR'),
  _piper(slug: 'de_DE-thorsten-medium', label: 'Thorsten', language: 'de-DE'),
  _piper(slug: 'it_IT-paola-medium', label: 'Paola', language: 'it-IT'),
  _piper(slug: 'nl_NL-mls_5809-low', label: 'MLS', language: 'nl-NL'),
  _piper(slug: 'pl_PL-darkman-medium', label: 'Darkman', language: 'pl-PL'),
  _piper(slug: 'ru_RU-dmitri-medium', label: 'Dmitri', language: 'ru-RU'),
  _piper(slug: 'sv_SE-nst-medium', label: 'NST', language: 'sv-SE'),
  _piper(slug: 'tr_TR-fahrettin-medium', label: 'Fahrettin', language: 'tr-TR'),

  // One model, fifty-three speakers. Downloading it once gives all of them,
  // which is why it is a single entry rather than one per voice.
  //
  // Speaker ids are the order sherpa-onnx packed the embeddings in, from
  // scripts/kokoro/v1.0/generate_voices_bin.py in that project.
  VoicePack(
    id: 'kokoro/multi-lang-v1_0',
    label: 'Kokoro multilíngue',
    kind: NeuralVoiceKind.kokoro,
    repo: 'csukuangfj/kokoro-multi-lang-v1_0',
    approxBytes: 400 * 1024 * 1024,
    modelFile: 'model.onnx',
    voicesFile: 'voices.bin',
    dictDir: 'dict',
    lexicon: ['lexicon-us-en.txt', 'lexicon-zh.txt'],
    voices: [
      NeuralVoice(id: 'kokoro/pf_dora', label: 'Dora', language: 'pt-BR', speakerId: 42),
      NeuralVoice(id: 'kokoro/pm_alex', label: 'Alex', language: 'pt-BR', speakerId: 43),
      NeuralVoice(id: 'kokoro/pm_santa', label: 'Santa', language: 'pt-BR', speakerId: 44),
      NeuralVoice(id: 'kokoro/af_heart', label: 'Heart', language: 'en-US', speakerId: 3),
      NeuralVoice(id: 'kokoro/af_bella', label: 'Bella', language: 'en-US', speakerId: 2),
      NeuralVoice(id: 'kokoro/am_michael', label: 'Michael', language: 'en-US', speakerId: 16),
      NeuralVoice(id: 'kokoro/bf_emma', label: 'Emma', language: 'en-GB', speakerId: 21),
      NeuralVoice(id: 'kokoro/bm_george', label: 'George', language: 'en-GB', speakerId: 26),
      NeuralVoice(id: 'kokoro/ef_dora', label: 'Dora', language: 'es-ES', speakerId: 28),
      NeuralVoice(id: 'kokoro/em_alex', label: 'Alex', language: 'es-ES', speakerId: 29),
      NeuralVoice(id: 'kokoro/ff_siwis', label: 'Siwis', language: 'fr-FR', speakerId: 30),
      NeuralVoice(id: 'kokoro/if_sara', label: 'Sara', language: 'it-IT', speakerId: 35),
      NeuralVoice(id: 'kokoro/im_nicola', label: 'Nicola', language: 'it-IT', speakerId: 36),
      NeuralVoice(id: 'kokoro/jf_alpha', label: 'Alpha', language: 'ja-JP', speakerId: 37),
      NeuralVoice(id: 'kokoro/jm_kumo', label: 'Kumo', language: 'ja-JP', speakerId: 41),
      NeuralVoice(id: 'kokoro/hf_alpha', label: 'Alpha', language: 'hi-IN', speakerId: 31),
      NeuralVoice(id: 'kokoro/zf_xiaoxiao', label: 'Xiaoxiao', language: 'zh-CN', speakerId: 47),
      NeuralVoice(id: 'kokoro/zm_yunyang', label: 'Yunyang', language: 'zh-CN', speakerId: 52),
    ],
  ),
];

VoicePack? voicePackById(String id) {
  for (final pack in voicePacks) {
    if (pack.id == id) return pack;
  }
  return null;
}

/// The pack that provides a given voice, and the voice itself.
({VoicePack pack, NeuralVoice voice})? resolveVoice(String voiceId) {
  for (final pack in voicePacks) {
    for (final voice in pack.voices) {
      if (voice.id == voiceId) return (pack: pack, voice: voice);
    }
  }
  return null;
}

/// Every voice in the catalogue, flattened.
Iterable<NeuralVoice> get allNeuralVoices =>
    voicePacks.expand((pack) => pack.voices);
