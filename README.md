# Sépia

[Português](README.md) · [English](README.en.md)

Leitor, biblioteca e editor de Markdown feito em Flutter. O Sépia foi pensado para quem quer guardar textos, editar sem trocar de ferramenta e depois deixar a interface desaparecer para simplesmente ler.

## O que já funciona

### Ler
- modo leitura que bloqueia edição, usa controles compactos e permite ocultá-los automaticamente;
- fonte Merriweather e tema Sépia como padrão;
- **treze famílias de leitura empacotadas** — Merriweather clássico (2.002, o padrão, com peso Black), Merriweather 4 (o redesenho de 2023 do Google Fonts), Newsreader, Merriweather Sans, Literata, Lora, Bitter, Source Serif 4, EB Garamond, Atkinson Hyperlegible, Inter, Roboto Mono e JetBrains Mono — cada uma pré-visualizada na própria letra no seletor;
- **treze paletas de leitura** divididas em claras (Papel, Pergaminho, Creme, Cinza, Menta, Céu) e escuras (Sépia, Artifact, Noite, Tinta, Solarizado, Nord, AMOLED);
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
- separador de capítulos com toggle global no menu de edição: ativa/desativa a edição por seção para todos os documentos grandes;
- navegação por capítulos no modo leitura: botão ao lado do ouvir que abre um picker de capítulos para pular direto ao trecho desejado;
- syntax highlighting para Dart, JavaScript, TypeScript, JSON, YAML, HTML, CSS, Python, Java, Kotlin, Swift, shell, SQL e XML.

### Guardar
- biblioteca local com busca, favoritos, pastas, subpastas e contagem de palavras;
- criação de `.md` e `.txt` na raiz ou dentro de uma pasta;
- renomeação e movimentação entre pastas e de volta à raiz;
- importação múltipla, por arrastar e soltar no navegador ou de pastas inteiras, preservando a hierarquia, com limite de 5 MB por arquivo;
- arquivos que não são texto (`.docx`, `.pdf`, imagens) são recusados mesmo se renomeados — a checagem é nos bytes, não na extensão;
- exclusão de pastas com confirmação, levando junto subpastas e documentos;
- sincronização opcional com um servidor próprio, com puxar-para-atualizar na biblioteca;
- persistência local e exportação do arquivo original pela caixa de diálogo "salvar" do sistema, direto para a pasta Downloads, sem pedir permissão de armazenamento.

### Em qualquer lugar
- tema Material 3 claro, escuro, AMOLED ou do sistema, com fundos claro e escuro personalizados;
- opção para a leitura seguir integralmente as cores do app ou usar sua própria paleta;
- interface localizada em português do Brasil e inglês, com opção de seguir o sistema;
- tamanho da interface ajustável por barra, somando-se à escala de fonte do próprio sistema;
- aviso de nova versão ao abrir, com link direto para o APK da arquitetura do aparelho — nada é baixado nem instalado sem você escolher;
- versões web, Android e iOS a partir da mesma base Flutter (as vozes neurais são exclusivas das versões nativas).

## Sépia e Sépia Lite

Cada Release traz **duas** builds Android do mesmo app:

| | **Sépia** (`sepia-<versão>-android-*.apk`) | **Sépia Lite** (`sepia-lite-<versão>-android-*.apk`) |
|---|---|---|
| Foco | completo | mesmo app, APK menor |
| Tamanho do APK `arm64` (por ABI) | ~48 MB | ~25 MB |
| Voz neural (Piper / Kokoro, on-device) | sim, via `sherpa_onnx` (~26 MB de libs nativas) | **não** — só a voz do sistema |
| Voz do sistema (Android/navegador) | sim | sim |
| Fontes, temas e as 13 paletas de leitura | idênticas nos dois, **empacotadas** (offline) | ← |
| Editor, marcadores, navegação por capítulos | sim | sim |
| Sincronização com servidor próprio | sim | sim |
| Aviso de nova versão | aponta para os APKs `sepia-*` | aponta para os APKs `sepia-lite-*` |
| `applicationId` | `dev.elias.sepia_reader` | `dev.elias.sepia_reader.lite` (as duas convivem no mesmo aparelho) |
| Minificação R8 / *shrink* de recursos | não | sim |

