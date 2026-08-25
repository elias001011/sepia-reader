import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../l10n/l10n.dart';
import '../models/bookmark.dart';
import '../models/library_document.dart';
import '../services/document_io.dart';
import '../state/app_controller.dart';
import '../widgets/markdown_view.dart';
import 'bookmarks_sheet.dart';
import 'reader_settings_sheet.dart';

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

class _EditorScreenState extends State<EditorScreen> {
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

  Timer? _saveTimer;
  Timer? _statsTimer;
  Timer? _previewTimer;
  Timer? _readerControlsTimer;
  bool _readingMode = false;
  bool _readerControlsVisible = true;
  bool _showPreview = false;
  String? _activeBookmarkPopupId;

  LibraryDocument? get _stored =>
      widget.controller.documentById(widget.documentId);

  @override
  void initState() {
    super.initState();
    final document = _stored!;
    _contentController = TextEditingController(text: document.content)
      ..addListener(_onChanged);
    _titleController = TextEditingController(text: document.title)
      ..addListener(_onChanged);
    _previewContent = ValueNotifier(document.content);
    _stats.value = _statsFor(document.content);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _statsTimer?.cancel();
    _previewTimer?.cancel();
    _readerControlsTimer?.cancel();
    if (_dirty.value) unawaited(_save());
    widget.controller.removeListener(_refresh);
    _undoController.dispose();
    _dirty.dispose();
    _stats.dispose();
    _previewContent.dispose();
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  ({int words, int minutes}) _statsFor(String content) {
    final trimmed = content.trim();
    final words = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    return (words: words, minutes: words == 0 ? 0 : (words / 220).ceil());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    // No setState here: rebuilding the whole editor on every keystroke made
    // large documents crawl (a full document copy, two regex passes over the
    // entire text for the counters, and a live markdown re-render).
    _dirty.value = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _save);
    _statsTimer?.cancel();
    _statsTimer = Timer(const Duration(milliseconds: 400), () {
      _stats.value = _statsFor(_contentController.text);
    });
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 400), () {
      _previewContent.value = _contentController.text;
    });
  }

  LibraryDocument get _draft {
    final document = _stored!;
    return document.copyWith(
      title: _titleController.text.trim().isEmpty
          ? context.l10n.untitled
          : _titleController.text.trim(),
      content: _contentController.text,
    );
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    await widget.controller.updateDocument(_draft);
    _dirty.value = false;
  }

  void _enterReadingMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _readingMode = true;
      _readerControlsVisible = true;
    });
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
    final chunks = chunksForDocument(_stored!);
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
    final chunks = chunksForDocument(_stored!);
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
        title: TextField(
          controller: _titleController,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
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
          return Column(
            children: [
              if (!wide && !_showPreview || wide)
                _editorToolbar(
                  context,
                  includeMarkdownTools: _stored!.isMarkdown,
                ),
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
        setState(() => _showPreview = value.first);
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
          onTap: () => _insert('\n---\n'),
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
                  document: _draft,
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: safeTop + 52,
              child: IgnorePointer(
                ignoring: _readerControlsVisible,
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
                offset: _readerControlsVisible
                    ? Offset.zero
                    : const Offset(0, -.7),
                child: AnimatedOpacity(
                  key: const ValueKey('reader-controls'),
                  duration: const Duration(milliseconds: 160),
                  opacity: _readerControlsVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_readerControlsVisible,
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
        );
      },
    ),
  );

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
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxWidth: 220),
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
    if (!_readerControlsVisible) {
      setState(() => _readerControlsVisible = true);
    }
    _scheduleReaderControlsHide();
  }

  void _scheduleReaderControlsHide({
    Duration delay = const Duration(seconds: 3),
  }) {
    _readerControlsTimer?.cancel();
    if (!widget.controller.settings.autoHideReaderControls) return;
    _readerControlsTimer = Timer(delay, () {
      if (mounted && _readingMode && _readerControlsVisible) {
        setState(() => _readerControlsVisible = false);
      }
    });
  }

  void _exitReadingMode() {
    _readerControlsTimer?.cancel();
    setState(() {
      _readingMode = false;
      _readerControlsVisible = true;
    });
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

  void _insert(String text) {
    final selection = _contentController.selection;
    final start = selection.isValid
        ? selection.start
        : _contentController.text.length;
    final end = selection.isValid ? selection.end : start;
    _contentController.value = _contentController.value.copyWith(
      text: _contentController.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _close() async {
    if (_dirty.value) await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _export() async {
    if (_dirty.value) await _save();
    try {
      await exportDocument(_draft);
      if (mounted) {
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

  void _openReaderSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReaderSettingsSheet(controller: widget.controller),
  );
}
