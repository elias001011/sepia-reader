import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  bool _isImportingFolder = false;
  bool _isImportingFiles = false;
  bool _isDraggingFiles = false;
  late final DocumentDropBinding _documentDropBinding;

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

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _forceSync,
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _topBar(context)),
                if (_update case final update?)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
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
                  ),
                if (_isImportingFolder || _isImportingFiles)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
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
                                          onOpen: () => _enterFolder(folder.id),
                                          onRename: () => _renameFolder(folder),
                                          onDelete: () => _deleteFolder(folder),
                                        );
                                      }
                                      final document =
                                          documents[index - folders.length];
                                      return _DocumentCard(
                                        document: document,
                                        folderPath: searching
                                            ? widget.controller
                                                  .folderPath(document.folderId)
                                                  .map((folder) => folder.name)
                                                  .join(' / ')
                                            : null,
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
            if (_isDraggingFiles) _dropOverlay(context),
          ],
        ),
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width < 620
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

  Widget _topBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
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
    });
  }

  Future<void> _showLibraryActions({bool importOnly = false}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!importOnly) ...[
                ListTile(
                  leading: const Icon(Icons.note_add_outlined),
                  title: Text(context.l10n.newDocument),
                  onTap: () => Navigator.pop(sheetContext, 'document'),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(context.l10n.newFolder),
                  onTap: () => Navigator.pop(sheetContext, 'folder'),
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(context.l10n.importFiles),
                onTap: () => Navigator.pop(sheetContext, 'importFiles'),
              ),
              ListTile(
                leading: const Icon(Icons.drive_folder_upload_outlined),
                title: Text(context.l10n.importFolder),
                subtitle: Text(context.l10n.compatibleFilesOnly),
                onTap: () => Navigator.pop(sheetContext, 'importFolder'),
              ),
            ],
          ),
        ),
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
    const rootValue = '__root__';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.moveDocument),
        // Width capped to the screen, not fixed: an AlertDialog does not
        // scroll sideways, so a wider-than-the-phone body just loses its
        // right edge.
        content: SizedBox(
          width: _dialogWidth(dialogContext, 440),
          height: 420,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.home_rounded),
                title: Text(context.l10n.root),
                selected: document.folderId == null,
                onTap: () => Navigator.pop(dialogContext, rootValue),
              ),
              for (final folder in widget.controller.folders)
                ListTile(
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(folder.name),
                  subtitle: Text(
                    widget.controller
                        .folderPath(folder.parentId)
                        .map((item) => item.name)
                        .join(' / '),
                  ),
                  selected: document.folderId == folder.id,
                  onTap: () => Navigator.pop(dialogContext, folder.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await widget.controller.moveDocument(
      document.id,
      selected == rootValue ? null : selected,
    );
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
            width: _dialogWidth(context, 420),
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
      await exportDocument(document);
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

  /// Preferred dialog body width, never wider than the screen allows.
  static double _dialogWidth(BuildContext context, double preferred) {
    final available = MediaQuery.sizeOf(context).width - 80;
    return available < preferred ? available.clamp(200.0, preferred) : preferred;
  }

  void _openSettings() => showAppSheet<void>(
    context: context,
    builder: (_) => SettingsSheet(controller: widget.controller),
  );
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.documentCount,
    required this.childFolderCount,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final LibraryFolder folder;
  final int documentCount;
  final int childFolderCount;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    size: 30,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') onRename();
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.folderPath,
    required this.onOpen,
    required this.onFavorite,
    required this.onRename,
    required this.onMove,
    required this.onExport,
    required this.onDelete,
  });
  final LibraryDocument document;
  final String? folderPath;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = document.content
        .replaceAll(RegExp(r'[#*_>`\[\]()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
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
