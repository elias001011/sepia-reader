# Sépia

[Português](README.md) · [English](README.en.md)

A calm, local-first Markdown library, reader, and editor built with Flutter. Sépia lets you keep documents together, edit them without changing tools, and hide the interface when it is time to simply read.

## Features

### Reading
- reading mode that locks editing, uses compact controls, and can hide them automatically;
- Merriweather and the Sépia theme by default;
- **eleven bundled reading families** — Merriweather (with an ExtraBold weight), Merriweather Sans, Literata, Lora, Bitter, Source Serif 4, EB Garamond, Atkinson Hyperlegible, Inter, Roboto Mono, and JetBrains Mono — each previewed in its own letters in the picker;
- **thirteen reading palettes**, split into light (Paper, Parchment, Cream, Grey, Mint, Sky) and dark (Sépia, Artifact, Night, Ink, Solarized, Nord, AMOLED);
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
- voices are downloaded on demand, with progress, cancellation, resumable downloads, and removal; a download keeps going if you close settings, and stays visible in the library;
- Markdown syntax is never read out loud — tables become prose, code and diagrams are skipped.

### Writing
- responsive editor with shortcuts for headings, bold, italic, quotes, lists, links, and code;
- per-session undo/redo through the interface, `Ctrl/Cmd+Z`, `Ctrl+Y`, or `Ctrl/Cmd+Shift+Z`;
- large documents are edited in parts, following the text's own chapters, so typing stays responsive — the saved file remains whole;
- chapter separator toggle in the editor menu: activates or deactivates sectioned editing globally for all large documents;
- chapter navigation in reading mode: a button next to Listen that opens a chapter picker to jump to any section;
- syntax highlighting for Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL, and XML.

### Keeping
- local library with search, favourites, folders, subfolders, and word counts;
- create `.md` and `.txt` at the root or inside a folder;
- rename and move documents between folders and back to the root;
- multiple import, by drag and drop in the browser or from whole folders, preserving the hierarchy, with a 5 MB per-file limit;
- files that are not text (`.docx`, `.pdf`, images) are turned away even when renamed — the check is on the bytes, not the extension;
- folder deletion with a confirmation that takes subfolders and documents with it;
- optional syncing with your own server, with pull-to-refresh in the library;
- local persistence and export of the original file through the system's own save dialog, straight into Downloads, with no storage permission asked.

### Everywhere
- Material 3 light, dark, AMOLED, or system theme, with custom light and dark backgrounds;
- an option for reading to follow the app colours entirely or use its own palette;
- interface localized in Brazilian Portuguese and English, with a follow-the-system option;
- adjustable interface size, composing with the system's own font scaling;
- a new-version notice on launch, linking straight to the APK for the device's architecture — nothing is downloaded or installed without being chosen;
- web, Android, and iOS builds from the same Flutter codebase (neural voices are native-only).

## Web storage and self-hosting

On the web, the library is stored locally in the browser and belongs to the origin serving Sépia—for example, `https://sepia-md.netlify.app`. The server only delivers the app's static files; documents are not uploaded to it. Different visitors do not share libraries, and Netlify does not receive document contents. Someone using the same browser profile and origin, however, can access that local library.

Self-hosting is therefore the recommended focus for a private installation with a stable address. It does not replace backups: clearing site data, switching browsers, or changing the domain can make that browser-local library unavailable. Export important documents regularly.

Every GitHub Release includes a self-hostable web archive and the
`sepia-*-server.py` sync server.

### Sync server

`sepia-<version>-server.py` is a single Python file (standard library only,
3.9+). It exposes a small, atomic JSON API at `/api/documents`, `/api/folders`,
`/api/settings`, and `/api/bookmarks` — that API is what the Android apps
(Sépia **and** Sépia Lite) and the web build use to keep one library in step
across devices. Nothing passes through a third party: the data lives in JSON
files next to the script. It is **not** the Flutter app — hosting sync never
means "downloading the whole app".

Two ways to run it:

- **Sync only (headless).** The recommended mode for an instance only ever
  reached by the native apps. No `web/` directory needed — anything that isn't
  `/api/...` or `/healthz` just returns 404.
- **Sync + web UI.** Extract `sepia-<version>-web.tar.gz` into a `web/` folder
  next to the script and the server also serves the web app at the root.

**Steps:**

1. **Put the files together** in a directory on the server (a mini-PC, a VPS,
   an old phone running Termux):

   ```
   sepia-server/
   ├── main.py            # renamed from sepia-<version>-server.py
   ├── restart-sepia.sh   # optional, "port-still-busy"-proof restart
   ├── web/               # WEB-UI MODE ONLY: contents of sepia-<version>-web.tar.gz
   └── data/              # created on first run; holds the library .json files
   ```

2. **Start it.** It listens on `0.0.0.0:8888` by default:

   ```bash
   python3 main.py
   # or customised:
   SEPIA_PORT=9000 SEPIA_DATA_DIR=/var/lib/sepia python3 main.py
   ```

   Variables: `SEPIA_PORT` (default `8888`), `SEPIA_WEB_DIR` (default `./web`),
   `SEPIA_DATA_DIR` (default `./data`). To keep it running, use `systemd`,
   `pm2`, a `tmux` session, or the bundled `restart-sepia.sh` (written for
   Termux but adaptable — it kills the old instance, waits for the port to
   free, and confirms with `curl .../healthz`). `/healthz` works in both modes
   and returns `{"ok": true, ...}` — handy for a systemd/Docker healthcheck.

   Example systemd unit (headless mode):

   ```ini
   [Unit]
   Description=Sepia sync
   After=network.target

   [Service]
   Environment=SEPIA_PORT=8888
   Environment=SEPIA_DATA_DIR=/var/lib/sepia
   Environment=SEPIA_WEB_DIR=/var/lib/sepia/web-none
   ExecStart=/usr/bin/python3 /opt/sepia/main.py
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target
   ```

