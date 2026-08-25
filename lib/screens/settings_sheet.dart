import 'dart:async';

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
  late final TextEditingController _serverUrlController;
  String? _syncStatus;
  bool _testing = false;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.settings;
    _serverUrlController = TextEditingController(text: _draft.syncServerUrl);
    unawaited(_loadLastSync());
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadLastSync() async {
    final value = await widget.controller.lastSyncAt();
    if (mounted) setState(() => _lastSyncAt = value);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _syncStatus = context.l10n.syncTesting;
    });
    final result = await widget.controller.testSyncConnection(
      _serverUrlController.text,
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _syncStatus = result.ok
          ? context.l10n.syncTestOk(result.documentCount)
          : context.l10n.syncTestFailed(result.error ?? '?');
    });
  }

  String get _syncSummary {
    if (!_draft.syncEnabled) return context.l10n.syncOff;
    final at = _lastSyncAt;
    if (at == null) return context.l10n.syncNever;
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return context.l10n.syncLast(
      '${two(local.day)}/${two(local.month)} '
      '${two(local.hour)}:${two(local.minute)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
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
                DropdownButtonFormField<String>(
                  initialValue: _themeChoice,
                  decoration: InputDecoration(labelText: context.l10n.theme),
                  items: [
                    DropdownMenuItem(
                      value: 'light',
                      child: Text(context.l10n.light),
                    ),
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(context.l10n.system),
                    ),
                    DropdownMenuItem(
                      value: 'dark',
                      child: Text(context.l10n.dark),
                    ),
                    DropdownMenuItem(
                      value: 'amoled',
                      child: Text(context.l10n.amoled),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _setTheme(value);
                  },
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
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(localeCode: value),
                  ),
                ),
                const SizedBox(height: 10),
                ColorField(
                  label: context.l10n.primaryColor,
                  value: _draft.seedColor,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(seedColor: value),
                  ),
                ),
                ColorField(
                  label: context.l10n.lightThemeBackground,
                  value: _draft.appBackground,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(appBackground: value),
                  ),
                ),
                ColorField(
                  label: context.l10n.darkThemeBackground,
                  value: _draft.darkAppBackground,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(darkAppBackground: value),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.readerThemeHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.autoHideReaderControls),
                  subtitle: Text(
                    context.l10n.autoHideReaderControlsDescription,
                  ),
                  value: _draft.autoHideReaderControls,
                  onChanged: (value) => setState(
                    () =>
                        _draft = _draft.copyWith(autoHideReaderControls: value),
                  ),
                ),
                const Divider(height: 32),
                Text(
                  context.l10n.syncSection,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.syncWithServer),
                  subtitle: Text(context.l10n.syncWithServerDescription),
                  value: _draft.syncEnabled,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(syncEnabled: value)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverUrlController,
                  enabled: _draft.syncEnabled,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: context.l10n.syncServerAddress,
                    hintText: context.l10n.syncServerAddressHint,
                  ),
                  onChanged: (value) =>
                      _draft = _draft.copyWith(syncServerUrl: value.trim()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_rounded),
                      label: Text(context.l10n.syncTestConnection),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _syncStatus ?? _syncSummary,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await widget.controller.updateSettings(
                        _draft.copyWith(
                          syncServerUrl: _serverUrlController.text.trim(),
                        ),
                      );
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
      ),
    );
  }

  String get _themeChoice =>
      _draft.amoledTheme ? 'amoled' : _draft.themeMode.name;

  void _setTheme(String choice) => setState(() {
    _draft = switch (choice) {
      'light' => _draft.copyWith(
        themeMode: ThemeMode.light,
        amoledTheme: false,
      ),
      'dark' => _draft.copyWith(themeMode: ThemeMode.dark, amoledTheme: false),
      'amoled' => _draft.copyWith(
        themeMode: ThemeMode.dark,
        amoledTheme: true,
        readerFollowsTheme: true,
        // Keep the explicit reader colors in sync with the AMOLED preset
        // too, not just the follow-theme flag: reader_settings_sheet.dart
        // flips readerFollowsTheme back to false the moment any reader
        // ColorField is touched, and it was falling back to whatever stale
        // (often sepia-brown) colors were stored here before.
        readerBackground: Colors.black,
        readerText: const Color(0xFFF5F5F5),
      ),
      _ => _draft.copyWith(themeMode: ThemeMode.system, amoledTheme: false),
    };
  });
}
