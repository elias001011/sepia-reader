# Histórico

As notas de cada Release publicada no GitHub descrevem as mudanças e a validação.
Este arquivo resume o que muda para quem usa o app, e mantém uma seção para o
que já está em `main` mas ainda não foi lançado.


## 2.5.5 — 2026-10-18

- Reutiliza a biblioteca ordenada e indexa pastas e contadores apenas quando os documentos mudam.
- Evita codificar o conteúdo inteiro para comparar revisões e deixa de regravar coleções inalteradas na sincronização.
- Processa JSON grande em segundo plano nas plataformas nativas; a gravação mantém a ordem dos autosaves. Na web, a codificação de textos grandes cede tempo à interface entre blocos.
- Fontes importadas são carregadas sob demanda e podem ser removidas nas configurações de leitura.
- Unifica menus de arquivos e pastas e controles deslizantes, com espaçamento consistente e rótulos que se adaptam à largura.
- Libera os blocos mantidos durante uma seleção após copiar, preservando a virtualização da leitura.
- Mantém endereço e token da mesma configuração em cada requisição, recusa redirecionamentos da API e evita consultas automáticas enquanto o endereço é digitado.
- Corrige o merge de datas locais de clientes antigos com datas UTC; o fuso legado é configurável no servidor.
- Avança o relógio de alterações após revisões futuras, protegendo edições, movimentos e exclusões contra cópias antigas.
- Aceita arquivos `.text` pela CLI e identifica servidor e cliente como 2.5.5.
- Substitui endereços de infraestrutura privada por exemplos genéricos na documentação e nos testes.

## 2.5.4 — 2026-10-17

- Criar, renomear, favoritar ou mover um documento envia ao servidor só esse documento, e não a biblioteca inteira.

## 2.5.3 — 2026-10-17

- Entrar numa pasta não leva mais a lista de volta ao topo; a posição da rolagem é mantida.
- O interruptor de acesso pela CLI some para quem não usa servidor, em vez de mostrar erro nas configurações.
- Ao tocar em "arquivos", a lista rola até a primeira linha de arquivos também nos layouts de várias colunas.

## 2.5.2 — 2026-10-17

- Mostra o ícone das pastas nos layouts de grade e lista compactos na cor de destaque, como no layout padrão.
- Ao entrar numa pasta, a lista começa no topo; ao voltar para a pasta de cima, a posição em que você estava é mantida.
- A seleção de tema mostra "Personalizado" uma vez só; o bloco de cores passa a se chamar "Editar minhas cores".
- O interruptor de acesso pela CLI foi para a seção de sincronização do servidor, sem o texto explicativo e sem o IP de exemplo.
- Os contadores "arquivos" e "pastas" no topo da biblioteca levam à lista correspondente.
- Os dois contadores ficam lado a lado, na mesma linha, com rolagem horizontal quando não cabem.

## 2.5.1 — 2026-10-17

- Corrige a tela "Não foi possível abrir os dados locais" na abertura do app, que afetava a 2.5.0. O plugin de preferências volta à versão usada na 2.2.8.
- Registra no log o erro real quando a inicialização falha, para diagnóstico.

## 2.5.0 — 2026-10-17

- Corrige o gesto de voltar em pastas e subpastas; seleção e busca são canceladas antes da navegação.
- Adiciona layouts de biblioteca padrão, grade e lista compactas, com preferência persistente e sem prévias nos modos compactos.
- Preserva blocos de leitura durante seleções longas e adiciona cópia integral sem expandir o documento virtualizado.
- Compacta temas em uma lista com filtro claro/escuro; acrescenta Carvão, Rosa suave, Oliva e uma paleta personalizada salva.
- Inclui Charis e Alegreya offline, suas licenças e importação local de fontes TTF/OTF.
- Adiciona a opção de manter a tela ligada apenas durante a leitura e enquanto o app está ativo.
- Entrega CLI Python independente, com conexão direta/SSH, pastas, upload, download, edição com proteção contra conflitos, movimentação e exclusão sincronizada.
- Adiciona configuração opcional da CLI no servidor e token de autenticação para os clientes.
- Corrige a corrida entre consultas de busca e grava timestamps de documentos, pastas e marcadores em UTC.
- Atualiza dependências compatíveis, migra para File Picker 13 e valida com Flutter 3.47.4.

## Não lançado

## 2.2.8 — 2026-08-31

Acabamento da otimização da 2.2.7, que tinha resolvido o travamento ao abrir
pastas mas introduzido engasgos na busca e dois defeitos de exibição.

