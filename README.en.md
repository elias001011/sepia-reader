# Sépia

[Português](README.md) · [English](README.en.md)

A calm, local-first Markdown library, reader, and editor built with Flutter. Sépia lets you keep documents together, edit them without changing tools, and hide the interface when it is time to simply read.

## Features

- Local library with search, favorites, and word counts.
- Create `.md` and `.txt` documents inside the app.
- Import multiple Markdown, text, and source-code files up to 5 MB each.
- Responsive editor with shortcuts for headings, bold, italic, quotes, lists, links, and code.
- Markdown preview with tables, quotes, and fenced code blocks.
- Syntax highlighting for Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL, and XML.
- Distraction-free reading mode that hides editing tools and locks the editor.
- Merriweather and the Sépia palette by default, plus Artifact, Paper, and Night presets.
- Configurable font, size, line height, page width, background, and text colors.
- Material 3 theme with light, dark, and system modes.
- Local persistence and export in the document's original format.
- Web, Android, and iOS targets from one Flutter codebase.

## Web storage and self-hosting

On the web, the library is stored locally in the browser and belongs to the origin serving Sépia—for example, `https://sepia.example.com`. The server only delivers the app's static files; documents are not uploaded to it.

Self-hosting is therefore the recommended focus for a private installation with a stable address. It does not replace backups: clearing site data, switching browsers, or changing the domain can make that browser-local library unavailable. Export important documents regularly.

Every GitHub Release includes a self-hostable web archive. Extract it into the root directory of any static web server. If Sépia will be hosted under a URL subpath, rebuild it with Flutter's matching `--base-href` option.

## Branches

- `main`: shared multiplatform source and project documentation.
- `app`: Android/iOS delivery with an Android build workflow.
- `web`: web/PWA delivery with a static build workflow.

## Run locally

Flutter 3.47 or newer is recommended.

```bash
flutter pub get
flutter run
```

Select a target when needed:

```bash
flutter run -d chrome
flutter run -d android
```

## Build

```bash
flutter build web --release
flutter build apk --release
```

## Releases

Semantic version tags automatically publish a GitHub Release containing the Android APK, the self-hostable web archive, and SHA-256 checksums:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The automated APK currently uses the development signing configuration and is intended for direct installation and testing. Configure a permanent signing key before Play Store distribution.

## Privacy and persistence

The MVP does not send document contents to a backend. On mobile and web, preferences and library data are kept on the current device. Browser storage is convenient but is not a backup or a cross-device synchronization system.

## Stack

Flutter, Material 3, `flutter_markdown_plus`, `highlight`, `file_picker`, `file_saver`, `shared_preferences`, and `google_fonts`.

## License

MIT.
