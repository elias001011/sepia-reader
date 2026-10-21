import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/l10n/app_localizations.dart';
import 'package:sepia_reader/screens/voice_downloads_sheet.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/services/tts/voice_download_manager.dart';
import 'package:sepia_reader/services/tts/voice_store_types.dart';

class InstalledStore implements VoiceStorage {
  @override
  bool get isSupported => true;
  @override
  Future<List<VoicePack>> installedPacks() async =>
      voicePacks.where((p) => p.isSupertonic).toList();
  @override
  Future<bool> isInstalled(VoicePack pack) async => pack.isSupertonic;
  @override
  Future<void> install(
    VoicePack pack, {
    void Function(VoiceInstallProgress)? onProgress,
    bool Function()? shouldCancel,
  }) async {}
  @override
  Future<void> remove(VoicePack pack) async {}
}

void main() {
  testWidgets(
    'compact voice manager shows recommendation and switches language',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final downloads = VoiceDownloadManager(store: InstalledStore());
      addTearDown(downloads.dispose);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: VoiceDownloadsSheet(
              downloads: downloads,
              selectedVoiceId: '',
              onSelected: (id) => selected = id,
              rate: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('M2'), findsNWidgets(2));
      expect(find.textContaining('Recomendada'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('M2').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar').first);
      await tester.pumpAndSettle();
      expect(selected, 'supertonic/3/M2');
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(find.text('English · Recomendada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