3. **Expose the address.** On a LAN, `http://SERVER-IP:8888` is enough. For
   access from outside, put it behind a reverse proxy that terminates HTTPS
   (Caddy, nginx, a Cloudflare Tunnel) — the server does not do TLS itself.

4. **Turn syncing on in the app.** Under **Settings → Sync**, enable *Sync
   with server* and enter the base address (`https://sepia.example.com` or
   `http://192.168.0.10:8888`). Leave the field empty **only** on the web
   build served by the server itself, where it uses its own origin. Use *Test
   connection* to confirm, and pull the library down to force a sync.

Turning syncing off asks whether to also wipe the server's copy; the local
library is never touched by that choice.

If Sépia will be hosted under a URL subpath, rebuild the web app with
Flutter's matching `--base-href` option.

The release archive bundles Flutter's rendering runtime, the eleven reading families, and Noto emoji and symbol fallbacks. The running app depends on neither Google Fonts nor a public CDN. On the `Lite` branch the fonts leave the bundle and are fetched by `google_fonts` the first time each one is used.

### Deploy to Netlify

1. Run `bash tool/build_web.sh`, or download and extract the `sepia-*-web.tar.gz` release asset.
2. Open **Deploys** in Netlify and drag the entire `build/web` folder into the manual deploy area.
3. Under **Domain management**, choose the desired address, such as `sepia-md.netlify.app`.

The generated folder already contains `_headers` and `_redirects` for WebAssembly, static routing, and an origin-only content policy.

## Sépia and Sépia Lite

Every Release ships **two** Android builds of the same app:

| | **Sépia** (`sepia-<version>-android-*.apk`) | **Sépia Lite** (`sepia-lite-<version>-android-*.apk`) |
|---|---|---|
| Focus | full-featured, 100% offline | smallest possible reading APK |
| `arm64` APK size (per-ABI) | ~48 MB | ~31 MB |
| Reading fonts | 11 families **bundled** (works with no internet) | the same families **fetched on demand** via `google_fonts` and cached on device (internet needed only the first time each font is used) |
| On-device neural voice (Piper / Kokoro) | yes, via `sherpa_onnx` | **no** — it is the largest part of the APK |
| System voice (Android/browser) | yes | yes |
| Editor, bookmarks, chapter navigation, themes, palettes | yes | yes |
| Sync with your own server | yes | yes |
| New-version notice | points at the `sepia-*` APKs | points at the `sepia-lite-*` APKs |
| `applicationId` | `dev.elias.sepia_reader` | `dev.elias.sepia_reader.lite` (the two coexist on one device) |
| R8 minification / resource shrinking | no | yes |

In short, Lite is the whole of Sépia minus the bundled fonts and the
on-device neural-TTS stack. Want the smallest APK and don't mind fetching
fonts once? Use Lite. Want everything working with no connection at all? Use
the regular build.

## Branches

- `main`: shared multiplatform source, the full app, and project documentation.
- `Lite`: the trimmed variant above, branched from `main` at each release.
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

For the trimmed variant, do the same from the `Lite` branch
(`git switch Lite`). The release CI builds both on every tag.

The web script bundles the Flutter runtime, the eleven reading families, and the Noto fallbacks for emoji and symbols into `build/web` itself; the app depends on neither Google Fonts nor a CDN at runtime. On the `Lite` branch the fonts leave the bundle and are fetched by `google_fonts` the first time each is used.

Neural voices run through `sherpa_onnx`, which ships native libraries for every Android architecture. That is what `--split-per-abi` is for: an `arm64-v8a` APK carries only the library its own device needs, while the universal one carries all of them. The voice models are **not** in the APK — the app downloads them on demand from its settings. The `Lite` branch does not include `sherpa_onnx`.

Files are stored locally on the device/browser with `shared_preferences`. Sépia does not send content to any server.

## Releases

Semantic tags automatically publish a GitHub Release with, for **Sépia** and **Sépia Lite**, one APK per architecture and a universal one, plus the static web bundle, the server `main.py`, and SHA-256 checksums:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The workflow builds the `Lite` branch from the tag's own commit (in a separate
worktree), so keep `Lite` up to date before tagging.

**Download `arm64-v8a`** — it is the architecture of virtually every current Android phone, and the smallest APK. `armeabi-v7a` serves older devices, `x86_64` serves emulators, and the universal build exists only as a compatibility fallback: it is considerably larger because it carries the native libraries for every architecture at once.

All of them use the current development signing key and are meant for direct installation and testing. For permanent release builds, configure the secrets `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_STORE_PASSWORD`, and `KEY_PASSWORD` in the GitHub repository — the workflow restores the keystore automatically. Before distributing through the Play Store, prefer an Android App Bundle — Play itself then delivers only each device's ABI.

## Privacy and persistence

The MVP does not send document contents to a backend. On mobile and web, preferences and library data are kept on the current device. Browser storage is convenient but is not a backup or a cross-device synchronization system.

## Stack

Flutter, Material 3, `flutter_markdown_plus`, `highlight`, `file_picker` (import and export), `shared_preferences`, `sherpa_onnx` (on-device neural voice), and locally bundled OFL fonts — on the `Lite` branch, `sherpa_onnx` is dropped and `google_fonts` replaces the font bundle.

## License

MIT.
