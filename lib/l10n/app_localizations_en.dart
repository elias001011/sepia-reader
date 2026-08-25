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
  String get appAppearance => 'App appearance';

  @override
  String get appAppearanceDescription =>
      'Choose the Material theme used by the library and editor.';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get system => 'System';

  @override
  String get dark => 'Dark';

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
  String get saveAppearance => 'Save appearance';

  @override
  String get readerSettings => 'Reading settings';

  @override
  String get readerSettingsDescription =>
      'These settings apply to every document.';

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
}
