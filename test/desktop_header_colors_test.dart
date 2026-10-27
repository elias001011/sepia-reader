import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/desktop_header_colors.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.elias.sepia_reader/window');
  final sent = <Map<Object?, Object?>>[];

  setUp(() {
    sent.clear();
    DesktopHeaderColors.resetForTesting();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'setHeaderColors');
          sent.add(call.arguments as Map<Object?, Object?>);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reader paper follows the app theme when the reader does', () {
    const scheme = ColorScheme.light(
      surface: Color(0xFFF5EFE6),
      onSurface: Color(0xFF2B2118),
    );
    final paper = readerPaperFor(
      const AppSettings(readerFollowsTheme: true),
      scheme,
    );
    expect(paper.background, const Color(0xFFF5EFE6));
    expect(paper.foreground, const Color(0xFF2B2118));
  });

  test('reader paper uses the reader colours when they are set', () {
    const settings = AppSettings(
      readerBackground: Color(0xFF1E1E1E),
      readerText: Color(0xFFE0D6C2),
    );
    final paper = readerPaperFor(settings, ColorScheme.dark());
    expect(paper.background, const Color(0xFF1E1E1E));
    expect(paper.foreground, const Color(0xFFE0D6C2));
  });

  test('sends ARGB colours to the runner once per change', () async {
    DesktopHeaderColors.setApp(
      const Color(0xFFF5EFE6),
      const Color(0xFF2B2118),
    );
    DesktopHeaderColors.setApp(
      const Color(0xFFF5EFE6),
      const Color(0xFF2B2118),
    );
    await Future<void>.delayed(Duration.zero);
    expect(sent, [
      {'background': 0xFFF5EFE6, 'foreground': 0xFF2B2118},
    ]);
  });

  test('reading paper wins until its own owner clears it', () async {
    final reader = Object();
    final other = Object();
    DesktopHeaderColors.setApp(
      const Color(0xFFF5EFE6),
      const Color(0xFF2B2118),
    );
    DesktopHeaderColors.setReading(
      reader,
      const Color(0xFF1E1E1E),
      const Color(0xFFE0D6C2),
    );
    DesktopHeaderColors.clearReading(other);
    await Future<void>.delayed(Duration.zero);
    expect(sent.last, {'background': 0xFF1E1E1E, 'foreground': 0xFFE0D6C2});

    DesktopHeaderColors.clearReading(reader);
    await Future<void>.delayed(Duration.zero);
    expect(sent.last, {'background': 0xFFF5EFE6, 'foreground': 0xFF2B2118});
  });

  test('does nothing outside Linux', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    DesktopHeaderColors.setApp(
      const Color(0xFFF5EFE6),
      const Color(0xFF2B2118),
    );
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
  });
}
