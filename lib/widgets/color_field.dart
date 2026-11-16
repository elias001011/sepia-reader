import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'sheet_scaffold.dart';

class ColorField extends StatelessWidget {
  const ColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showAppSheet<Color>(
          context: context,
          builder: (sheetContext) =>
              _ColorPickerSheet(label: label, value: value),
        );
        if (picked != null && context.mounted) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              '#${value.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.label, required this.value});

  final String label;
  final Color value;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final _controller = TextEditingController(text: _hex(widget.value));
  late Color _selected = widget.value;
  bool _valid = true;

  static const _palette = [
    Color(0xFF000000),
    Color(0xFF121212),
    Color(0xFF6B4933),
    Color(0xFF2B211D),
    Color(0xFF111827),
    Color(0xFFFAFAFA),
    Color(0xFFF5EFE6),
    Color(0xFFFFFBF5),
    Color(0xFFFFF8ED),
    Color(0xFF203A32),
    Color(0xFF6B3948),
    Color(0xFF31516B),
    Color(0xFF9A6B45),
  ];

  static String _hex(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(Color color) => setState(() {
    _selected = color;
    _controller.text = _hex(color);
    _valid = true;
  });

  @override
  Widget build(BuildContext context) {
    return SheetPrompt(
      title: widget.label,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in _palette)
                _swatch(context, color, selected: _matches(color)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.l10n.hexColor,
              prefixText: '#',
              hintText: '6B4933',
              errorText: _valid ? null : context.l10n.invalidHexColor,
            ),
            onChanged: (raw) {
              final clean = raw.trim().replaceAll('#', '');
              final valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean);
              setState(() {
                _valid = valid;
                if (valid) {
                  _selected = Color(int.parse('FF$clean', radix: 16));
                }
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          // Applying while the field holds an invalid value used to keep the
          // previous colour without saying so.
          onPressed: _valid ? () => Navigator.pop(context, _selected) : null,
          child: Text(context.l10n.apply),
        ),
      ],
    );
  }

  bool _matches(Color color) => color.toARGB32() == _selected.toARGB32();

  Widget _swatch(BuildContext context, Color color, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '#${_hex(color)}',
      child: InkWell(
        onTap: () => _pick(color),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  color: color.computeLuminance() > .45
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
