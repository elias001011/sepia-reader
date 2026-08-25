import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../state/app_controller.dart';
import '../widgets/color_field.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AppSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.settings;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.appAppearance,
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
                context.l10n.appAppearanceDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.theme,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(context.l10n.light),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(context.l10n.system),
                      icon: const Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(context.l10n.dark),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {_draft.themeMode},
                  onSelectionChanged: (value) => setState(
                    () => _draft = _draft.copyWith(themeMode: value.first),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _draft.localeCode,
                decoration: InputDecoration(labelText: context.l10n.language),
                items: [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(context.l10n.system),
                  ),
                  DropdownMenuItem(
                    value: 'pt_BR',
                    child: Text(context.l10n.portugueseBrazil),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(context.l10n.english),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(localeCode: value)),
              ),
              const SizedBox(height: 10),
              ColorField(
                label: context.l10n.primaryColor,
                value: _draft.seedColor,
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(seedColor: value)),
              ),
              ColorField(
                label: context.l10n.lightThemeBackground,
                value: _draft.appBackground,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(appBackground: value),
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
                    child: Text(context.l10n.saveAppearance),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
