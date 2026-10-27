## Sépia 2.5.9

Correção para o desktop Linux.

- **Barra superior:** no Linux, a barra do Sépia segue as cores do app, inclusive o fundo escuro ou o AMOLED. Antes ela ficava branca, com o tema claro do GTK, mesmo com o app escuro.
- **Modo leitura:** enquanto um documento é lido, a barra assume a cor do papel da leitura e o texto da cor do texto, então fica igual ao fundo da página.
- Android, iOS, web e servidor não mudam além do número da versão.

Validado com análise estática e testes Flutter. A cor da barra depende do ambiente gráfico: a correção vale para a barra desenhada pelo GTK, usada em GNOME e Wayland. Em outros gerenciadores de janela, a barra continua sendo a do próprio sistema.
