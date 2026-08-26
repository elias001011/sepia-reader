import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/tts/neural_tts_engine.dart';
import '../services/tts/tts_engine.dart';
import '../services/tts/voice_catalog.dart';
import '../services/tts/voice_download_manager.dart';
import '../services/tts/voice_store.dart';
import '../widgets/sheet_scaffold.dart';

/// Manages the neural voices stored on the device.
///
/// Organised around the *pack*, not the voice, because that is what a
/// download actually is. Piper ships one voice per model, so the two are the
/// same thing there; Kokoro is a single 400 MB model holding dozens of
/// speakers, and offering to download it once per speaker — as this screen
/// used to — invited the user to fetch the same file eighteen times.
class VoiceDownloadsSheet extends StatefulWidget {
  const VoiceDownloadsSheet({
    super.key,
    required this.downloads,
    required this.selectedVoiceId,
    required this.onSelected,
    required this.rate,
  });

  final VoiceDownloadManager downloads;
  final String selectedVoiceId;
  final ValueChanged<String> onSelected;
  final double rate;

  @override
  State<VoiceDownloadsSheet> createState() => _VoiceDownloadsSheetState();
}

class _VoiceDownloadsSheetState extends State<VoiceDownloadsSheet> {
  late String _selected;

  /// Its own store, only for auditioning: the download manager is typed to
  /// the narrow storage interface, and playing a sample needs the real one.
  final VoiceStore _store = VoiceStore();

  /// Voice currently being auditioned, and the engine doing it. A neural
  /// model takes a moment to load, so the button has to say so.
  String? _previewing;
  TtsEngine? _previewEngine;

