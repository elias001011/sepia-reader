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
    this.syncEnabled = true,
    this.syncServerUrl = '',
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

  /// Whether the library is mirrored to a server. Persisted locally as well
  /// as here (see `StorageService.loadSyncConfig`); the local copy always
  /// wins, so a synced settings payload can never turn a device's own sync
  /// off or repoint it at another host.
  final bool syncEnabled;

  /// Base URL of the sync server. Empty means "the origin this app was
  /// loaded from", which is the normal self-hosted setup.
  final String syncServerUrl;

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
      syncEnabled: json['syncEnabled'] as bool? ?? true,
      syncServerUrl: json['syncServerUrl'] as String? ?? '',
    );
  }
}
