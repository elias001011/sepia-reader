import 'package:flutter/material.dart';

import 'sheet_scaffold.dart';

/// One row of a choice sheet.
///
/// A plain icon covers the usual case; [color] and [textStyle] exist because
/// the reading palette wants a colour sample and the font list wants the font
/// itself, and both belong in the leading slot rather than as a special case
/// somewhere else.
class SheetChoice<T> {
  const SheetChoice({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.textStyle,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final TextStyle? textStyle;
}

/// The app panel, listing choices. Resolves to the picked value, or null if
/// the sheet was closed without one.
Future<T?> showSheetChoices<T>({
  required BuildContext context,
  required String title,
  required List<SheetChoice<T>> choices,
  T? value,
  String? description,
}) {
  if (choices.isEmpty) return Future<T?>.value();
  return showAppSheet<T>(
    context: context,
    builder: (sheetContext) => SheetScaffold.list(
      title: title,
      description: description,
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        final selected = choice.value == value;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _ChoiceLeading(choice: choice, selected: selected),
          title: Text(choice.label, style: choice.textStyle),
          subtitle: choice.subtitle == null ? null : Text(choice.subtitle!),
          trailing: selected ? const Icon(Icons.check_rounded) : null,
          selected: selected,
          onTap: () => Navigator.pop(sheetContext, choice.value),
        );
      },
    ),
  );
}

class _ChoiceLeading extends StatelessWidget {
  const _ChoiceLeading({required this.choice, required this.selected});

  final SheetChoice<dynamic> choice;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = choice.color;
    if (color != null) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: choice.textStyle == null
            ? null
            : Text('Aa', style: choice.textStyle),
      );
    }
    final icon = choice.icon;
    if (icon == null) return const SizedBox(width: 30);
    return Icon(icon);
  }
}

/// A form field that shows the current choice and opens the same panel as
/// everything else when tapped, instead of a dropdown menu.
class SheetChoiceField<T> extends StatelessWidget {
  const SheetChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.description,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<SheetChoice<T>> choices;
  final ValueChanged<T> onChanged;
  final String? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    SheetChoice<T>? selected;
    for (final choice in choices) {
      if (choice.value == value) {
        selected = choice;
        break;
      }
    }
    return Semantics(
      button: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () async {
                final picked = await showSheetChoices<T>(
                  context: context,
                  title: label,
                  choices: choices,
                  value: value,
                  description: description,
                );
                if (picked != null && context.mounted) onChanged(picked);
              }
            : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            suffixIcon: const Icon(Icons.expand_more_rounded),
          ),
          isEmpty: selected == null,
          child: Row(
            children: [
              if (selected != null) ...[
                _ChoiceLeading(choice: selected, selected: false),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  selected?.label ?? '',
                  style: selected?.textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