  /// Identifies the current audition. Tapping a second voice while the first
  /// is speaking used to release the engine out from under the awaited
  /// `speak()`, which then threw and showed the user an error for something
  /// they had not done.
  int _previewToken = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedVoiceId;
    unawaited(widget.downloads.refreshInstalled());
  }

  @override
  void dispose() {
    unawaited(_previewEngine?.release());
    super.dispose();
  }

  Future<void> _preview(VoicePack pack, NeuralVoice voice) async {
    final sample = context.l10n.ttsPreviewText;
    final wasPlaying = _previewing == voice.id;
    // Whatever was playing stops, and its own invocation learns that it is
    // no longer current from the token rather than from an exception.
    final token = ++_previewToken;
    final previous = _previewEngine;
    _previewEngine = null;
    if (mounted) setState(() => _previewing = null);
    await previous?.release();
    if (wasPlaying || token != _previewToken) return;

    final engine = NeuralTtsEngine(pack: pack, voice: voice, store: _store);
    if (!mounted) return;
    setState(() {
      _previewEngine = engine;
      _previewing = voice.id;
    });
    try {
      await engine.prepare();
      await engine.configure(rate: widget.rate, pitch: 1);
      await engine.speak(sample);
    } catch (error) {
      if (mounted && token == _previewToken) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ttsFailed('$error'))),
        );
      }
    } finally {
      // The model goes back as soon as the sample ends. Holding several
      // hundred megabytes of Kokoro for as long as this sheet happens to be
      // open is exactly what the engine is written to avoid.
      if (token == _previewToken) {
        _previewEngine = null;
        await engine.release();
        if (mounted) setState(() => _previewing = null);
      }
    }
  }

  Future<void> _remove(VoicePack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.l10n.ttsVoiceRemoveConfirm(pack.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.ttsVoiceRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _previewEngine?.release();
    await widget.downloads.remove(pack);
    if (!mounted) return;
    if (pack.voices.any((voice) => voice.id == _selected)) {
      setState(() => _selected = '');
      widget.onSelected('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        final light = voicePacks
            .where((pack) => pack.tier == NeuralVoiceTier.light)
            .toList();
        final best = voicePacks
            .where((pack) => pack.tier == NeuralVoiceTier.best)
            .toList();
        return SheetScaffold(
          title: context.l10n.ttsVoicesTitle,
          description: context.l10n.ttsVoicesDescription,
          children: [
            if (!widget.downloads.hasLoadedInstalled)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _tierHeader(
                context,
                context.l10n.ttsTierLight,
                context.l10n.ttsTierLightHint,
              ),
              ..._groupedByLanguage(light),
              _tierHeader(
                context,
                context.l10n.ttsTierBest,
                context.l10n.ttsTierBestHint,
              ),
              for (final pack in best) ..._kokoroPack(context, pack),
            ],
          ],
        );
      },
    );
  }

  Widget _tierHeader(BuildContext context, String title, String hint) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  /// Piper packs, grouped by the language of their single voice.
  List<Widget> _groupedByLanguage(List<VoicePack> packs) {
    final byLanguage = <String, List<VoicePack>>{};
    for (final pack in packs) {
      byLanguage.putIfAbsent(pack.voices.first.language, () => []).add(pack);
    }
    final languages = byLanguage.keys.toList()
      ..sort((a, b) => languageLabelFor(a).compareTo(languageLabelFor(b)));
    return [
      for (final language in languages) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
          child: Text(
            languageLabelFor(language),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final pack in byLanguage[language]!)
          _packTile(context, pack, pack.voices.first),
      ],
    ];
  }

  /// The one multi-speaker pack: a single download, then a voice list.
  List<Widget> _kokoroPack(BuildContext context, VoicePack pack) {
    final installed = widget.downloads.isInstalled(pack);
    final byLanguage = <String, List<NeuralVoice>>{};
    for (final voice in pack.voices) {
      byLanguage.putIfAbsent(voice.language, () => []).add(voice);
    }
    return [
      _packTile(context, pack, null),
      if (installed)
        for (final entry in byLanguage.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 4, 2),
            child: Text(
              languageLabelFor(entry.key),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final voice in entry.value)
            _voiceRow(context, pack, voice, indent: 20),
        ],
    ];
  }

  /// A downloadable pack. [soleVoice] is set when the pack has exactly one,
  /// in which case the row doubles as that voice's row.
  Widget _packTile(BuildContext context, VoicePack pack, NeuralVoice? soleVoice) {
    final installed = widget.downloads.isInstalled(pack);
    final job = widget.downloads.jobFor(pack);
    final megabytes = (pack.approxBytes / (1024 * 1024)).round();

    if (installed && soleVoice != null) {
      return _voiceRow(context, pack, soleVoice, onRemove: () => _remove(pack));
    }

    final Widget trailing;
    if (job != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (job.state == VoiceDownloadState.failed)
            IconButton(
              tooltip: context.l10n.ttsVoiceInstall,
              onPressed: () {
                widget.downloads.dismiss(pack);
                widget.downloads.enqueue(pack);
              },
              icon: const Icon(Icons.refresh_rounded),
            )
          else
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: job.state == VoiceDownloadState.queued || job.fraction == 0
                    ? null
                    : job.fraction,
              ),
            ),
          IconButton(
            tooltip: context.l10n.ttsVoiceCancel,
            onPressed: () => widget.downloads.cancel(pack),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
    } else if (installed) {
      trailing = IconButton(
        tooltip: context.l10n.ttsVoiceRemove,
        onPressed: () => _remove(pack),
        icon: const Icon(Icons.delete_outline_rounded),
      );
    } else {
      trailing = FilledButton.tonal(
        onPressed: () => widget.downloads.enqueue(pack),
        child: Text(context.l10n.ttsVoiceInstall),
      );
    }

    final subtitle = switch (job?.state) {
      VoiceDownloadState.queued => context.l10n.ttsVoiceQueued,
      VoiceDownloadState.running => context.l10n.ttsVoiceDownloading(
        (job!.fraction * 100).round(),
      ),
      VoiceDownloadState.failed => context.l10n.ttsVoiceInstallFailed(
        job!.error ?? '?',
      ),
      null => installed
          ? context.l10n.ttsVoiceInstalled
          : pack.isKokoro
          ? '${context.l10n.ttsVoiceSize(megabytes)} · '
                '${context.l10n.ttsVoiceCount(pack.voices.length)}'
          : context.l10n.ttsVoiceSize(megabytes),
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        installed ? Icons.download_done_rounded : Icons.download_rounded,
        color: installed ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(pack.label),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing,
    );
  }

  /// An installed voice: audition it, use it, and (for a one-voice pack)
  /// remove the model behind it.
  Widget _voiceRow(
    BuildContext context,
    VoicePack pack,
    NeuralVoice voice, {
    double indent = 0,
    VoidCallback? onRemove,
  }) {
    final selected = _selected == voice.id;
    final playing = _previewing == voice.id;
    return ListTile(
      contentPadding: EdgeInsets.only(left: indent),
      leading: IconButton(
        tooltip: playing ? context.l10n.ttsStop : context.l10n.ttsPreview,
        onPressed: () => _preview(pack, voice),
        icon: Icon(
          playing ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
          size: 30,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(voice.label),
      subtitle: Text(
        selected ? context.l10n.ttsVoiceInUse : voice.languageLabel,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          else
            TextButton(
              onPressed: () {
                setState(() => _selected = voice.id);
                widget.onSelected(voice.id);
              },
              child: Text(context.l10n.ttsVoiceUse),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: context.l10n.ttsVoiceRemove,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}
