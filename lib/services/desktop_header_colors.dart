import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef HeaderColors = ({Color background, Color foreground});

/// Paints the Linux header bar with the app's colours, or with the reader's
/// paper while a document is open in reading mode.
///
/// The header bar belongs to GTK, so Flutter's theme never reaches it. The
/// runner (linux/runner/my_application.cc) listens on [_channel] and styles
/// the bar. Every other platform ignores these calls.
class DesktopHeaderColors {
  DesktopHeaderColors._();

  static const _channel = MethodChannel('dev.elias.sepia_reader/window');

  static HeaderColors? _app;
  static HeaderColors? _reading;
  static Object? _readingOwner;
  static String? _lastSent;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static void setApp(Color background, Color foreground) {
    _app = (background: background, foreground: foreground);
    _apply();
  }

  /// [owner] identifies who set the paper, so a screen that is closing only
  /// clears what it set itself.
  static void setReading(Object owner, Color background, Color foreground) {
    _readingOwner = owner;
    _reading = (background: background, foreground: foreground);
    _apply();
  }

  static void clearReading(Object owner) {
    if (!identical(_readingOwner, owner)) return;
    _readingOwner = null;
    _reading = null;
    _apply();
  }

  @visibleForTesting
  static void resetForTesting() {
    _app = null;
    _reading = null;
    _readingOwner = null;
    _lastSent = null;
  }

  static void _apply() {
    if (!_supported) return;
    final colors = _reading ?? _app;
    if (colors == null) return;
    final key =
        '${colors.background.toARGB32()}:${colors.foreground.toARGB32()}';
    if (key == _lastSent) return;
    _lastSent = key;
    unawaited(_send(colors));
  }

  static Future<void> _send(HeaderColors colors) async {
    try {
      await _channel.invokeMethod<void>('setHeaderColors', {
        'background': colors.background.toARGB32(),
        'foreground': colors.foreground.toARGB32(),
      });
    } on PlatformException catch (_) {
      // The runner rejected the colours; the header keeps the GTK theme.
    } on MissingPluginException catch (_) {
      // Built without the Linux runner, such as a web or test build.
    }
  }
}

/// Keeps the header bar on the app's own theme. Placed once at the root of
/// the app, so it only reports when the theme changes.
class DesktopHeaderSync extends StatefulWidget {
  const DesktopHeaderSync({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopHeaderSync> createState() => _DesktopHeaderSyncState();
}

class _DesktopHeaderSyncState extends State<DesktopHeaderSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    DesktopHeaderColors.setApp(
      theme.scaffoldBackgroundColor,
      theme.colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Gives the header bar the reader's paper while [child] is on screen. A null
/// [paper] means the content uses the app's theme, so the header keeps it.
class DesktopReaderHeader extends StatefulWidget {
  const DesktopReaderHeader({
    super.key,
    required this.paper,
    required this.child,
  });

  final HeaderColors? paper;
  final Widget child;

  @override
  State<DesktopReaderHeader> createState() => _DesktopReaderHeaderState();
}

class _DesktopReaderHeaderState extends State<DesktopReaderHeader> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DesktopReaderHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    DesktopHeaderColors.clearReading(this);
    super.dispose();
  }

  void _sync() {
    final paper = widget.paper;
    if (paper == null) {
      DesktopHeaderColors.clearReading(this);
    } else {
      DesktopHeaderColors.setReading(this, paper.background, paper.foreground);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
