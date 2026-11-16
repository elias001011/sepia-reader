import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/l10n/app_localizations.dart';
import 'package:sepia_reader/widgets/name_entry_sheet.dart';
import 'package:sepia_reader/widgets/sheet_choices.dart';
import 'package:sepia_reader/widgets/sheet_scaffold.dart';

/// Hosts a sheet exactly the way the app does, so the bounds, the closing
/// gestures and the keyboard behaviour are the real ones.
Future<void> _openSheet(
  WidgetTester tester, {
  required Size size,
  required WidgetBuilder builder,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAppSheet<void>(context: context, builder: builder),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Map<String, WidgetBuilder> get _sheets => {
  'formulário com ação': (_) => const NameEntrySheet(
    title: 'Novo documento',
    label: 'Nome do arquivo',
    actionLabel: 'Criar',
    initialFormat: 'md',
    formats: [
      SheetChoice(value: 'md', label: 'Markdown (.md)'),
      SheetChoice(value: 'txt', label: 'Texto simples (.txt)'),
    ],
  ),
  'lista de escolhas': (_) => SheetScaffold.list(
    title: 'Tema',
    itemCount: 6,
    itemBuilder: (context, index) => ListTile(title: Text('Opção $index')),
  ),
};

void main() {
  for (final size in const [
    Size(320, 700),
    Size(390, 844),
    Size(1440, 900),
    Size(800, 320),
  ]) {
    for (final entry in _sheets.entries) {
      testWidgets('${entry.key} cabe em $size', (tester) async {
        await _openSheet(
          tester,
          size: size,
          builder: entry.value,
          textScale: 1.6,
        );

        final panel = tester.getRect(find.byType(SheetScaffold));
        expect(tester.takeException(), isNull);
        expect(panel.width, lessThanOrEqualTo(kSheetMaxWidth));
        expect(panel.left, greaterThanOrEqualTo(0));
        expect(panel.right, lessThanOrEqualTo(size.width));
        // A janela baixa rola: nada é cortado fora do alcance.
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('no desktop o painel abraça o conteúdo e fica centralizado', (
    tester,
  ) async {
    await _openSheet(
      tester,
      size: const Size(1600, 1000),
      builder: _sheets['lista de escolhas']!,
    );

    // Conteúdo curto: o painel fica no piso, não estica pela tela.
    final panel = tester.getRect(find.byType(SheetScaffold));
    expect(panel.width, 360);
    expect(panel.center.dx, closeTo(800, 1));

    // Ações do rodapé continuam no lugar com o painel ancorado embaixo.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SheetScaffold), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('conteúdo largo para no teto, mesmo em tela enorme', (
    tester,
  ) async {
    await _openSheet(
      tester,
      size: const Size(3000, 1200),
      builder: (_) => SheetScaffold(
        title: 'Marcadores',
        children: [Text('trecho muito longo ' * 60, maxLines: 2)],
      ),
    );

    final panel = tester.getRect(find.byType(SheetScaffold));
    expect(panel.width, kSheetMaxWidth);
    expect(panel.center.dx, closeTo(1500, 1));
  });

  testWidgets('recorte da câmera num lado não descentraliza o painel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: _sheets['lista de escolhas']!,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(SheetScaffold));
    expect(panel.center.dx, closeTo(400, 1));
  });

  testWidgets('o teclado empurra a janela em vez de cobrir os campos', (
    tester,
  ) async {
    await _openSheet(
      tester,
      size: const Size(390, 844),
      builder: _sheets['formulário com ação']!,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final create = tester.getRect(find.widgetWithText(FilledButton, 'Criar'));
    expect(create.bottom, lessThanOrEqualTo(844 - 320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar não devolve nome nem formato', (tester) async {
    NameEntry? result;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppSheet<NameEntry>(
                  context: context,
                  builder: (_) => const NameEntrySheet(
                    title: 'Renomear',
                    label: 'Nome',
                    actionLabel: 'Renomear',
                    initialValue: 'Antigo',
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Novo');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(SheetScaffold), findsNothing);
  });

  testWidgets('escolher devolve o valor e marca o atual', (tester) async {
    String? picked;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showSheetChoices<String>(
                  context: context,
                  title: 'Tema',
                  value: 'sistema',
                  choices: const [
                    SheetChoice(
                      value: 'claro',
                      label: 'Claro',
                      icon: Icons.light_mode_rounded,
                    ),
                    SheetChoice(
                      value: 'sistema',
                      label: 'Sistema',
                      icon: Icons.brightness_auto_rounded,
                    ),
                  ],
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final selected = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where((tile) => tile.selected)
        .single;
    expect((selected.title! as Text).data, 'Sistema');

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(picked, 'claro');
    expect(find.byType(SheetScaffold), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
