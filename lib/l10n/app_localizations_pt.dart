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
  String get appAppearance => 'Configurações';

  @override
  String get appAppearanceDescription =>
      'Tema, idioma, sincronização e leitura em voz alta. O botão no fim salva tudo o que está nesta tela.';

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
  String get saveAppearance => 'Salvar';

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
  String get presetsLight => 'Claros';

  @override
  String get presetsDark => 'Escuros';

  @override
  String get sepiaPreset => 'Sépia';

  @override
  String get artifactPreset => 'Artifact';

  @override
  String get paperPreset => 'Papel';

  @override
  String get nightPreset => 'Noite';

  @override
  String get parchmentPreset => 'Pergaminho';

  @override
  String get creamPreset => 'Creme';

  @override
  String get greyPreset => 'Cinza';

  @override
  String get mintPreset => 'Menta';

  @override
  String get skyPreset => 'Céu';

  @override
  String get inkPreset => 'Tinta';

  @override
  String get solarizedPreset => 'Solarizado';

  @override
  String get nordPreset => 'Nord';

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
  String get appearance => 'Configurações';

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
  String get exportSelectionFailed =>
      'Não foi possível exportar os arquivos selecionados.';

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

  @override
  String get addBookmark => 'Marcar esta posição';

  @override
  String get bookmarkAdded => 'Marcador adicionado';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get bookmarksEmpty =>
      'Nenhum marcador ainda. Toque no ícone de marcador na barra de leitura para guardar onde você parou.';

  @override
  String get removeBookmark => 'Remover marcador';

  @override
  String get goToBookmark => 'Ir para o marcador';

  @override
  String get syncSection => 'Sincronização';

  @override
  String get syncWithServer => 'Sincronizar com o servidor';

  @override
  String get syncWithServerDescription =>
      'Mantém a biblioteca igual em todos os aparelhos que abrem este servidor.';

  @override
  String get syncServerAddress => 'Endereço do servidor';

  @override
  String get syncServerAddressHint =>
      'Vazio: usar o endereço de onde o app foi aberto';

  @override
  String get syncTestConnection => 'Testar conexão';

  @override
  String get syncTesting => 'Testando…';

  @override
  String syncTestOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conectado. $count documentos no servidor.',
      one: 'Conectado. 1 documento no servidor.',
    );
    return '$_temp0';
  }

  @override
  String syncTestFailed(String error) {
    return 'Falhou: $error';
  }

  @override
  String get syncOff => 'Sincronização desligada';

  @override
  String get syncNever => 'Ainda não sincronizado';

  @override
  String syncLast(String time) {
    return 'Última sincronização: $time';
  }

  @override
  String get syncDisabledTitle => 'Desligar a sincronização';

  @override
  String get syncDisabledBody =>
      'A partir de agora este aparelho para de enviar e receber mudanças. A biblioteca que está aqui continua inteira, aconteça o que acontecer.\n\nFalta decidir o que fazer com a cópia que já está no servidor:\n\n• Manter no servidor — a cópia fica lá, intacta. Outros aparelhos que sincronizam continuam com ela, e se você religar a sincronização aqui as duas partes voltam a se juntar.\n\n• Apagar do servidor — a cópia do servidor é esvaziada agora. Os outros aparelhos que sincronizam vão receber essa exclusão e ficar sem esses documentos também. Este aparelho não perde nada.';

  @override
  String get syncKeepOnServer => 'Manter no servidor';

  @override
  String get syncWipeFromServer => 'Apagar do servidor';

  @override
  String get syncWipeFailed =>
      'Sincronização desligada, mas não foi possível apagar a cópia no servidor. Ela continua lá.';

  @override
  String get syncWipeDone => 'Cópia do servidor apagada.';

  @override
  String get syncPullDone => 'Biblioteca sincronizada com o servidor.';

  @override
  String get syncPullFailed =>
      'Não foi possível falar com o servidor. Sua biblioteca local está intacta.';

  @override
  String get syncPullDisabled =>
      'A sincronização está desligada. Ligue nas configurações para usar este gesto.';

  @override
  String deleteFolderTitle(String name) {
    return 'Excluir “$name”?';
  }

  @override
  String get deleteFolderEmptyBody => 'A pasta está vazia. Ela será excluída.';

  @override
  String deleteFolderBody(int documents, int subfolders) {
    String _temp0 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents documentos',
      one: '1 documento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subfolders,
      locale: localeName,
      other: '$subfolders subpastas',
      one: '1 subpasta',
      zero: 'nenhuma subpasta',
    );
    return 'Isto exclui também $_temp0 e $_temp1. Não dá para desfazer.';
  }

  @override
  String folderDeleted(String name) {
    return '“$name” foi excluída.';
  }

  @override
  String unsupportedBinaryFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count arquivos foram recusados: não são texto (por exemplo .docx ou .pdf).',
      one: '1 arquivo foi recusado: não é texto (por exemplo .docx ou .pdf).',
    );
    return '$_temp0';
  }

  @override
  String get ttsSection => 'Leitura em voz alta';

  @override
  String get ttsEnable => 'Ativar a leitura em voz alta';

  @override
  String get ttsEnableDescription =>
      'Adiciona um botão de ouvir no modo leitura.';

  @override
  String get ttsEngineSystem => 'Voz do sistema';

  @override
  String get ttsEngineSystemDescription =>
      'Ultra leve: usa a voz que o Android ou o navegador já tem. Não baixa nada, não ocupa espaço e funciona offline.';

  @override
  String get ttsEngineNeural => 'Voz neural no aparelho';

  @override
  String get ttsEngineNeuralDescription =>
      'Muito mais natural. Roda offline no próprio aparelho, sem API e sem mandar seu texto para lugar nenhum — mas precisa baixar uma voz primeiro.';

  @override
  String get ttsVoice => 'Voz';

  @override
  String get ttsVoiceAuto => 'Escolher automaticamente';

  @override
  String get ttsRate => 'Velocidade';

  @override
  String get ttsPitch => 'Tom';

  @override
  String get ttsPreview => 'Ouvir uma amostra';

  @override
  String get ttsPreviewText => 'Esta é a voz que vai ler seus documentos.';

  @override
  String get ttsNoVoices => 'Nenhuma voz encontrada neste aparelho.';

  @override
  String get ttsLoadingVoices => 'Procurando vozes…';

  @override
  String get ttsListen => 'Ouvir';

  @override
  String get ttsChooseChapter => 'Ouvir a partir de';

  @override
  String get ttsWholeDocument => 'Ler o documento inteiro';

  @override
  String get ttsNoChapters =>
      'Este documento não tem capítulos (#/##), então dá para ouvir ele inteiro.';

  @override
  String ttsChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String get ttsFromHere => 'Começar de onde parei';

  @override
  String get ttsStop => 'Parar';

  @override
  String get ttsPause => 'Pausar';

  @override
  String get ttsResume => 'Continuar';

  @override
  String get ttsPrevious => 'Trecho anterior';

  @override
  String get ttsNext => 'Próximo trecho';

  @override
  String ttsFailed(String error) {
    return 'A leitura em voz alta falhou: $error';
  }

  @override
  String get ttsNothingToRead => 'Não há texto para ler nesta parte.';

  @override
  String ttsProgress(int current, int total) {
    return '$current de $total';
  }

  @override
  String get viewerSource => 'Código';

  @override
  String get viewerPreview => 'Prévia';

  @override
  String get appearanceSection => 'Aparência';

  @override
  String editSectionPosition(int current, int total) {
    return '$current/$total';
  }

  @override
  String get editSectionHint =>
      'Documento grande: o editor carrega uma parte por vez para não travar. O documento inteiro continua salvo e o modo leitura mostra tudo.';

  @override
  String get editSectionPrevious => 'Parte anterior';

  @override
  String get editSectionNext => 'Próxima parte';

  @override
  String get editSectionChoose => 'Escolher a parte';

  @override
  String get editWholeDocument =>
      'Desligar a edição por capítulo (vale para todos os documentos)';

  @override
  String editSectionPart(String number) {
    return 'Parte $number';
  }

  @override
  String get ttsEngineNeuralUnavailableWeb =>
      'No navegador só a voz do sistema funciona: a voz neural precisa rodar nativamente. Use o app Android para isso.';

  @override
  String get ttsManageVoices => 'Baixar vozes';

  @override
  String get ttsVoicesTitle => 'Vozes para baixar';

  @override
  String get ttsVoicesDescription =>
      'Baixe uma vez e use offline para sempre. Fica guardada no aparelho e dá para remover quando quiser.';

  @override
  String get ttsVoiceInstall => 'Baixar';

  @override
  String get ttsVoiceRemove => 'Remover';

  @override
  String get ttsVoiceInstalled => 'Instalada';

  @override
  String get ttsVoiceUse => 'Usar';

  @override
  String get ttsVoiceInUse => 'Em uso';

  @override
  String ttsVoiceDownloading(int percent) {
    return 'Baixando… $percent%';
  }

  @override
  String get ttsVoiceCancel => 'Cancelar';

  @override
  String ttsVoiceSize(int size) {
    return '$size MB';
  }

  @override
  String ttsVoiceInstallFailed(String error) {
    return 'Não deu para baixar a voz: $error';
  }

  @override
  String ttsVoiceRemoveConfirm(String name) {
    return 'Remover “$name”? Os arquivos saem do aparelho e dá para baixar de novo depois.';
  }

  @override
  String get ttsVoiceHeavy =>
      'Modelo grande: precisa de bastante espaço e memória. Em aparelho mais fraco, prefira as vozes Piper.';

  @override
  String get ttsNoNeuralVoice => 'Nenhuma voz neural instalada ainda.';

  @override
  String get ttsTierLight => 'Leve';

  @override
  String get ttsTierBest => 'Melhor';

  @override
  String get ttsTierLightHint => 'Piper · roda bem em qualquer aparelho';

  @override
  String get ttsTierBestHint =>
      'Kokoro · um único modelo com várias vozes e idiomas, mais natural, mas pede bastante espaço e memória';

  @override
  String get ttsFellBackToSystem =>
      'A voz neural não pôde ser usada agora; lendo com a voz do sistema.';

  @override
  String get ttsVoiceQueued => 'Na fila…';

  @override
  String ttsVoiceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vozes',
      one: '1 voz',
    );
    return '$_temp0';
  }

  @override
  String get unsavedTitle => 'Sair sem salvar?';

  @override
  String get unsavedBody => 'Você mudou algo aqui e ainda não salvou.';

  @override
  String get unsavedSaveAndLeave => 'Salvar e sair';

  @override
  String get unsavedDiscard => 'Sair sem salvar';

  @override
  String get interfaceScale => 'Tamanho da interface';

  @override
  String get interfaceScaleDescription =>
      'Deixa tudo maior ou menor: textos, botões e espaçamentos.';

  @override
  String get interfaceScaleReset => 'Voltar ao padrão';

  @override
  String get updateSection => 'Atualizações';

  @override
  String get updateCheckAutomatically => 'Procurar atualizações ao abrir';

  @override
  String get updateCheckAutomaticallyDescription =>
      'Consulta as releases no GitHub quando há internet. Nada é baixado sozinho.';

  @override
  String updateAvailable(String version) {
    return 'Sépia $version disponível';
  }

  @override
  String updateCurrent(String version) {
    return 'Você está na versão $version, a mais recente.';
  }

  @override
  String get updateCheckNow => 'Procurar agora';

  @override
  String get updateChecking => 'Procurando…';

  @override
  String updateFailed(String error) {
    return 'Não deu para consultar as atualizações: $error';
  }

  @override
  String get updateOpen => 'Ver a release';

  @override
  String get updateDownload => 'Baixar APK';

  @override
  String get updateLater => 'Agora não';

  @override
  String get updateWebHint =>
      'Esta é a versão web: quem atualiza é o servidor que a hospeda.';

  @override
  String get updateNotes => 'Novidades';

  @override
  String voiceDownloadRunning(String name, int percent) {
    return 'Baixando $name · $percent%';
  }

  @override
  String voiceDownloadQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count na fila',
      one: 'mais 1 na fila',
    );
    return '$_temp0';
  }

  @override
  String get voiceDownloadBackgroundHint =>
      'Pode fechar as configurações: o download continua enquanto o app estiver aberto.';

  @override
  String updateOpenFailed(String url) {
    return 'Não foi possível abrir o link. Ele é: $url';
  }

  @override
  String updateInstalled(String version) {
    return 'Versão $version instalada.';
  }

  @override
  String get chapterNavigation => 'Capítulos';

  @override
  String get chapterNavigationHere => 'Continuar lendo daqui';

  @override
  String get chapterSeparatorToggle => 'Editar por capítulo';

  @override
  String get clearSelection => 'Limpar seleção';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String get deleteSelectionTitle => 'Excluir os itens selecionados?';

  @override
  String deleteSelectionBody(int documents, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents documentos',
      one: '1 documento',
      zero: 'nenhum documento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders pastas',
      one: '1 pasta',
      zero: 'nenhuma pasta',
    );
    return 'Isto remove $_temp0 e $_temp1, junto com tudo que as pastas contêm. Não dá para desfazer.';
  }

  @override
  String exportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos exportados.',
      one: '1 arquivo exportado.',
      zero: 'Nada para exportar.',
    );
    return '$_temp0';
  }
}
