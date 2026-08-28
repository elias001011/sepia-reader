import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../services/tts/system_tts_engine.dart';
import '../services/tts/tts_engine.dart';
import '../services/tts/voice_catalog.dart';
import '../services/update_checker.dart';
import '../state/app_controller.dart';
import '../widgets/color_field.dart';
import '../widgets/sheet_scaffold.dart';
import 'voice_downloads_sheet.dart';

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


  String? _appVersion;
  AppUpdate? _update;
  bool _checkingUpdate = false;
  String? _updateError;

  /// Whether a check has actually happened in this sheet. Saying "you are on
  /// the latest" before asking anyone asserts something nobody verified —
  /// and it said it even with the check switched off.
  bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.settings;
    _serverUrlController = TextEditingController(text: _draft.syncServerUrl);
    unawaited(_loadLastSync());
    unawaited(_loadVersion());
    unawaited(widget.controller.voiceDownloads.refreshInstalled());
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    unawaited(_voiceEngine?.release());
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final version = await widget.controller.updates.currentVersion();
    if (mounted) setState(() => _appVersion = version);
  }

  Future<void> _loadLastSync() async {
    final value = await widget.controller.lastSyncAt();
    if (mounted) setState(() => _lastSyncAt = value);
  }

  /// Whether anything here differs from what is stored.
  bool get _isDirty {
    final draft = _draft.copyWith(
      syncServerUrl: _serverUrlController.text.trim(),
    );
    return jsonEncode(draft.toJson()) !=
            jsonEncode(widget.controller.settings.toJson()) ||
        _wipeServerOnSave;
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
      await _save();
      return;
    }
    if (mounted) Navigator.pop(context);
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
        // nothing about which side was affected.
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
      // Must happen while syncing is still enabled, otherwise the request
      // has no server to go to.
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
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: SheetScaffold(
        title: context.l10n.appAppearance,
        description: context.l10n.appAppearanceDescription,
        onClose: _requestClose,
        footer: SizedBox(
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
        children: [
          _sectionTitle(context, context.l10n.appearanceSection),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _themeChoice,
            decoration: InputDecoration(labelText: context.l10n.theme),
            items: [
              DropdownMenuItem(value: 'light', child: Text(context.l10n.light)),
              DropdownMenuItem(value: 'system', child: Text(context.l10n.system)),
              DropdownMenuItem(value: 'dark', child: Text(context.l10n.dark)),
              DropdownMenuItem(value: 'amoled', child: Text(context.l10n.amoled)),
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
              DropdownMenuItem(value: 'system', child: Text(context.l10n.system)),
              DropdownMenuItem(
                value: 'pt_BR',
                child: Text(context.l10n.portugueseBrazil),
              ),
              DropdownMenuItem(value: 'en', child: Text(context.l10n.english)),
            ],
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(localeCode: value)),
          ),
          const SizedBox(height: 18),
          _interfaceScale(context),
          const SizedBox(height: 4),
          ColorField(
            label: context.l10n.primaryColor,
            value: _draft.seedColor,
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(seedColor: value)),
          ),
          ColorField(
            label: context.l10n.lightThemeBackground,
            value: _draft.appBackground,
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(appBackground: value)),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.autoHideReaderControls),
            subtitle: Text(context.l10n.autoHideReaderControlsDescription),
            value: _draft.autoHideReaderControls,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(autoHideReaderControls: value),
            ),
          ),

          const Divider(height: 32),
          _sectionTitle(context, context.l10n.ttsSection),
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
              description: _neuralSupported
                  ? context.l10n.ttsEngineNeuralDescription
                  : context.l10n.ttsEngineNeuralUnavailableWeb,
              enabled: _neuralSupported,
            ),
            const SizedBox(height: 12),
            if (_usingNeural) _neuralVoiceRow(context) else _voicePicker(context),
            const SizedBox(height: 8),
            _slider(
              context,
              label: context.l10n.ttsRate,
              value: _draft.ttsRate,
              min: 0.5,
              max: 2,
              divisions: 15,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(ttsRate: value)),
            ),
            // Pitch is a platform-voice control: a neural model renders its
            // voice as trained, so the slider there would do nothing.
            if (!_usingNeural) ...[
              _slider(
                context,
                label: context.l10n.ttsPitch,
                value: _draft.ttsPitch,
                min: 0.5,
                max: 2,
                divisions: 15,
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(ttsPitch: value)),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _previewVoice,
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(context.l10n.ttsPreview),
              ),
            ],
          ],

          const Divider(height: 32),
          _sectionTitle(context, context.l10n.syncSection),
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
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(syncServerUrl: value.trim()),
            ),
          ),
          const SizedBox(height: 10),
          // Wrap, not Row: at a larger interface scale, or in a language
          // with a longer label, the button and the status text no longer
          // fit side by side and a Row simply overflows.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              Text(
                _syncStatus ?? _syncSummary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),

          const Divider(height: 32),
          _sectionTitle(context, context.l10n.updateSection),
          _updateSection(context),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _interfaceScale(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${context.l10n.interfaceScale} · '
              '${(_draft.uiScale * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (_draft.uiScale != 1)
            TextButton(
              onPressed: () =>
                  setState(() => _draft = _draft.copyWith(uiScale: 1)),
              child: Text(context.l10n.interfaceScaleReset),
            ),
        ],
      ),
      Text(
        context.l10n.interfaceScaleDescription,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Slider(
        value: _draft.uiScale.clamp(0.8, 1.6),
        min: 0.8,
        max: 1.6,
        divisions: 16,
        label: '${(_draft.uiScale * 100).round()}%',
        onChanged: (value) =>
            setState(() => _draft = _draft.copyWith(uiScale: value)),
      ),
    ],
  );

  Widget _updateSection(BuildContext context) {
    final update = _update;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.updateCheckAutomatically),
          subtitle: Text(context.l10n.updateCheckAutomaticallyDescription),
          value: _draft.checkForUpdates,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(checkForUpdates: value)),
        ),
        const SizedBox(height: 4),
        if (update != null)
          UpdateCard(update: update)
        else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _checkingUpdate ? null : _checkUpdate,
                icon: _checkingUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_rounded),
                label: Text(context.l10n.updateCheckNow),
              ),
              Text(
                _updateError ??
                    (_checkingUpdate
                        ? context.l10n.updateChecking
                        : _checkedUpdate
                        ? context.l10n.updateCurrent(_appVersion ?? '…')
                        : context.l10n.updateInstalled(_appVersion ?? '…')),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
    });
    try {
      final update = await widget.controller.updates.check(force: true);
      if (mounted) {
        setState(() {
          _update = update;
          _checkedUpdate = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _updateError = context.l10n.updateFailed('$error'));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  /// Language the cached engine was built for, so changing the interface
  /// language and then tapping preview in the same sheet does not audition
  /// the old one.
  String? _engineLocale;

  TtsEngine get _engine {
    if (_voiceEngine != null && _engineLocale == _draft.localeCode) {
      return _voiceEngine!;
    }
    unawaited(_voiceEngine?.release());
    _engineLocale = _draft.localeCode;
    return _voiceEngine = SystemTtsEngine(
      preferredLanguage: switch (_draft.localeCode) {
        'pt_BR' => 'pt-BR',
        'en' => 'en-US',
        _ => null,
      },
    );
  }

  bool get _neuralSupported => widget.controller.voiceDownloads.isSupported;

  bool get _usingNeural => _draft.ttsEngine == 'neural' && _neuralSupported;

  Future<void> _loadVoices() async {
    if (_loadingVoices || _voices != null) return;
    setState(() => _loadingVoices = true);
    List<TtsVoice> voices = const [];
    // Read once into a local: the getter releases and rebuilds the engine
    // when the language changes, so evaluating it again after an await can
    // hand back a different instance from the one just set up.
    final engine = _engine;
    try {
      voices = await engine.availableVoices();
      // The browser populates its voice list asynchronously and reports an
      // empty one until it has: a single retry turns "no voices found" into
      // the real list on the web build.
      if (voices.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        voices = await engine.availableVoices();
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
    final engine = _engine;
    try {
      await engine.stop();
      await engine.prepare();
      await engine.configure(
        voiceId: _draft.ttsVoiceId.isEmpty ? null : _draft.ttsVoiceId,
        rate: _draft.ttsRate,
        pitch: _draft.ttsPitch,
      );
      await engine.speak(sample);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ttsFailed('$error'))),
        );
      }
    }
  }

  Widget _neuralVoiceRow(BuildContext context) {
    final resolved = resolveVoice(_draft.ttsNeuralVoiceId);
    return Row(
      children: [
        Expanded(
          child: Text(
            resolved == null
                ? context.l10n.ttsNoNeuralVoice
                : '${resolved.voice.languageLabel} · ${resolved.voice.label}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: _openVoiceDownloads,
          icon: const Icon(Icons.download_rounded),
          label: Text(context.l10n.ttsManageVoices),
        ),
      ],
    );
  }

  void _openVoiceDownloads() => showAppSheet<void>(
    context: context,
    builder: (_) => VoiceDownloadsSheet(
      downloads: widget.controller.voiceDownloads,
      selectedVoiceId: _draft.ttsNeuralVoiceId,
      rate: _draft.ttsRate,
      onSelected: (id) =>
          setState(() => _draft = _draft.copyWith(ttsNeuralVoiceId: id)),
    ),
  );

  /// One selectable speech backend. Written by hand rather than with
  /// RadioListTile so the unavailable option can still show what it would
  /// be, greyed out, instead of being hidden until it is usable.
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
      onChanged: (value) =>
          setState(() => _draft = _draft.copyWith(ttsVoiceId: value ?? '')),
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
      'light' => _draft.copyWith(themeMode: ThemeMode.light, amoledTheme: false),
      'dark' => _draft.copyWith(themeMode: ThemeMode.dark, amoledTheme: false),
      'amoled' => _draft.copyWith(
        themeMode: ThemeMode.dark,
        amoledTheme: true,
        readerFollowsTheme: true,
        // Keep the explicit reader colours in sync with the AMOLED preset
        // too, not just the follow-theme flag: reader_settings_sheet.dart
        // flips readerFollowsTheme back to false the moment any reader
        // ColorField is touched, and it was falling back to whatever stale
        // (often sepia-brown) colours were stored here before.
        readerBackground: Colors.black,
        readerText: const Color(0xFFF5F5F5),
      ),
      _ => _draft.copyWith(themeMode: ThemeMode.system, amoledTheme: false),
    };
  });
}

