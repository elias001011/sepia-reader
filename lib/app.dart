import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'state/app_controller.dart';
import 'theme/sepia_theme.dart';

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
      title: 'Sépia',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildSepiaTheme(settings, Brightness.light),
      darkTheme: buildSepiaTheme(settings, Brightness.dark),
      home: LibraryScreen(controller: widget.controller),
    );
  }
}
