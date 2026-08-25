/// How heavy a voice is to download and to run.
///
/// Three steps, and the app is meant to be usable at every one of them: the
/// platform voice needs nothing at all, Piper is a small download that runs
/// comfortably on a modest phone, and Kokoro is a much larger one that
/// sounds better where there is room for it.
enum NeuralVoiceTier {
  /// A small, single-language model. Tens of megabytes, quick to load.
  light,

  /// A large multilingual model. Better voice, several hundred megabytes of
  /// download and a matching appetite for memory while it runs.
  best,
}

/// Which sherpa-onnx model family a downloadable voice belongs to.
///
/// The two differ in more than size. Piper is one voice per model, natively
/// trained on its own language; Kokoro is one large multilingual model whose
/// voices are speaker ids inside it. That distinction decides how the model
/// is configured and how a voice is selected at generation time, so it is
/// modelled here rather than being guessed from the file names.
enum NeuralVoiceKind { piper, kokoro }

/// A voice that can be downloaded and then run entirely on the device.
class NeuralVoice {
  const NeuralVoice({
    required this.id,
    required this.label,
    required this.language,
    required this.kind,
    required this.repo,
    required this.approxBytes,
    required this.modelFile,
    this.tokensFile = 'tokens.txt',
    this.voicesFile,
    this.dataDir = 'espeak-ng-data',
    this.dictDir,
    this.lexicon = const [],
    this.speakerId = 0,
    this.espeakLang = '',
    this.note,
  });

  /// Stable identifier stored in settings, e.g. `piper/pt_BR-faber-medium`.
  final String id;

  /// Name shown in the picker.
  final String label;

  /// BCP-47-ish tag, used to group the picker by language.
  final String language;

  final NeuralVoiceKind kind;

  /// Hugging Face repository the files come from.
  ///
  /// The files are fetched individually rather than as the project's
  /// published `.tar.bz2`: decompressing bzip2 in Dart runs at roughly
  /// 175 ms per megabyte (measured), which is 3.5 s for the smallest Piper
  /// voice and around a minute for Kokoro on a desktop — worse on a phone,
  /// and it needs the whole archive plus its expansion in memory at once.
  /// Streaming each file straight to disk costs neither.
  final String repo;

  /// Rough download size, for the picker. The real total comes from the
  /// repository listing at install time.
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

  /// Kokoro only: which speaker inside the shared model this voice is.
  final int speakerId;

  /// espeak-ng language for Kokoro's G2P.
  final String espeakLang;

  final String? note;

  bool get isKokoro => kind == NeuralVoiceKind.kokoro;

  NeuralVoiceTier get tier =>
      isKokoro ? NeuralVoiceTier.best : NeuralVoiceTier.light;

  String get languageLabel => switch (language) {
    'pt-BR' => 'Português (Brasil)',
    'pt-PT' => 'Português (Portugal)',
    'en-US' => 'English (US)',
    'en-GB' => 'English (UK)',
    _ => language,
  };
}

