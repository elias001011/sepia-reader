import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.localeCode = 'system',
    this.themeMode = ThemeMode.system,
    this.seedColor = const Color(0xFF9A6B45),
    this.appBackground = const Color(0xFFF5EFE6),
    this.darkAppBackground = const Color(0xFF171310),
    this.amoledTheme = false,
    this.readerBackground = const Color(0xFF6B4933),
    this.readerText = const Color(0xFFFFF8ED),
    this.readerFollowsTheme = false,
    this.autoHideReaderControls = false,
    this.readerFont = 'Merriweather',
    this.readerFontSize = 20,
    this.readerLineHeight = 1.75,
    this.readerWidth = 760,
    this.syncEnabled = false,
    this.syncServerUrl = '',
    this.ttsEnabled = true,
    this.ttsEngine = 'system',
    this.ttsVoiceId = '',
    this.ttsNeuralVoiceId = '',
    this.ttsRate = 1,
    this.ttsPitch = 1,
    this.uiScale = 1,
    this.checkForUpdates = true,
    this.sectionedEditing = true,
  });
  final String localeCode;
  final ThemeMode themeMode;
  final Color seedColor;
  final Color appBackground;
  final Color darkAppBackground;
  final bool amoledTheme;
  final Color readerBackground;
  final Color readerText;
  final bool readerFollowsTheme;
  final bool autoHideReaderControls;
  final String readerFont;
  final double readerFontSize;
  final double readerLineHeight;
  final double readerWidth;

  /// Whether the library is mirrored to a server. Off by default: a
  /// local-first app should not assume a server exists until one is named.
  /// Persisted locally as well as here (see `StorageService.loadSyncConfig`);
  /// the local copy always wins, so a synced settings payload can never turn
  /// a device's own sync off or repoint it at another host.
  final bool syncEnabled;

  /// Base URL of the sync server. Empty means "the origin this app was
  /// loaded from", which is the normal self-hosted setup.
  final String syncServerUrl;

  /// Whether reading mode offers to read the document out loud.
  ///
  /// On by default. It shipped off, behind a settings screen whose only
  /// entry point was a button labelled "Aparência", and the result was
  /// exactly what you would expect: the feature was invisible. A reader
  /// control belongs in the reader; the switch is there to turn it off.
  final bool ttsEnabled;

  /// Which speech backend to use. 'system' is the platform voice; further
  /// values are reserved for the locally-run neural engine.
  final String ttsEngine;

  /// Platform-voice identifier; empty means "whatever the engine picks for
  /// the current language".
  final String ttsVoiceId;

  /// Which downloaded neural voice to use, from [neuralVoices]. Kept apart
  /// from [ttsVoiceId] so switching engines back and forth does not lose
  /// either choice.
  final String ttsNeuralVoiceId;

  /// Speaking speed as a multiplier, 1.0 being the voice's natural pace.
  final double ttsRate;

  /// Voice pitch as a multiplier, 1.0 being unmodified.
  final double ttsPitch;

  /// Overall interface size, 1.0 being the platform default.
  ///
  /// The same layout reads as cramped on a phone and undersized on a
  /// desktop monitor, and no single default suits both. This scales the text
  /// and, through visual density, the controls sized around it.
  final double uiScale;

  /// Whether to ask GitHub for a newer release on launch.
  final bool checkForUpdates;

  /// Whether large documents are split into chapters for editing.
  ///
  /// On by default: a keystroke in a 90 000 character field costs ~42 ms
  /// versus ~10 ms in an 8 000 character slice, so sectioned editing keeps
  /// typing fast. Turning this off loads the whole document into the field,
  /// which is slower but lets you search and edit across chapter boundaries.
  final bool sectionedEditing;

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    Color? seedColor,
    Color? appBackground,
    Color? darkAppBackground,
    bool? amoledTheme,
    Color? readerBackground,
    Color? readerText,
    bool? readerFollowsTheme,
    bool? autoHideReaderControls,
    String? readerFont,
    double? readerFontSize,
    double? readerLineHeight,
    double? readerWidth,
    bool? syncEnabled,
    String? syncServerUrl,
    bool? ttsEnabled,
    String? ttsEngine,
    String? ttsVoiceId,
    String? ttsNeuralVoiceId,
    double? ttsRate,
    double? ttsPitch,
    double? uiScale,
    bool? checkForUpdates,
    bool? sectionedEditing,
  }) => AppSettings(
    localeCode: localeCode ?? this.localeCode,
    themeMode: themeMode ?? this.themeMode,
    seedColor: seedColor ?? this.seedColor,
    appBackground: appBackground ?? this.appBackground,
    darkAppBackground: darkAppBackground ?? this.darkAppBackground,
    amoledTheme: amoledTheme ?? this.amoledTheme,
    readerBackground: readerBackground ?? this.readerBackground,
    readerText: readerText ?? this.readerText,
    readerFollowsTheme: readerFollowsTheme ?? this.readerFollowsTheme,
    autoHideReaderControls:
        autoHideReaderControls ?? this.autoHideReaderControls,
    readerFont: readerFont ?? this.readerFont,
    readerFontSize: readerFontSize ?? this.readerFontSize,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
    readerWidth: readerWidth ?? this.readerWidth,
    syncEnabled: syncEnabled ?? this.syncEnabled,
    syncServerUrl: syncServerUrl ?? this.syncServerUrl,
    ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    ttsEngine: ttsEngine ?? this.ttsEngine,
    ttsVoiceId: ttsVoiceId ?? this.ttsVoiceId,
    ttsNeuralVoiceId: ttsNeuralVoiceId ?? this.ttsNeuralVoiceId,
    ttsRate: ttsRate ?? this.ttsRate,
    ttsPitch: ttsPitch ?? this.ttsPitch,
    uiScale: uiScale ?? this.uiScale,
    checkForUpdates: checkForUpdates ?? this.checkForUpdates,
    sectionedEditing: sectionedEditing ?? this.sectionedEditing,
  );

  Map<String, dynamic> toJson() => {
    'localeCode': localeCode,
    'themeMode': themeMode.name,
    'seedColor': seedColor.toARGB32(),
    'appBackground': appBackground.toARGB32(),
    'darkAppBackground': darkAppBackground.toARGB32(),
    'amoledTheme': amoledTheme,
    'readerBackground': readerBackground.toARGB32(),
    'readerText': readerText.toARGB32(),
    'readerFollowsTheme': readerFollowsTheme,
    'autoHideReaderControls': autoHideReaderControls,
    'readerFont': readerFont,
    'readerFontSize': readerFontSize,
    'readerLineHeight': readerLineHeight,
    'readerWidth': readerWidth,
    'syncEnabled': syncEnabled,
    'syncServerUrl': syncServerUrl,
    'ttsEnabled': ttsEnabled,
    'ttsEngine': ttsEngine,
    'ttsVoiceId': ttsVoiceId,
    'ttsNeuralVoiceId': ttsNeuralVoiceId,
    'ttsRate': ttsRate,
    'ttsPitch': ttsPitch,
    'uiScale': uiScale,
    'checkForUpdates': checkForUpdates,
    'sectionedEditing': sectionedEditing,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final modeName = json['themeMode'] as String? ?? 'system';
    return AppSettings(
      localeCode: json['localeCode'] as String? ?? 'system',
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => ThemeMode.system,
      ),
      seedColor: Color(json['seedColor'] as int? ?? 0xFF9A6B45),
      appBackground: Color(json['appBackground'] as int? ?? 0xFFF5EFE6),
      darkAppBackground: Color(json['darkAppBackground'] as int? ?? 0xFF171310),
      amoledTheme: json['amoledTheme'] as bool? ?? false,
      readerBackground: Color(json['readerBackground'] as int? ?? 0xFF6B4933),
      readerText: Color(json['readerText'] as int? ?? 0xFFFFF8ED),
      readerFollowsTheme: json['readerFollowsTheme'] as bool? ?? false,
      autoHideReaderControls: json['autoHideReaderControls'] as bool? ?? false,
      readerFont: json['readerFont'] as String? ?? 'Merriweather',
      readerFontSize: (json['readerFontSize'] as num? ?? 20).toDouble(),
      readerLineHeight: (json['readerLineHeight'] as num? ?? 1.75).toDouble(),
      readerWidth: (json['readerWidth'] as num? ?? 760).toDouble(),
      syncEnabled: json['syncEnabled'] as bool? ?? false,
      syncServerUrl: json['syncServerUrl'] as String? ?? '',
      ttsEnabled: json['ttsEnabled'] as bool? ?? true,
      ttsEngine: json['ttsEngine'] as String? ?? 'system',
      ttsVoiceId: json['ttsVoiceId'] as String? ?? '',
      ttsNeuralVoiceId: json['ttsNeuralVoiceId'] as String? ?? '',
      ttsRate: (json['ttsRate'] as num? ?? 1).toDouble().clamp(0.5, 2.0),
      ttsPitch: (json['ttsPitch'] as num? ?? 1).toDouble().clamp(0.5, 2.0),
      uiScale: (json['uiScale'] as num? ?? 1).toDouble().clamp(0.8, 1.6),
      checkForUpdates: json['checkForUpdates'] as bool? ?? true,
      sectionedEditing: json['sectionedEditing'] as bool? ?? true,
    );
  }
}
