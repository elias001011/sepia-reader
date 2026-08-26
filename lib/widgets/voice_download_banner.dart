import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/tts/voice_download_manager.dart';

/// Shows a voice download that is still running.
///
/// The download outlives the screen that started it, which is only useful if
/// it is still visible from somewhere — otherwise "it kept going" is
/// indistinguishable from "it silently stopped".
class VoiceDownloadBanner extends StatelessWidget {
  const VoiceDownloadBanner({super.key, required this.downloads});

  final VoiceDownloadManager downloads;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: downloads,
    builder: (context, _) {
      final jobs = downloads.jobs
          .where((job) => job.state != VoiceDownloadState.failed)
          .toList();
      if (jobs.isEmpty) return const SizedBox.shrink();
      final current = jobs.first;
      final waiting = jobs.length - 1;
      final scheme = Theme.of(context).colorScheme;
      return Card(
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: current.fraction == 0 ? null : current.fraction,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.voiceDownloadRunning(
                        current.pack.label,
                        (current.fraction * 100).round(),
                      ),
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      waiting > 0
                          ? context.l10n.voiceDownloadQueued(waiting)
                          : context.l10n.voiceDownloadBackgroundHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.ttsVoiceCancel,
                onPressed: () => downloads.cancel(current.pack),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      );
    },
  );
}
