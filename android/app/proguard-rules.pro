# Sépia Lite — R8 minify + resource shrink are on for the release build.
#
# Flutter's Gradle plugin already injects the keeps for `io.flutter.**`.
# The only plugin left that touches platform APIs by name is flutter_tts.
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn io.flutter.embedding.**
