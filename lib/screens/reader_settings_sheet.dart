import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../state/app_controller.dart';
import '../widgets/color_field.dart';
import '../widgets/sheet_scaffold.dart';

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

  /// Whether anything here differs from what is stored.
  bool get _isDirty =>
      jsonEncode(_draft.toJson()) !=
      jsonEncode(widget.controller.settings.toJson());

  Future<void> _apply() async {
    await widget.controller.updateSettings(_draft);
    if (mounted) Navigator.pop(context);
  }

  /// Closing with unsaved changes asks rather than silently discarding them.
  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.unsavedTitle),
        content: Text(dialogContext.l10n.unsavedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: Text(dialogContext.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text(dialogContext.l10n.unsavedDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: Text(dialogContext.l10n.unsavedSaveAndLeave),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return;
    if (choice == 'save') {
      await _apply();
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: SheetScaffold(
        title: context.l10n.readerSettings,
        description: context.l10n.readerSettingsDescription,
        onClose: _requestClose,
        footer: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(context.l10n.applyReading),
            ),
          ),
        ),
        children: [
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.followAppTheme),
                  subtitle: Text(context.l10n.followAppThemeDescription),
                  value: _draft.readerFollowsTheme,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(readerFollowsTheme: value),
                  ),
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
                    _preset(
                      context,
                      context.l10n.amoled,
                      Colors.black,
                      const Color(0xFFF5F5F5),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                    () => _draft = _draft.copyWith(
                      readerBackground: value,
                      readerFollowsTheme: false,
                    ),
                  ),
                ),
                ColorField(
                  label: context.l10n.textColor,
                  value: _draft.readerText,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(
                      readerText: value,
                      readerFollowsTheme: false,
                    ),
                  ),
                ),
        ],
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
        readerFollowsTheme: false,
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
