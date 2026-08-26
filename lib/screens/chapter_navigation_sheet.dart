import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/document_sections.dart';
import '../widgets/sheet_scaffold.dart';

/// Asks which chapter to jump to in reading mode.
///
/// Reuses the same chapter detection as TTS ([sectionsOf]), but without any
/// speech logic — pure navigation.
class ChapterNavigationSheet extends StatelessWidget {
  const ChapterNavigationSheet({
    super.key,
    required this.sections,
    required this.currentChunkIndex,
    required this.onPick,
  });

  final List<DocumentSection> sections;

  /// Chunk currently on screen, used to highlight "resume from here".
  final int currentChunkIndex;

  /// Called with the chosen section so the caller can scroll to it.
  final ValueChanged<DocumentSection> onPick;

  @override
  Widget build(BuildContext context) {
    final chapters = sections.where((s) => s.level > 0).toList();
    final whole = DocumentSection(
      title: context.l10n.ttsWholeDocument,
      level: 0,
      startChunk: 0,
      endChunk: sections.isEmpty ? 0 : sections.last.endChunk,
    );
    final resumeOffered = currentChunkIndex > 0;
    final leading = resumeOffered ? 2 : 1;
    final dividerAt = chapters.isEmpty ? -1 : leading;

    return SheetScaffold.list(
      title: context.l10n.chapterNavigation,
      description: chapters.isEmpty
          ? context.l10n.ttsNoChapters
          : context.l10n.ttsChapterCount(chapters.length),
      itemCount: leading + (chapters.isEmpty ? 0 : 1 + chapters.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.vertical_align_top_rounded),
            title: Text(context.l10n.ttsWholeDocument),
            onTap: () => onPick(whole),
          );
        }
        if (resumeOffered && index == 1) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.my_location_rounded),
            title: Text(context.l10n.chapterNavigationHere),
            onTap: () => onPick(
              DocumentSection(
                title: context.l10n.chapterNavigationHere,
                level: 0,
                startChunk: currentChunkIndex,
                endChunk: whole.endChunk,
              ),
            ),
          );
        }
        if (index == dividerAt) return const Divider();
        final chapter = chapters[index - dividerAt - 1];
        return ListTile(
          contentPadding: EdgeInsets.only(left: chapter.level == 1 ? 0 : 18),
          leading: Icon(
            chapter.level == 1
                ? Icons.bookmark_rounded
                : Icons.subdirectory_arrow_right_rounded,
            size: chapter.level == 1 ? 22 : 18,
          ),
          title: Text(
            chapter.title,
            style: TextStyle(
              fontWeight:
                  chapter.level == 1 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          onTap: () => onPick(chapter),
        );
      },
    );
  }
}