Em resumo: o Lite é o Sépia inteiro — mesma UI, mesmas fontes offline, mesmo
sync — **sem a pilha de voz neural on-device**, que responde por quase toda a
diferença de tamanho. Use o Lite se não precisa das vozes neurais e quer o
APK menor.

## Branches

- `main`: base multiplataforma, app completo e documentação do projeto;
- `Lite`: a variante enxuta descrita acima, ramificada de `main` a cada release.

As antigas branches de entrega `app` e `web` foram aposentadas na v2.2.0 — o
workflow de release (`release.yml`) já compila APKs, o pacote web e o servidor
a cada tag. Os últimos estados delas ficam nas tags `archive/app` e
`archive/web`.

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

Para a variante enxuta, faça o mesmo a partir da branch `Lite`
(`git switch Lite`). O CI de release já compila as duas a cada tag.

O script web inclui o runtime Flutter, as treze famílias de leitura, os fallbacks Noto para emojis e símbolos, e roda tudo a partir do próprio `build/web`; a aplicação não depende de Google Fonts nem de um CDN em execução. A branch `Lite` empacota as mesmas fontes.

As vozes neurais rodam via `sherpa_onnx`, que traz bibliotecas nativas para cada arquitetura Android. Por isso o `--split-per-abi`: um APK `arm64-v8a` carrega só a biblioteca do próprio aparelho, enquanto o universal carrega as de todas. Os modelos de voz **não** vão no APK — são baixados sob demanda pelo app, de dentro das configurações. A branch `Lite` não inclui `sherpa_onnx`.

Os arquivos ficam armazenados localmente no dispositivo/navegador com `shared_preferences`. O Sépia não envia conteúdo para servidores.

## Web e self-hosting

Na web, a biblioteca é salva no armazenamento local do navegador e fica vinculada à origem usada para acessar o Sépia — por exemplo, `https://sepia-md.netlify.app`. O servidor entrega apenas os arquivos estáticos do app; os documentos não são enviados para ele. Visitantes diferentes não compartilham bibliotecas, e o Netlify não recebe o conteúdo dos documentos. Alguém usando o mesmo perfil do navegador e a mesma origem, porém, terá acesso àquela biblioteca local.

Por isso, self-hosting é o foco recomendado para uma instalação privada e com endereço estável. Ainda assim, o usuário deve exportar documentos importantes: limpar os dados do site, trocar de navegador ou mudar o domínio pode tornar a biblioteca local inacessível.

O pacote web self-hostable e o servidor de sincronização `sepia-*-server.py`
são anexados a cada GitHub Release.

### Servidor de sincronização

`sepia-<versão>-server.py` é um único arquivo Python (só a biblioteca padrão,
3.9+). Ele expõe uma API JSON pequena e atômica em `/api/documents`,
`/api/folders`, `/api/settings` e `/api/bookmarks` — é isso que os apps Android
(Sépia **e** Sépia Lite) e a web usam para manter a biblioteca igual em vários
aparelhos. Nenhum conteúdo passa por terceiros: os dados ficam em arquivos JSON
ao lado do script. Ele **não** é o app Flutter — pra hospedar o sync você nunca
precisa "baixar o app inteiro".

Dá pra rodar de dois jeitos:

- **Só sync (headless).** É o modo recomendado para uma instância que só é
  acessada pelos apps nativos. Não precisa da pasta `web/` — qualquer rota que
  não seja `/api/...` ou `/healthz` responde 404, e é só isso.
- **Sync + interface web.** Extraia `sepia-<versão>-web.tar.gz` numa pasta
  `web/` ao lado do script; aí o servidor também entrega o app web na raiz.

**Passo a passo:**

1. **Coloque os arquivos juntos** num diretório no servidor (um mini-PC, um
   VPS, um celular velho com Termux):

   ```
   sepia-server/
   ├── main.py            # renomeado de sepia-<versão>-server.py
   ├── restart-sepia.sh   # opcional, reinício "à prova de porta ocupada"
   ├── web/               # SÓ no modo com interface: conteúdo de sepia-<versão>-web.tar.gz
   └── data/              # criado sozinho; guarda os .json da biblioteca
   ```

