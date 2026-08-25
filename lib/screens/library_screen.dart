import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/library_document.dart';
import '../services/document_io.dart';
import '../state/app_controller.dart';
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final documents = widget.controller.documents.where((document) {
      final haystack =
          '${document.title}.${document.extension} ${document.content}'
              .toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _topBar(context)),
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
                        const SizedBox(height: 30),
                        _sectionHeader(context, documents.length),
                        const SizedBox(height: 16),
                        if (documents.isEmpty)
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
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisExtent: 238,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: documents.length,
                                itemBuilder: (context, index) => _DocumentCard(
                                  document: documents[index],
                                  onOpen: () => _open(documents[index]),
                                  onFavorite: () => widget.controller
                                      .toggleFavorite(documents[index].id),
                                  onExport: () => _export(documents[index]),
                                  onDelete: () =>
                                      _confirmDelete(documents[index]),
                                ),
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
      floatingActionButton: MediaQuery.sizeOf(context).width < 620
          ? FloatingActionButton.extended(
              onPressed: _createDocument,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.newLabel),
            )
          : null,
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
                tooltip: context.l10n.appearance,
                onPressed: _openSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
              if (MediaQuery.sizeOf(context).width >= 620) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _importFiles,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(context.l10n.importLabel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _createDocument,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.l10n.newDocument),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: .55),
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
                    onPressed: _importFiles,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(context.l10n.importFiles),
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

  Widget _sectionHeader(BuildContext context, int count) => Wrap(
    spacing: 10,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        _query.isEmpty ? context.l10n.libraryTitle : context.l10n.results,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      Chip(label: Text(context.l10n.fileCount(count))),
    ],
  );

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
            width: 420,
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
        allowedExtensions: const [
          'md',
          'markdown',
          'txt',
          'dart',
          'js',
          'ts',
          'json',
          'yaml',
          'yml',
          'html',
          'css',
          'py',
          'java',
          'kt',
          'swift',
          'sh',
          'sql',
          'xml',
        ],
      );
      var imported = 0;
      for (final file in files) {
        if (await file.length() > 5 * 1024 * 1024) continue;
        final bytes = await file.readAsBytes();
        final parts = file.name.split('.');
        final extension = parts.length > 1 ? parts.last.toLowerCase() : 'txt';
        final title = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('.')
            : file.name;
        await widget.controller.createDocument(
          title: title,
          extension: extension,
          content: utf8.decode(bytes, allowMalformed: true),
        );
        imported++;
      }
      if (mounted && files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importedCount(imported))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
      }
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

  void _openSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SettingsSheet(controller: widget.controller),
  );
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onOpen,
    required this.onFavorite,
    required this.onExport,
    required this.onDelete,
  });
  final LibraryDocument document;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
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
                      if (value == 'export') onExport();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: const Icon(Icons.download_rounded),
                          title: Text(context.l10n.exportLabel),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline_rounded),
                          title: Text(context.l10n.delete),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
