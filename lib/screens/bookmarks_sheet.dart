import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bookmark.dart';

class BookmarksSheet extends StatelessWidget {
  const BookmarksSheet({
    super.key,
    required this.bookmarks,
    required this.onOpen,
    required this.onRemove,
  });

  final List<ReadingBookmark> bookmarks;
  final ValueChanged<ReadingBookmark> onOpen;
  final ValueChanged<ReadingBookmark> onRemove;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.bookmarks,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          if (bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(
                context.l10n.bookmarksEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return ListTile(
                    leading: const Icon(Icons.bookmark_rounded),
                    title: Text(
                      bookmark.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${(bookmark.scrollFraction * 100).round()}% · '
                      '${MaterialLocalizations.of(context).formatCompactDate(bookmark.createdAt)}',
                    ),
                    trailing: IconButton(
                      tooltip: context.l10n.removeBookmark,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => onRemove(bookmark),
                    ),
                    onTap: () => onOpen(bookmark),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
