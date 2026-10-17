# Revisão funcional e de código — Sépia 2.5

Revisão em 17/10/2026, sobre a base 2.2.8, incluindo as versões completa e Lite.

## Correções verificadas

- A biblioteca trocava o identificador da pasta na mesma rota e não tratava o
  botão/gesto de voltar do sistema. Um `PopScope` cancela seleção, limpa busca
  e sobe para a pasta mãe, nessa ordem. Pastas removidas durante sincronização
  retornam à raiz. A rolagem fica identificada por pasta e layout.
- Resultados de uma consulta antiga podiam chegar durante o debounce da
  consulta seguinte. A geração da busca agora é invalidada ao digitar.
- A seleção de leitura podia perder os parágrafos que eram reciclados pelo
  leitor virtualizado. Os blocos visitados ficam vivos enquanto há seleção e
  são liberados ao limpá-la. A ação de copiar o documento inteiro usa a fonte
  completa, sem construir centenas de parágrafos. A hipótese é compatível com
  o relato da tela branca; o gesto exato do aparelho original ainda depende
  do teste em dispositivo físico na nova versão.
- Documentos, pastas e marcadores gravavam datas locais sem fuso. Os novos
  registros usam UTC explícito para ordenar edições do app e da CLI.
- A CLI trabalha dentro do bloqueio da biblioteca, valida nomes e destinos,
  impede ciclos de pastas, protege edições com revisão otimista e conserva
  exclusões como tombstones. Importação e exportação preservam quebras de linha.
  Erros de edição preservam uma cópia local, e dados JSON corrompidos impedem
  gravações da CLI em vez de serem substituídos por uma biblioteca vazia.
- O servidor recusa dois processos compartilhando a porta, limita a espera de
  conexões inativas e resolve caminhos estáticos reais, incluindo symlinks.
- O token opcional é aplicado aos endpoints da biblioteca e fica fora das
  preferências sincronizadas. A CLI é desativada por padrão; sua configuração
  é separada dos leitores. O controle sem token só aceita alterações locais.

## Desempenho e dependências

Os layouts compactos não extraem prévias dos documentos e mantêm a construção
preguiçosa dos cartões. O leitor mantém a virtualização fora da seleção.
Os testes existentes continuam cobrindo edição por capítulos, estabilidade de
marcadores, busca assíncrona, persistência e recuperação de sincronização.
As dependências foram atualizadas dentro das restrições compatíveis; File
Picker foi migrado para 13.1 e o novo wakelock usa 1.8.1. CI e Release usam
Flutter 3.47.4, a versão validada localmente.

## Validação e implantação

Os resultados finais e a revisão Git exata são registrados no relatório de
implantação do servidor. A publicação exige análise estática e todos os testes
nas duas branches, além dos testes Python, builds Android das duas variantes e
build web offline. Atualizações de instalações existentes devem preservar o
diretório de dados e o modo de operação, com backup anterior à troca dos arquivos.
Esta revisão cobre funcionamento e os caminhos alterados; não é uma auditoria
completa de segurança nem garante ausência de outros defeitos.
