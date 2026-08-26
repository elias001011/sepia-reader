# Sépia

[Português](README.md) · [English](README.en.md)

Leitor, biblioteca e editor de Markdown feito em Flutter. O Sépia foi pensado para quem quer guardar textos, editar sem trocar de ferramenta e depois deixar a interface desaparecer para simplesmente ler.

## O que já funciona

### Ler
- modo leitura que bloqueia edição, usa controles compactos e permite ocultá-los automaticamente;
- fonte Merriweather e tema Sépia como padrão, com presets Artifact, Papel e Noite;
- fonte, tamanho, entrelinha, largura, fundo e texto configuráveis;
- marcadores ancorados ao trecho do texto, não à posição de rolagem — não escorregam quando o documento muda de tamanho;
- Markdown completo: títulos, ênfase, riscado, listas, listas de tarefas, citações aninhadas, tabelas com alinhamento, links (inclusive por referência), imagens, notas de rodapé e blocos de código;
- visualizador dedicado para código, com numeração de linhas, separado do leitor de prosa;
- prévia de arquivos `.html`, com o código a um toque de distância;
- documentos grandes virtualizados: só o que está na tela é construído.

### Ouvir
- leitura em voz alta, com escolha do capítulo (`#`/`##`) por onde começar, "continuar de onde parei", pausa, avanço de trecho e controle de velocidade;
- o texto rola acompanhando a voz;
- três níveis de voz:
  - **voz do sistema** — ultra leve, usa o que o Android ou o navegador já tem, nada para baixar;
  - **Piper** (~80 MB) — voz neural que roda bem em qualquer aparelho;
  - **Kokoro** (~400 MB) — mais natural, para quem tem espaço e memória sobrando;
- as duas neurais rodam offline no próprio aparelho via sherpa-onnx: nenhum texto sai do dispositivo, sem API e sem chave;
- vozes baixadas sob demanda, com progresso, cancelamento, retomada de download interrompido e remoção; o download continua se você fechar as configurações e fica visível na biblioteca;
- a sintaxe do Markdown não é lida em voz alta — tabelas viram texto, código e diagramas são pulados.

### Escrever
- editor responsivo com atalhos para títulos, negrito, itálico, citações, listas, links e código;
- desfazer/refazer por sessão via interface, `Ctrl/Cmd+Z`, `Ctrl+Y` ou `Ctrl/Cmd+Shift+Z`;
- documentos grandes editados por partes, seguindo os capítulos do próprio texto, para a digitação não travar — o arquivo salvo continua inteiro;
- syntax highlighting para Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL e XML.

### Guardar
- biblioteca local com busca, favoritos, pastas, subpastas e contagem de palavras;
- criação de `.md` e `.txt` na raiz ou dentro de uma pasta;
- renomeação e movimentação entre pastas e de volta à raiz;
- importação múltipla, por arrastar e soltar no navegador ou de pastas inteiras, preservando a hierarquia, com limite de 5 MB por arquivo;
- arquivos que não são texto (`.docx`, `.pdf`, imagens) são recusados mesmo se renomeados — a checagem é nos bytes, não na extensão;
- exclusão de pastas com confirmação, levando junto subpastas e documentos;
- sincronização opcional com um servidor próprio, com puxar-para-atualizar na biblioteca;
- persistência local e exportação do arquivo original.

### Em qualquer lugar
- tema Material 3 claro, escuro, AMOLED ou do sistema, com fundos claro e escuro personalizados;
- opção para a leitura seguir integralmente as cores do app ou usar sua própria paleta;
- interface localizada em português do Brasil e inglês, com opção de seguir o sistema;
- tamanho da interface ajustável por barra, somando-se à escala de fonte do próprio sistema;
- aviso de nova versão ao abrir, com link direto para o APK da arquitetura do aparelho — nada é baixado nem instalado sem você escolher;
- versões web, Android e iOS a partir da mesma base Flutter (as vozes neurais são exclusivas das versões nativas).

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
flutter build apk --release --split-per-abi   # um APK por arquitetura
flutter build apk --release                   # universal, todas juntas
```

O script web inclui o runtime Flutter, as fontes Inter, Merriweather, Lora e Roboto Mono, além dos fallbacks Noto para emojis e símbolos, no próprio `build/web`; a aplicação não depende de Google Fonts nem de um CDN em execução.

As vozes neurais rodam via `sherpa_onnx`, que traz bibliotecas nativas para cada arquitetura Android. Por isso o `--split-per-abi`: um APK `arm64-v8a` carrega só a biblioteca do próprio aparelho, enquanto o universal carrega as de todas. Os modelos de voz **não** vão no APK — são baixados sob demanda pelo app, de dentro das configurações.

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

Tags semânticas publicam automaticamente um GitHub Release com um APK por arquitetura, um APK universal, o pacote web estático e checksums SHA-256:

```bash
git tag v1.2.0
git push origin v1.2.0
```

**Baixe o `arm64-v8a`** — é a arquitetura de praticamente todo celular Android atual, e é o menor dos APKs. O `armeabi-v7a` serve aparelhos antigos, o `x86_64` serve emuladores, e o universal existe só como recurso de compatibilidade, sendo bem maior porque carrega as bibliotecas nativas de todas as arquiteturas ao mesmo tempo.

Todos usam a assinatura de desenvolvimento atual e são indicados para instalação direta/testes. Antes de distribuir pela Play Store, configure uma chave de assinatura permanente e prefira um Android App Bundle — o próprio Play entrega só a ABI de cada aparelho.

## Stack

Flutter + Material 3, `flutter_markdown_plus`, `highlight`, `file_picker`, `file_saver`, `shared_preferences` e fontes OFL empacotadas localmente.

## Licença

MIT.