/// Voices offered for download.
///
/// Piper leads the list deliberately. Its Brazilian voices are trained on
/// Brazilian Portuguese, where Kokoro's are three speakers inside a
/// multilingual model, and a ~77 MB download that loads in a moment beats a
/// ~380 MB one that needs several hundred megabytes of RAM to run — on the
/// phone this is actually read on, that is the difference between a feature
/// and a demo.
const neuralVoices = <NeuralVoice>[
  NeuralVoice(
    id: 'piper/pt_BR-faber-medium',
    label: 'Faber',
    language: 'pt-BR',
    kind: NeuralVoiceKind.piper,
    repo: 'csukuangfj/vits-piper-pt_BR-faber-medium',
    approxBytes: 81 * 1024 * 1024,
    modelFile: 'pt_BR-faber-medium.onnx',
  ),
  NeuralVoice(
    id: 'piper/pt_BR-cadu-medium',
    label: 'Cadu',
    language: 'pt-BR',
    kind: NeuralVoiceKind.piper,
    repo: 'csukuangfj/vits-piper-pt_BR-cadu-medium',
    approxBytes: 81 * 1024 * 1024,
    modelFile: 'pt_BR-cadu-medium.onnx',
  ),
  NeuralVoice(
    id: 'piper/pt_BR-jeff-medium',
    label: 'Jeff',
    language: 'pt-BR',
    kind: NeuralVoiceKind.piper,
    repo: 'csukuangfj/vits-piper-pt_BR-jeff-medium',
    approxBytes: 81 * 1024 * 1024,
    modelFile: 'pt_BR-jeff-medium.onnx',
  ),
  NeuralVoice(
    id: 'piper/pt_PT-tugao-medium',
    label: 'Tugão',
    language: 'pt-PT',
    kind: NeuralVoiceKind.piper,
    repo: 'csukuangfj/vits-piper-pt_PT-tugao-medium',
    approxBytes: 81 * 1024 * 1024,
    modelFile: 'pt_PT-tugao-medium.onnx',
  ),
  NeuralVoice(
    id: 'piper/en_US-amy-medium',
    label: 'Amy',
    language: 'en-US',
    kind: NeuralVoiceKind.piper,
    repo: 'csukuangfj/vits-piper-en_US-amy-medium',
    approxBytes: 81 * 1024 * 1024,
    modelFile: 'en_US-amy-medium.onnx',
  ),
  // Kokoro: one model, three Brazilian speakers inside it. Downloaded and
  // stored once however many of them are used.
  NeuralVoice(
    id: 'kokoro/pf_dora',
    label: 'Dora (Kokoro)',
    language: 'pt-BR',
    kind: NeuralVoiceKind.kokoro,
    repo: 'csukuangfj/kokoro-multi-lang-v1_0',
    approxBytes: 400 * 1024 * 1024,
    modelFile: 'model.onnx',
    voicesFile: 'voices.bin',
    dictDir: 'dict',
    lexicon: ['lexicon-us-en.txt', 'lexicon-zh.txt'],
    speakerId: 42,
    espeakLang: 'pt-br',
    note: 'kokoro-heavy',
  ),
  NeuralVoice(
    id: 'kokoro/pm_alex',
    label: 'Alex (Kokoro)',
    language: 'pt-BR',
    kind: NeuralVoiceKind.kokoro,
    repo: 'csukuangfj/kokoro-multi-lang-v1_0',
    approxBytes: 400 * 1024 * 1024,
    modelFile: 'model.onnx',
    voicesFile: 'voices.bin',
    dictDir: 'dict',
    lexicon: ['lexicon-us-en.txt', 'lexicon-zh.txt'],
    speakerId: 43,
    espeakLang: 'pt-br',
    note: 'kokoro-heavy',
  ),
  NeuralVoice(
    id: 'kokoro/pm_santa',
    label: 'Santa (Kokoro)',
    language: 'pt-BR',
    kind: NeuralVoiceKind.kokoro,
    repo: 'csukuangfj/kokoro-multi-lang-v1_0',
    approxBytes: 400 * 1024 * 1024,
    modelFile: 'model.onnx',
    voicesFile: 'voices.bin',
    dictDir: 'dict',
    lexicon: ['lexicon-us-en.txt', 'lexicon-zh.txt'],
    speakerId: 44,
    espeakLang: 'pt-br',
    note: 'kokoro-heavy',
  ),
];

NeuralVoice? neuralVoiceById(String id) {
  for (final voice in neuralVoices) {
    if (voice.id == id) return voice;
  }
  return null;
}

/// Voices that share a download. Kokoro's speakers all live in one model, so
/// installing any of them installs the rest.
List<NeuralVoice> voicesSharing(NeuralVoice voice) =>
    neuralVoices.where((other) => other.repo == voice.repo).toList();
