import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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
      onTap: () => _showColorDialog(context),
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

  Future<void> _showColorDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: value.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
    var selected = value;
    const palette = [
      Color(0xFF6B4933),
      Color(0xFF2B211D),
      Color(0xFF111827),
      Color(0xFFF5EFE6),
      Color(0xFFFFFBF5),
      Color(0xFFFFF8ED),
      Color(0xFF203A32),
      Color(0xFF6B3948),
      Color(0xFF31516B),
      Color(0xFF9A6B45),
    ];
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: palette.map((color) {
                    final active = color.toARGB32() == selected.toARGB32();
                    return InkWell(
                      onTap: () {
                        setDialogState(() => selected = color);
                        controller.text = color
                            .toARGB32()
                            .toRadixString(16)
                            .substring(2)
                            .toUpperCase();
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: active ? 3 : 1,
                          ),
                        ),
                        child: active
                            ? Icon(
                                Icons.check_rounded,
                                color: color.computeLuminance() > .45
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: context.l10n.hexColor,
                    prefixText: '#',
                    hintText: '6B4933',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (raw) {
                    final clean = raw.replaceAll('#', '');
                    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) {
                      setDialogState(
                        () =>
                            selected = Color(int.parse('FF$clean', radix: 16)),
                      );
                    }
                  },
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
              onPressed: () => Navigator.pop(context, selected),
              child: Text(context.l10n.apply),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null) onChanged(result);
  }
}
