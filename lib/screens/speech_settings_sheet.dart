import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/app_controller.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/speech_controls.dart';

class SpeechSettingsSheet extends StatefulWidget {
  const SpeechSettingsSheet({
    super.key,
    required this.controller,
    required this.supportsPitch,
  });
  final AppController controller;
  final bool supportsPitch;

  @override
  State<SpeechSettingsSheet> createState() => _SpeechSettingsSheetState();
}

class _SpeechSettingsSheetState extends State<SpeechSettingsSheet> {
  late double _rate = widget.controller.settings.ttsRate;
  late double _pitch = widget.controller.settings.ttsPitch;
  bool _saving = false;

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await widget.controller.updateSettings(
        widget.controller.settings.copyWith(ttsRate: _rate, ttsPitch: _pitch),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: context.l10n.ttsSpeechTitle,
    description: context.l10n.ttsSpeechSettingsHint,
    footer: FilledButton(
      onPressed: _saving ? null : _apply,
      child: Text(context.l10n.apply),
    ),
    children: [
      SpeechControls(
        rate: _rate,
        pitch: _pitch,
        supportsPitch: widget.supportsPitch,
        onRateChanged: (value) => setState(() => _rate = value),
        onPitchChanged: (value) => setState(() => _pitch = value),
      ),
    ],
  );
}
