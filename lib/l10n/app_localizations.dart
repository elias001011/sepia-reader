import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sépia'**
  String get appTitle;

  /// No description provided for @appAppearance.
  ///
  /// In en, this message translates to:
  /// **'App appearance'**
  String get appAppearance;

  /// No description provided for @appAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the Material theme used by the library and editor.'**
  String get appAppearanceDescription;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @amoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED'**
  String get amoled;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @portugueseBrazil.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get portugueseBrazil;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @primaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get primaryColor;

  /// No description provided for @lightThemeBackground.
  ///
  /// In en, this message translates to:
  /// **'Light theme background'**
  String get lightThemeBackground;

  /// No description provided for @darkThemeBackground.
  ///
  /// In en, this message translates to:
  /// **'Dark theme background'**
  String get darkThemeBackground;

  /// No description provided for @readerThemeHint.
  ///
  /// In en, this message translates to:
  /// **'Reading colors are independent unless “Follow app theme” is enabled in Reading settings.'**
  String get readerThemeHint;

  /// No description provided for @autoHideReaderControls.
  ///
  /// In en, this message translates to:
  /// **'Hide controls while reading'**
  String get autoHideReaderControls;

  /// No description provided for @autoHideReaderControlsDescription.
  ///
  /// In en, this message translates to:
  /// **'In reading mode, hide controls after a moment or while scrolling. Tap the top to show them.'**
  String get autoHideReaderControlsDescription;

  /// No description provided for @saveAppearance.
  ///
  /// In en, this message translates to:
  /// **'Save appearance'**
  String get saveAppearance;

  /// No description provided for @readerSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readerSettings;

  /// No description provided for @readerSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'These settings apply to every document.'**
  String get readerSettingsDescription;

  /// No description provided for @followAppTheme.
  ///
  /// In en, this message translates to:
  /// **'Follow app theme'**
  String get followAppTheme;

  /// No description provided for @followAppThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the current app surfaces and text colors while reading.'**
  String get followAppThemeDescription;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @sepiaPreset.
  ///
  /// In en, this message translates to:
  /// **'Sépia'**
  String get sepiaPreset;

  /// No description provided for @artifactPreset.
  ///
  /// In en, this message translates to:
  /// **'Artifact'**
  String get artifactPreset;

  /// No description provided for @paperPreset.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paperPreset;

  /// No description provided for @nightPreset.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get nightPreset;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @systemFont.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemFont;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @lineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get lineHeight;

  /// No description provided for @pageWidth.
  ///
  /// In en, this message translates to:
  /// **'Page width'**
  String get pageWidth;

  /// No description provided for @readerBackground.
  ///
  /// In en, this message translates to:
  /// **'Reading background'**
  String get readerBackground;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get textColor;

  /// No description provided for @applyReading.
  ///
  /// In en, this message translates to:
  /// **'Apply to reading'**
  String get applyReading;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get hexColor;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @newDocument.
  ///
  /// In en, this message translates to:
  /// **'New document'**
  String get newDocument;

  /// No description provided for @libraryHero.
  ///
  /// In en, this message translates to:
  /// **'Your library,\nat your pace.'**
  String get libraryHero;

  /// No description provided for @libraryHeroDescription.
  ///
  /// In en, this message translates to:
  /// **'Read without noise. Write without leaving.'**
  String get libraryHeroDescription;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title or content…'**
  String get searchHint;

  /// No description provided for @importFiles.
  ///
  /// In en, this message translates to:
  /// **'Import files'**
  String get importFiles;

  /// No description provided for @importFolder.
  ///
  /// In en, this message translates to:
  /// **'Import folder'**
  String get importFolder;

  /// No description provided for @compatibleFilesOnly.
  ///
  /// In en, this message translates to:
  /// **'Only compatible text and code files will be added.'**
  String get compatibleFilesOnly;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @folderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Books to read'**
  String get folderNameHint;

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// No description provided for @renameDocument.
  ///
  /// In en, this message translates to:
  /// **'Rename file'**
  String get renameDocument;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @root.
  ///
  /// In en, this message translates to:
  /// **'Library root'**
  String get root;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveTo;

  /// No description provided for @moveDocument.
  ///
  /// In en, this message translates to:
  /// **'Move document'**
  String get moveDocument;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// No description provided for @folderNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is not empty. Move or delete its contents first.'**
  String get folderNotEmpty;

  /// No description provided for @noCompatibleFiles.
  ///
  /// In en, this message translates to:
  /// **'No compatible files were found in this folder.'**
  String get noCompatibleFiles;

  /// No description provided for @folderCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no folders} =1{1 folder} other{{count} folders}}'**
  String folderCount(int count);

  /// No description provided for @folderContents.
  ///
  /// In en, this message translates to:
  /// **'{files} files · {folders} folders'**
  String folderContents(int files, int folders);

  /// No description provided for @folderImported.
  ///
  /// In en, this message translates to:
  /// **'{imported} compatible files imported · {skipped} skipped'**
  String folderImported(int imported, int skipped);

  /// No description provided for @filesImported.
  ///
  /// In en, this message translates to:
  /// **'{imported} files imported · {skipped} skipped'**
  String filesImported(int imported, int skipped);

  /// No description provided for @dropFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop files to import'**
  String get dropFilesHere;

  /// No description provided for @dropFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Markdown, text, or code · up to 5 MB per file'**
  String get dropFilesHint;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no files} =1{1 file} other{{count} files}}'**
  String fileCount(int count);

  /// No description provided for @nextReading.
  ///
  /// In en, this message translates to:
  /// **'Your next read starts here'**
  String get nextReading;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @emptyLibraryHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a Markdown document or import a text file.'**
  String get emptyLibraryHelp;

  /// No description provided for @emptySearchHelp.
  ///
  /// In en, this message translates to:
  /// **'Try another search term.'**
  String get emptySearchHelp;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @fileNameHint.
  ///
  /// In en, this message translates to:
  /// **'My notes'**
  String get fileNameHint;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @markdownFormat.
  ///
  /// In en, this message translates to:
  /// **'Markdown (.md)'**
  String get markdownFormat;

  /// No description provided for @plainTextFormat.
  ///
  /// In en, this message translates to:
  /// **'Plain text (.txt)'**
  String get plainTextFormat;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @importedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file imported.} other{{count} files imported.}}'**
  String importedCount(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import: {error}'**
  String importFailed(String error);

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'File exported.'**
  String get exported;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export: {error}'**
  String exportFailed(String error);

  /// No description provided for @deleteFileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete file?'**
  String get deleteFileQuestion;

  /// No description provided for @deleteFileDescription.
  ///
  /// In en, this message translates to:
  /// **'“{filename}” will be removed from the library.'**
  String deleteFileDescription(String filename);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get unfavorite;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @emptyDocument.
  ///
  /// In en, this message translates to:
  /// **'Empty document — tap to begin.'**
  String get emptyDocument;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String wordCount(int count);

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get now;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String daysAgo(int count);

  /// No description provided for @documentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Document not found.'**
  String get documentNotFound;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readingSettings;

  /// No description provided for @readingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readingMode;

  /// No description provided for @editorLabel.
  ///
  /// In en, this message translates to:
  /// **'EDITOR'**
  String get editorLabel;

  /// No description provided for @readingLabel.
  ///
  /// In en, this message translates to:
  /// **'READING'**
  String get readingLabel;

  /// No description provided for @startWriting.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get startWriting;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @undoSession.
  ///
  /// In en, this message translates to:
  /// **'Undo · this session only'**
  String get undoSession;

  /// No description provided for @redoSession.
  ///
  /// In en, this message translates to:
  /// **'Redo · this session only'**
  String get redoSession;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @horizontalRule.
  ///
  /// In en, this message translates to:
  /// **'Horizontal rule'**
  String get horizontalRule;

  /// No description provided for @textPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get textPlaceholder;

  /// No description provided for @codePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'code'**
  String get codePlaceholder;

  /// No description provided for @readingMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min read} other{{count} min read}}'**
  String readingMinutes(int count);

  /// No description provided for @backToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get backToLibrary;

  /// No description provided for @adjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get adjustments;

  /// No description provided for @exitReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Exit reading mode'**
  String get exitReadingMode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
