import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/l10n/app_localizations.dart';
import 'package:sepia_reader/l10n/app_localizations_pt.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/screens/editor_screen.dart';
import 'package:sepia_reader/services/storage_service.dart';
import 'package:sepia_reader/state/app_controller.dart';

import 'support/offline_updates.dart';

/// Counts how many times the settings are written.
class _CountingController extends AppController {
  _CountingController({super.updateChecker});

  int settingsWrites = 0;

  @override
  Future<void> updateSettings(AppSettings next) async {
    settingsWrites++;
    // A slow write (a busy disk, or the server wipe that waits on the
    // network) is what leaves room for a second tap.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await super.updateSettings(next);
  }
}

/// A storage whose document writes fail, as a full disk or a revoked
/// permission would make them.
class _FailingStorage extends StorageService {
  @override
  Future<void> saveDocument(
    List<LibraryDocument> documents,
    LibraryDocument changed,
  ) => Future.error(StateError('disk full'));
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openEditor(
  WidgetTester tester,
  AppController controller,
  String id,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditorScreen(controller: controller, documentId: id),
    ),
  );
  await _settle(tester);
}

void main() {
  group('biblioteca ilegível', () {
    test('guarda uma cópia em vez de sumir em silêncio', () async {
      SharedPreferences.setMockInitialValues({
        'sepia.documents.v1': '{isto não é json',
      });
      final storage = StorageService();

      final loaded = await storage.loadLocalDocuments();

      expect(loaded, isEmpty);
      expect(storage.documentsUnreadable, isTrue);
      final prefs = await SharedPreferences.getInstance();
      final backups = prefs.getKeys().where(
        (key) => key.startsWith('sepia.documents.v1.unreadable.'),
      );
      expect(backups, hasLength(1));
      expect(prefs.getString(backups.single), '{isto não é json');
    });

    test('instalação nova não conta como ilegível', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      expect(await storage.loadLocalDocuments(), isEmpty);
      expect(storage.documentsUnreadable, isFalse);
    });

    test('o aviso sai uma vez e o texto original sobrevive', () async {
      SharedPreferences.setMockInitialValues({
        'sepia.documents.v1': 'quebrado',
      });
      final controller = AppController(updateChecker: offlineUpdateChecker());
      await controller.initialize();

      expect(controller.takeLibraryUnreadableNotice(), isTrue);
      expect(controller.takeLibraryUnreadableNotice(), isFalse);
      // A biblioteca foi recriada, mas o conteúdo antigo continua guardado.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any((key) => key.startsWith('sepia.documents.v1.unre')),
        isTrue,
      );
      expect(controller.documents, isNotEmpty);
    });
  });

  group('editor', () {
    testWidgets('documento apagado pelo sync não derruba o salvamento', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(updateChecker: offlineUpdateChecker());
      await controller.initialize();
      final document = await controller.createDocument(
        title: 'Rascunho',
        content: 'texto',
      );
      await _openEditor(tester, controller, document.id);

      await tester.enterText(find.byType(TextField).last, 'texto novo');
      // O sync remove o documento enquanto há uma edição pendente.
      await controller.deleteDocument(document.id);
      await tester.pump(const Duration(milliseconds: 900));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(AppLocalizationsPt().documentNotFound), findsOneWidget);
    });

    testWidgets('falha ao salvar avisa e mantém o editor aberto', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(
        storage: _FailingStorage(),
        updateChecker: offlineUpdateChecker(),
      );
      await controller.initialize();
      // O documento de boas-vindas já está na memória.
      final id = controller.documents.first.id;
      await _openEditor(tester, controller, id);

      await tester.enterText(find.byType(TextField).last, 'texto novo');
      await tester.pump(const Duration(milliseconds: 900));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
      // Sair com o salvamento falhando mantém o texto na tela.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await _settle(tester);
      expect(find.byType(EditorScreen), findsOneWidget);
    });
  });

  testWidgets('toque duplo em Salvar fecha só uma vez', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
    final controller = _CountingController(
      updateChecker: offlineUpdateChecker(),
    );
    await controller.initialize();
    await tester.pumpWidget(SepiaApp(controller: controller));
    await _settle(tester);
    await tester.tap(find.byTooltip('Configurações'));
    await _settle(tester);

    final save = find.text('Salvar');
    await tester.ensureVisible(save);
    // Dois toques antes de qualquer quadro: o segundo não pode repetir o
    // salvamento nem fechar a tela de baixo.
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Configurações'), findsOneWidget);
    expect(
      controller.settingsWrites,
      1,
      reason: 'o segundo toque repetiu o salvamento',
    );
  });
}
