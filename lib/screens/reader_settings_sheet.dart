import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../state/app_controller.dart';
import '../widgets/color_field.dart';

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({super.key, required this.controller});
  final AppController controller;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late AppSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.settings;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Center(
          child: SizedBox(
            width: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.readerSettings,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.readerSettingsDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                Text(
                  context.l10n.presets,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _preset(
                      context,
                      context.l10n.sepiaPreset,
                      const Color(0xFF6B4933),
                      const Color(0xFFFFF8ED),
                    ),
                    _preset(
                      context,
                      context.l10n.artifactPreset,
                      const Color(0xFF2B211D),
                      const Color(0xFFE7DDD2),
                    ),
                    _preset(
                      context,
                      context.l10n.paperPreset,
                      const Color(0xFFFFFBF2),
                      const Color(0xFF322720),
                    ),
                    _preset(
                      context,
                      context.l10n.nightPreset,
                      const Color(0xFF111318),
                      const Color(0xFFE8E2DA),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<String>(
                  initialValue: _draft.readerFont,
                  decoration: InputDecoration(labelText: context.l10n.font),
                  items:
                      const [
                            'Merriweather',
                            'Lora',
                            'Inter',
                            'Roboto Mono',
                            'Sistema',
                          ]
                          .map(
                            (font) => DropdownMenuItem(
                              value: font,
                              child: Text(
                                font == 'Sistema'
                                    ? context.l10n.systemFont
                                    : font,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (font) => setState(
                    () => _draft = _draft.copyWith(readerFont: font),
                  ),
                ),
                const SizedBox(height: 18),
                _slider(
                  context,
                  label: context.l10n.size,
                  value: _draft.readerFontSize,
                  min: 14,
                  max: 34,
                  divisions: 20,
                  suffix: '${_draft.readerFontSize.round()} px',
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(readerFontSize: value),
                  ),
                ),
                _slider(
                  context,
                  label: context.l10n.lineHeight,
                  value: _draft.readerLineHeight,
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  suffix: _draft.readerLineHeight.toStringAsFixed(1),
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(readerLineHeight: value),
                  ),
                ),
                _slider(
                  context,
                  label: context.l10n.pageWidth,
                  value: _draft.readerWidth,
                  min: 520,
                  max: 1040,
                  divisions: 13,
                  suffix: '${_draft.readerWidth.round()} px',
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(readerWidth: value),
                  ),
                ),
                const SizedBox(height: 8),
                ColorField(
                  label: context.l10n.readerBackground,
                  value: _draft.readerBackground,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(readerBackground: value),
                  ),
                ),
                ColorField(
                  label: context.l10n.textColor,
                  value: _draft.readerText,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(readerText: value),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await widget.controller.updateSettings(_draft);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.l10n.applyReading),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preset(
    BuildContext context,
    String label,
    Color background,
    Color text,
  ) => ActionChip(
    avatar: CircleAvatar(
      backgroundColor: background,
      radius: 10,
      child: Icon(Icons.circle, size: 8, color: text),
    ),
    label: Text(label),
    onPressed: () => setState(
      () => _draft = _draft.copyWith(
        readerBackground: background,
        readerText: text,
      ),
    ),
  );

  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) => Column(
    children: [
      Row(
        children: [
          Text(label),
          const Spacer(),
          Text(suffix, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );
}
