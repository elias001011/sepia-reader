# Sépia

[Português](README.md) · [English](README.en.md)

A calm, local-first Markdown library, reader, and editor built with Flutter. Sépia lets you keep documents together, edit them without changing tools, and hide the interface when it is time to simply read.

## Features

### Reading
- reading mode that locks editing, uses compact controls, and can hide them automatically;
- Merriweather and the Sépia theme by default, with Artifact, Paper, and Night presets;
- configurable font, size, line height, width, background, and text colour;
- bookmarks anchored to the passage rather than to a scroll position — they do not drift when the document changes size;
- full Markdown: headings, emphasis, strikethrough, lists, task lists, nested quotes, aligned tables, links (reference-style included), images, footnotes, and code blocks;
- a dedicated code viewer with line numbers, separate from the prose reader;
- `.html` preview, with the source one tap away;
- large documents are virtualized: only what is on screen is built.

### Listening
- read-aloud, with a chapter (`#`/`##`) picker to start from, "carry on from where I stopped", pause, skip, and speed control;
- the page scrolls along with the voice;
- three voice tiers:
  - **system voice** — ultra light, uses what Android or the browser already has, nothing to download;
  - **Piper** (~80 MB) — a neural voice that runs well on any device;
  - **Kokoro** (~400 MB) — more natural, for devices with space and memory to spare;
- both neural tiers run offline on the device through sherpa-onnx: no text leaves the device, no API and no key;
- voices are downloaded on demand, with progress, cancellation, resumable downloads, and removal;
- Markdown syntax is never read out loud — tables become prose, code and diagrams are skipped.

### Writing
- responsive editor with shortcuts for headings, bold, italic, quotes, lists, links, and code;
- per-session undo/redo through the interface, `Ctrl/Cmd+Z`, `Ctrl+Y`, or `Ctrl/Cmd+Shift+Z`;
- large documents are edited in parts, following the text's own chapters, so typing stays responsive — the saved file remains whole;
- syntax highlighting for Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL, and XML.

### Keeping
- local library with search, favourites, folders, subfolders, and word counts;
- create `.md` and `.txt` at the root or inside a folder;
- rename and move documents between folders and back to the root;
- multiple import, by drag and drop in the browser or from whole folders, preserving the hierarchy, with a 5 MB per-file limit;
- files that are not text (`.docx`, `.pdf`, images) are turned away even when renamed — the check is on the bytes, not the extension;
- folder deletion with a confirmation that takes subfolders and documents with it;
- optional syncing with your own server, with pull-to-refresh in the library;
- local persistence and export of the original file.

### Everywhere
- Material 3 light, dark, AMOLED, or system theme, with custom light and dark backgrounds;
- an option for reading to follow the app colours entirely or use its own palette;
- interface localized in Brazilian Portuguese and English, with a follow-the-system option;
- web, Android, and iOS builds from the same Flutter codebase (neural voices are native-only).

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
- read-aloud in reading mode, with a chapter (`#`/`##`) picker to start from, "carry on from where I stopped", pause, skip and speed control;
- three voice tiers: the native Android/browser voice (ultra light, nothing to download), **Piper** (~80 MB, runs well on any device) and **Kokoro** (~400 MB, more natural), both running offline on the device itself through sherpa-onnx — no text leaves the device, no API and no key;
- neural voices downloaded on demand, with progress, cancellation, resumable downloads and removal;
- reading-mode bookmarks anchored to the passage rather than to a scroll position;
- dedicated code viewer with line numbers, separate from the prose reader;
- `.html` preview in reading mode, with the source one tap away;
- large documents edited in parts (the text's own chapters), keeping typing responsive without changing the saved file;
- files that are not text (`.docx`, `.pdf`, images) turned away on import, even when renamed;
- folder deletion with a confirmation that takes subfolders and documents with it;
- optional syncing with your own server, with pull-to-refresh in the library;

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
flutter build apk --release --split-per-abi   # one APK per architecture
flutter build apk --release                   # universal, all of them
```

The web script bundles the Flutter runtime, the Inter, Merriweather, Lora, and Roboto Mono fonts, and the Noto fallbacks for emoji and symbols into `build/web` itself; the app depends on neither Google Fonts nor a CDN at runtime.

Neural voices run through `sherpa_onnx`, which ships native libraries for every Android architecture. That is what `--split-per-abi` is for: an `arm64-v8a` APK carries only the library its own device needs, while the universal one carries all of them. The voice models are **not** in the APK — the app downloads them on demand from its settings.

Files are stored locally on the device/browser with `shared_preferences`. Sépia does not send content to any server.

## Releases

Semantic tags automatically publish a GitHub Release with one APK per architecture, a universal APK, the static web bundle, and SHA-256 checksums:

```bash
git tag v1.2.0
git push origin v1.2.0
```

**Download `arm64-v8a`** — it is the architecture of virtually every current Android phone, and the smallest APK. `armeabi-v7a` serves older devices, `x86_64` serves emulators, and the universal build exists only as a compatibility fallback: it is considerably larger because it carries the native libraries for every architecture at once.

All of them use the current development signing key and are meant for direct installation and testing. Before distributing through the Play Store, set up a permanent signing key and prefer an Android App Bundle — Play itself then delivers only each device's ABI.

## Privacy and persistence

The MVP does not send document contents to a backend. On mobile and web, preferences and library data are kept on the current device. Browser storage is convenient but is not a backup or a cross-device synchronization system.

## Stack

Flutter, Material 3, `flutter_markdown_plus`, `highlight`, `file_picker`, `file_saver`, `shared_preferences`, and locally bundled OFL fonts.

## License

MIT.
