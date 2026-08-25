import 'dart:async';

import 'package:flutter/material.dart';

import '../models/library_document.dart';
import '../services/document_io.dart';
import '../state/app_controller.dart';
import '../widgets/markdown_view.dart';
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
  Timer? _saveTimer;
  bool _dirty = false;
  bool _readingMode = false;
  bool _showPreview = false;

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
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty) unawaited(_save());
    widget.controller.removeListener(_refresh);
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _save);
    setState(() {});
  }

  LibraryDocument get _draft {
    final document = _stored!;
    return document.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'Sem título'
          : _titleController.text.trim(),
      content: _contentController.text,
    );
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    await widget.controller.updateDocument(_draft);
    _dirty = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_stored == null) {
      return const Scaffold(
        body: Center(child: Text('Documento não encontrado.')),
      );
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _dirty
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
          IconButton(
            tooltip: 'Ajustes de leitura',
            onPressed: _openReaderSettings,
            icon: const Icon(Icons.text_fields_rounded),
          ),
          IconButton(
            tooltip: 'Exportar',
            onPressed: _export,
            icon: const Icon(Icons.download_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => _readingMode = true);
              },
              icon: const Icon(Icons.menu_book_rounded),
              label: MediaQuery.sizeOf(context).width >= 620
                  ? const Text('Modo leitura')
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Column(
            children: [
              if (_stored!.isMarkdown && (!wide && !_showPreview || wide))
                _formatToolbar(context),
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
                'EDITOR',
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
                'LEITURA',
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
      decoration: const InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.all(24),
        hintText: 'Comece a escrever…',
      ),
    ),
  );

  Widget _preview(BuildContext context) =>
      DocumentView(document: _draft, settings: widget.controller.settings);

  Widget _mobileTabs(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Editar'),
          icon: Icon(Icons.edit_outlined),
        ),
        ButtonSegment(
          value: true,
          label: Text('Visualizar'),
          icon: Icon(Icons.visibility_outlined),
        ),
      ],
      selected: {_showPreview},
      onSelectionChanged: (value) {
        FocusScope.of(context).unfocus();
        setState(() => _showPreview = value.first);
      },
    ),
  );

  Widget _formatToolbar(BuildContext context) {
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: 'Título',
        icon: Icons.title_rounded,
        onTap: () => _linePrefix('## '),
      ),
      (
        label: 'Negrito',
        icon: Icons.format_bold_rounded,
        onTap: () => _wrap('**', '**', 'texto'),
      ),
      (
        label: 'Itálico',
        icon: Icons.format_italic_rounded,
        onTap: () => _wrap('_', '_', 'texto'),
      ),
      (
        label: 'Citação',
        icon: Icons.format_quote_rounded,
        onTap: () => _linePrefix('> '),
      ),
      (
        label: 'Lista',
        icon: Icons.format_list_bulleted_rounded,
        onTap: () => _linePrefix('- '),
      ),
      (
        label: 'Código',
        icon: Icons.code_rounded,
        onTap: () => _wrap('`', '`', 'código'),
      ),
      (
        label: 'Link',
        icon: Icons.link_rounded,
        onTap: () => _wrap('[', '](https://)', 'texto'),
      ),
      (
        label: 'Linha',
        icon: Icons.horizontal_rule_rounded,
        onTap: () => _insert('\n---\n'),
      ),
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
    child: Row(
      children: [
        Text(
          '${_draft.wordCount} palavras',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(width: 16),
        Text(
          '${_draft.readingMinutes} min de leitura',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const Spacer(),
        Text(
          '.${_draft.extension}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );

  Widget _readerOnly(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: DocumentView(
            document: _draft,
            settings: widget.controller.settings,
            padding: EdgeInsets.fromLTRB(
              28,
              MediaQuery.paddingOf(context).top + 72,
              28,
              64,
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 16,
          child: _readerButton(
            context,
            tooltip: 'Voltar à biblioteca',
            icon: Icons.arrow_back_rounded,
            onPressed: _close,
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: Row(
            children: [
              _readerButton(
                context,
                tooltip: 'Ajustes',
                icon: Icons.text_fields_rounded,
                onPressed: _openReaderSettings,
              ),
              const SizedBox(width: 8),
              _readerButton(
                context,
                tooltip: 'Sair do modo leitura',
                icon: Icons.edit_rounded,
                onPressed: () => setState(() => _readingMode = false),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _readerButton(
    BuildContext context, {
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
        icon: Icon(icon),
      ),
    ),
  );

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
    if (_dirty) await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _export() async {
    if (_dirty) await _save();
    try {
      await exportDocument(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Arquivo exportado.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $error')),
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
