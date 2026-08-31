import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models/app_settings.dart';
import 'screens/library_screen.dart';
import 'state/app_controller.dart';
import 'theme/sepia_theme.dart';

/// Paints the first Flutter frame immediately while local persistence opens.
///
/// This is intentionally separate from [SepiaApp]: the controller supplies
/// the saved locale and theme, neither of which is available until its quick,
/// disk-only initialization has completed.
class SepiaBootstrap extends StatefulWidget {
  const SepiaBootstrap({super.key, required this.controller});

  final AppController controller;

  @override
  State<SepiaBootstrap> createState() => _SepiaBootstrapState();
}

class _SepiaBootstrapState extends State<SepiaBootstrap> {
  late final Future<void> _initialization = widget.controller.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return SepiaApp(controller: widget.controller);
        }
        final failed = snapshot.hasError;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF9A6B45),
              surface: const Color(0xFFF5EFE6),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFFC69A72),
              surface: const Color(0xFF171310),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Sépia',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  if (failed)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'Não foi possível abrir os dados locais. '
                        'Feche e abra o aplicativo novamente.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.controller.settings;
    widget.controller.addListener(_refreshSettings);
    // Let MaterialApp paint the local library first. Network reconciliation
    // begins on the following frame and can never hold the launch screen up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.syncAfterLaunch());
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshSettings);
    widget.controller.dispose();
    super.dispose();
  }

  /// The app shell only depends on settings. Document and folder changes are
  /// already observed by the screens that display them.
  void _refreshSettings() {
    final next = widget.controller.settings;
    if (!identical(next, _settings) && mounted) {
      setState(() => _settings = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
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
