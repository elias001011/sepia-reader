/// Which build of Sépia this is.
///
/// `false` on `main` (the full app), `true` on the `Lite` branch. A release
/// carries the APKs for both — `sepia-<ver>-android-*.apk` and
/// `sepia-lite-<ver>-android-*.apk` — so the update check has to offer the
/// one that matches the build asking. This is the only line that differs
/// between the branches for that purpose; see [pickApkFor].
const bool appIsLite = true;
