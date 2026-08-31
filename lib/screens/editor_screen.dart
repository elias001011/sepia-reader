import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../l10n/l10n.dart';
import '../models/bookmark.dart';
import '../models/app_settings.dart';
import '../models/library_document.dart';
import '../services/document_io.dart';
import '../services/document_kind.dart';
import '../services/document_sections.dart';
import '../services/html_preview.dart';
import '../services/tts/neural_tts_engine.dart';
import '../services/tts/system_tts_engine.dart';
import '../services/tts/tts_engine.dart';
import '../services/tts/tts_playback.dart';
import '../services/tts/voice_catalog.dart';
import '../services/tts/voice_store.dart';
import '../state/app_controller.dart';
import '../widgets/markdown_view.dart';
import '../widgets/sheet_scaffold.dart';
import 'bookmarks_sheet.dart';
import 'chapter_navigation_sheet.dart';
import 'listen_sheet.dart';
import 'reader_settings_sheet.dart';

int _countWords(Iterable<String> parts) {
  var words = 0;
  var inWord = false;
  for (final part in parts) {
    for (final unit in part.codeUnits) {
      final whitespace = unit <= 0x20 ||
          unit == 0x85 ||
          unit == 0xA0 ||
          unit == 0x1680 ||
          (unit >= 0x2000 && unit <= 0x200A) ||
          unit == 0x2028 ||
          unit == 0x2029 ||
          unit == 0x202F ||
          unit == 0x205F ||
          unit == 0x3000;
      if (whitespace) {
        inWord = false;
      } else if (!inWord) {
        words++;
        inWord = true;
      }
    }
  }
  return words;
}

String _joinEditorSections(List<String> parts) => parts.join();

