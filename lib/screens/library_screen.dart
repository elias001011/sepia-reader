import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/l10n.dart';
import '../models/document_drop.dart';
import '../models/library_document.dart';
import '../models/library_folder.dart';
import '../services/document_drop.dart';
import '../services/document_kind.dart';
import '../services/document_io.dart';
import '../services/folder_importer.dart';
import '../services/update_checker.dart';
import '../state/app_controller.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/voice_download_banner.dart';
import 'editor_screen.dart';
import 'settings_sheet.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _currentFolderId;

  /// Ids picked in multi-select mode. Empty means the screen is in its
  /// normal browsing state; non-empty swaps the top bar for the action bar
  /// and turns a card tap into a select/deselect.
  final Set<String> _selectedDocIds = {};
  final Set<String> _selectedFolderIds = {};
  bool get _selecting =>
      _selectedDocIds.isNotEmpty || _selectedFolderIds.isNotEmpty;

  bool _isImportingFolder = false;
  bool _isImportingFiles = false;
  bool _isDraggingFiles = false;
  late final DocumentDropBinding _documentDropBinding;

  /// Measured height of the pinned floating header, so the scroll view can
  /// leave exactly that much room above its content. Updated whenever the
  /// header's contents change (top bar ⇄ selection bar, a notice appearing).
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _documentDropBinding = bindDocumentDrop(
      onDragActive: _setFileDragActive,
      onDrop: _importDroppedFiles,
    );
    unawaited(_checkForUpdate());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _documentDropBinding.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// A newer release, once one has been found. Checked when the library
  /// opens, quietly: a missing connection is not worth interrupting anyone
  /// for, so a failure here leaves the banner simply absent.
  AppUpdate? _update;

  Future<void> _checkForUpdate() async {
    if (!widget.controller.settings.checkForUpdates) return;
    try {
      final update = await widget.controller.updates.check();
      if (mounted && update != null) setState(() => _update = update);
    } catch (error) {
      debugPrint('sepia: update check failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final sourceDocuments = searching
        ? widget.controller.documents
        : widget.controller.documentsIn(_currentFolderId);
    final documents = sourceDocuments.where((document) {
      final haystack =
          '${document.title}.${document.extension} ${document.content}'
              .toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();
    final folders = searching
        ? const <LibraryFolder>[]
        : widget.controller.foldersIn(_currentFolderId);

    // Before _MeasureSize has reported, use a close estimate so the content
    // does not start flush at the top for one frame and then jump down.
    final headerSpace = _headerHeight > 0
        ? _headerHeight
        : MediaQuery.paddingOf(context).top + 72;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            // The floating header handles the top inset itself; SafeArea here
            // keeps the library clear of the gesture bar and any side cutout,
            // the way `body: SafeArea(...)` used to before this was pinned.
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                // The spinner drops in below the floating header, not under it.
                edgeOffset: headerSpace,
                onRefresh: _forceSync,
                child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Reserve the room the pinned header floats in; the library
                  // scrolls under it.
                  SliverToBoxAdapter(
                    child: SizedBox(height: headerSpace + 8),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _hero(context),
                              const SizedBox(height: 22),
                              _breadcrumbs(context),
                              const SizedBox(height: 22),
                              _sectionHeader(
                                context,
                                documentCount: documents.length,
                                folderCount: folders.length,
                              ),
                              const SizedBox(height: 16),
                              if (documents.isEmpty && folders.isEmpty)
                                _emptyState(context)
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns = constraints.maxWidth >= 980
                                        ? 3
                                        : constraints.maxWidth >= 620
                                        ? 2
                                        : 1;
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisExtent: 238,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                      itemCount:
                                          folders.length + documents.length,
                                      itemBuilder: (context, index) {
                                        if (index < folders.length) {
                                          final folder = folders[index];
                                          return _FolderCard(
                                            folder: folder,
                                            documentCount: widget.controller
                                                .folderDocumentCount(folder.id),
                                            childFolderCount: widget.controller
                                                .foldersIn(folder.id)
                                                .length,
                                            selecting: _selecting,
                                            selected: _selectedFolderIds
                                                .contains(folder.id),
                                            onToggleSelect: () =>
                                                _toggleSelectFolder(folder.id),
                                            onOpen: () =>
                                                _enterFolder(folder.id),
                                            onRename: () =>
                                                _renameFolder(folder),
                                            onMove: () => _moveFolder(folder),
                                            onDelete: () =>
                                                _deleteFolder(folder),
                                          );
                                        }
                                        final document =
                                            documents[index - folders.length];
                                        return _DocumentCard(
                                          document: document,
                                          folderPath: searching
                                              ? widget.controller
                                                    .folderPath(
                                                      document.folderId,
                                                    )
                                                    .map(
                                                      (folder) => folder.name,
                                                    )
                                                    .join(' / ')
                                              : null,
                                          selecting: _selecting,
                                          selected: _selectedDocIds
                                              .contains(document.id),
                                          onToggleSelect: () =>
                                              _toggleSelectDoc(document.id),
                                          onOpen: () => _open(document),
                                          onFavorite: () => widget.controller
                                              .toggleFavorite(document.id),
                                          onRename: () =>
                                              _renameDocument(document),
                                          onMove: () => _moveDocument(document),
                                          onExport: () => _export(document),
                                          onDelete: () =>
                                              _confirmDelete(document),
                                        );
                                      },
                                    );
                                  },
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
            ),
          ),
          // Pinned above the library, floating over it. The bar you act on
          // stays put and the content slides under it; only the cards below
          // scroll away. `_MeasureSize` feeds the real height back so the
          // spacer sliver above matches whatever is showing right now
          // (top bar vs selection bar, with or without a notice).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MeasureSize(
              onChange: (size) {
                // Fires from a post-frame callback: the State may already be
                // gone (hot reload, the home widget being swapped out).
                if (!mounted) return;
                if ((size.height - _headerHeight).abs() > 0.5) {
                  setState(() => _headerHeight = size.height);
                }
              },
              child: _floatingHeader(context),
            ),
          ),
          if (_isDraggingFiles) _dropOverlay(context),
        ],
      ),
      floatingActionButton:
          MediaQuery.sizeOf(context).width < 620 && !_selecting
          ? FloatingActionButton.extended(
              onPressed: _showLibraryActions,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.newLabel),
            )
          : null,
    );
  }

  void _setFileDragActive(bool active) {
    if (!mounted || !supportsDocumentDrop) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      if (_isDraggingFiles) setState(() => _isDraggingFiles = false);
      return;
    }
    if (_isDraggingFiles != active) {
      setState(() => _isDraggingFiles = active);
    }
  }

  Widget _dropOverlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .94),
            border: Border.all(color: scheme.primary, width: 3),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .2),
                blurRadius: 28,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 58,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.dropFilesHere,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.dropFilesHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Everything pinned at the top: the bar (browsing or multi-select), and
  /// any notices under it. Genuinely transparent — only a short fade sits
  /// behind the status bar to keep the clock legible; everywhere else the
  /// library is visible sliding under the floating bars.
  Widget _floatingHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Solid behind the status bar and the bar row so the library does
          // not smear across the clock as it scrolls up; then a short fade,
          // and below that the notices float over the content for real.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 76,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface,
                    scheme.surface,
                    scheme.surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.82, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _selecting ? _selectionBar(context) : _topBar(context),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: VoiceDownloadBanner(
                  downloads: widget.controller.voiceDownloads,
                ),
              ),
            ),
            if (_update case final update?)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: UpdateCard(
                      update: update,
                      onDismiss: () => setState(() => _update = null),
                    ),
                  ),
                ),
              ),
            if (_isImportingFolder || _isImportingFiles)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A card that floats clear of the screen edges and the status bar, not a
    // full-bleed strip fused to the system bar above it. The library content
    // below is what stays edge to edge.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .55),
              ),
            ),
            child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/sepia_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sépia',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                // Labelled "Aparência" with a tune icon, this was the only
                // door to theme, language, syncing and reading aloud — and
                // it read as a door to none of them but the first.
                tooltip: context.l10n.appearance,
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_rounded),
              ),
              if (MediaQuery.sizeOf(context).width >= 620) ...[
                const SizedBox(width: 8),
                MenuAnchor(
                  builder: (context, menu, _) => OutlinedButton.icon(
                    onPressed: menu.open,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(context.l10n.importLabel),
                  ),
                  menuChildren: [
                    MenuItemButton(
                      onPressed: _importFiles,
                      leadingIcon: const Icon(Icons.description_outlined),
                      child: Text(context.l10n.importFiles),
                    ),
                    MenuItemButton(
                      onPressed: _importFolder,
                      leadingIcon: const Icon(
                        Icons.drive_folder_upload_outlined,
                      ),
                      child: Text(context.l10n.importFolder),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                MenuAnchor(
                  builder: (context, menu, _) => FilledButton.icon(
                    onPressed: menu.open,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.newLabel),
                  ),
                  menuChildren: [
                    MenuItemButton(
                      onPressed: _createDocument,
                      leadingIcon: const Icon(Icons.note_add_outlined),
                      child: Text(context.l10n.newDocument),
                    ),
                    MenuItemButton(
                      onPressed: _createFolder,
                      leadingIcon: const Icon(Icons.create_new_folder_outlined),
                      child: Text(context.l10n.newFolder),
                    ),
                  ],
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAmoled =
        widget.controller.settings.amoledTheme &&
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isAmoled
            ? Colors.black
            : scheme.primaryContainer.withValues(alpha: .55),
        border: isAmoled ? Border.all(color: scheme.outlineVariant) : null,
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.libraryHero,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.05),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.libraryHeroDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
          final search = TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: context.l10n.searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 24),
                search,
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLibraryActions(importOnly: true),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(context.l10n.importLabel),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: intro),
              const SizedBox(width: 32),
              Expanded(child: search),
            ],
          );
        },
      ),
    );
  }

  Widget _breadcrumbs(BuildContext context) {
    final path = widget.controller.folderPath(_currentFolderId);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.home_rounded, size: 18),
            label: Text(context.l10n.root),
            onPressed: () => _enterFolder(null),
          ),
          for (final folder in path) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right_rounded, size: 20),
            ),
            ActionChip(
              avatar: const Icon(Icons.folder_rounded, size: 18),
              label: Text(folder.name),
              onPressed: () => _enterFolder(folder.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required int documentCount,
    required int folderCount,
  }) => Wrap(
    spacing: 10,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        _query.isEmpty ? context.l10n.libraryTitle : context.l10n.results,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      Chip(label: Text(context.l10n.fileCount(documentCount))),
      if (_query.isEmpty)
        Chip(label: Text(context.l10n.folderCount(folderCount))),
    ],
  );

  void _enterFolder(String? folderId) {
    _searchController.clear();
    setState(() {
      _currentFolderId = folderId;
      _query = '';
      _selectedDocIds.clear();
      _selectedFolderIds.clear();
    });
  }

  void _clearSelection() => setState(() {
    _selectedDocIds.clear();
    _selectedFolderIds.clear();
  });

  void _toggleSelectDoc(String id) => setState(() {
    _selectedDocIds.contains(id)
        ? _selectedDocIds.remove(id)
        : _selectedDocIds.add(id);
  });

  void _toggleSelectFolder(String id) => setState(() {
    _selectedFolderIds.contains(id)
        ? _selectedFolderIds.remove(id)
        : _selectedFolderIds.add(id);
  });

  /// Contextual bar shown in place of [_topBar] while items are selected:
  /// count on the left, the actions that apply to a mixed selection on the
  /// right.
  Widget _selectionBar(BuildContext context) {
    final count = _selectedDocIds.length + _selectedFolderIds.length;
    // Only needs to know whether *anything* would be exported. A picked
    // document answers it outright; otherwise ask each picked folder in turn
    // and stop at the first that holds something — cheaper than expanding the
    // whole selection into a document list on every selection toggle.
    final hasDocuments = _selectedDocIds.isNotEmpty ||
        _selectedFolderIds.any(
          (id) => widget.controller.folderDocumentCount(id) > 0,
        );
    final scheme = Theme.of(context).colorScheme;
    // Same floating treatment as [_topBar]: an action bar laid over the
    // library, not welded to the status bar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.primary.withValues(alpha: .45)),
            ),
            child: Row(
            children: [
              IconButton(
                tooltip: context.l10n.clearSelection,
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  context.l10n.selectionCount(count),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: context.l10n.moveTo,
                onPressed: _moveSelection,
                icon: const Icon(Icons.drive_file_move_outline),
              ),
              if (hasDocuments)
                IconButton(
                  tooltip: context.l10n.exportLabel,
                  onPressed: _exportSelection,
                  icon: const Icon(Icons.download_rounded),
                ),
              IconButton(
                tooltip: context.l10n.delete,
                onPressed: _deleteSelection,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  /// Asks for a destination folder. Returns a `(folderId: …)` record —
  /// `folderId` null meaning the library root — or null if dismissed.
  /// [blockedFolderIds] are hidden from the list: a folder cannot be moved
  /// into itself or one of its own descendants. [currentFolderId] (with the
  /// sentinel `('root')` for the library root) is marked as where the item
  /// lives now, so moving a single document still shows its current home.
  Future<({String? folderId})?> _pickFolderDestination({
    required Set<String> blockedFolderIds,
    String? title,
    ({String? id})? currentFolderId,
  }) {
    return showDialog<({String? folderId})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title ?? dialogContext.l10n.moveTo),
        content: SizedBox(
          width: appDialogWidth(dialogContext, 440),
          height: 420,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.home_rounded),
                title: Text(dialogContext.l10n.root),
                trailing: currentFolderId != null && currentFolderId.id == null
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () =>
                    Navigator.pop(dialogContext, (folderId: null)),
              ),
              for (final folder in widget.controller.folders)
                if (!blockedFolderIds.contains(folder.id))
                  ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(folder.name),
                    subtitle: Text(
                      widget.controller
                          .folderPath(folder.parentId)
                          .map((item) => item.name)
                          .join(' / '),
                    ),
                    trailing: currentFolderId?.id == folder.id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () =>
                        Navigator.pop(dialogContext, (folderId: folder.id)),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _moveSelection() async {
    final blocked = {
      for (final id in _selectedFolderIds)
        ...widget.controller.folderContents(id).folderIds,
    };
    final target = await _pickFolderDestination(blockedFolderIds: blocked);
    if (target == null || !mounted) return;
    await widget.controller.moveEntries(
      folderIds: _selectedFolderIds.toSet(),
      documentIds: _selectedDocIds.toSet(),
      destinationParentId: target.folderId,
    );
    _clearSelection();
  }

  Future<void> _moveFolder(LibraryFolder folder) async {
    final blocked = widget.controller.folderContents(folder.id).folderIds;
    final target = await _pickFolderDestination(blockedFolderIds: blocked);
    if (target == null || !mounted) return;
    await widget.controller.moveFolder(folder.id, target.folderId);
  }

  Future<void> _deleteSelection() async {
    final documents = widget.controller
        .documentsForSelection(
          folderIds: _selectedFolderIds,
          documentIds: _selectedDocIds,
        )
        .length;
    // Count every folder that will actually be tombstoned — the picked ones
    // and all their descendants — so the confirmation does not say "1 folder"
    // for a delete that takes a whole subtree, the way the single-folder
    // delete already does.
    final removedFolders = {
      for (final id in _selectedFolderIds)
        ...widget.controller.folderContents(id).folderIds,
    };
    final folders = removedFolders.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteSelectionTitle),
        content: Text(
          dialogContext.l10n.deleteSelectionBody(documents, folders),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // If the folder currently open is one of the doomed ones, step up to its
    // parent — the same place the single-folder delete lands — rather than
    // all the way back to the root.
    final fallbackFolderId =
        _currentFolderId != null && removedFolders.contains(_currentFolderId)
        ? widget.controller.folderById(_currentFolderId!)?.parentId
        : _currentFolderId;
    await widget.controller.deleteEntries(
      folderIds: _selectedFolderIds.toSet(),
      documentIds: _selectedDocIds.toSet(),
    );
    if (!mounted) return;
    _clearSelection();
    if (fallbackFolderId != _currentFolderId) {
      setState(() => _currentFolderId = fallbackFolderId);
    }
  }

  Future<void> _exportSelection() async {
    final documents = widget.controller.documentsForSelection(
      folderIds: _selectedFolderIds,
      documentIds: _selectedDocIds,
    );
    var exported = 0;
    var failed = 0;
    for (final document in documents) {
      try {
        if (await exportDocument(document) == ExportOutcome.saved) exported++;
      } catch (error) {
        failed++;
        debugPrint('sepia: export of ${document.title} failed: $error');
      }
    }
    if (!mounted) return;
    _clearSelection();
    // "Nothing to export" is the wrong thing to say when there was plenty to
    // export and every write threw — the export button is only shown when the
    // selection holds documents.
    final message = exported == 0 && failed > 0
        ? context.l10n.exportSelectionFailed
        : context.l10n.exportedCount(exported);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showLibraryActions({bool importOnly = false}) async {
    final action = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => SheetScaffold(
        title: importOnly
            ? sheetContext.l10n.importLabel
            : sheetContext.l10n.newLabel,
        children: [
          if (!importOnly) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.note_add_outlined),
              title: Text(sheetContext.l10n.newDocument),
              onTap: () => Navigator.pop(sheetContext, 'document'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(sheetContext.l10n.newFolder),
              onTap: () => Navigator.pop(sheetContext, 'folder'),
            ),
            const Divider(),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(sheetContext.l10n.importFiles),
            onTap: () => Navigator.pop(sheetContext, 'importFiles'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drive_folder_upload_outlined),
            title: Text(sheetContext.l10n.importFolder),
            subtitle: Text(sheetContext.l10n.compatibleFilesOnly),
            onTap: () => Navigator.pop(sheetContext, 'importFolder'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'document':
        await _createDocument();
      case 'folder':
        await _createFolder();
      case 'importFiles':
        await _importFiles();
      case 'importFolder':
        await _importFolder();
    }
  }

  Future<void> _createFolder() async {
    final name = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.newFolder),
        content: TextField(
          controller: name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.folderName,
            hintText: context.l10n.folderNameHint,
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    final value = name.text;
    name.dispose();
    if (created == true) {
      await widget.controller.createFolder(
        name: value,
        parentId: _currentFolderId,
      );
    }
  }

  Future<void> _renameFolder(LibraryFolder folder) async {
    final name = TextEditingController(text: folder.name);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.renameFolder),
        content: TextField(
          controller: name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: context.l10n.folderName),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.rename),
          ),
        ],
      ),
    );
    final value = name.text;
    name.dispose();
    if (renamed == true) await widget.controller.renameFolder(folder.id, value);
  }

  Future<void> _renameDocument(LibraryDocument document) async {
    var value = document.title;
    final renamed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.renameDocument),
        content: TextFormField(
          initialValue: value,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.fileName,
            suffixText: '.${document.extension}',
          ),
          onChanged: (name) => value = name,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.rename),
          ),
        ],
      ),
    );
    if (renamed == true) {
      await widget.controller.renameDocument(document.id, value);
    }
  }

  /// Pull-to-refresh. Reports the outcome, because a spinner that just
  /// stops looks identical whether the server answered, timed out, or was
  /// never contacted at all.
  Future<void> _forceSync() async {
    final result = await widget.controller.forceSync();
    if (!mounted) return;
    final message = switch (result) {
      SyncRunResult.done => context.l10n.syncPullDone,
      SyncRunResult.failed => context.l10n.syncPullFailed,
      SyncRunResult.disabled => context.l10n.syncPullDisabled,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Deleting a folder used to be refused outright while anything was
  /// inside it, which just made the user empty it by hand first. Warn about
  /// what goes with it, then do the whole thing.
  Future<void> _deleteFolder(LibraryFolder folder) async {
    final contents = widget.controller.folderContents(folder.id);
    final subfolders = contents.folderIds.length - 1;
    final documents = contents.documents.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteFolderTitle(folder.name)),
        content: Text(
          documents == 0 && subfolders == 0
              ? dialogContext.l10n.deleteFolderEmptyBody
              : dialogContext.l10n.deleteFolderBody(documents, subfolders),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.deleteFolder(folder.id);
    if (!mounted) return;
    if (_currentFolderId != null &&
        contents.folderIds.contains(_currentFolderId)) {
      setState(() => _currentFolderId = folder.parentId);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.folderDeleted(folder.name))),
    );
  }

  Future<void> _moveDocument(LibraryDocument document) async {
    final target = await _pickFolderDestination(
      blockedFolderIds: const {},
      title: context.l10n.moveDocument,
      currentFolderId: (id: document.folderId),
    );
    if (target == null) return;
    await widget.controller.moveDocument(document.id, target.folderId);
  }

  Widget _emptyState(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Icon(
          _query.isEmpty
              ? Icons.library_books_outlined
              : Icons.search_off_rounded,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _query.isEmpty ? context.l10n.nextReading : context.l10n.nothingFound,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _query.isEmpty
              ? context.l10n.emptyLibraryHelp
              : context.l10n.emptySearchHelp,
        ),
      ],
    ),
  );

  Future<void> _open(LibraryDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          controller: widget.controller,
          documentId: document.id,
        ),
      ),
    );
  }

  Future<void> _createDocument() async {
    final title = TextEditingController();
    var extension = 'md';
    final created = await showDialog<LibraryDocument>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.newDocument),
          content: SizedBox(
            width: appDialogWidth(context, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.fileName,
                    hintText: context.l10n.fileNameHint,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: extension,
                  decoration: InputDecoration(labelText: context.l10n.format),
                  items: [
                    DropdownMenuItem(
                      value: 'md',
                      child: Text(context.l10n.markdownFormat),
                    ),
                    DropdownMenuItem(
                      value: 'txt',
                      child: Text(context.l10n.plainTextFormat),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => extension = value ?? 'md'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final document = await widget.controller.createDocument(
                  title: title.text,
                  extension: extension,
                  folderId: _currentFolderId,
                );
                if (context.mounted) Navigator.pop(context, document);
              },
              child: Text(context.l10n.create),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (created != null && mounted) await _open(created);
  }

  Future<void> _importFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedDocumentExtensions.toList(),
      );
      final selected = <DroppedDocumentFile>[];
      var skipped = 0;
      for (final file in files) {
        if (await file.length() > maxImportedFileBytes ||
            !isSupportedDocumentPath(file.name)) {
          skipped++;
          continue;
        }
        selected.add(
          DroppedDocumentFile(name: file.name, bytes: await file.readAsBytes()),
        );
      }
      if (mounted && files.isNotEmpty) {
        final imported = await _importDocumentFiles(selected);
        if (mounted) _showImportResult(imported, skipped);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
      }
    }
  }

  Future<void> _importDroppedFiles(DocumentDropSelection selection) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (selection.files.isEmpty && selection.skippedFiles == 0) return;
    setState(() {
      _isDraggingFiles = false;
      _isImportingFiles = true;
    });
    try {
      final imported = await _importDocumentFiles(selection.files);
      if (mounted) _showImportResult(imported, selection.skippedFiles);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingFiles = false);
    }
  }

  /// Number of files the last import turned away because their bytes were
  /// not text, kept so the result message can say so specifically.
  int _lastBinaryRejections = 0;

  Future<int> _importDocumentFiles(List<DroppedDocumentFile> files) async {
    var imported = 0;
    _lastBinaryRejections = 0;
    for (final file in files) {
      // The extension allowlist is not enough on its own: a picker filter is
      // only a hint the user can override, Android content URIs do not
      // always carry a usable name, and renaming a .docx to .txt walks
      // straight past it. One of those landing in the library used to
      // produce a document full of replacement characters that also broke
      // the reader.
      if (isBinaryPayload(file.bytes)) {
        _lastBinaryRejections++;
        continue;
      }
      final parts = file.name.split('.');
      final extension = parts.length > 1
          ? parts.removeLast().toLowerCase()
          : 'txt';
      final title = parts.isEmpty ? file.name : parts.join('.');
      await widget.controller.createDocument(
        title: title,
        extension: extension,
        content: utf8.decode(file.bytes, allowMalformed: true),
        folderId: _currentFolderId,
      );
      imported++;
    }
    return imported;
  }

  void _showImportResult(int imported, int skipped) {
    final binary = _lastBinaryRejections;
    skipped += binary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imported == 0 && binary > 0
              ? context.l10n.unsupportedBinaryFiles(binary)
              : imported == 0
              ? context.l10n.noCompatibleFiles
              : skipped == 0
              ? context.l10n.importedCount(imported)
              : context.l10n.filesImported(imported, skipped),
        ),
      ),
    );
  }

  Future<void> _importFolder() async {
    if (_isImportingFolder) return;
    setState(() => _isImportingFolder = true);
    try {
      final selection = await pickDocumentFolder();
      if (selection == null || !mounted) return;
      final result = await widget.controller.importFolder(
        selection,
        parentId: _currentFolderId,
      );
      if (!mounted) return;
      final skipped = selection.skippedFiles + result.rejected;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.imported == 0
                ? context.l10n.noCompatibleFiles
                : context.l10n.folderImported(result.imported, skipped),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingFolder = false);
    }
  }

  Future<void> _export(LibraryDocument document) async {
    try {
      final outcome = await exportDocument(document);
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

  Future<void> _confirmDelete(LibraryDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteFileQuestion),
        content: Text(
          context.l10n.deleteFileDescription(
            '${document.title}.${document.extension}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.deleteDocument(document.id);
  }

  void _openSettings() => showAppSheet<void>(
    context: context,
    enableDrag: false,
    builder: (_) => SettingsSheet(controller: widget.controller),
  );
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.documentCount,
    required this.childFolderCount,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
    required this.onOpen,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  final LibraryFolder folder;
  final int documentCount;
  final int childFolderCount;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
    clipBehavior: Clip.antiAlias,
    color: selected ? scheme.secondaryContainer : null,
    shape: selected
        ? RoundedRectangleBorder(
            side: BorderSide(color: scheme.primary, width: 2),
            borderRadius: BorderRadius.circular(12),
          )
        : null,
    child: InkWell(
      onTap: selecting ? onToggleSelect : onOpen,
      onLongPress: onToggleSelect,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.folder_rounded,
                    size: 30,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                if (!selecting)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'move') onMove();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined),
                            const SizedBox(width: 12),
                            Text(context.l10n.rename),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            const Icon(Icons.drive_file_move_outline),
                            const SizedBox(width: 12),
                            Text(context.l10n.moveTo),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded),
                            const SizedBox(width: 12),
                            Text(context.l10n.delete),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
            ),
            const Spacer(),
            Text(
              context.l10n.folderContents(documentCount, childFolderCount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.openFolder,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.folderPath,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
    required this.onOpen,
    required this.onFavorite,
    required this.onRename,
    required this.onMove,
    required this.onExport,
    required this.onDelete,
  });
  final LibraryDocument document;
  final String? folderPath;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = document.content
        .replaceAll(RegExp(r'[#*_>`\[\]()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.secondaryContainer : null,
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: selecting ? onToggleSelect : onOpen,
        onLongPress: onToggleSelect,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      document.extension.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  if (selecting)
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? scheme.primary : scheme.outline,
                    )
                  else ...[
                  IconButton(
                    tooltip: document.isFavorite
                        ? context.l10n.unfavorite
                        : context.l10n.favorite,
                    onPressed: onFavorite,
                    icon: Icon(
                      document.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: document.isFavorite ? Colors.amber.shade700 : null,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'move') onMove();
                      if (value == 'export') onExport();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined),
                            const SizedBox(width: 12),
                            Text(context.l10n.rename),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            const Icon(Icons.drive_file_move_outline),
                            const SizedBox(width: 12),
                            Text(context.l10n.moveTo),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            const Icon(Icons.download_rounded),
                            const SizedBox(width: 12),
                            Text(context.l10n.exportLabel),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded),
                            const SizedBox(width: 12),
                            Text(context.l10n.delete),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
              if (folderPath != null && folderPath!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  folderPath!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${document.title}.${document.extension}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  preview.isEmpty ? context.l10n.emptyDocument : preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _relativeDate(context, document.updatedAt),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.wordCount(document.wordCount),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeDate(BuildContext context, DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return context.l10n.now;
  if (difference.inHours < 1) {
    return context.l10n.minutesAgo(difference.inMinutes);
  }
  if (difference.inDays < 1) return context.l10n.hoursAgo(difference.inHours);
  if (difference.inDays < 7) return context.l10n.daysAgo(difference.inDays);
  return MaterialLocalizations.of(context).formatCompactDate(date);
}

/// Reports its child's laid-out size once per change, after the frame. Used
/// to keep the library's scroll offset in step with the pinned header, whose
/// height is not fixed (a release notice makes it taller, multi-select mode
/// makes it a little shorter).
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _previous;

  @override
  void performLayout() {
    super.performLayout();
    final size = child?.size ?? Size.zero;
    if (size == _previous) return;
    _previous = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
  }
}
