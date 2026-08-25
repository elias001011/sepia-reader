/// Storage for on-device neural voices.
///
/// Split by platform because the whole thing rests on a real filesystem: the
/// web build has no `dart:io`, so importing the implementation there does not
/// merely fail at runtime, it fails to compile. The stub keeps the API
/// present and answers "not supported", which is exactly what the settings
/// screen needs to say.
library;

export 'voice_store_types.dart';
export 'voice_store_stub.dart'
    if (dart.library.io) 'voice_store_io.dart';