2. **Suba o servidor.** Por padrão ele escuta em `0.0.0.0:8888`:

   ```bash
   python3 main.py
   # ou personalizando:
   SEPIA_PORT=9000 SEPIA_DATA_DIR=/var/lib/sepia python3 main.py
   ```

   Variáveis: `SEPIA_PORT` (padrão `8888`), `SEPIA_WEB_DIR` (padrão `./web`),
   `SEPIA_DATA_DIR` (padrão `./data`). Para deixar rodando, use `systemd`,
   `pm2`, um `tmux`, ou o `restart-sepia.sh` incluído (feito para Termux, mas
   adaptável — ele derruba a instância antiga, espera a porta liberar e
   confirma com `curl .../healthz`). O `/healthz` funciona nos dois modos e
   devolve `{"ok": true, ...}` — bom para _healthcheck_ de systemd/Docker.

   Exemplo de unidade systemd (modo só-sync):

   ```ini
   [Unit]
   Description=Sepia sync
   After=network.target

   [Service]
   Environment=SEPIA_PORT=8888
   Environment=SEPIA_DATA_DIR=/var/lib/sepia
   Environment=SEPIA_WEB_DIR=/var/lib/sepia/web-none
   ExecStart=/usr/bin/python3 /opt/sepia/main.py
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target
   ```

3. **Exponha o endereço.** Numa LAN, `http://IP-DO-SERVIDOR:8888` já basta.
   Para acesso externo, ponha atrás de um proxy reverso com HTTPS
   (Caddy, nginx, Cloudflare Tunnel) — o servidor não termina TLS sozinho.

4. **Ligue a sincronização no app.** Em **Configurações → Sincronização**,
   ative *Sincronizar com servidor* e informe o endereço base
   (`https://sepia.seudominio.com` ou `http://192.168.0.10:8888`). Deixe o
   campo vazio **apenas** na web servida pelo próprio servidor — aí ele usa a
   própria origem. Use *Testar conexão* para confirmar, e puxe a biblioteca
   para baixo para forçar uma sincronização.

Desligar a sincronização pergunta se você quer apagar também a cópia que está
no servidor; a biblioteca local nunca é afetada por essa escolha.

### Publicar no Netlify

1. Execute `bash tool/build_web.sh` ou baixe e extraia o arquivo `sepia-*-web.tar.gz` da Release.
2. No painel do Netlify, abra **Deploys** e arraste a pasta `build/web` inteira para a área de deploy manual.
3. Em **Domain management**, defina o endereço desejado, como `sepia-md.netlify.app`.

Os arquivos `_headers` e `_redirects` já são incluídos na build para compatibilidade com WebAssembly, rotas estáticas e uma política de conteúdo restrita à própria origem.

## Releases

Tags semânticas publicam automaticamente um GitHub Release com, para **Sépia** e **Sépia Lite**, um APK por arquitetura e um universal, além do pacote web estático, o `main.py` do servidor e checksums SHA-256:

```bash
git tag v1.2.0
git push origin v1.2.0
```

O workflow constrói a branch `Lite` a partir do mesmo commit da tag (num
_worktree_ separado), então mantenha `Lite` atualizada antes de taguear.

**Baixe o `arm64-v8a`** — é a arquitetura de praticamente todo celular Android atual, e é o menor dos APKs. O `armeabi-v7a` serve aparelhos antigos, o `x86_64` serve emuladores, e o universal existe só como recurso de compatibilidade, sendo bem maior porque carrega as bibliotecas nativas de todas as arquiteturas ao mesmo tempo.

Todos usam a assinatura de desenvolvimento atual e são indicados para instalação direta/testes. Para builds de release permanentes, configure os secrets `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_STORE_PASSWORD` e `KEY_PASSWORD` no repositório GitHub — o workflow restaura a keystore automaticamente. Antes de distribuir pela Play Store, prefira um Android App Bundle — o próprio Play entrega só a ABI de cada aparelho.

## Stack

Flutter + Material 3, `flutter_markdown_plus`, `highlight`, `file_picker` (importar e exportar), `shared_preferences`, `sherpa_onnx` (voz neural on-device) e fontes OFL empacotadas localmente — a branch `Lite` só não inclui `sherpa_onnx`.

## Licença

MIT.
