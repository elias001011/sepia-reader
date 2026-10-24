## Sépia 2.5.8

Esta versão traz o Sépia para o desktop Linux.

- **Sépia para Linux (x86_64):** baixe `sepia-2.5.8-linux-x64.tar.gz`, extraia e rode `bash install.sh`. A instalação é só para o seu usuário (`~/.local/opt/sepia`), sem root, com atalho no menu e o comando `sepia-desktop`. Para remover: `bash install.sh --remove`.
- Mesma biblioteca, leitura, edição e sincronização com o servidor Sépia dos outros apps. Aponte para o endereço e o token do seu servidor em **Configurações → Sincronização**.
- **Voz:** no Linux, validei apenas as vozes remotas (Azure, ElevenLabs, servidor Sépia). A voz do sistema não existe nesta plataforma, e as vozes neurais locais aparecem nas configurações mas não foram testadas no Linux.
- **Requisitos:** GTK 3, GStreamer (com os plugins de áudio) e libsecret, presentes na maioria das distribuições com ambiente gráfico.
- Corrige o erro ao parar a voz do sistema em plataformas que não a oferecem.

Validado com testes Flutter/Python, análise estática, build Linux release e abertura do app em Linux. Só x86_64; sem pacote ARM, AppImage, Flatpak ou .deb nesta versão.
