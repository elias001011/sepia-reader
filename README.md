# Sépia

[Português](README.md) · [English](README.en.md)

Leitor, biblioteca e editor de Markdown feito em Flutter. O Sépia foi pensado para quem quer guardar textos, editar sem trocar de ferramenta e depois deixar a interface desaparecer para simplesmente ler.

## O que já funciona

- biblioteca local com busca, favoritos, pastas, subpastas e contagem de palavras;
- criação de `.md` e `.txt` na raiz ou diretamente dentro de uma pasta;
- renomeação e movimentação de documentos entre pastas e de volta à raiz;
- importação múltipla, por arrastar e soltar no navegador ou de pastas inteiras, preservando a hierarquia e aceitando arquivos compatíveis de até 5 MB;
- editor responsivo com atalhos para títulos, negrito, itálico, citações, listas, links e código;
- desfazer/refazer por sessão via interface, `Ctrl/Cmd+Z`, `Ctrl+Y` ou `Ctrl/Cmd+Shift+Z`;
- preview correto de Markdown, tabelas, citações e blocos de código, com contraste independente do tema do app;
- syntax highlighting para Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL e XML;
- modo leitura que bloqueia edição, usa controles compactos e permite ocultá-los automaticamente;
- fonte Merriweather e tema Sépia como padrão, com presets Artifact, Papel e Noite;
- fonte, tamanho, entrelinha, largura, fundo e texto configuráveis;
- tema Material 3 claro, escuro, AMOLED ou do sistema, com fundos claro e escuro personalizados;
- opção para a leitura seguir integralmente as cores do app ou usar sua própria paleta;
- interface localizada em português do Brasil e inglês, com opção de seguir o sistema;
- persistência local e exportação do arquivo original;
- versões web, Android e iOS a partir da mesma base Flutter.
- leitura em voz alta opcional no modo leitura, com escolha do capítulo (`#`/`##`) por onde começar, controles de pausa, avanço e velocidade, usando a voz nativa do Android ou do navegador (sem download, sem API, sem internet);
- visualizador dedicado para código, com numeração de linhas, separado do leitor de prosa;
- prévia simples de arquivos `.html` no modo leitura, com o código a um toque de distância;
- documentos grandes são editados por partes (capítulos do próprio texto), mantendo a digitação fluida sem alterar o arquivo salvo;
- arquivos que não são texto (`.docx`, `.pdf`, imagens) são recusados na importação, mesmo renomeados;
- exclusão de pastas com confirmação, levando junto subpastas e documentos;
- sincronização opcional com um servidor próprio, com puxar-para-atualizar na biblioteca;

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
bash tool/build_web.sh
flutter build apk --release
flutter build apk --release --target-platform android-arm64
```

O script web inclui o runtime Flutter, as fontes Inter, Merriweather, Lora e Roboto Mono, além dos fallbacks Noto para emojis e símbolos, no próprio `build/web`; a aplicação não depende de Google Fonts nem de um CDN em execução.

Os arquivos ficam armazenados localmente no dispositivo/navegador com `shared_preferences`. O Sépia não envia conteúdo para servidores.

## Web e self-hosting

Na web, a biblioteca é salva no armazenamento local do navegador e fica vinculada à origem usada para acessar o Sépia — por exemplo, `https://sepia-md.netlify.app`. O servidor entrega apenas os arquivos estáticos do app; os documentos não são enviados para ele. Visitantes diferentes não compartilham bibliotecas, e o Netlify não recebe o conteúdo dos documentos. Alguém usando o mesmo perfil do navegador e a mesma origem, porém, terá acesso àquela biblioteca local.

Por isso, self-hosting é o foco recomendado para uma instalação privada e com endereço estável. Ainda assim, o usuário deve exportar documentos importantes: limpar os dados do site, trocar de navegador ou mudar o domínio pode tornar a biblioteca local inacessível.

O pacote web self-hostable é anexado a cada GitHub Release.

### Publicar no Netlify

1. Execute `bash tool/build_web.sh` ou baixe e extraia o arquivo `sepia-*-web.tar.gz` da Release.
2. No painel do Netlify, abra **Deploys** e arraste a pasta `build/web` inteira para a área de deploy manual.
3. Em **Domain management**, defina o endereço desejado, como `sepia-md.netlify.app`.

Os arquivos `_headers` e `_redirects` já são incluídos na build para compatibilidade com WebAssembly, rotas estáticas e uma política de conteúdo restrita à própria origem.

## Releases

Tags semânticas publicam automaticamente um GitHub Release com um APK Android universal, um APK `arm64-v8a` menor para aparelhos modernos, o pacote web estático e checksums SHA-256:

```bash
git tag v1.2.0
git push origin v1.2.0
```

O APK ARM64 é o download recomendado para a maioria dos aparelhos modernos; o universal fica disponível como opção de compatibilidade. Ambos usam a assinatura de desenvolvimento atual e são indicados para instalação direta/testes. Antes de distribuir pela Play Store, configure uma chave de assinatura permanente e prefira um Android App Bundle.

## Stack

Flutter + Material 3, `flutter_markdown_plus`, `highlight`, `file_picker`, `file_saver`, `shared_preferences` e fontes OFL empacotadas localmente.

## Licença

MIT.