/// Offers a newer release: what changed, and where to get it.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.update, this.onDismiss});

  final AppUpdate update;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final apkUrl = update.apkUrl;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.updateAvailable(update.version),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: context.l10n.updateLater,
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  // The notes are GitHub's generated markdown — headings, a
                  // bullet list of commits, a "Full Changelog" link. Rendered
                  // as plain Text they came out as literal `##` and `**`.
                  child: MarkdownBody(
                    data: update.notes,
                    selectable: false,
                    softLineBreak: true,
                    onTapLink: (text, href, title) {
                      if (href != null) _open(context, href);
                    },
                    styleSheet: _notesStyle(context),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (apkUrl != null)
                  FilledButton.icon(
                    onPressed: () => _open(context, apkUrl),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.l10n.updateDownload),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _open(context, update.pageUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(context.l10n.updateOpen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A deliberately small markdown style for the release notes: GitHub's
  /// generated body leads with an `## What's Changed` heading that would
  /// otherwise tower over a card this size.
  MarkdownStyleSheet _notesStyle(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final scheme = theme.colorScheme;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: small,
      listBullet: small,
      a: small?.copyWith(
        color: scheme.primary,
        decoration: TextDecoration.underline,
      ),
      h1: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      h2: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      h3: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      blockSpacing: 6,
      code: small?.copyWith(
        fontFamily: 'Roboto Mono',
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  // The download is handed to the browser and the system installer rather
  // than fetched in-app: an APK this app downloaded still needs the user to
  // approve installing it, so there is nothing to gain by hiding the step.
  //
  // Guarded, because launching can fail for reasons the user can act on —
  // no browser installed, or the address blocked — and a button that throws
  // into the void looks exactly like a button that is broken.
  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.updateOpenFailed(url);
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) messenger.showSnackBar(SnackBar(content: Text(failed)));
    } catch (error) {
      debugPrint('sepia: could not open $url: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}
