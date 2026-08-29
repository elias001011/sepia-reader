# Histórico

As notas de cada Release publicada no GitHub são geradas a partir dos commits.
Este arquivo resume o que muda para quem usa o app, e mantém uma seção para o
que já está em `main` mas ainda não foi lançado.

## Não lançado

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
