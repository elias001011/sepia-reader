import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/screens/reader_settings_sheet.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';
import 'package:sepia_reader/widgets/reader_selection.dart';
import 'package:sepia_reader/widgets/color_field.dart';

import 'support/offline_updates.dart';

void main() {
  Future<AppController> controller() async {
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
    final result = AppController(updateChecker: offlineUpdateChecker());
    await result.initialize();
    return result;
  }

  testWidgets('system back walks folders, clears search, then selection', (
    tester,
  ) async {
    final app = await controller();
    final parent = await app.createFolder(name: 'Pai');
    await app.createFolder(name: 'Filha', parentId: parent.id);
    await tester.pumpWidget(SepiaApp(controller: app));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pai').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pai').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filha').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filha').last);
    await tester.pumpAndSettle();
    expect(find.text('Filha'), findsOneWidget); // breadcrumb
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Filha'), findsOneWidget); // child card of Pai
    expect(find.byType(BackButton), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Filha'), findsNothing);
    expect(find.text('Pai'), findsOneWidget);
    await tester.ensureVisible(find.text('Pai'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Pai'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact layouts omit previews, persist, and open files', (
    tester,
  ) async {
    final app = await controller();
    await app.createDocument(title: 'Compacto', content: 'PREVIA EXCLUSIVA');
    await tester.pumpWidget(SepiaApp(controller: app));
    await tester.pumpAndSettle();
    expect(find.text('PREVIA EXCLUSIVA'), findsOneWidget);
    await tester.tap(find.byTooltip('Layout da biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lista compacta'));
    await tester.pumpAndSettle();
    expect(find.text('PREVIA EXCLUSIVA'), findsNothing);
    expect(find.text('Compacto.md'), findsOneWidget);
    expect(app.settings.libraryLayout, 'list');
    final restored = AppController(updateChecker: offlineUpdateChecker());
    await restored.initialize();
    expect(restored.settings.libraryLayout, 'list');
    await tester.tap(find.byTooltip('Layout da biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade compacta'));
    await tester.pumpAndSettle();
    expect(find.text('PREVIA EXCLUSIVA'), findsNothing);
    await tester.ensureVisible(find.text('Compacto.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compacto.md'));

    await tester.pumpAndSettle();
    expect(find.text('Compacto.md'), findsNothing);
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('new reader settings survive serialization and legacy defaults', () {
    final settings = const AppSettings().copyWith(
      libraryLayout: 'grid',
      keepScreenOn: true,
      customReaderBackground: const Color(0xFF123456),
      customReaderText: const Color(0xFFFEDCBA),
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.libraryLayout, 'grid');
    expect(restored.keepScreenOn, isTrue);
    expect(restored.customReaderBackground, const Color(0xFF123456));
    expect(restored.customReaderText, const Color(0xFFFEDCBA));
    expect(AppSettings.fromJson({}).keepScreenOn, isFalse);
    expect(AppSettings.fromJson({}).libraryLayout, 'standard');
    expect(
      AppSettings.fromJson({'readerLineHeight': 1.75}).readerLineHeight,
      1.75,
    );
  });

  testWidgets('themes filter by brightness and save a custom pair', (
    tester,
  ) async {
    final app = await controller();
    await tester.pumpWidget(SepiaApp(controller: app));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReaderSettingsSheet(controller: app),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('Papel'), findsOneWidget);
    expect(
      find.text('Sépia'),
      findsOneWidget,
    ); // only the app header, outside the menu
    await tester.tap(find.text('Papel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizado').first);
    await tester.pumpAndSettle();
    tester
        .widget<ColorField>(find.byType(ColorField).first)
        .onChanged(const Color(0xFF123456));
    await tester.pump();
    tester
        .widget<ColorField>(find.byType(ColorField).last)
        .onChanged(const Color(0xFFFEDCBA));
    await tester.pump();
    await tester.ensureVisible(find.text('Salvar como tema personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar como tema personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar na leitura'));
    await tester.pumpAndSettle();
    expect(app.settings.customReaderBackground, const Color(0xFF123456));
    expect(app.settings.customReaderText, const Color(0xFFFEDCBA));
    expect(app.settings.readerBackground, const Color(0xFF123456));
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen wake lock follows reading mode and app lifecycle', (
    tester,
  ) async {
    final toggles = <bool>[];
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      _WakeCodec(),
    );
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (message) async {
        toggles.add(((message as List).single as List).single as bool);
        return [null];
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, null),
    );
    final app = await controller();
    await app.updateSettings(app.settings.copyWith(keepScreenOn: true));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(SepiaApp(controller: app));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bem-vindo ao Sépia.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bem-vindo ao Sépia.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo leitura'));
    await tester.pumpAndSettle();
    expect(toggles.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(toggles.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(toggles.last, isTrue);
    await tester.tap(find.byTooltip('Sair do modo leitura'));
    await tester.pumpAndSettle();
    expect(toggles.last, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy entire long document reaches unrealized blocks', (
    tester,
  ) async {
    final content = List.generate(
      500,
      (i) => 'Parágrafo $i: texto para copiar. ' * 8,
    ).join('\n\n');
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final now = DateTime(2026);
    final app = await controller();
    await tester.pumpWidget(SepiaApp(controller: app));
    await tester.pumpAndSettle();
    // Use the app's localizations for the selection context menu.
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => Scaffold(
          body: DocumentView(
            document: LibraryDocument(
              id: 'copy',
              title: 'Long',
              content: content,
              extension: 'md',
              createdAt: now,
              updatedAt: now,
            ),
            settings: app.settings,
          ),
        ),
        transitionDuration: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBlock).evaluate().length, lessThan(100));
    final area = tester.state<SelectionAreaState>(find.byType(SelectionArea));
    area.selectableRegion.selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('Parágrafo 0').first,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar documento inteiro').last);
    await tester.pumpAndSettle();
    expect(clipboard, content);
    expect(tester.takeException(), isNull);
  });
}

class _WakeCodec extends StandardMessageCodec {
  const _WakeCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) =>
      type == 129 ? readValue(buffer) : super.readValueOfType(type, buffer);
}
