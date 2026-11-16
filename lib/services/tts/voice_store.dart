/// Storage for on-device neural voices.
///
/// Sépia Lite drops the on-device neural stack entirely, so this always
/// resolves to the stub: the API stays present and answers "not supported",
/// which is exactly what the settings screen needs to say.
library;

export 'voice_store_types.dart';
export 'voice_store_stub.dart';
