# Sépia

[Português](README.md) · [English](README.en.md)

A calm, local-first Markdown library, reader, and editor built with Flutter. Sépia lets you keep documents together, edit them without changing tools, and hide the interface when it is time to simply read.

## Features

- Local library with search, favorites, folders, nested folders, and word counts.
- Create `.md` and `.txt` documents at the root or directly inside a folder.
- Rename and move documents between folders or back to the library root.
- Import individual files, drag and drop them in the browser, or import whole folders while preserving compatible files and nested paths, up to 5 MB per file.
- Responsive editor with shortcuts for headings, bold, italic, quotes, lists, links, and code.
- Session-scoped undo/redo through the UI, `Ctrl/Cmd+Z`, `Ctrl+Y`, or `Ctrl/Cmd+Shift+Z`.
- Markdown preview with tables, quotes, and fenced code blocks, with contrast independent from the app theme.
- Syntax highlighting for Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL, and XML.
- Distraction-free reading mode with compact controls, locked editing, and optional auto-hide.
- Merriweather and the Sépia palette by default, plus Artifact, Paper, and Night presets.
- Configurable font, size, line height, page width, background, and text colors.
- Material 3 theme with light, dark, AMOLED, and system modes, plus configurable light and dark backgrounds.
- Reading colors can follow the app theme or remain independently customized.
- Brazilian Portuguese and English UI, with an option to follow the system locale.
- Local persistence and export in the document's original format.
- Web, Android, and iOS targets from one Flutter codebase.

## Web storage and self-hosting

On the web, the library is stored locally in the browser and belongs to the origin serving Sépia—for example, `https://sepia-md.netlify.app`. The server only delivers the app's static files; documents are not uploaded to it. Different visitors do not share libraries, and Netlify does not receive document contents. Someone using the same browser profile and origin, however, can access that local library.

Self-hosting is therefore the recommended focus for a private installation with a stable address. It does not replace backups: clearing site data, switching browsers, or changing the domain can make that browser-local library unavailable. Export important documents regularly.

Every GitHub Release includes a self-hostable web archive. Extract it into the root directory of any static web server. If Sépia will be hosted under a URL subpath, rebuild it with Flutter's matching `--base-href` option.

The release archive bundles Flutter's rendering runtime, Inter, Merriweather, Lora, Roboto Mono, and Noto emoji and symbol fallbacks. The running app does not depend on Google Fonts or a public CDN.

### Deploy to Netlify

1. Run `bash tool/build_web.sh`, or download and extract the `sepia-*-web.tar.gz` release asset.
2. Open **Deploys** in Netlify and drag the entire `build/web` folder into the manual deploy area.
3. Under **Domain management**, choose the desired address, such as `sepia-md.netlify.app`.

The generated folder already contains `_headers` and `_redirects` for WebAssembly, static routing, and an origin-only content policy.

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
bash tool/build_web.sh
flutter build apk --release
flutter build apk --release --target-platform android-arm64
```

## Releases

Semantic version tags automatically publish a GitHub Release containing a universal Android APK, a smaller modern-device `arm64-v8a` APK, the self-hostable web archive, and SHA-256 checksums:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The ARM64 APK is recommended for most modern devices; the universal APK remains available for compatibility. Both currently use the development signing configuration and are intended for direct installation and testing. Configure a permanent signing key and prefer an Android App Bundle before Play Store distribution.

## Privacy and persistence

The MVP does not send document contents to a backend. On mobile and web, preferences and library data are kept on the current device. Browser storage is convenient but is not a backup or a cross-device synchronization system.

## Stack

Flutter, Material 3, `flutter_markdown_plus`, `highlight`, `file_picker`, `file_saver`, `shared_preferences`, and locally bundled OFL fonts.

## License

MIT.
