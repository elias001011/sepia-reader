// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Sépia';

  @override
  String get appAppearance => 'Aparência do app';

  @override
  String get appAppearanceDescription =>
      'Defina o tema Material usado na biblioteca e no editor.';

  @override
  String get theme => 'Tema';

  @override
  String get light => 'Claro';

  @override
  String get system => 'Sistema';

  @override
  String get dark => 'Escuro';

  @override
  String get language => 'Idioma';

  @override
  String get portugueseBrazil => 'Português (Brasil)';

  @override
  String get english => 'English';

  @override
  String get primaryColor => 'Cor principal';

  @override
  String get lightThemeBackground => 'Fundo do tema claro';

  @override
  String get saveAppearance => 'Salvar aparência';

  @override
  String get readerSettings => 'Ajustes de leitura';

  @override
  String get readerSettingsDescription =>
      'Os ajustes são usados em todos os documentos.';

  @override
  String get presets => 'Presets';

  @override
  String get sepiaPreset => 'Sépia';

  @override
  String get artifactPreset => 'Artifact';

  @override
  String get paperPreset => 'Papel';

  @override
  String get nightPreset => 'Noite';

  @override
  String get font => 'Fonte';

  @override
  String get systemFont => 'Sistema';

  @override
  String get size => 'Tamanho';

  @override
  String get lineHeight => 'Entrelinha';

  @override
  String get pageWidth => 'Largura da página';

  @override
  String get readerBackground => 'Fundo da leitura';

  @override
  String get textColor => 'Cor do texto';

  @override
  String get applyReading => 'Aplicar na leitura';

  @override
  String get hexColor => 'Cor hexadecimal';

  @override
  String get cancel => 'Cancelar';

  @override
  String get apply => 'Aplicar';

  @override
  String get newLabel => 'Novo';

  @override
  String get appearance => 'Aparência';

  @override
  String get importLabel => 'Importar';

  @override
  String get newDocument => 'Novo documento';

  @override
  String get libraryHero => 'Sua biblioteca,\nno seu ritmo.';

  @override
  String get libraryHeroDescription =>
      'Leia sem ruído. Escreva sem sair daqui.';

  @override
  String get searchHint => 'Buscar por título ou conteúdo…';

  @override
  String get importFiles => 'Importar arquivos';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get results => 'Resultados';

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos',
      one: '1 arquivo',
      zero: 'nenhum arquivo',
    );
    return '$_temp0';
  }

  @override
  String get nextReading => 'Sua próxima leitura começa aqui';

  @override
  String get nothingFound => 'Nada encontrado';

  @override
  String get emptyLibraryHelp =>
      'Crie um Markdown ou importe um arquivo de texto.';

  @override
  String get emptySearchHelp => 'Tente buscar outro termo.';

  @override
  String get fileName => 'Nome do arquivo';

  @override
  String get fileNameHint => 'Minhas anotações';

  @override
  String get format => 'Formato';

  @override
  String get markdownFormat => 'Markdown (.md)';

  @override
  String get plainTextFormat => 'Texto simples (.txt)';

  @override
  String get create => 'Criar';

  @override
  String importedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos importados.',
      one: '1 arquivo importado.',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String error) {
    return 'Não foi possível importar: $error';
  }

  @override
  String get exported => 'Arquivo exportado.';

  @override
  String exportFailed(String error) {
    return 'Não foi possível exportar: $error';
  }

  @override
  String get deleteFileQuestion => 'Excluir arquivo?';

  @override
  String deleteFileDescription(String filename) {
    return '“$filename” será removido da biblioteca.';
  }

  @override
  String get delete => 'Excluir';

  @override
  String get favorite => 'Favoritar';

  @override
  String get unfavorite => 'Desfavoritar';

  @override
  String get exportLabel => 'Exportar';

  @override
  String get emptyDocument => 'Documento vazio — toque para começar.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palavras',
      one: '1 palavra',
    );
    return '$_temp0';
  }

  @override
  String get now => 'agora';

  @override
  String minutesAgo(int count) {
    return 'há $count min';
  }

  @override
  String hoursAgo(int count) {
    return 'há $count h';
  }

  @override
  String daysAgo(int count) {
    return 'há $count d';
  }

  @override
  String get documentNotFound => 'Documento não encontrado.';

  @override
  String get untitled => 'Sem título';

  @override
  String get readingSettings => 'Ajustes de leitura';

  @override
  String get readingMode => 'Modo leitura';

  @override
  String get editorLabel => 'EDITOR';

  @override
  String get readingLabel => 'LEITURA';

  @override
  String get startWriting => 'Comece a escrever…';

  @override
  String get edit => 'Editar';

  @override
  String get preview => 'Visualizar';

  @override
  String get undoSession => 'Desfazer · histórico desta sessão';

  @override
  String get redoSession => 'Refazer · histórico desta sessão';

  @override
  String get heading => 'Título';

  @override
  String get bold => 'Negrito';

  @override
  String get italic => 'Itálico';

  @override
  String get quote => 'Citação';

  @override
  String get list => 'Lista';

  @override
  String get code => 'Código';

  @override
  String get link => 'Link';

  @override
  String get horizontalRule => 'Linha';

  @override
  String get textPlaceholder => 'texto';

  @override
  String get codePlaceholder => 'código';

  @override
  String readingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min de leitura',
      one: '1 min de leitura',
    );
    return '$_temp0';
  }

  @override
  String get backToLibrary => 'Voltar à biblioteca';

  @override
  String get adjustments => 'Ajustes';

  @override
  String get exitReadingMode => 'Sair do modo leitura';
}