/// Inserts a block construct with a blank line on each occupied side. `---`
/// directly under prose is a Setext heading, which the old toolbar produced.
@visibleForTesting
({String text, int cursor}) insertMarkdownBlock(
  String source, {
  required int start,
  required int end,
  required String block,
}) {
  final before = source.substring(0, start);
  final after = source.substring(end);
  final prefix = before.isEmpty || before.endsWith('\n\n')
      ? ''
      : before.endsWith('\n') ? '\n' : '\n\n';
  final suffix = after.isEmpty
      ? '\n'
      : after.startsWith('\n\n') ? '' : after.startsWith('\n') ? '\n' : '\n\n';
  final replacement = '$prefix$block$suffix';
  return (
    text: source.replaceRange(start, end, replacement),
    cursor: start + replacement.length,
  );
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.controller,
    required this.documentId,
  });
  final AppController controller;
  final String documentId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _contentController;
  late final TextEditingController _titleController;
  final UndoHistoryController _undoController = UndoHistoryController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  /// Typing must not rebuild the whole screen. These notifiers let only the
  /// small widgets that actually depend on the text rebuild: the save
  /// indicator, the status bar counters, and the (debounced) live preview.
  final ValueNotifier<bool> _dirty = ValueNotifier(false);
  final ValueNotifier<({int words, int minutes})> _stats = ValueNotifier((
    words: 0,
    minutes: 0,
  ));
  late final ValueNotifier<String> _previewContent;
  bool _previewVisible = false;

  Timer? _saveTimer;
  Future<void> _saveQueue = Future.value();
  Timer? _statsTimer;
  Timer? _previewTimer;
  Timer? _readerControlsTimer;
  bool _readingMode = false;
  /// Reader chrome visibility, as a notifier rather than as state.
  ///
  /// It used to be a plain field flipped with setState, which rebuilt the
  /// whole reader — including the document — every time the controls faded
  /// in or out or the auto-hide timer fired. On a 180 kB document that
  /// rebuild measured ~18 ms, so simply tapping the screen cost most of a
  /// frame. Only the chrome listens to this now.
  final ValueNotifier<bool> _readerControls = ValueNotifier(true);
  bool _showPreview = false;
  String? _activeBookmarkPopupId;

  /// The document title is a plain label until it is tapped.
  ///
  /// It used to be a live TextField sitting in the AppBar, which made it the
  /// first focusable node of this route: every time a modal sheet on top of
  /// the editor closed, focus restoration landed on it, selecting the title
  /// and popping the soft keyboard as though a rename had been requested.
  /// A label cannot be focused, so there is nothing left to land on.
  bool _editingTitle = false;
  final FocusNode _titleFocus = FocusNode();

  /// Long documents are edited one section at a time.
  ///
  /// Flutter's EditableText lays out the whole string on every keystroke and
  /// has no viewport culling, so the cost scales with the document: measured
  /// in this repo's own probe, a keystroke costs ~42 ms with ~90 000
  /// characters in the field and ~10 ms with an ~8 000 character slice of the
  /// same text. Nothing in this screen can make the first number smaller —
  /// the only lever is how much text is in the field, so above
  /// [sectionedEditingThreshold] the field holds one section and the rest of
  /// the document is held aside in [_sectionPrefix] / [_sectionSuffix].
  bool _sectioned = false;
  List<EditableSection> _editSections = const [];
  int _editSectionIndex = 0;
  String _sectionPrefix = '';
  String _sectionSuffix = '';
  int _outsideSectionWords = 0;
  bool _programmaticTextChange = false;

  /// Whether this document is long enough, and has enough structure, for
  /// sectioned editing to actually do something. When it is not — a short
  /// note like the welcome document, or anything under two slices — the
  /// "edit by chapter" control is hidden entirely rather than shown as a
  /// switch that changes nothing. Computed from the whole document, never
  /// from the [AppSettings.sectionedEditing] preference, so the control
  /// still reappears to let the setting be turned back on.
  bool _sectionable = false;

  /// Built the first time the user asks to listen, and released on the way
  /// out of reading mode — a speech backend (and, for the neural engine
  /// coming later, its model) has no business staying resident while
  /// somebody is only reading.
  TtsPlaybackController? _tts;
  final VoiceStore _voiceStore = VoiceStore();

  /// Identifies which backend the player currently holds, so a settings
  /// change swaps it instead of silently reading in the old voice.
  String? _engineKey;

  /// The last speech error already shown to the user, so a failure that
  /// arrives through the controller listener (one that lands after playback
  /// has started) is not also announced by [_startListening], and is not
  /// repeated on every subsequent notification.
  String? _surfacedTtsError;

  /// True only while [_startListening] is bringing a voice up. In that window
  /// it, not the controller listener, decides what the user is told — so a
  /// neural failure that is about to be papered over by the system-voice
  /// fallback is not flashed on screen first.
  bool _listenStarting = false;

  /// `.html` is shown as a rendered preview by default, with the source one
  /// tap away. The conversion is memoised because it walks the whole file.
  var _showMarkupSource = false;
  String? _markupSource;
  String? _markupResult;
  LibraryDocument? _readerSourceSnapshot;

  LibraryDocument? get _stored =>
      widget.controller.documentById(widget.documentId);

  @override
  void initState() {
    super.initState();
    final document = _stored!;
    _configureSections(document.content, index: 0);
    // When sectioning is on and produced slices, the document is sectionable
    // by definition — no need for _isSectionable to scan it a second time.
    _sectionable = _sectioned || _isSectionable(document.content);
    _contentController = TextEditingController(text: _sectionText(document.content))
      ..addListener(_onChanged);
    _titleController = TextEditingController(text: document.title)
      ..addListener(_onTitleChanged);
    _previewContent = ValueNotifier(_sectionText(document.content));
    _stats.value = _currentStats();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus && _editingTitle && mounted) {
        setState(() => _editingTitle = false);
      }
    });
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // dispose is not guaranteed when Android/iOS suspends or kills a process.
    // Flush the debounce while the app still has execution time.
    if (state != AppLifecycleState.resumed && _dirty.value) {
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _statsTimer?.cancel();
    _previewTimer?.cancel();
    _readerControlsTimer?.cancel();
    _readerControls.dispose();
    _tts?.dispose();
    if (_dirty.value) unawaited(_save());
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_refresh);
    _undoController.dispose();
    _dirty.dispose();
    _stats.dispose();
    _previewContent.dispose();
    _contentController.dispose();
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  ({int words, int minutes}) _currentStats() {
    final words = _sectioned
        ? _outsideSectionWords + _countWords([_contentController.text])
        : _countWords([_contentController.text]);
    return (words: words, minutes: words == 0 ? 0 : (words / 220).ceil());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    if (_programmaticTextChange) return;
    // No setState here: rebuilding the whole editor on every keystroke made
    // large documents crawl (a full document copy, two regex passes over the
    // entire text for the counters, and a live markdown re-render).
    _dirty.value = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _save);
    _statsTimer?.cancel();
    _statsTimer = Timer(const Duration(milliseconds: 400), () {
      _stats.value = _currentStats();
    });
    _previewTimer?.cancel();
    if (_previewVisible) {
      _previewTimer = Timer(const Duration(milliseconds: 400), () {
        _previewContent.value = _contentController.text;
      });
    }
  }

  void _onTitleChanged() {
    _dirty.value = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _save);
  }

  /// The full document, with the section currently in the field spliced back
  /// into the text held aside around it.
  String get _fullContent => _sectioned
      ? '$_sectionPrefix${_contentController.text}$_sectionSuffix'
      : _contentController.text;

  LibraryDocument get _draft {
    final document = _stored!;
    return document.copyWith(
      title: _titleController.text.trim().isEmpty
          ? context.l10n.untitled
          : _titleController.text.trim(),
      content: _fullContent,
    );
  }

  /// Whether sectioned editing would produce more than one slice for
  /// [content] — the test for showing the "edit by chapter" control at all.
  static bool _isSectionable(String content) =>
      content.length >= sectionedEditingThreshold &&
      editableSectionsOf(content).length >= 2;

  /// Recomputes [_sectionable] after an edit may have pushed the document
  /// across the threshold, and repaints the app bar if it changed.
  void _refreshSectionable() {
    final next = _isSectionable(_fullContent);
    if (next != _sectionable && mounted) {
      setState(() => _sectionable = next);
    }
  }

  /// Decides whether [content] is edited whole or in slices, and selects
  /// which slice. Does not touch the text field — callers set that up.
  void _configureSections(String content, {required int index}) {
    final needsSectioning = widget.controller.settings.sectionedEditing &&
        content.length >= sectionedEditingThreshold;
    if (!needsSectioning) {
      _sectioned = false;
      _editSections = const [];
      _editSectionIndex = 0;
      _sectionPrefix = '';
      _sectionSuffix = '';
      _outsideSectionWords = 0;
      return;
    }
    final sections = editableSectionsOf(content);
    if (sections.length < 2) {
      _sectioned = false;
      _editSections = const [];
      _editSectionIndex = 0;
      _sectionPrefix = '';
      _sectionSuffix = '';
      _outsideSectionWords = 0;
      return;
    }
    _sectioned = true;
    _editSections = sections;
    _editSectionIndex = index.clamp(0, sections.length - 1);
    final section = sections[_editSectionIndex];
    _sectionPrefix = content.substring(0, section.start);
    _sectionSuffix = content.substring(section.end);
    // Only the active slice changes while typing. Recounting the immutable
    // prefix and suffix every 400 ms made sectioned editing scan the entire
    // book despite keeping only one chapter in EditableText.
    _outsideSectionWords =
        _countWords([_sectionPrefix]) + _countWords([_sectionSuffix]);
  }

  String _sectionText(String content) {
    if (!_sectioned) return content;
    final section = _editSections[_editSectionIndex];
    return content.substring(section.start, section.end);
  }

  /// Saves what is in the field, then re-slices the (now updated) document
  /// and loads [index]. Re-slicing rather than reusing the old offsets is
  /// what keeps the boundaries right after an edit changed the length.
  Future<void> _openSection(int index) async {
    if (_dirty.value) await _save();
    final content = _stored?.content ?? _fullContent;
    setState(() {
      _configureSections(content, index: index);
      final text = _sectionText(content);
      _programmaticTextChange = true;
      try {
        _contentController.value = TextEditingValue(
          text: text,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } finally {
        _programmaticTextChange = false;
      }
      _previewContent.value = text;
    });
  }

  /// Rebuilds the field with the whole document in it. The persistent side of
  /// this — turning [AppSettings.sectionedEditing] off so every document
  /// opens whole from now on — is [_toggleChapterSeparator]'s job; this only
  /// reshapes the field, and is always reached through it.
  Future<void> _editWholeDocument() async {
    if (_dirty.value) await _save();
    final content = _stored?.content ?? _fullContent;
    setState(() {
      _sectioned = false;
      _editSections = const [];
      _editSectionIndex = 0;
      _sectionPrefix = '';
      _sectionSuffix = '';
      _outsideSectionWords = 0;
      _programmaticTextChange = true;
      try {
        _contentController.value = TextEditingValue(
          text: content,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } finally {
        _programmaticTextChange = false;
      }
      _previewContent.value = content;
    });
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    // Snapshot exactly what is being persisted, before the await.
    final savedContent = _contentController.text;
    final savedTitle = _titleController.text;
    final persistedTitle = savedTitle.trim().isEmpty
        ? context.l10n.untitled
        : savedTitle.trim();
    final document = _stored!;
    final prefix = _sectionPrefix;
    final suffix = _sectionSuffix;
    final wasSectioned = _sectioned;
    final operation = _saveQueue.then(
      (_) => _persistSnapshot(
        document: document,
        title: persistedTitle,
        rawTitle: savedTitle,
        sectionContent: savedContent,
        prefix: prefix,
        suffix: suffix,
        wasSectioned: wasSectioned,
      ),
    );
    _saveQueue = operation.then<void>((_) {}, onError: (_, __) {});
    await operation;
  }

  Future<void> _persistSnapshot({
    required LibraryDocument document,
    required String title,
    required String rawTitle,
    required String sectionContent,
    required String prefix,
    required String suffix,
    required bool wasSectioned,
  }) async {
    // Splicing a multi-megabyte book creates another full-size string. Keep
    // that allocation off the UI isolate; the captured pieces also guarantee
    // this save cannot accidentally include text typed after it started.
    final fullContent = wasSectioned
        ? await compute(_joinEditorSections, [prefix, sectionContent, suffix])
        : sectionContent;
    final draft = document.copyWith(
      title: title,
      content: fullContent,
    );
    await widget.controller.updateDocument(draft, notify: false);
    // The write above is what mattered; if the editor was torn down during it
    // (dispose() calls _save() for a still-dirty document) there is nothing
    // left to reconcile, and the controllers below are already disposed.
    if (!mounted) return;
    // Only mark the editor clean if nothing was typed during the await.
    // Clearing it unconditionally dropped a keystroke that landed mid-save:
    // the flag then said "saved", so _close() skipped its flush and dispose()
    // cancelled the pending timer. A still-dirty flag just means the queued
    // timer (or _close) will persist the newer text.
    if (_contentController.text == sectionContent &&
        _titleController.text == rawTitle) {
      _dirty.value = false;
    }
    // A sectioned document is already known to be sectionable. Rebuilding
    // and parsing the complete document after every autosave defeated the
    // point of editing only one chapter at a time.
    if (!_sectioned) _refreshSectionable();
  }

  /// The document as reading mode should show it: `.html` becomes markdown
  /// unless the source was explicitly asked for, everything else is itself.
  LibraryDocument get _readerDocument {
    final draft = _readerSourceSnapshot ?? _draft;
    final isMarkup = documentKindOf(draft.extension) == DocumentKind.markup;
    // Source view, and every non-HTML document, is shown as it is — an
    // .html file read as source lands in the code viewer, which is what
    // "show me the source" should mean.
    if (!isMarkup || _showMarkupSource) return draft;
    if (_markupSource != draft.content) {
      _markupSource = draft.content;
      _markupResult = htmlToMarkdown(draft.content);
    }
    return draft.copyWith(content: _markupResult!, extension: 'md');
  }

  TtsPlaybackController get _speech =>
      _tts ??= TtsPlaybackController(engine: _buildEngine())
        ..addListener(_onSpeechChanged);

  /// The backend the current settings ask for.
  ///
  /// Falls back to the platform voice whenever the neural one cannot serve:
  /// on the web, where there is no native inference, and when no voice has
  /// been downloaded yet. Silence would be the wrong answer to "read this
  /// to me"; a plainer voice is not.
  TtsEngine _buildEngine() {
    final settings = widget.controller.settings;
    if (settings.ttsEngine == 'neural' && _voiceStore.isSupported) {
      final resolved = resolveVoice(settings.ttsNeuralVoiceId);
      if (resolved != null) {
        return NeuralTtsEngine(
          pack: resolved.pack,
          voice: resolved.voice,
          store: _voiceStore,
        );
      }
    }
    return SystemTtsEngine(preferredLanguage: _preferredLanguage(settings));
  }

  /// The app's own language choice as a BCP-47 tag, or null when it follows
  /// the system and the device's own answer should win.
  static String? _preferredLanguage(AppSettings settings) =>
      switch (settings.localeCode) {
        'pt_BR' => 'pt-BR',
        'en' => 'en-US',
        _ => null,
      };

  String get _wantedEngineKey {
    final settings = widget.controller.settings;
    return settings.ttsEngine == 'neural' && _voiceStore.isSupported
        ? 'neural:${settings.ttsNeuralVoiceId}'
        : 'system';
  }

  Future<void> _ensureEngine() async {
    final wanted = _wantedEngineKey;
    if (_tts == null) {
      // Touching the getter builds the player with the right backend
      // already; swapping it immediately afterwards would only churn.
      _engineKey = wanted;
      _speech;
      return;
    }
    if (_engineKey == wanted) return;
    _engineKey = wanted;
    await _tts!.useEngine(_buildEngine());
  }

  /// Keeps the page under the voice: when the reader moves on to a chunk
  /// that is not the one on screen, scroll to it.
  void _onSpeechChanged() {
    if (!mounted) return;
    final controller = _tts;
    if (controller == null) return;
    // A failure that lands after playback has already begun (the engine loses
    // its audio route mid-chapter) surfaces here — the checks in
    // [_startListening] all ran before the first utterance was spoken. During
    // start-up, though, _startListening is in charge (see [_listenStarting]).
    if (!_listenStarting) _surfaceTtsError();
    // No setState: the player bar listens to the controller itself. Calling
    // it here would rebuild the whole document once per sentence.
    if (!controller.isPlaying) return;
    final target = controller.currentChunkIndex;
    if (target == null || !_itemScrollController.isAttached) return;
    final visible = _itemPositionsListener.itemPositions.value;
    final onScreen = visible.any(
      (position) =>
          position.index == target &&
          position.itemLeadingEdge >= -0.1 &&
          position.itemLeadingEdge < 0.85,
    );
    if (onScreen) return;
    _itemScrollController.scrollTo(
      index: target,
      alignment: 0.18,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  /// Shows the "voice failed" message once per distinct error. Called both
  /// from [_startListening] (a backend that will not start) and from the
  /// controller listener (a backend that dies mid-chapter); [_surfacedTtsError]
  /// keeps the two from doubling up, and resets when the error clears so the
  /// next listen can report its own.
  void _surfaceTtsError() {
    final error = _tts?.error;
    if (error == null) {
      _surfacedTtsError = null;
      return;
    }
    if (error == _surfacedTtsError) return;
    _surfacedTtsError = error;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.ttsFailed(error))),
    );
  }

  Future<void> _openListenSheet() async {
    final document = _readerDocument;
    final sections = sectionsOf(document);
    final here = _topVisibleChunk?.index;
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => ListenSheet(
        sections: sections,
        currentChunkIndex: here,
        onPick: (section) {
          Navigator.pop(sheetContext);
          unawaited(_startListening(document, section));
        },
      ),
    );
  }

  Future<void> _startListening(
    LibraryDocument document,
    DocumentSection section,
  ) async {
    final settings = widget.controller.settings;
    // While this runs, _startListening owns error reporting: the controller
    // listener must not pop the neural error it is about to swallow by
    // falling back to the system voice. Mid-chapter failures, which arrive
    // after this returns, are the listener's to surface.
    _listenStarting = true;
    try {
      await _ensureEngine();
      // One rebuild, to put the player bar's listener into the tree. Every
      // update after this comes through the listener instead.
      if (mounted) setState(() {});

      Future<void> run() => _speech.start(
        document: document,
        section: section,
        voiceId: settings.ttsVoiceId.isEmpty ? null : settings.ttsVoiceId,
        rate: settings.ttsRate,
        pitch: settings.ttsPitch,
      );

      await run();
      if (!mounted) return;
      var controller = _tts!;

      // A neural voice depends on a downloaded model, native inference and the
      // device's audio output — three things that can be missing or broken in
      // ways this app cannot fix. Silence is the wrong answer to "read this to
      // me"; falling back to the platform voice and saying so is not.
      if (controller.error != null && _engineKey != 'system') {
        debugPrint(
          'sepia: neural voice failed, falling back: ${controller.error}',
        );
        _engineKey = 'system';
        await controller.useEngine(SystemTtsEngine());
        await run();
        if (!mounted) return;
        controller = _tts!;
        if (controller.error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.ttsFellBackToSystem)),
          );
        }
      }

      if (controller.error != null) {
        _surfaceTtsError();
      } else if (controller.pieceCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ttsNothingToRead)),
        );
      } else {
        _showReaderControls();
      }
    } finally {
      _listenStarting = false;
    }
  }

  void _enterReadingMode() {
    FocusScope.of(context).unfocus();
    // Reuse one source object for the whole reading session so the
    // identity-keyed Markdown chunk cache survives bookmark/chapter actions.
    _readerSourceSnapshot = _draft;
    _readerControls.value = true;
    setState(() => _readingMode = true);
    _scheduleReaderControlsHide();
  }

  /// The topmost chunk currently at least partially visible, or null before
  /// the list has laid out anything yet.
  ItemPosition? get _topVisibleChunk {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return null;
    final sorted = positions.toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    return sorted.firstWhere(
      (p) => p.itemLeadingEdge >= 0,
      orElse: () => sorted.first,
    );
  }

  Future<void> _addBookmarkHere() async {
    final top = _topVisibleChunk;
    if (top == null) return;
    final chunks = chunksForDocument(_readerDocument);
    final index = top.index.clamp(0, chunks.length - 1).toInt();
    final trimmed = chunks[index].replaceAll(RegExp(r'\s+'), ' ').trim();
    final excerpt = trimmed.length > 80
        ? '${trimmed.substring(0, 80)}…'
        : trimmed;
    await widget.controller.addBookmark(
      widget.documentId,
      chunkIndex: index,
      alignment: top.itemLeadingEdge.clamp(0.0, 1.0),
      excerpt: excerpt.isEmpty ? context.l10n.untitled : excerpt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.bookmarkAdded),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _goToBookmark(ReadingBookmark bookmark) async {
    if (!_itemScrollController.isAttached) return;
    final chunks = chunksForDocument(_readerDocument);
    if (chunks.isEmpty) return;
    final index = bookmark.chunkIndex.clamp(0, chunks.length - 1).toInt();
    await _itemScrollController.scrollTo(
      index: index,
      alignment: bookmark.alignment,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _openBookmarksSheet() {
    showAppSheet<void>(
      context: context,
      builder: (sheetContext) => BookmarksSheet(
        bookmarks: widget.controller.bookmarksForDocument(widget.documentId),
        onOpen: (bookmark) {
          Navigator.pop(sheetContext);
          _goToBookmark(bookmark);
        },
        onRemove: (bookmark) => widget.controller.removeBookmark(bookmark.id),
      ),
    );
  }

  Future<void> _openChapterNavigation() async {
    final document = _readerDocument;
    final sections = sectionsOf(document);
    final here = _topVisibleChunk?.index ?? 0;
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => ChapterNavigationSheet(
        sections: sections,
        currentChunkIndex: here,
        onPick: (section) {
          Navigator.pop(sheetContext);
          _scrollToChunk(section.startChunk);
        },
      ),
    );
  }

  Future<void> _scrollToChunk(int index) async {
    if (!_itemScrollController.isAttached) return;
    final chunks = chunksForDocument(_readerDocument);
    final target = index.clamp(0, chunks.length - 1).toInt();
    await _itemScrollController.scrollTo(
      index: target,
      alignment: 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_stored == null) {
      return Scaffold(body: Center(child: Text(context.l10n.documentNotFound)));
    }
    if (_readingMode) return _readerOnly(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: _title(context),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 620)
            ValueListenableBuilder<bool>(
              valueListenable: _dirty,
              builder: (context, dirty, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: dirty
                    ? const Padding(
                        key: ValueKey('saving'),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Padding(
                        key: const ValueKey('saved'),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.cloud_done_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          if (MediaQuery.sizeOf(context).width < 620)
            PopupMenuButton<String>(
              tooltip: context.l10n.adjustments,
              onSelected: (value) {
                if (value == 'reader-settings') _openReaderSettings();
                if (value == 'export') _export();
                if (value == 'chapter-separator') _toggleChapterSeparator();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reader-settings',
                  child: ListTile(
                    leading: const Icon(Icons.text_fields_rounded),
                    title: Text(context.l10n.readingSettings),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_sectionable)
                  PopupMenuItem(
                    value: 'chapter-separator',
                    child: ListTile(
                      leading: Icon(
                        widget.controller.settings.sectionedEditing
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                      ),
                      title: Text(context.l10n.chapterSeparatorToggle),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: Text(context.l10n.exportLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              tooltip: context.l10n.readingSettings,
              onPressed: _openReaderSettings,
              icon: const Icon(Icons.text_fields_rounded),
            ),
            if (_sectionable)
              IconButton(
                tooltip: context.l10n.chapterSeparatorToggle,
                onPressed: _toggleChapterSeparator,
                icon: Icon(
                  widget.controller.settings.sectionedEditing
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                ),
              ),
            IconButton(
              tooltip: context.l10n.exportLabel,
              onPressed: _export,
              icon: const Icon(Icons.download_rounded),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: MediaQuery.sizeOf(context).width < 620
                ? IconButton.filledTonal(
                    tooltip: context.l10n.readingMode,
                    onPressed: _enterReadingMode,
                    icon: const Icon(Icons.menu_book_rounded),
                  )
                : FilledButton.tonalIcon(
                    onPressed: _enterReadingMode,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(context.l10n.readingMode),
                  ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          _previewVisible = wide || _showPreview;
          return Column(
            children: [
              if (!wide && !_showPreview || wide)
                _editorToolbar(
                  context,
                  includeMarkdownTools: _stored!.isMarkdown,
                ),
              if (_sectioned) _sectionBar(context),
              if (!wide) _mobileTabs(context),
              Expanded(
                child: wide
                    ? _wideEditor(context)
                    : _showPreview
                    ? _preview(context)
                    : _editor(context),
              ),
              _statusBar(context),
            ],
          );
        },
      ),
    );
  }

  /// Bar shown while a long document is being edited a section at a time.
  Widget _sectionBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final section = _editSections[_editSectionIndex];
    final label = section.title == '…'
        ? context.l10n.editSectionPart('1')
        : RegExp(r'^\d+$').hasMatch(section.title)
        ? context.l10n.editSectionPart(section.title)
        : section.title;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Tooltip(
            message: context.l10n.editSectionHint,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 6),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Text(
            context.l10n.editSectionPosition(
              _editSectionIndex + 1,
              _editSections.length,
            ),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          IconButton(
            tooltip: context.l10n.editSectionPrevious,
            visualDensity: VisualDensity.compact,
            onPressed: _editSectionIndex > 0
                ? () => _openSection(_editSectionIndex - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: context.l10n.editSectionNext,
            visualDensity: VisualDensity.compact,
            onPressed: _editSectionIndex < _editSections.length - 1
                ? () => _openSection(_editSectionIndex + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          PopupMenuButton<int>(
            tooltip: context.l10n.editSectionChoose,
            onSelected: (value) =>
                value == -1 ? _toggleChapterSeparator() : _openSection(value),
            itemBuilder: (context) => [
              for (var i = 0; i < _editSections.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Text(
                    _editSections[i].title == '…'
                        ? context.l10n.editSectionPart('1')
                        : RegExp(r'^\d+$').hasMatch(_editSections[i].title)
                        ? context.l10n.editSectionPart(_editSections[i].title)
                        : _editSections[i].title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: -1,
                child: Text(context.l10n.editWholeDocument),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    if (!_editingTitle) {
      return InkWell(
        onTap: () {
          setState(() => _editingTitle = true);
          _titleFocus.requestFocus();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Tooltip(
            message: context.l10n.rename,
            child: Text(
              _titleController.text.trim().isEmpty
                  ? context.l10n.untitled
                  : _titleController.text,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return TextField(
      controller: _titleController,
      focusNode: _titleFocus,
      style: style,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => setState(() => _editingTitle = false),
      decoration: const InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _wideEditor(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Text(
                context.l10n.editorLabel,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(letterSpacing: 1.2),
              ),
            ),
            Expanded(child: _editor(context)),
          ],
        ),
      ),
      VerticalDivider(width: 1),
      Expanded(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Text(
                context.l10n.readingLabel,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(letterSpacing: 1.2),
              ),
            ),
            Expanded(child: _preview(context)),
          ],
        ),
      ),
    ],
  );

  Widget _editor(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: TextField(
      controller: _contentController,
      undoController: _undoController,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 15.5,
        height: 1.65,
      ),
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.all(24),
        hintText: context.l10n.startWriting,
      ),
    ),
  );

  // Renders from the debounced text so a live preview does not re-parse the
  // whole markdown document on every keystroke.
  Widget _preview(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: _previewContent,
    builder: (context, content, _) => DocumentView(
      document: _stored!.copyWith(content: content),
      settings: widget.controller.settings,
    ),
  );

  Widget _mobileTabs(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: false,
          label: Text(context.l10n.edit),
          icon: const Icon(Icons.edit_outlined),
        ),
        ButtonSegment(
          value: true,
          label: Text(context.l10n.preview),
          icon: const Icon(Icons.visibility_outlined),
        ),
      ],
      selected: {_showPreview},
      onSelectionChanged: (value) {
        FocusScope.of(context).unfocus();
        final showPreview = value.first;
        if (showPreview) _previewContent.value = _contentController.text;
        setState(() => _showPreview = showPreview);
      },
    ),
  );

  // Listens to the undo controller directly instead of calling setState on
  // every text change: only the two undo/redo buttons depend on it.
  Widget _editorToolbar(
    BuildContext context, {
    required bool includeMarkdownTools,
  }) => ValueListenableBuilder<UndoHistoryValue>(
    valueListenable: _undoController,
    builder: (context, history, _) =>
        _editorToolbarBody(context, history, includeMarkdownTools),
  );

  Widget _editorToolbarBody(
    BuildContext context,
    UndoHistoryValue history,
    bool includeMarkdownTools,
  ) {
    final actions = <({String label, IconData icon, VoidCallback? onTap})>[
      (
        label: context.l10n.undoSession,
        icon: Icons.undo_rounded,
        onTap: history.canUndo ? _undoController.undo : null,
      ),
      (
        label: context.l10n.redoSession,
        icon: Icons.redo_rounded,
        onTap: history.canRedo ? _undoController.redo : null,
      ),
      if (includeMarkdownTools) ...[
        (
          label: context.l10n.heading,
          icon: Icons.title_rounded,
          onTap: () => _linePrefix('## '),
        ),
        (
          label: context.l10n.bold,
          icon: Icons.format_bold_rounded,
          onTap: () => _wrap('**', '**', context.l10n.textPlaceholder),
        ),
        (
          label: context.l10n.italic,
          icon: Icons.format_italic_rounded,
          onTap: () => _wrap('_', '_', context.l10n.textPlaceholder),
        ),
        (
          label: context.l10n.quote,
          icon: Icons.format_quote_rounded,
          onTap: () => _linePrefix('> '),
        ),
        (
          label: context.l10n.list,
          icon: Icons.format_list_bulleted_rounded,
          onTap: () => _linePrefix('- '),
        ),
        (
          label: context.l10n.code,
          icon: Icons.code_rounded,
          onTap: () => _wrap('`', '`', context.l10n.codePlaceholder),
        ),
        (
          label: context.l10n.link,
          icon: Icons.link_rounded,
          onTap: () => _wrap('[', '](https://)', context.l10n.textPlaceholder),
        ),
        (
          label: context.l10n.horizontalRule,
          icon: Icons.horizontal_rule_rounded,
          onTap: () => _insertBlock('---'),
        ),
      ],
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          scrollDirection: Axis.horizontal,
          itemCount: actions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) => IconButton.outlined(
            tooltip: actions[index].label,
            onPressed: actions[index].onTap,
            icon: Icon(actions[index].icon, size: 19),
          ),
        ),
      ),
    );
  }

  Widget _statusBar(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: ValueListenableBuilder<({int words, int minutes})>(
      valueListenable: _stats,
      builder: (context, stats, _) => Row(
        children: [
          if (MediaQuery.sizeOf(context).width < 620)
            Expanded(
              child: Text(
                '${context.l10n.wordCount(stats.words)} · '
                '${context.l10n.readingMinutes(stats.minutes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            )
          else ...[
            Text(
              context.l10n.wordCount(stats.words),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 16),
            Text(
              context.l10n.readingMinutes(stats.minutes),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const Spacer(),
          ],
          const SizedBox(width: 12),
          Text(
            '.${_stored?.extension ?? 'md'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );

  Widget _readerOnly(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final safeTop = MediaQuery.paddingOf(context).top;
        final settings = widget.controller.settings;
        return Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onReaderScroll,
                child: DocumentView(
                  document: _readerDocument,
                  asSource: _showMarkupSource,
                  settings: settings,
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  padding: EdgeInsets.fromLTRB(
                    compact ? 20 : 28,
                    safeTop + (compact ? 54 : 72),
                    compact ? 20 : 28,
                    compact ? 48 : 64,
                  ),
                ),
              ),
            ),
            if (widget.controller
                .bookmarksForDocument(widget.documentId)
                .isNotEmpty)
              Positioned.fill(
                child: ValueListenableBuilder<Iterable<ItemPosition>>(
                  valueListenable: _itemPositionsListener.itemPositions,
                  builder: (context, positions, _) {
                    // itemLeadingEdge is already a fraction of the viewport
                    // (0 = aligned with its top edge), reported from the
                    // list's real, currently-realized layout — not an
                    // extrapolated maxScrollExtent — so this position is
                    // exact for every visible chunk, and simply absent for
                    // chunks that are not currently on screen.
                    final byIndex = {
                      for (final position in positions) position.index: position,
                    };
                    final viewportHeight = constraints.maxHeight;
                    return Stack(
                      children: [
                        for (final bookmark in widget.controller
                            .bookmarksForDocument(widget.documentId))
                          if (byIndex[bookmark.chunkIndex] case final position?)
                            _bookmarkMarker(
                              context,
                              bookmark,
                              position,
                              compact,
                              viewportHeight,
                            ),
                      ],
                    );
                  },
                ),
              ),
            // Only this subtree listens to the chrome's visibility, so
            // showing and hiding the controls no longer rebuilds the
            // document underneath them.
            ValueListenableBuilder<bool>(
              valueListenable: _readerControls,
              builder: (context, visible, controls) => Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: safeTop + 52,
                    child: IgnorePointer(
                      ignoring: visible,
                      child: GestureDetector(
                        key: const ValueKey('reader-controls-reveal-area'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _showReaderControls,
                      ),
                    ),
                  ),
                  Positioned(
                    top: safeTop + (compact ? 7 : 12),
                    left: compact ? 10 : 16,
                    right: compact ? 10 : 16,
                    child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                offset: visible ? Offset.zero : const Offset(0, -.7),
                child: AnimatedOpacity(
                  key: const ValueKey('reader-controls'),
                  duration: const Duration(milliseconds: 160),
                  opacity: visible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: Row(
                      children: [
                        _readerButton(
                          context,
                          compact: compact,
                          tooltip: context.l10n.backToLibrary,
                          icon: Icons.arrow_back_rounded,
                          onPressed: _close,
                        ),
                        const Spacer(),
                        if (documentKindOf(_stored!.extension) ==
                            DocumentKind.markup) ...[
                          _readerButton(
                            context,
                            compact: compact,
                            tooltip: _showMarkupSource
                                ? context.l10n.viewerPreview
                                : context.l10n.viewerSource,
                            icon: _showMarkupSource
                                ? Icons.article_rounded
                                : Icons.code_rounded,
                            onPressed: () => setState(
                              () => _showMarkupSource = !_showMarkupSource,
                            ),
                          ),
                          SizedBox(width: compact ? 5 : 8),
                        ],
                        if (widget.controller.settings.ttsEnabled) ...[
                          _readerButton(
                            context,
                            compact: compact,
                            tooltip: context.l10n.ttsListen,
                            icon: Icons.headphones_rounded,
                            onPressed: _openListenSheet,
                          ),
                          SizedBox(width: compact ? 5 : 8),
                        ],
                        _readerButton(
                          context,
                          compact: compact,
                          tooltip: context.l10n.chapterNavigation,
                          icon: Icons.table_rows_rounded,
                          onPressed: _openChapterNavigation,
                        ),
                        SizedBox(width: compact ? 5 : 8),
                        _readerButton(
                          context,
                          compact: compact,
                          tooltip: context.l10n.addBookmark,
                          icon: Icons.bookmark_add_rounded,
                          onPressed: _addBookmarkHere,
                        ),
                        SizedBox(width: compact ? 5 : 8),
                        _readerButton(
                          context,
                          compact: compact,
                          tooltip: context.l10n.bookmarks,
                          icon: Icons.bookmark_rounded,
                          onPressed: _openBookmarksSheet,
                        ),
                        SizedBox(width: compact ? 5 : 8),
                        _readerButton(
                          context,
                          compact: compact,
                          tooltip: context.l10n.adjustments,
                          icon: Icons.text_fields_rounded,
                          onPressed: _openReaderSettings,
                        ),
                        SizedBox(width: compact ? 5 : 8),
                        _readerButton(
                          context,
                          compact: compact,
                          tooltip: context.l10n.exitReadingMode,
                          icon: Icons.edit_rounded,
                          onPressed: _exitReadingMode,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                  ),
                ],
              ),
            ),
            // The player bar listens to the speech controller directly, so
            // moving from one sentence to the next redraws the bar and
            // nothing else.
            if (_tts case final speech?)
              ListenableBuilder(
                listenable: speech,
                builder: (context, _) => speech.isActive
                    ? Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _playerBar(context, compact),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        );
      },
    ),
  );

  /// Playback controls, pinned to the bottom while something is being read.
  ///
  /// Deliberately outside the auto-hiding reader chrome: the controls that
  /// hide are the ones you only need between passages, and this is the one
  /// you reach for mid-sentence.
  Widget _playerBar(BuildContext context, bool compact) {
    final controller = _tts!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: controller.progress,
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 4, compact ? 4 : 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.sectionTitle ??
                              context.l10n.ttsWholeDocument,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          context.l10n.ttsProgress(
                            controller.pieceIndex + 1,
                            controller.pieceCount,
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.ttsPrevious,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.skip(-1),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton.filled(
                    tooltip: controller.isPlaying
                        ? context.l10n.ttsPause
                        : context.l10n.ttsResume,
                    onPressed: controller.isPlaying
                        ? controller.pause
                        : controller.resume,
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.ttsNext,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.skip(1),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  IconButton(
                    tooltip: context.l10n.ttsStop,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.stop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readerButton(
    BuildContext context, {
    required bool compact,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.black.withValues(alpha: .32),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        color: Colors.white,
        constraints: BoxConstraints.tightFor(
          width: compact ? 36 : 48,
          height: compact ? 36 : 48,
        ),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          fixedSize: Size.square(compact ? 36 : 48),
        ),
        iconSize: compact ? 18 : 24,
        icon: Icon(icon),
      ),
    ),
  );

  Widget _bookmarkMarker(
    BuildContext context,
    ReadingBookmark bookmark,
    ItemPosition position,
    bool compact,
    double viewportHeight,
  ) {
    final top = position.itemLeadingEdge * viewportHeight;
    final isOpen = _activeBookmarkPopupId == bookmark.id;
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      right: compact ? 6 : 10,
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(
                () => _activeBookmarkPopupId = isOpen ? null : bookmark.id,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.bookmark_rounded,
                  size: 14,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          if (isOpen)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 220,
                maxHeight: 120,
              ),
              child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      bookmark.excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.removeBookmark,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      widget.controller.removeBookmark(bookmark.id);
                      setState(() => _activeBookmarkPopupId = null);
                    },
                  ),
                ],
              ),
            ),
            ),
        ],
      ),
    );
  }

  bool _onReaderScroll(ScrollNotification notification) {
    if (!widget.controller.settings.autoHideReaderControls) return false;
    if (notification is ScrollStartNotification) {
      _readerControlsTimer?.cancel();
    } else if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _scheduleReaderControlsHide(delay: const Duration(milliseconds: 650));
    }
    return false;
  }

  void _showReaderControls() {
    if (!_readerControls.value) {
      _readerControls.value = true;
    }
    _scheduleReaderControlsHide();
  }

  void _scheduleReaderControlsHide({
    Duration delay = const Duration(seconds: 3),
  }) {
    _readerControlsTimer?.cancel();
    if (!widget.controller.settings.autoHideReaderControls) return;
    _readerControlsTimer = Timer(delay, () {
      if (mounted && _readingMode && _readerControls.value) {
        _readerControls.value = false;
      }
    });
  }

  void _exitReadingMode() {
    _readerControlsTimer?.cancel();
    // Leaving the reader hands the speech backend back: nothing should be
    // speaking over the editor, and nothing should stay loaded for a
    // document the user is no longer reading.
    unawaited(_tts?.release());
    _readerSourceSnapshot = null;
    _readerControls.value = true;
    setState(() => _readingMode = false);
  }

  void _wrap(String before, String after, String placeholder) {
    final selection = _contentController.selection;
    final valid = selection.isValid;
    final start = valid ? selection.start : _contentController.text.length;
    final end = valid ? selection.end : start;
    final selected = start == end
        ? placeholder
        : _contentController.text.substring(start, end);
    final replacement = '$before$selected$after';
    _contentController.value = _contentController.value.copyWith(
      text: _contentController.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + before.length,
        extentOffset: start + before.length + selected.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _linePrefix(String prefix) {
    final selection = _contentController.selection;
    final cursor = selection.isValid
        ? selection.start
        : _contentController.text.length;
    final lineStart =
        _contentController.text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0) +
        1;
    _contentController.value = _contentController.value.copyWith(
      text: _contentController.text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
      composing: TextRange.empty,
    );
  }

  void _insertBlock(String block) {
    final selection = _contentController.selection;
    final start = selection.isValid
        ? selection.start
        : _contentController.text.length;
    final end = selection.isValid ? selection.end : start;
    final insertion = insertMarkdownBlock(
      _contentController.text,
      start: start,
      end: end,
      block: block,
    );
    _contentController.value = _contentController.value.copyWith(
      text: insertion.text,
      selection: TextSelection.collapsed(offset: insertion.cursor),
      composing: TextRange.empty,
    );
  }

  Future<void> _close() async {
    unawaited(_tts?.release());
    if (_dirty.value) await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _export() async {
    if (_dirty.value) await _save();
    try {
      final outcome = await exportDocument(_draft);
      if (mounted && outcome == ExportOutcome.saved) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.exported)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  /// Saves first, like [_openSection] and [_editWholeDocument] do — the
  /// content this reconfigures around comes from [_stored], and a toggle
  /// that skipped the save would rebuild the field from whatever was on
  /// disk before this keystroke, dropping it.
  Future<void> _toggleChapterSeparator() async {
    if (_dirty.value) await _save();
    final newValue = !widget.controller.settings.sectionedEditing;
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(sectionedEditing: newValue),
    );
    if (!mounted) return;
    if (newValue && !_sectioned) {
      final content = _stored?.content ?? _fullContent;
      setState(() {
        _configureSections(content, index: 0);
        final text = _sectionText(content);
        _programmaticTextChange = true;
        try {
          _contentController.value = TextEditingValue(
            text: text,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } finally {
          _programmaticTextChange = false;
        }
        _previewContent.value = text;
      });
    } else if (!newValue && _sectioned) {
      await _editWholeDocument();
    } else {
      // The setting flipped but the field was already in the shape it
      // implies (e.g. the document is too short to section) — nothing to
      // reconfigure, but the toggle icon still needs to repaint.
      setState(() {});
    }
  }

  void _openReaderSettings() => showAppSheet<void>(
    context: context,
    enableDrag: false,
    builder: (_) => ReaderSettingsSheet(controller: widget.controller),
  );
}
