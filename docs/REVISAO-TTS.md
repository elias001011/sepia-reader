# Revisão da leitura em voz alta

Data: 18/10/2026. Alterações posteriores à 2.5.5, ainda sem nova release.

## Problemas corrigidos

A preparação antecipada era chamada antes da fala atual. Como a síntese nativa
é sequencial, o próximo trecho podia ocupar o worker primeiro. Pedidos simultâneos
do mesmo texto não eram compartilhados, e parar a reprodução não invalidava uma
síntese ainda em andamento. O resultado podia tocar depois de uma pausa ou salto.

O novo buffer compartilha pedidos em andamento, prioriza a fala atual, mantém
somente um próximo trecho especulativo e conserva até três arquivos de áudio.
Pausa, salto e mudança de velocidade invalidam os resultados anteriores. Uma
chamada FFI que já começou pode terminar, mas seu resultado é descartado.

O encerramento anterior enviava uma mensagem de liberação e matava o isolate
imediatamente, podendo impedir `OfflineTts.free()` de executar. Agora o worker
libera o modelo e encerra seu ReceivePort; o motor aguarda a saída. Existe um
limite de 60 segundos para um worker que deixe de responder. A inicialização do
modelo também confirma prontidão antes de iniciar a leitura, permitindo o fallback
para a voz nativa quando a preparação falha.

A fala de Markdown usa o parser já instalado no app, sem nova dependência.
Referências, ênfase aninhada, tabelas sem barras externas, entidades e código
indentado passam a ser interpretados estruturalmente. O texto enviado às vozes
normaliza reticências e travessões, exclui separadores e preserva acentos.
Hesitações com continuação em minúscula, como “Eu… sim”, viram pausas internas.
O arquivo original permanece intacto.

Trechos ficam limitados a 240 caracteres, exceto uma palavra isolada que exceda
esse limite. A divisão respeita palavras, busca pontuação e evita copiar o restante
inteiro do parágrafo a cada corte. Documentos nativos com pelo menos 32 mil
caracteres são preparados em outro isolate. Na web, a preparação cede execução
entre grupos de blocos.

O áudio neural recebe 120 ms de silêncio inicial e 60 ms finais, sem recortar
amostras geradas. A saída usa conteúdo de fala no Android e mantém o player entre
trechos. Cada motor tem seu próprio diretório temporário, evitando que uma prévia
de voz remova os arquivos de outra reprodução.

## Controles e Lite

O leitor tem um painel “Voz e ritmo”. Aplicar velocidade/tom reinicia o trecho
atual, preservando a posição e o estado de pausa. Os controles são compartilhados
com as configurações gerais. Tom é oferecido apenas quando o motor o suporta;
Piper e Kokoro mantêm o tom do modelo. A Lite mantém a voz nativa e recebe a
limpeza do texto, a fila de navegação e esses controles.

A voz nativa agora seleciona o idioma antes da voz específica, evitando que
`setLanguage` desfaça a escolha no Android. A velocidade normal é mapeada à escala
normalizada de Android/iOS/macOS, mantendo o multiplicador direto na web. Falhas
reportadas pelo plugin deixam de avançar silenciosamente para o próximo trecho.

## Validação

- Testes de texto, fila, cancelamento durante síntese/preparação do player,
  velocidade, pausa, navegação rápida e preparação de um documento de mil blocos.
- Testes do plugin nativo por canal: ordem idioma/voz, velocidade, cancelamento
  durante a espera após `stop` e propagação de erros.
- Revisão visual do player e painel em 320 × 700, escala de interface de 140%,
  com fontes reais e ícones Material; painel sem corte no título e controles
  sem overflow. Também há testes de layout do painel com e sem controle de tom.
- Síntese real de um trecho fornecido privadamente pelo usuário com Faber e Cadu,
  passando pelo controlador, buffer e worker da aplicação. Ambos geraram os 12
  trechos. Arquivos de áudio, texto de entrada e evidências permanecem em
  `scratchpad`, fora do Git; o trecho não faz parte dos testes públicos.
- Verificação nativa de memória em ciclos sucessivos de carregar, sintetizar e
  liberar o modelo. Os resultados locais não são um benchmark de celular.

Não há aparelho Android conectado neste ambiente. A geração de WAVs e os testes
de navegação não confirmam percepção de naturalidade, pronúncia de nomes
estrangeiros, comportamento de fones Bluetooth ou latência em hardware móvel.
Piper e Kokoro foram mantidos; nenhum modelo adicional foi incluído no aplicativo.

## Referências técnicas

- [API de áudio do audioplayers](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextAndroid-class.html).
- Bindings instalados de `sherpa_onnx` 1.13.6 e implementações Android, Apple e web
  de `flutter_tts` 4.2.5, conferidos no código das dependências em uso.
