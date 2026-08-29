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
  /// **'Settings'**
  String get appAppearance;

  /// No description provided for @appAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, syncing and reading aloud. The button at the end saves everything on this screen.'**
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
  /// **'Save'**
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

  /// No description provided for @presetsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get presetsLight;

  /// No description provided for @presetsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get presetsDark;

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

  /// No description provided for @parchmentPreset.
  ///
  /// In en, this message translates to:
  /// **'Parchment'**
  String get parchmentPreset;

  /// No description provided for @creamPreset.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get creamPreset;

  /// No description provided for @greyPreset.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get greyPreset;

  /// No description provided for @mintPreset.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get mintPreset;

  /// No description provided for @skyPreset.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get skyPreset;

  /// No description provided for @inkPreset.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get inkPreset;

  /// No description provided for @solarizedPreset.
  ///
  /// In en, this message translates to:
  /// **'Solarized'**
  String get solarizedPreset;

  /// No description provided for @nordPreset.
  ///
  /// In en, this message translates to:
  /// **'Nord'**
  String get nordPreset;

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
  /// **'Settings'**
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

  /// No description provided for @exportSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the selected files.'**
  String get exportSelectionFailed;

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

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this spot'**
  String get addBookmark;

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added'**
  String get bookmarkAdded;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet. Tap the bookmark icon on the reading bar to save where you left off.'**
  String get bookmarksEmpty;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @goToBookmark.
  ///
  /// In en, this message translates to:
  /// **'Go to bookmark'**
  String get goToBookmark;

  /// No description provided for @syncSection.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncSection;

  /// No description provided for @syncWithServer.
  ///
  /// In en, this message translates to:
  /// **'Sync with the server'**
  String get syncWithServer;

  /// No description provided for @syncWithServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeps the library identical on every device that opens this server.'**
  String get syncWithServerDescription;

  /// No description provided for @syncServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get syncServerAddress;

  /// No description provided for @syncServerAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Empty: use the address the app was opened from'**
  String get syncServerAddressHint;

  /// No description provided for @syncTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get syncTestConnection;

  /// No description provided for @syncTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get syncTesting;

  /// No description provided for @syncTestOkSimple.
  ///
  /// In en, this message translates to:
  /// **'Connected. The server responded normally.'**
  String get syncTestOkSimple;

  /// No description provided for @syncTestOk.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Connected. 1 document on the server.} other{Connected. {count} documents on the server.}}'**
  String syncTestOk(int count);

  /// No description provided for @syncTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String syncTestFailed(String error);

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Sync is off'**
  String get syncOff;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get syncNever;

  /// No description provided for @syncLast.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {time}'**
  String syncLast(String time);

  /// No description provided for @syncDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn syncing off'**
  String get syncDisabledTitle;

  /// No description provided for @syncDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'From now on this device stops sending and receiving changes. The library that is here stays whole, whatever you choose.\n\nWhat is left to decide is the copy already on the server:\n\n• Keep on server — the copy stays there, untouched. Other devices that sync keep it, and if you turn syncing back on here the two sides merge again.\n\n• Erase from server — the server copy is emptied now. Other devices that sync will receive that deletion and lose those documents too. This device loses nothing.'**
  String get syncDisabledBody;

  /// No description provided for @syncKeepOnServer.
  ///
  /// In en, this message translates to:
  /// **'Keep on server'**
  String get syncKeepOnServer;

  /// No description provided for @syncWipeFromServer.
  ///
  /// In en, this message translates to:
  /// **'Erase from server'**
  String get syncWipeFromServer;

  /// No description provided for @syncWipeFailed.
  ///
  /// In en, this message translates to:
  /// **'Syncing is off, but the copy on the server could not be erased. It is still there.'**
  String get syncWipeFailed;

  /// No description provided for @syncWipeDone.
  ///
  /// In en, this message translates to:
  /// **'Server copy erased.'**
  String get syncWipeDone;

  /// No description provided for @syncPullDone.
  ///
  /// In en, this message translates to:
  /// **'Library synced with the server.'**
  String get syncPullDone;

  /// No description provided for @syncPullFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Your local library is untouched.'**
  String get syncPullFailed;

  /// No description provided for @syncPullDisabled.
  ///
  /// In en, this message translates to:
  /// **'Syncing is off. Turn it on in settings to use this gesture.'**
  String get syncPullDisabled;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteFolderTitle(String name);

  /// No description provided for @deleteFolderEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The folder is empty. It will be deleted.'**
  String get deleteFolderEmptyBody;

  /// No description provided for @deleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'This also deletes {documents, plural, =1{1 document} other{{documents} documents}} and {subfolders, plural, =0{no subfolders} =1{1 subfolder} other{{subfolders} subfolders}}. This cannot be undone.'**
  String deleteFolderBody(int documents, int subfolders);

  /// No description provided for @folderDeleted.
  ///
  /// In en, this message translates to:
  /// **'“{name}” was deleted.'**
  String folderDeleted(String name);

  /// No description provided for @unsupportedBinaryFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file was turned away: it is not text (for example .docx or .pdf).} other{{count} files were turned away: they are not text (for example .docx or .pdf).}}'**
  String unsupportedBinaryFiles(int count);

  /// No description provided for @ttsSection.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get ttsSection;

  /// No description provided for @ttsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable reading aloud'**
  String get ttsEnable;

  /// No description provided for @ttsEnableDescription.
  ///
  /// In en, this message translates to:
  /// **'Adds a listen button to reading mode.'**
  String get ttsEnableDescription;

  /// No description provided for @ttsEngineSystem.
  ///
  /// In en, this message translates to:
  /// **'System voice'**
  String get ttsEngineSystem;

  /// No description provided for @ttsEngineSystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Ultra light: uses the voice Android or your browser already has. Nothing to download, no storage used, works offline.'**
  String get ttsEngineSystemDescription;

  /// No description provided for @ttsEngineNeural.
  ///
  /// In en, this message translates to:
  /// **'On-device neural voice'**
  String get ttsEngineNeural;

  /// No description provided for @ttsEngineNeuralDescription.
  ///
  /// In en, this message translates to:
  /// **'Far more natural. Runs offline on the device itself, with no API and without sending your text anywhere — but a voice has to be downloaded first.'**
  String get ttsEngineNeuralDescription;

  /// No description provided for @ttsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ttsVoice;

  /// No description provided for @ttsVoiceAuto.
  ///
  /// In en, this message translates to:
  /// **'Choose automatically'**
  String get ttsVoiceAuto;

  /// No description provided for @ttsRate.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ttsRate;

  /// No description provided for @ttsPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get ttsPitch;

  /// No description provided for @ttsPreview.
  ///
  /// In en, this message translates to:
  /// **'Play a sample'**
  String get ttsPreview;

  /// No description provided for @ttsPreviewText.
  ///
  /// In en, this message translates to:
  /// **'This is the voice that will read your documents.'**
  String get ttsPreviewText;

  /// No description provided for @ttsNoVoices.
  ///
  /// In en, this message translates to:
  /// **'No voices found on this device.'**
  String get ttsNoVoices;

  /// No description provided for @ttsLoadingVoices.
  ///
  /// In en, this message translates to:
  /// **'Looking for voices…'**
  String get ttsLoadingVoices;

  /// No description provided for @ttsListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get ttsListen;

  /// No description provided for @ttsChooseChapter.
  ///
  /// In en, this message translates to:
  /// **'Listen from'**
  String get ttsChooseChapter;

  /// No description provided for @ttsWholeDocument.
  ///
  /// In en, this message translates to:
  /// **'Read the whole document'**
  String get ttsWholeDocument;

  /// No description provided for @ttsNoChapters.
  ///
  /// In en, this message translates to:
  /// **'This document has no chapters (#/##), so you can listen to all of it.'**
  String get ttsNoChapters;

  /// No description provided for @ttsChapterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chapter} other{{count} chapters}}'**
  String ttsChapterCount(int count);

  /// No description provided for @ttsFromHere.
  ///
  /// In en, this message translates to:
  /// **'Start where I left off'**
  String get ttsFromHere;

  /// No description provided for @ttsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get ttsStop;

  /// No description provided for @ttsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get ttsPause;

  /// No description provided for @ttsResume.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get ttsResume;

  /// No description provided for @ttsPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous passage'**
  String get ttsPrevious;

  /// No description provided for @ttsNext.
  ///
  /// In en, this message translates to:
  /// **'Next passage'**
  String get ttsNext;

  /// No description provided for @ttsFailed.
  ///
  /// In en, this message translates to:
  /// **'Reading aloud failed: {error}'**
  String ttsFailed(String error);

  /// No description provided for @ttsNothingToRead.
  ///
  /// In en, this message translates to:
  /// **'There is no text to read in this part.'**
  String get ttsNothingToRead;

  /// No description provided for @ttsProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String ttsProgress(int current, int total);

  /// No description provided for @viewerSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get viewerSource;

  /// No description provided for @viewerPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get viewerPreview;

  /// No description provided for @appearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// No description provided for @editSectionPosition.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String editSectionPosition(int current, int total);

  /// No description provided for @editSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Large document: the editor loads one part at a time so typing stays fast. The whole document is still saved, and reading mode shows all of it.'**
  String get editSectionHint;

  /// No description provided for @editSectionPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous part'**
  String get editSectionPrevious;

  /// No description provided for @editSectionNext.
  ///
  /// In en, this message translates to:
  /// **'Next part'**
  String get editSectionNext;

  /// No description provided for @editSectionChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose part'**
  String get editSectionChoose;

  /// No description provided for @editWholeDocument.
  ///
  /// In en, this message translates to:
  /// **'Turn off editing by chapter (applies to every document)'**
  String get editWholeDocument;

  /// No description provided for @editSectionPart.
  ///
  /// In en, this message translates to:
  /// **'Part {number}'**
  String editSectionPart(String number);

  /// No description provided for @ttsEngineNeuralUnavailableWeb.
  ///
  /// In en, this message translates to:
  /// **'In the browser only the system voice works: the neural voice needs to run natively. Use the Android app for that.'**
  String get ttsEngineNeuralUnavailableWeb;

  /// No description provided for @ttsManageVoices.
  ///
  /// In en, this message translates to:
  /// **'Download voices'**
  String get ttsManageVoices;

  /// No description provided for @ttsVoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Voices to download'**
  String get ttsVoicesTitle;

  /// No description provided for @ttsVoicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Download once and use offline forever. It is stored on the device and can be removed whenever you like.'**
  String get ttsVoicesDescription;

  /// No description provided for @ttsVoiceInstall.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get ttsVoiceInstall;

  /// No description provided for @ttsVoiceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get ttsVoiceRemove;

  /// No description provided for @ttsVoiceInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get ttsVoiceInstalled;

  /// No description provided for @ttsVoiceUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get ttsVoiceUse;

  /// No description provided for @ttsVoiceInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get ttsVoiceInUse;

  /// No description provided for @ttsVoiceDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String ttsVoiceDownloading(int percent);

  /// No description provided for @ttsVoiceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ttsVoiceCancel;

  /// No description provided for @ttsVoiceSize.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String ttsVoiceSize(int size);

  /// No description provided for @ttsVoiceInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the voice: {error}'**
  String ttsVoiceInstallFailed(String error);

  /// No description provided for @ttsVoiceRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}”? The files leave the device and can be downloaded again later.'**
  String ttsVoiceRemoveConfirm(String name);

  /// No description provided for @ttsVoiceHeavy.
  ///
  /// In en, this message translates to:
  /// **'Large model: needs plenty of space and memory. On a weaker phone, prefer the Piper voices.'**
  String get ttsVoiceHeavy;

  /// No description provided for @ttsNoNeuralVoice.
  ///
  /// In en, this message translates to:
  /// **'No neural voice installed yet.'**
  String get ttsNoNeuralVoice;

  /// No description provided for @ttsTierLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get ttsTierLight;

  /// No description provided for @ttsTierBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get ttsTierBest;

  /// No description provided for @ttsTierLightHint.
  ///
  /// In en, this message translates to:
  /// **'Piper · runs well on any device'**
  String get ttsTierLightHint;

  /// No description provided for @ttsTierBestHint.
  ///
  /// In en, this message translates to:
  /// **'Kokoro · one model with many voices and languages, more natural, but wants plenty of space and memory'**
  String get ttsTierBestHint;

  /// No description provided for @ttsFellBackToSystem.
  ///
  /// In en, this message translates to:
  /// **'The neural voice could not be used right now; reading with the system voice.'**
  String get ttsFellBackToSystem;

  /// No description provided for @ttsVoiceQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued…'**
  String get ttsVoiceQueued;

  /// No description provided for @ttsVoiceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 voice} other{{count} voices}}'**
  String ttsVoiceCount(int count);

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get unsavedTitle;

  /// No description provided for @unsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You changed something here and have not saved it.'**
  String get unsavedBody;

  /// No description provided for @unsavedSaveAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Save and leave'**
  String get unsavedSaveAndLeave;

  /// No description provided for @unsavedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get unsavedDiscard;

  /// No description provided for @interfaceScale.
  ///
  /// In en, this message translates to:
  /// **'Interface size'**
  String get interfaceScale;

  /// No description provided for @interfaceScaleDescription.
  ///
  /// In en, this message translates to:
  /// **'Makes everything bigger or smaller: text, buttons and spacing.'**
  String get interfaceScaleDescription;

  /// No description provided for @interfaceScaleReset.
  ///
  /// In en, this message translates to:
  /// **'Back to default'**
  String get interfaceScaleReset;

  /// No description provided for @updateSection.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateSection;

  /// No description provided for @updateCheckAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Check for updates on launch'**
  String get updateCheckAutomatically;

  /// No description provided for @updateCheckAutomaticallyDescription.
  ///
  /// In en, this message translates to:
  /// **'Asks GitHub releases when there is internet. Nothing is downloaded on its own.'**
  String get updateCheckAutomaticallyDescription;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Sépia {version} available'**
  String updateAvailable(String version);

  /// No description provided for @updateCurrent.
  ///
  /// In en, this message translates to:
  /// **'You are on {version}, the latest.'**
  String updateCurrent(String version);

  /// No description provided for @updateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updateCheckNow;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updateChecking;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates: {error}'**
  String updateFailed(String error);

  /// No description provided for @updateOpen.
  ///
  /// In en, this message translates to:
  /// **'View the release'**
  String get updateOpen;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download APK'**
  String get updateDownload;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get updateLater;

  /// No description provided for @updateWebHint.
  ///
  /// In en, this message translates to:
  /// **'This is the web build: the server hosting it is what updates.'**
  String get updateWebHint;

  /// No description provided for @updateNotes.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateNotes;

  /// No description provided for @voiceDownloadRunning.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name} · {percent}%'**
  String voiceDownloadRunning(String name, int percent);

  /// No description provided for @voiceDownloadQueued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more queued} other{{count} more queued}}'**
  String voiceDownloadQueued(int count);

  /// No description provided for @voiceDownloadBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'You can close settings: the download keeps going while the app is open.'**
  String get voiceDownloadBackgroundHint;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link. It is: {url}'**
  String updateOpenFailed(String url);

  /// No description provided for @updateInstalled.
  ///
  /// In en, this message translates to:
  /// **'Version {version} installed.'**
  String updateInstalled(String version);

  /// No description provided for @chapterNavigation.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapterNavigation;

  /// No description provided for @chapterNavigationHere.
  ///
  /// In en, this message translates to:
  /// **'Continue reading here'**
  String get chapterNavigationHere;

  /// No description provided for @chapterSeparatorToggle.
  ///
  /// In en, this message translates to:
  /// **'Edit by chapter'**
  String get chapterSeparatorToggle;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectionCount(int count);

  /// No description provided for @deleteSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected items?'**
  String get deleteSelectionTitle;

  /// No description provided for @deleteSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'This removes {documents, plural, =0{no documents} =1{1 document} other{{documents} documents}} and {folders, plural, =0{no folders} =1{1 folder} other{{folders} folders}}, along with everything the folders hold. It cannot be undone.'**
  String deleteSelectionBody(int documents, int folders);

  /// No description provided for @exportedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to export.} =1{1 file exported.} other{{count} files exported.}}'**
  String exportedCount(int count);
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
