import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'settings_slider.dart';

/// Shared by library settings and the in-reader speech panel (also in Lite).
class SpeechControls extends StatelessWidget {
  const SpeechControls({
    super.key,
    required this.rate,
    required this.pitch,
    required this.supportsPitch,
    required this.onRateChanged,
    required this.onPitchChanged,
  });
  final double rate, pitch;
  final bool supportsPitch;
  final ValueChanged<double> onRateChanged, onPitchChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsSlider(
        label: context.l10n.ttsRate,
        value: rate,
        min: .5,
        max: 2,
        divisions: 15,
        onChanged: onRateChanged,
      ),
      if (supportsPitch)
        SettingsSlider(
          label: context.l10n.ttsPitch,
          value: pitch,
          min: .5,
          max: 2,
          divisions: 15,
          onChanged: onPitchChanged,
        )
      else
        Text(
          context.l10n.ttsNeuralPitchHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );
}
