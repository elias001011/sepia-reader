import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/library_screen.dart';
import 'state/app_controller.dart';
import 'theme/sepia_theme.dart';

/// Applies the user's interface scale on top of the platform's own.
///
/// Composing rather than replacing matters: somebody who has already turned
/// the system font size up should not have that undone by opening this app.
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.platform, this.factor);

  final TextScaler platform;
  final double factor;

  @override
  double scale(double fontSize) => platform.scale(fontSize) * factor;

  // Still required by the base class, though nothing in this app reads it.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => platform.textScaleFactor * factor;
}

class SepiaApp extends StatefulWidget {
  const SepiaApp({super.key, required this.controller});
  final AppController controller;
  @override
  State<SepiaApp> createState() => _SepiaAppState();
}

class _SepiaAppState extends State<SepiaApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.controller.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: switch (settings.localeCode) {
        'pt_BR' => const Locale('pt', 'BR'),
        'en' => const Locale('en'),
        _ => null,
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: settings.themeMode,
      theme: buildSepiaTheme(settings, Brightness.light),
      darkTheme: buildSepiaTheme(settings, Brightness.dark),
      // The user's own scale multiplies the platform's rather than replacing
      // it: someone who has already turned system font size up should not
      // have that undone by opening this app.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: _ScaledTextScaler(media.textScaler, settings.uiScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: LibraryScreen(controller: widget.controller),
    );
  }
}
