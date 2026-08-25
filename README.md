# Sépia

[Português](README.md) · [English](README.en.md)

Leitor, biblioteca e editor de Markdown feito em Flutter. O Sépia foi pensado para quem quer guardar textos, editar sem trocar de ferramenta e depois deixar a interface desaparecer para simplesmente ler.

## O que já funciona

- biblioteca local com busca, favoritos e contagem de palavras;
- criação de `.md` e `.txt` dentro do app;
- importação múltipla de Markdown, texto e arquivos de código de até 5 MB;
- editor responsivo com atalhos para títulos, negrito, itálico, citações, listas, links e código;
- preview correto de Markdown, tabelas, citações e blocos de código;
- syntax highlighting para Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL e XML;
- modo leitura que oculta as ferramentas e bloqueia edição;
- fonte Merriweather e tema Sépia como padrão, com presets Artifact, Papel e Noite;
- fonte, tamanho, entrelinha, largura, fundo e texto configuráveis;
- tema Material 3 claro, escuro ou do sistema, com cores personalizadas;
- persistência local e exportação do arquivo original;
- versões web, Android e iOS a partir da mesma base Flutter.

## Branches

- `main`: base multiplataforma e documentação do projeto;
- `app`: entrega mobile (Android/iOS);
- `web`: entrega web/PWA.

## Rodando localmente

Requer Flutter 3.47 ou mais recente.

```bash
flutter pub get
flutter run
```

Para escolher um destino:

```bash
flutter run -d chrome
flutter run -d android
```

## Builds

```bash
flutter build web --release
flutter build apk --release
```

Os arquivos ficam armazenados localmente no dispositivo/navegador com `shared_preferences`. O MVP não envia conteúdo para servidores.

## Web e self-hosting

Na web, a biblioteca é salva no armazenamento local do navegador e fica vinculada à origem usada para acessar o Sépia — por exemplo, `https://sepia.exemplo.com`. O servidor entrega apenas os arquivos estáticos do app; os documentos não são enviados para ele.

Por isso, self-hosting é o foco recomendado para uma instalação privada e com endereço estável. Ainda assim, o usuário deve exportar documentos importantes: limpar os dados do site, trocar de navegador ou mudar o domínio pode tornar a biblioteca local inacessível.

O pacote web self-hostable é anexado a cada GitHub Release.

## Releases

Tags semânticas publicam automaticamente um GitHub Release com o APK Android, o pacote web estático e checksums SHA-256:

```bash
git tag v1.0.0
git push origin v1.0.0
```

O APK automatizado usa a assinatura de desenvolvimento atual e é indicado para instalação direta/testes. Antes de distribuir pela Play Store, configure uma chave de assinatura permanente.

## Stack

Flutter + Material 3, `flutter_markdown_plus`, `highlight`, `file_picker`, `file_saver`, `shared_preferences` e `google_fonts`.

## Licença

MIT.
