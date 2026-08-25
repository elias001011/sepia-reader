import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/tts/voice_catalog.dart';
import '../services/tts/voice_store.dart';

/// Manages the neural voices stored on the device.
///
/// The download is the whole cost of this feature — tens to hundreds of
/// megabytes, once — so it is deliberately explicit: sizes up front, real
/// progress, cancellable mid-way, and removable afterwards. Nothing is
/// fetched because a switch was flipped.
class VoiceDownloadsSheet extends StatefulWidget {
  const VoiceDownloadsSheet({
    super.key,
    required this.store,
    required this.selectedVoiceId,
    required this.onSelected,
  });

  final VoiceStore store;
  final String selectedVoiceId;
  final ValueChanged<String> onSelected;

  @override
  State<VoiceDownloadsSheet> createState() => _VoiceDownloadsSheetState();
}

class _VoiceDownloadsSheetState extends State<VoiceDownloadsSheet> {
  final Set<String> _installed = {};
  final Map<String, VoiceInstallProgress> _progress = {};
  final Set<String> _cancelling = {};
  late String _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedVoiceId;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final installed = await widget.store.installedVoices();
    if (!mounted) return;
    setState(() {
      _installed
        ..clear()
        ..addAll(installed.map((voice) => voice.id));
      _loading = false;
    });
  }

  Future<void> _install(NeuralVoice voice) async {
    setState(() {
      _progress[voice.id] = const VoiceInstallProgress(
        filesDone: 0,
        filesTotal: 0,
        bytesDone: 0,
        bytesTotal: 0,
      );
    });
    try {
      await widget.store.install(
        voice,
        onProgress: (progress) {
          if (mounted) setState(() => _progress[voice.id] = progress);
        },
        shouldCancel: () => _cancelling.contains(voice.id),
      );
      // Voices sharing a model are all installed at once.
      for (final shared in voicesSharing(voice)) {
        _installed.add(shared.id);
      }
      if (_selected.isEmpty) {
        _selected = voice.id;
        widget.onSelected(voice.id);
      }
    } on VoiceInstallCancelled {
      await widget.store.remove(voice);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ttsVoiceInstallFailed('$error'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _progress.remove(voice.id);
          _cancelling.remove(voice.id);
        });
      }
    }
  }

  Future<void> _remove(NeuralVoice voice) async {
    final shared = voicesSharing(voice);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(
          dialogContext.l10n.ttsVoiceRemoveConfirm(voice.label),
        ),
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
    await widget.store.remove(voice);
    if (!mounted) return;
    setState(() {
      for (final other in shared) {
        _installed.remove(other.id);
        if (_selected == other.id) {
          _selected = '';
          widget.onSelected('');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Grouped by how heavy they are rather than by language: the download
    // size is the decision being made here, and it is the one thing a phone
    // with little room left cares about.
    final byTier = <NeuralVoiceTier, List<NeuralVoice>>{};
    for (final voice in neuralVoices) {
      byTier.putIfAbsent(voice.tier, () => []).add(voice);
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text(
                context.l10n.ttsVoicesTitle,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.l10n.ttsVoicesDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tier in NeuralVoiceTier.values)
                      if (byTier[tier] case final voices?) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 2),
                          child: Text(
                            tier == NeuralVoiceTier.light
                                ? context.l10n.ttsTierLight
                                : context.l10n.ttsTierBest,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                          child: Text(
                            tier == NeuralVoiceTier.light
                                ? context.l10n.ttsTierLightHint
                                : context.l10n.ttsTierBestHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        for (final voice in voices) _voiceTile(context, voice),
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _voiceTile(BuildContext context, NeuralVoice voice) {
    final installed = _installed.contains(voice.id);
    final progress = _progress[voice.id];
    final selected = _selected == voice.id;
    final megabytes = (voice.approxBytes / (1024 * 1024)).round();

    Widget trailing;
    if (progress != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: progress.bytesTotal == 0 ? null : progress.fraction,
            ),
          ),
          IconButton(
            tooltip: context.l10n.ttsVoiceCancel,
            onPressed: () => setState(() => _cancelling.add(voice.id)),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
    } else if (installed) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!selected)
            TextButton(
              onPressed: () {
                setState(() => _selected = voice.id);
                widget.onSelected(voice.id);
              },
              child: Text(context.l10n.ttsVoiceUse),
            ),
          IconButton(
            tooltip: context.l10n.ttsVoiceRemove,
            onPressed: () => _remove(voice),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      );
    } else {
      trailing = FilledButton.tonal(
        onPressed: () => _install(voice),
        child: Text(context.l10n.ttsVoiceInstall),
      );
    }

    final subtitleParts = <String>[
      if (progress != null)
        context.l10n.ttsVoiceDownloading((progress.fraction * 100).round())
      else if (selected)
        context.l10n.ttsVoiceInUse
      else if (installed)
        context.l10n.ttsVoiceInstalled
      else
        context.l10n.ttsVoiceSize(megabytes),
      if (voice.note == 'kokoro-heavy') context.l10n.ttsVoiceHeavy,
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(
        selected
            ? Icons.record_voice_over_rounded
            : Icons.graphic_eq_rounded,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text('${voice.label} · ${voice.languageLabel}'),
      subtitle: Text(
        subtitleParts.join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: trailing,
    );
  }
}
