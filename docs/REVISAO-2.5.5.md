# Revisão 2.5.5

## Desempenho e persistência

A biblioteca conserva uma lista ordenada por revisão, sem refazer a ordenação a
cada acesso. Um índice agrupa documentos e pastas e propaga as contagens de baixo
para cima; a construção percorre cada registro uma vez, mesmo com pastas profundas.
A virtualização continua ativa nos três layouts.

A sincronização compara identificadores e revisões sem codificar o texto inteiro.
Coleções inalteradas não são regravadas. Gravações grandes usam um isolate nas
plataformas nativas; na web, a codificação de conteúdo é dividida em blocos com
pausas para a interface. As gravações locais e a reconciliação de documentos
compartilham uma fila para preservar a ordem quando há edição durante o sync.

Fontes importadas são registradas quando selecionadas. Copiar uma seleção limpa
a seleção e permite que os blocos antigos voltem a ser descartados pelo leitor.

## Correções de funcionamento

- Endereço e token são capturados juntos para cada requisição; a consulta de
  capacidade do servidor não pode contaminar o cache de outra configuração.
- Requisições da API recusam redirecionamentos, inclusive na CLI Python.
- Datas sem fuso de clientes antigos usam um fuso legado configurável e são
  devolvidas como UTC. Datas já explícitas preservam seu instante.
- Novas alterações avançam além das revisões já observadas, mesmo com relógios
  adiantados. Exclusões por CLI também consideram os marcadores envolvidos.
- A CLI aceita `.text` e informa a versão 2.5.5, assim como o servidor.
- Exemplos públicos usam domínios e configurações genéricos.

## Aparência e adaptação

Menus de arquivos e pastas compartilham implementação, ícones e espaçamento.
Os controles deslizantes usam o mesmo componente, com valor visível e rótulo que
pode quebrar linha. O controle de restaurar a escala se adapta à largura; a altura
dos cartões acompanha o texto ampliado. O seletor de cores pode rolar em janelas
baixas, e contadores usam singular e plural corretamente.

As prévias HTML usam o conversor de leitura em uma amostra limitada; prévias de
código e texto simples preservam seus caracteres. Grade e lista continuam sem
prévia de conteúdo.

A conferência visual usa arquivos fictícios em um ambiente local isolado e cobre
biblioteca, layouts, pastas, editor, prévia, leitor, capítulos, marcadores, temas,
fontes, cores e configurações, em larguras de celular e desktop. Testes adicionais
cobrem nomes longos e interface ampliada em 320 e 768 pixels.

## Validação

- Análise estática Flutter sem ocorrências.
- Suíte Flutter completa, incluindo sincronização concorrente, arquivos grandes,
  virtualização, cópia, navegação e adaptação de layout.
- 24 testes Python; operações de biblioteca usam dados temporários.
- A suíte Python também foi executada em Python 3.14 no Termux.
- Builds Android e web e testes da variante Lite são verificados pelo workflow
  de release antes da publicação dos artefatos.

A inspeção de navegador verifica o resultado da compilação web. Não substitui
medições de fluidez e consumo no hardware de cada aparelho Android.
