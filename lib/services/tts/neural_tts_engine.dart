/// On-device neural speech, split by platform for the same reason as
/// [VoiceStore]: the implementation is built on `dart:io` and FFI, neither of
/// which exists in the web build.
library;

export 'neural_tts_engine_stub.dart'
    if (dart.library.io) 'neural_tts_engine_io.dart';