- **Busca:** digitar na busca não reprocessa mais a biblioteca inteira a cada
  evento de fundo (favoritar um resultado, um sync terminando) — só quando algum
  documento que a busca poderia casar realmente mudou. Os resultados param de
  piscar e a varredura pesada sai do caminho da digitação.
- **Biblioteca:** a contagem de documentos por pasta deixa de ser recalculada
  durante a busca, quando nenhum cartão de pasta está na tela.
- **Editor:** abrir o mesmo documento com um toque duplo rápido não deixa mais um
  ouvinte preso, que multiplicava o custo dos itens acima.
- **Sincronização:** uma falha momentânea ao sondar o servidor (aparelho sem
  rede na abertura, servidor ainda subindo) não prende mais o autosave no envio
  da coleção inteira pelo resto da sessão — a sonda é refeita no próximo
  salvamento.
- **Editor:** o preview escondido volta a acompanhar o texto, então girar a tela
  ou entrar em tela dividida mostra o preview atualizado, não o texto de quando o
  editor abriu.

## 2.2.7 — 2026-08-31 (retirada)

Publicada e retirada no mesmo dia: os APKs traziam engasgos de FPS na busca e ao
abrir pastas. O conteúdo abaixo foi corrigido e relançado na 2.2.8.

- **Desempenho:** bibliotecas grandes agora virtualizam os cartões e deixam de
  reprocessar o corpo de todos os documentos a cada clique ou salvamento.
- **Editor e leitor:** preview oculto deixa de renderizar durante a digitação;
  contagem de palavras e navegação reutilizam os dados já calculados.
- **Sincronização:** o autosave reaproveita o JSON dos documentos inalterados e
  servidores novos recebem apenas o registro editado. Servidores antigos são
  detectados e continuam recebendo a coleção completa com segurança.
- **Proteção de dados:** gravações locais são ordenadas, o app salva ao ser
  suspenso e um registro malformado não descarta os demais documentos válidos.
- **Markdown:** o botão de linha horizontal agora insere o espaço necessário,
  evitando transformar acidentalmente o diálogo anterior em título Setext.
  Títulos Setext escritos de propósito continuam funcionando como na v1.
- **Voz:** uma falha no meio de um capítulo (o aparelho perde a saída de áudio,
  a voz do sistema morre) agora encerra a leitura e mostra o motivo, em vez de
  deixar a barra do player parada com um botão de pausa que não faz nada. Uma
  interrupção normal — pausar, pular, trocar de capítulo — não é mais registrada
  como erro.
- **Editor:** uma tecla digitada no exato instante em que o salvamento
  automático estava gravando não é mais descartada ao sair da tela.

## 2.2.6 — 2026-08-29

- Configuração vinda de um servidor de sincronização com um campo de tipo
  errado não derruba mais a sincronização inteira.
- Bloco de código cercado por quatro ou mais crases deixa de ser fechado por
  uma cerca interna de três no renderizador.
- Importar uma pasta em que todo arquivo é binário não deixa mais uma pasta
  vazia criada e sincronizada.
- Primeira correção do player de voz preso em falha (ver "Não lançado" para o
  acabamento).

## 2.2.5 — 2026-08-29

- Inicialização não fica mais bloqueada esperando a rede; o sync foi endurecido
  contra respostas malformadas e travas de `Future`.
- Servidor de sincronização passa a comprimir as respostas (gzip), o que reduz
  muito o tempo de sincronizar bibliotecas grandes em redes lentas.
- Correções em decodificação de sync, cercas de código, falha de TTS e
  importação de pasta vazia.

## 2.2.4 — 2026-08-29

Consolida e substitui as retiradas 2.2.0–2.2.3.

- Pacote de fontes de leitura (treze famílias), incluindo a Merriweather como
  sempre foi (padrão), a Merriweather (2017) clássica como opção separada e a
  Newsreader; mais paletas de leitura claras e escuras.
- **Sépia Lite:** segunda build Android, sem a pilha de voz neural on-device,
  bem menor, publicada na mesma Release.
- Cabeçalho da biblioteca fixado na tela e flutuando sobre o conteúdo, com
  fundo realmente transparente.
- Exportação para a pasta Downloads pela caixa de diálogo do sistema volta a
  funcionar.
- Permissão de `INTERNET` restaurada no APK de release (sync e verificação de
  atualização voltaram a funcionar).
- Espaçamento estranho acima dos cartões da biblioteca corrigido.
- Notas de atualização no cartão passam a renderizar Markdown em vez de texto
  cru.
- Servidor de sincronização ganha modo headless (só sync, sem interface web) e
  endpoint `/healthz`.
- Branches de entrega `app` e `web` aposentadas.
