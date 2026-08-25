import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/document_sections.dart';

/// Asks where to start listening.
///
/// A document with `#`/`##` headings lists them, so a fic can be picked up at
/// chapter seven instead of always from the top; one without them offers the
/// whole thing, which is the only honest option when there is nothing to cut
/// along.
class ListenSheet extends StatelessWidget {
  const ListenSheet({
    super.key,
    required this.sections,
    required this.onPick,
    this.currentChunkIndex,
  });

  final List<DocumentSection> sections;
  final ValueChanged<DocumentSection> onPick;

  /// Chunk currently on screen, used to offer "start where I left off".
  final int? currentChunkIndex;

  @override
  Widget build(BuildContext context) {
    final chapters = sections.where((section) => section.level > 0).toList();
    final whole = DocumentSection(
      title: context.l10n.ttsWholeDocument,
      level: 0,
      startChunk: 0,
      endChunk: sections.isEmpty ? 0 : sections.last.endChunk,
    );
    final here = currentChunkIndex;
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
                context.l10n.ttsChooseChapter,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                chapters.isEmpty
                    ? context.l10n.ttsNoChapters
                    : context.l10n.ttsChapterCount(chapters.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_circle_fill_rounded),
                    title: Text(context.l10n.ttsWholeDocument),
                    onTap: () => onPick(whole),
                  ),
                  if (here != null && here > 0)
                    ListTile(
                      leading: const Icon(Icons.my_location_rounded),
                      title: Text(context.l10n.ttsFromHere),
                      onTap: () => onPick(
                        DocumentSection(
                          title: context.l10n.ttsFromHere,
                          level: 0,
                          startChunk: here,
                          endChunk: whole.endChunk,
                        ),
                      ),
                    ),
                  if (chapters.isNotEmpty) const Divider(),
                  for (final chapter in chapters)
                    ListTile(
                      contentPadding: EdgeInsets.only(
                        left: chapter.level == 1 ? 16 : 34,
                        right: 16,
                      ),
                      leading: Icon(
                        chapter.level == 1
                            ? Icons.bookmark_rounded
                            : Icons.subdirectory_arrow_right_rounded,
                        size: chapter.level == 1 ? 22 : 18,
                      ),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          fontWeight: chapter.level == 1
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      onTap: () => onPick(chapter),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
