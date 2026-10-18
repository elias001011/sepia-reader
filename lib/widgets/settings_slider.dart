import 'package:flutter/material.dart';

/// Consistent, wrapping labels and accessible value feedback across settings.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.suffix,
  });
  final String label;
  final double value, min, max;
  final int divisions;
  final String? suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatted = suffix ?? '${value.toStringAsFixed(2)}x';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(width: 12),
            Text(formatted, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: formatted,
          semanticFormatterCallback: (_) => '$label $formatted',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
