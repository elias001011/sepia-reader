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
  String get amoled => 'AMOLED';

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
  String get darkThemeBackground => 'Fundo do tema escuro';

  @override
  String get readerThemeHint =>
      'As cores de leitura são independentes, exceto quando “Seguir tema do app” está ativo nos ajustes de leitura.';

  @override
  String get autoHideReaderControls => 'Ocultar controles durante a leitura';

  @override
  String get autoHideReaderControlsDescription =>
      'No modo leitura, oculta os controles após alguns instantes ou ao rolar. Toque no topo para exibi-los.';

  @override
  String get saveAppearance => 'Salvar aparência';

  @override
  String get readerSettings => 'Ajustes de leitura';

  @override
  String get readerSettingsDescription =>
      'Os ajustes são usados em todos os documentos.';

  @override
  String get followAppTheme => 'Seguir tema do app';

  @override
  String get followAppThemeDescription =>
      'Usa as superfícies e cores de texto atuais do app durante a leitura.';

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
  String get importFolder => 'Importar pasta';

  @override
  String get compatibleFilesOnly =>
      'Somente arquivos de texto e código compatíveis serão adicionados.';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get folderName => 'Nome da pasta';

  @override
  String get folderNameHint => 'Fics para ler';

  @override
  String get renameFolder => 'Renomear pasta';

  @override
  String get renameDocument => 'Renomear arquivo';

  @override
  String get rename => 'Renomear';

  @override
  String get root => 'Raiz da biblioteca';

  @override
  String get moveTo => 'Mover para…';

  @override
  String get moveDocument => 'Mover documento';

  @override
  String get openFolder => 'Abrir pasta';

  @override
  String get folderNotEmpty =>
      'Esta pasta não está vazia. Mova ou exclua o conteúdo primeiro.';

  @override
  String get noCompatibleFiles =>
      'Nenhum arquivo compatível foi encontrado nesta pasta.';

  @override
  String folderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pastas',
      one: '1 pasta',
      zero: 'nenhuma pasta',
    );
    return '$_temp0';
  }

  @override
  String folderContents(int files, int folders) {
    return '$files arquivos · $folders pastas';
  }

  @override
  String folderImported(int imported, int skipped) {
    return '$imported arquivos compatíveis importados · $skipped ignorados';
  }

  @override
  String filesImported(int imported, int skipped) {
    return '$imported arquivos importados · $skipped ignorados';
  }

  @override
  String get dropFilesHere => 'Solte os arquivos para importar';

  @override
  String get dropFilesHint =>
      'Markdown, texto ou código · até 5 MB por arquivo';

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
