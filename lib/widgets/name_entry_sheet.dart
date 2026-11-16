import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'sheet_choices.dart';
import 'sheet_scaffold.dart';

/// What the form resolves to: the typed name, plus the chosen format when the
/// sheet offers one.
typedef NameEntry = ({String name, String? format});

/// A one-field form in the shared panel, used for creating folders and
/// documents and for renaming both.
///
/// The controller belongs to this widget, so it is created and disposed with
/// the sheet itself rather than by the caller after the route has gone.
class NameEntrySheet extends StatefulWidget {
  const NameEntrySheet({
    super.key,
    required this.title,
    required this.label,
    required this.actionLabel,
    this.description,
    this.initialValue = '',
    this.hint,
    this.suffix,
    this.formats,
    this.initialFormat,
  });

  final String title;
  final String? description;
  final String label;
  final String actionLabel;
  final String initialValue;
  final String? hint;
  final String? suffix;

  /// Formats offered below the name field. When null, none is shown.
  final List<SheetChoice<String>>? formats;
  final String? initialFormat;

  @override
  State<NameEntrySheet> createState() => _NameEntrySheetState();
}

class _NameEntrySheetState extends State<NameEntrySheet> {
  late final _controller = TextEditingController(text: widget.initialValue);
  late String? _format = widget.initialFormat;
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    // A second tap during the closing animation must not pop the page below
    // this sheet, nor create the document twice.
    if (_submitted) return;
    _submitted = true;
    Navigator.pop<NameEntry>(context, (
      name: _controller.text,
      format: _format,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final formats = widget.formats;
    return SheetPrompt(
      title: widget.title,
      description: widget.description,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              suffixText: widget.suffix,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (formats != null) ...[
            const SizedBox(height: 20),
            SheetChoiceField<String>(
              label: context.l10n.format,
              value: _format,
              choices: formats,
              onChanged: (value) => setState(() => _format = value),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
