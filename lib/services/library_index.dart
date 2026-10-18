import '../models/library_document.dart';
import '../models/library_folder.dart';

/// Built only when a library snapshot changes. Counts propagate once per
/// folder instead of walking every document up its ancestor chain on rebuild.
class LibraryIndex {
  LibraryIndex(List<LibraryDocument> documents, List<LibraryFolder> folders) {
    for (final folder in folders) {
      folderById[folder.id] = folder;
      (foldersByParent[folder.parentId] ??= []).add(folder);
      if (folder.parentId != null) {
        childFolderCounts.update(
          folder.parentId!,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final document in documents) {
      (documentsByFolder[document.folderId] ??= []).add(document);
      if (document.folderId != null) {
        folderDocumentCounts.update(
          document.folderId!,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final pending = {
      for (final f in folders) f.id: childFolderCounts[f.id] ?? 0,
    };
    final ready = [
      for (final f in folders)
        if (pending[f.id] == 0) f.id,
    ];
    while (ready.isNotEmpty) {
      final id = ready.removeLast();
      final parent = folderById[id]?.parentId;
      if (parent == null || !pending.containsKey(parent)) continue;
      folderDocumentCounts.update(
        parent,
        (n) => n + (folderDocumentCounts[id] ?? 0),
        ifAbsent: () => folderDocumentCounts[id] ?? 0,
      );
      pending[parent] = pending[parent]! - 1;
      if (pending[parent] == 0) ready.add(parent);
    }
  }

  final Map<String, LibraryFolder> folderById = {};
  final Map<String?, List<LibraryFolder>> foldersByParent = {};
  final Map<String?, List<LibraryDocument>> documentsByFolder = {};
  final Map<String, int> childFolderCounts = {};
  final Map<String, int> folderDocumentCounts = {};
}
