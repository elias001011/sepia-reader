# Contribuindo com o Sépia

Obrigado pelo interesse. Este documento reúne o que é exigido para que uma
contribuição seja integrada.

## Antes de abrir um PR

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter pub outdated          # informativo
python3 -m unittest discover -s server -p 'test_*.py'
```

O CI roda exatamente essa sequência (`.github/workflows/ci.yml`). Formatação,
análise estática e testes precisam passar; a lista de dependências desatualizadas
é informativa e não bloqueia sozinha — uma versão mais nova não significa que o
projeto deva adotá-la.

O relatório de cobertura fica em `coverage/lcov.info`. Não há meta numérica
obrigatória: o que se cobra é que **o comportamento alterado tenha teste**. Regra
de negócio, transformação de dados e interação de tela que mudou devem vir com
teste automatizado correspondente.

## Arquitetura

Mantenha a separação que o projeto já usa:

- `lib/state/app_controller.dart` — estado da aplicação e regras que coordenam
  documentos, pastas, marcadores e ajustes.
- `lib/services/` — persistência, sincronização, importação/exportação, voz.
- `lib/screens/` — telas e painéis.
- `lib/widgets/` — componentes reutilizáveis.

Novos widgets não devem concentrar regra de negócio. Evite `setState` para o que
já é notificado pelo `AppController`.

## Janelas

**Toda janela que abre algo usa o mesmo componente.** O painel de referência é o
dos marcadores:

- `showAppSheet(...)` abre o painel (largura máxima de 480 px, centralizado em
  janelas largas, preso à borda inferior no celular).
- `SheetScaffold` / `SheetScaffold.list` dão o cabeçalho, o fechamento e a
  rolagem.
- `SheetPrompt` para confirmações e formulários curtos dentro do mesmo painel.
- `showSheetConfirm` para perguntas de sim/não.
- `NameEntrySheet` para criar/renomear com um campo.
- `SheetChoiceField` + `showSheetChoices` para seletores e menus de ações.

Não reintroduza `showDialog`, `AlertDialog`, `PopupMenuButton` ou
`DropdownButton`: eles quebravam a consistência visual e o comportamento no
desktop.

Painéis com alterações não salvas usam `enableDrag: false` e `PopScope`, porque
arrastar para baixo chama `Navigator.pop` direto e ignora a pergunta.

## Ciclo de vida e erros

- `TextEditingController`, `ScrollController`, `Timer`, `StreamSubscription` e
  motores de TTS precisam de `dispose()` explícito no lugar certo.
- Depois de um `await`, verifique `mounted` antes de `setState`/`Navigator`.
- Formulário que abre uma janela não deve depender de controller criado fora da
  rota: o dono do controller é o widget da janela.
- Falha de I/O, rede ou plugin não pode virar tela em branco: mostre o estado de
  erro ou registre com `debugPrint` e mantenha o app utilizável.

## Acessibilidade e telas

- Ícone que executa ação precisa de `tooltip` (o leitor de tela usa esse texto).
- Verifique texto ampliado (até 2×), tema claro e escuro, tela estreita (320 px) e
  janela desktop larga e baixa.
- Áreas de toque de pelo menos 44×44 px.

## Plataformas

Android, iOS, web e Linux. Um build Linux não valida Windows, macOS, iOS ou web;
diga no PR o que foi realmente executado.

## Segurança

Não inclua chaves, tokens, dados reais de usuários nem logs com conteúdo privado.
Use dados fictícios e armazenamento temporário nos testes. A voz remota envia
texto do documento para um provedor externo: preserve o consentimento explícito e
a possibilidade de recusar. Veja [SECURITY.md](SECURITY.md).

## Dependências

Pacote novo exige justificativa no PR: o que resolve, por que o que já existe não
basta, manutenção recente e licença compatível com MIT. Plugins nativos também
pesam no tamanho do app e no suporte a cada plataforma.

## Documentação

Alteração visível ao usuário entra no `CHANGELOG.md`. Mudança de arquitetura ou de
API interna relevante deve aparecer aqui ou em `docs/`.

## Commits e PRs

Descreva o problema, o comportamento resultante e como reproduzir/testar. Vincule
a issue quando houver. Um PR deve ter escopo claro: correções não relacionadas vão
em PRs separados.

## Revisão

Serão avaliados: aderência às convenções de Dart/Flutter, arquitetura, ausência de
duplicação, tratamento de erro, performance (nada custoso dentro de `build`,
listas grandes com builder), acessibilidade, compatibilidade entre plataformas e
testes. Uma contribuição é integrada quando passa nos checks automáticos, tem
teste do comportamento alterado e recebe aprovação de um mantenedor.
