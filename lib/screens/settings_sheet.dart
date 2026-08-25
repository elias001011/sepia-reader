import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../services/tts/system_tts_engine.dart';
import '../services/tts/tts_engine.dart';
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

  /// Set when the user turned syncing off and chose to erase the server's
  /// copy; acted on when the settings are saved.
  bool _wipeServerOnSave = false;

  /// Built lazily and only for this sheet: listing voices and playing a
  /// sample needs an engine, but holding one open while the user is merely
  /// reading does not.
  TtsEngine? _voiceEngine;
  List<TtsVoice>? _voices;
  bool _loadingVoices = false;

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
    unawaited(_voiceEngine?.release());
    super.dispose();
  }

  TtsEngine get _engine => _voiceEngine ??= SystemTtsEngine();

  Future<void> _loadVoices() async {
    if (_loadingVoices || _voices != null) return;
    setState(() => _loadingVoices = true);
    List<TtsVoice> voices = const [];
    try {
      voices = await _engine.availableVoices();
      // The browser populates its voice list asynchronously and reports an
      // empty one until it has: a single retry turns "no voices found" into
      // the real list on the web build.
      if (voices.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        voices = await _engine.availableVoices();
      }
    } catch (error) {
      debugPrint('sepia: could not list voices: $error');
    }
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _loadingVoices = false;
    });
  }

  Future<void> _previewVoice() async {
    final sample = context.l10n.ttsPreviewText;
    try {
      await _engine.prepare();
      await _engine.configure(
        voiceId: _draft.ttsVoiceId.isEmpty ? null : _draft.ttsVoiceId,
        rate: _draft.ttsRate,
        pitch: _draft.ttsPitch,
      );
      await _engine.stop();
      unawaited(_engine.speak(sample));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ttsFailed('$error'))),
        );
      }
    }
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

  /// Handles the sync switch. Turning it off asks what should happen to the
  /// copy that lives on the server — the local library is never at stake, so
  /// the question is deliberately about the remote side only.
  Future<void> _onSyncToggled(bool value) async {
    final wasEnabled = _draft.syncEnabled;
    setState(() => _draft = _draft.copyWith(syncEnabled: value));
    if (!wasEnabled || value) {
      setState(() => _wipeServerOnSave = false);
      return;
    }
    final wipe = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.syncDisabledTitle),
        // Spelling out what each button does to the *server* is the whole
        // point of this dialog — "keep" and "erase" on their own said
        // nothing about which side was affected — so the text is long
        // enough to need scrolling on a short screen.
        content: SingleChildScrollView(
          child: Text(dialogContext.l10n.syncDisabledBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.syncWipeFromServer),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.syncKeepOnServer),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _wipeServerOnSave = wipe ?? false);
  }

  Future<void> _save() async {
    final draft = _draft.copyWith(
      syncServerUrl: _serverUrlController.text.trim(),
    );
    var wipeFailed = false;
    if (_wipeServerOnSave) {
      // Must happen while syncing is still enabled, otherwise the request has
      // no server to go to.
      wipeFailed = !await widget.controller.clearServerCopy();
    }
    await widget.controller.updateSettings(draft);
    if (!mounted) return;
    if (_wipeServerOnSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wipeFailed ? context.l10n.syncWipeFailed : context.l10n.syncWipeDone,
          ),
        ),
      );
    }
    Navigator.pop(context);
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
          // A fixed width, not a maximum: on any screen narrower than
          // this the sheet overflowed and its right edge — switches,
          // buttons, the close control — was simply cut off. Which is
          // every phone, where this app is mostly used.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.appAppearance,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
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
                  context.l10n.appearanceSection,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                  isExpanded: true,
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
                  context.l10n.ttsSection,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.ttsEnable),
                  subtitle: Text(context.l10n.ttsEnableDescription),
                  value: _draft.ttsEnabled,
                  onChanged: (value) {
                    setState(() => _draft = _draft.copyWith(ttsEnabled: value));
                    if (value) unawaited(_loadVoices());
                  },
                ),
                if (_draft.ttsEnabled) ...[
                  const SizedBox(height: 4),
                  _engineOption(
                    context,
                    value: 'system',
                    title: context.l10n.ttsEngineSystem,
                    description: context.l10n.ttsEngineSystemDescription,
                    enabled: true,
                  ),
                  _engineOption(
                    context,
                    value: 'neural',
                    title: context.l10n.ttsEngineNeural,
                    description: context.l10n.ttsEngineNeuralDescription,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  _voicePicker(context),
                  const SizedBox(height: 8),
                  _slider(
                    context,
                    label: context.l10n.ttsRate,
                    value: _draft.ttsRate,
                    min: 0.5,
                    max: 2,
                    divisions: 15,
                    onChanged: (value) => setState(
                      () => _draft = _draft.copyWith(ttsRate: value),
                    ),
                  ),
                  _slider(
                    context,
                    label: context.l10n.ttsPitch,
                    value: _draft.ttsPitch,
                    min: 0.5,
                    max: 2,
                    divisions: 15,
                    onChanged: (value) => setState(
                      () => _draft = _draft.copyWith(ttsPitch: value),
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _previewVoice,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: Text(context.l10n.ttsPreview),
                  ),
                ],
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
                  onChanged: _onSyncToggled,
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
                    onPressed: _save,
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

  /// One selectable speech backend. Written by hand rather than with
  /// RadioListTile so the unavailable neural option can still show what it
  /// will be, greyed out, instead of being hidden until it ships.
  Widget _engineOption(
    BuildContext context, {
    required String value,
    required String title,
    required String description,
    required bool enabled,
  }) {
    final selected = _draft.ttsEngine == value && enabled;
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        child: ListTile(
          leading: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? scheme.primary : scheme.outline,
          ),
          title: Text(title),
          subtitle: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: enabled
              ? () => setState(() => _draft = _draft.copyWith(ttsEngine: value))
              : null,
        ),
      ),
    );
  }

  Widget _voicePicker(BuildContext context) {
    final voices = _voices;
    if (_loadingVoices || voices == null) {
      if (voices == null && !_loadingVoices) unawaited(_loadVoices());
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.ttsLoadingVoices,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    if (voices.isEmpty) {
      return Text(
        context.l10n.ttsNoVoices,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    // A device can report a hundred voices. Grouping by locale and labelling
    // each entry with it is what makes picking one workable at all.
    final known = voices.any((voice) => voice.id == _draft.ttsVoiceId);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: known ? _draft.ttsVoiceId : '',
      decoration: InputDecoration(labelText: context.l10n.ttsVoice),
      items: [
        DropdownMenuItem(value: '', child: Text(context.l10n.ttsVoiceAuto)),
        for (final voice in voices)
          DropdownMenuItem(
            value: voice.id,
            child: Text(
              '${voice.locale} · ${voice.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(
        () => _draft = _draft.copyWith(ttsVoiceId: value ?? ''),
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label · ${value.toStringAsFixed(2)}x',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.toStringAsFixed(2)}x',
        onChanged: onChanged,
      ),
    ],
  );

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
