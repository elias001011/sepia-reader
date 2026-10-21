part of 'voice_catalog.dart';

// Original upstream FP32 models used in the listening comparison.
// Fixed revisions avoid silently changing models or downloading repository extras.
final _supertonicPacks = <VoicePack>[
  VoicePack(
    id: 'supertonic/3',
    label: 'Supertonic 3',
    kind: NeuralVoiceKind.supertonic,
    repo: 'supertone-oss-archive/supertonic-3',
    revision: 'aafc6e32416a594460b32413efc49d7fe4ce6d46',
    approxBytes: 398960012,
    modelFile: 'onnx/vector_estimator.onnx',
    files: const [
      VoicePackFile(
        'LICENSE',
        15007,
        '0d944a9110fed9a9602d60e0423a272903e7bd21ab060490774efc77c2275e9f',
      ),
      VoicePackFile(
        'onnx/duration_predictor.onnx',
        3700147,
        'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db',
      ),
      VoicePackFile(
        'onnx/text_encoder.onnx',
        36416150,
        'c7befd5ea8c3119769e8a6c1486c4edc6a3bc8365c67621c881bbb774b9902ff',
      ),
      VoicePackFile(
        'onnx/tts.json',
        8253,
        '42078d3aef1cd43ab43021f3c54f47d2d75ceb4e75f627f118890128b06a0d09',
      ),
      VoicePackFile(
        'onnx/unicode_indexer.json',
        277676,
        '9bf7346e43883a81f8645c81224f786d43c5b57f3641f6e7671a7d6c493cb24f',
      ),
      VoicePackFile(
        'onnx/vector_estimator.onnx',
        256534781,
        '883ac868ea0275ef0e991524dc64f16b3c0376efd7c320af6b53f5b780d7c61c',
      ),
      VoicePackFile(
        'onnx/vocoder.onnx',
        101424195,
        '085de76dd8e8d5836d6ca66826601f615939218f90e519f70ee8a36ed2a4c4ba',
      ),
      VoicePackFile(
        'voice_styles/M1.json',
        291748,
        'e35604687f5d23694b8e91593a93eec0e4eca6c0b02bb8ed69139ab2ea6b0a5b',
      ),
      VoicePackFile(
        'voice_styles/M2.json',
        292055,
        'b76cbf62bac707c710cf0ae5aba5e31eea1a6339a9734bfae33ab98499534a50',
      ),
    ],
    voices: _supertonicVoices(3, const [
      'pt',
      'en',
      'ko',
      'ja',
      'ar',
      'bg',
      'cs',
      'da',
      'de',
      'el',
      'es',
      'et',
      'fi',
      'fr',
      'hi',
      'hr',
      'hu',
      'id',
      'it',
      'lt',
      'lv',
      'nl',
      'pl',
      'ro',
      'ru',
      'sk',
      'sl',
      'sv',
      'tr',
      'uk',
      'vi',
    ]),
  ),
  VoicePack(
    id: 'supertonic/2',
    label: 'Supertonic 2',
    kind: NeuralVoiceKind.supertonic,
    repo: 'supertone-oss-archive/supertonic-2',
    revision: '7edbcd0bba8cd579100a353a9e0b2b49cad7c875',
    approxBytes: 263955971,
    modelFile: 'onnx/vector_estimator.onnx',
    files: const [
      VoicePackFile(
        'LICENSE',
        15007,
        '0d944a9110fed9a9602d60e0423a272903e7bd21ab060490774efc77c2275e9f',
      ),
      VoicePackFile(
        'onnx/duration_predictor.onnx',
        1521526,
        '6d556b3691165c364be91dc0bd894656b5949f5acd2750d8ec2f954010845011',
      ),
      VoicePackFile(
        'onnx/text_encoder.onnx',
        27431318,
        'dd5f535ed629f7df86071043e15f541ce1b2ab7f1bdbce4c7892b307bca79fa3',
      ),
      VoicePackFile(
        'onnx/tts.json',
        8699,
        'ee531d9af9b80438a2ed703e22155ee6c83b12595ab22fd3bb6de94c7502fe96',
      ),
      VoicePackFile(
        'onnx/unicode_indexer.json',
        262196,
        'b7662a73a0703f43b97c0f2e089f8e8325e26f5d841aca393b5a54c509c92df1',
      ),
      VoicePackFile(
        'onnx/vector_estimator.onnx',
        132471364,
        '105e9d66fd8756876b210a6b4aa03fc393b1eaca3a8dadcc8d9a3bc785c86a35',
      ),
      VoicePackFile(
        'onnx/vocoder.onnx',
        101405066,
        '19bd51f47a186069c752403518a40f7ea4c647455056d2511f7249691ecddf7c',
      ),
      VoicePackFile(
        'voice_styles/M1.json',
        420510,
        'a04c823cbda6dd1c7de131ec68fea83bbb70d7f29d61623304eb871e3b83b5a1',
      ),
      VoicePackFile(
        'voice_styles/M2.json',
        420285,
        '7ddd07bf873a3fd67d09ef4e8293b486beb658158b47e371166198e4c6926072',
      ),
    ],
    voices: _supertonicVoices(2, const ['pt', 'en', 'ko', 'es', 'fr']),
  ),
];

List<NeuralVoice> _supertonicVoices(int version, List<String> languages) => [
  for (final language in languages)
    for (final speaker in [2, 1])
      NeuralVoice(
        id: language == 'pt'
            ? 'supertonic/$version/M$speaker'
            : 'supertonic/$version/$language/M$speaker',
        label: 'M$speaker',
        language: language,
        speakerId: speaker - 1,
      ),
];
