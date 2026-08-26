import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bookmark.dart';
import '../widgets/sheet_scaffold.dart';

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
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return SheetScaffold(
        title: context.l10n.bookmarks,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            child: Text(
              context.l10n.bookmarksEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    return SheetScaffold.list(
      title: context.l10n.bookmarks,
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bookmark_rounded),
          title: Text(
            bookmark.excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            MaterialLocalizations.of(
              context,
            ).formatCompactDate(bookmark.createdAt),
          ),
          trailing: IconButton(
            tooltip: context.l10n.removeBookmark,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => onRemove(bookmark),
          ),
          onTap: () => onOpen(bookmark),
        );
      },
    );
  }
}
