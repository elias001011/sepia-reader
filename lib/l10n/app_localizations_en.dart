// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sépia';

  @override
  String get appAppearance => 'Settings';

  @override
  String get appAppearanceDescription =>
      'Theme, language, syncing and reading aloud. The button at the end saves everything on this screen.';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get system => 'System';

  @override
  String get dark => 'Dark';

  @override
  String get amoled => 'AMOLED';

  @override
  String get language => 'Language';

  @override
  String get portugueseBrazil => 'Português (Brasil)';

  @override
  String get english => 'English';

  @override
  String get primaryColor => 'Primary color';

  @override
  String get lightThemeBackground => 'Light theme background';

  @override
  String get darkThemeBackground => 'Dark theme background';

  @override
  String get readerThemeHint =>
      'Reading colors are independent unless “Follow app theme” is enabled in Reading settings.';

  @override
  String get autoHideReaderControls => 'Hide controls while reading';

  @override
  String get autoHideReaderControlsDescription =>
      'In reading mode, hide controls after a moment or while scrolling. Tap the top to show them.';

  @override
  String get saveAppearance => 'Save';

  @override
  String get readerSettings => 'Reading settings';

  @override
  String get readerSettingsDescription =>
      'These settings apply to every document.';

  @override
  String get followAppTheme => 'Follow app theme';

  @override
  String get followAppThemeDescription =>
      'Use the current app surfaces and text colors while reading.';

  @override
  String get presets => 'Presets';

  @override
  String get sepiaPreset => 'Sépia';

  @override
  String get artifactPreset => 'Artifact';

  @override
  String get paperPreset => 'Paper';

  @override
  String get nightPreset => 'Night';

  @override
  String get font => 'Font';

  @override
  String get systemFont => 'System';

  @override
  String get size => 'Size';

  @override
  String get lineHeight => 'Line height';

  @override
  String get pageWidth => 'Page width';

  @override
  String get readerBackground => 'Reading background';

  @override
  String get textColor => 'Text color';

  @override
  String get applyReading => 'Apply to reading';

  @override
  String get hexColor => 'Hex color';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get newLabel => 'New';

  @override
  String get appearance => 'Appearance';

  @override
  String get importLabel => 'Import';

  @override
  String get newDocument => 'New document';

  @override
  String get libraryHero => 'Your library,\nat your pace.';

  @override
  String get libraryHeroDescription =>
      'Read without noise. Write without leaving.';

  @override
  String get searchHint => 'Search by title or content…';

  @override
  String get importFiles => 'Import files';

  @override
  String get importFolder => 'Import folder';

  @override
  String get compatibleFilesOnly =>
      'Only compatible text and code files will be added.';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get folderNameHint => 'Books to read';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get renameDocument => 'Rename file';

  @override
  String get rename => 'Rename';

  @override
  String get root => 'Library root';

  @override
  String get moveTo => 'Move to…';

  @override
  String get moveDocument => 'Move document';

  @override
  String get openFolder => 'Open folder';

  @override
  String get folderNotEmpty =>
      'This folder is not empty. Move or delete its contents first.';

  @override
  String get noCompatibleFiles =>
      'No compatible files were found in this folder.';

  @override
  String folderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '1 folder',
      zero: 'no folders',
    );
    return '$_temp0';
  }

  @override
  String folderContents(int files, int folders) {
    return '$files files · $folders folders';
  }

  @override
  String folderImported(int imported, int skipped) {
    return '$imported compatible files imported · $skipped skipped';
  }

  @override
  String filesImported(int imported, int skipped) {
    return '$imported files imported · $skipped skipped';
  }

  @override
  String get dropFilesHere => 'Drop files to import';

  @override
  String get dropFilesHint => 'Markdown, text, or code · up to 5 MB per file';

  @override
  String get libraryTitle => 'Library';

  @override
  String get results => 'Results';

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
      zero: 'no files',
    );
    return '$_temp0';
  }

  @override
  String get nextReading => 'Your next read starts here';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get emptyLibraryHelp =>
      'Create a Markdown document or import a text file.';

  @override
  String get emptySearchHelp => 'Try another search term.';

  @override
  String get fileName => 'File name';

  @override
  String get fileNameHint => 'My notes';

  @override
  String get format => 'Format';

  @override
  String get markdownFormat => 'Markdown (.md)';

  @override
  String get plainTextFormat => 'Plain text (.txt)';

  @override
  String get create => 'Create';

  @override
  String importedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files imported.',
      one: '1 file imported.',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String error) {
    return 'Could not import: $error';
  }

  @override
  String get exported => 'File exported.';

  @override
  String exportFailed(String error) {
    return 'Could not export: $error';
  }

  @override
  String get deleteFileQuestion => 'Delete file?';

  @override
  String deleteFileDescription(String filename) {
    return '“$filename” will be removed from the library.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Remove favorite';

  @override
  String get exportLabel => 'Export';

  @override
  String get emptyDocument => 'Empty document — tap to begin.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get now => 'now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String daysAgo(int count) {
    return '$count d ago';
  }

  @override
  String get documentNotFound => 'Document not found.';

  @override
  String get untitled => 'Untitled';

  @override
  String get readingSettings => 'Reading settings';

  @override
  String get readingMode => 'Reading mode';

  @override
  String get editorLabel => 'EDITOR';

  @override
  String get readingLabel => 'READING';

  @override
  String get startWriting => 'Start writing…';

  @override
  String get edit => 'Edit';

  @override
  String get preview => 'Preview';

  @override
  String get undoSession => 'Undo · this session only';

  @override
  String get redoSession => 'Redo · this session only';

  @override
  String get heading => 'Heading';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get quote => 'Quote';

  @override
  String get list => 'List';

  @override
  String get code => 'Code';

  @override
  String get link => 'Link';

  @override
  String get horizontalRule => 'Horizontal rule';

  @override
  String get textPlaceholder => 'text';

  @override
  String get codePlaceholder => 'code';

  @override
  String readingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min read',
      one: '1 min read',
    );
    return '$_temp0';
  }

  @override
  String get backToLibrary => 'Back to library';

  @override
  String get adjustments => 'Adjustments';

  @override
  String get exitReadingMode => 'Exit reading mode';

  @override
  String get addBookmark => 'Bookmark this spot';

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get bookmarksEmpty =>
      'No bookmarks yet. Tap the bookmark icon on the reading bar to save where you left off.';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get goToBookmark => 'Go to bookmark';

  @override
  String get syncSection => 'Sync';

  @override
  String get syncWithServer => 'Sync with the server';

  @override
  String get syncWithServerDescription =>
      'Keeps the library identical on every device that opens this server.';

  @override
  String get syncServerAddress => 'Server address';

  @override
  String get syncServerAddressHint =>
      'Empty: use the address the app was opened from';

  @override
  String get syncTestConnection => 'Test connection';

  @override
  String get syncTesting => 'Testing…';

  @override
  String syncTestOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connected. $count documents on the server.',
      one: 'Connected. 1 document on the server.',
    );
    return '$_temp0';
  }

  @override
  String syncTestFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get syncOff => 'Sync is off';

  @override
  String get syncNever => 'Not synced yet';

  @override
  String syncLast(String time) {
    return 'Last sync: $time';
  }

  @override
  String get syncDisabledTitle => 'Turn syncing off';

  @override
  String get syncDisabledBody =>
      'From now on this device stops sending and receiving changes. The library that is here stays whole, whatever you choose.\n\nWhat is left to decide is the copy already on the server:\n\n• Keep on server — the copy stays there, untouched. Other devices that sync keep it, and if you turn syncing back on here the two sides merge again.\n\n• Erase from server — the server copy is emptied now. Other devices that sync will receive that deletion and lose those documents too. This device loses nothing.';

  @override
  String get syncKeepOnServer => 'Keep on server';

  @override
  String get syncWipeFromServer => 'Erase from server';

  @override
  String get syncWipeFailed =>
      'Syncing is off, but the copy on the server could not be erased. It is still there.';

  @override
  String get syncWipeDone => 'Server copy erased.';

  @override
  String get syncPullDone => 'Library synced with the server.';

  @override
  String get syncPullFailed =>
      'Could not reach the server. Your local library is untouched.';

  @override
  String get syncPullDisabled =>
      'Syncing is off. Turn it on in settings to use this gesture.';

  @override
  String deleteFolderTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteFolderEmptyBody =>
      'The folder is empty. It will be deleted.';

  @override
  String deleteFolderBody(int documents, int subfolders) {
    String _temp0 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents documents',
      one: '1 document',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subfolders,
      locale: localeName,
      other: '$subfolders subfolders',
      one: '1 subfolder',
      zero: 'no subfolders',
    );
    return 'This also deletes $_temp0 and $_temp1. This cannot be undone.';
  }

  @override
  String folderDeleted(String name) {
    return '“$name” was deleted.';
  }

  @override
  String unsupportedBinaryFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count files were turned away: they are not text (for example .docx or .pdf).',
      one:
          '1 file was turned away: it is not text (for example .docx or .pdf).',
    );
    return '$_temp0';
  }

  @override
  String get ttsSection => 'Read aloud';

  @override
  String get ttsEnable => 'Enable reading aloud';

  @override
  String get ttsEnableDescription => 'Adds a listen button to reading mode.';

  @override
  String get ttsEngineLabel => 'Voice';

  @override
  String get ttsEngineSystem => 'System voice';

  @override
  String get ttsEngineSystemDescription =>
      'Uses the voice Android or your browser already has. Nothing to download, works offline.';

  @override
  String get ttsEngineNeural => 'Local neural model (in progress)';

  @override
  String get ttsEngineNeuralDescription =>
      'A far more natural voice, running on the device itself. Not available in this version yet — follow along at github.com/elias001011/sepia-reader/issues/1.';

  @override
  String get ttsVoice => 'Voice';

  @override
  String get ttsVoiceAuto => 'Choose automatically';

  @override
  String get ttsRate => 'Speed';

  @override
  String get ttsPitch => 'Pitch';

  @override
  String get ttsPreview => 'Play a sample';

  @override
  String get ttsPreviewText =>
      'This is the voice that will read your documents.';

  @override
  String get ttsNoVoices => 'No voices found on this device.';

  @override
  String get ttsLoadingVoices => 'Looking for voices…';

  @override
  String get ttsListen => 'Listen';

  @override
  String get ttsChooseChapter => 'Listen from';

  @override
  String get ttsWholeDocument => 'Read the whole document';

  @override
  String get ttsNoChapters =>
      'This document has no chapters (#/##), so you can listen to all of it.';

  @override
  String ttsChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String get ttsFromHere => 'Start where I left off';

  @override
  String get ttsStop => 'Stop';

  @override
  String get ttsPause => 'Pause';

  @override
  String get ttsResume => 'Continue';

  @override
  String get ttsPrevious => 'Previous passage';

  @override
  String get ttsNext => 'Next passage';

  @override
  String ttsFailed(String error) {
    return 'Reading aloud failed: $error';
  }

  @override
  String get ttsNothingToRead => 'There is no text to read in this part.';

  @override
  String ttsProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get viewerSource => 'Source';

  @override
  String get viewerPreview => 'Preview';

  @override
  String get viewerCodeLabel => 'Code viewer';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get editSectionTitle => 'Editing in parts';

  @override
  String editSectionPosition(int current, int total) {
    return '$current/$total';
  }

  @override
  String get editSectionHint =>
      'Large document: the editor loads one part at a time so typing stays fast. The whole document is still saved, and reading mode shows all of it.';

  @override
  String get editSectionPrevious => 'Previous part';

  @override
  String get editSectionNext => 'Next part';

  @override
  String get editSectionChoose => 'Choose part';

  @override
  String get editWholeDocument => 'Edit the whole document (may be slow)';

  @override
  String editSectionPart(String number) {
    return 'Part $number';
  }
}
