## Sépia 2.5.7

Esta versão acrescenta leitura em voz alta por API e pelo próprio servidor Sépia.

- **Azure Speech e ElevenLabs:** use sua chave, escolha voz/modelo, ajuste a velocidade e ouça uma prévia. Há planos com franquias limitadas; disponibilidade, termos e cobrança dependem da sua conta.
- **Servidor Sépia:** síntese opcional com Supertonic 3 M1/M2 em CPU. O app pode herdar endereço/token da sincronização ou usar um servidor informado separadamente.
- **Também na Lite e na web:** reprodução remota sem baixar modelos neurais no aparelho. As opções de voz anteriores são preservadas.
- Autorização explícita antes de enviar texto. Chaves ficam no armazenamento seguro do aparelho, fora da sincronização e das exportações; no navegador, somente na sessão atual.
- Preparação da próxima fala opcional, inicialmente desligada para evitar consumo antecipado de cota. Pausa, salto e mudança de velocidade descartam respostas antigas.
- Backend com autenticação, uma síntese por vez, limites de texto/áudio e processamento independente do lock da biblioteca. O servidor básico continua sem dependências externas.
- Novo arquivo `sepia-2.5.7-tts-server.tar.gz` com backend e manifesto; os pesos originais (~381 MiB) são opcionais, verificados por SHA-256 e mantêm sua licença.

Configuração e instalação: [guia de TTS remoto](https://github.com/elias001011/sepia-reader/blob/main/docs/TTS-REMOTO.md).

Validado com testes Flutter/Python, análise estática, build web, reprodução no navegador e síntese real no servidor Termux. Contratos Azure/ElevenLabs foram testados com respostas simuladas; acesso e qualidade por conta exigem suas próprias chaves. O servidor pode ser mais lento que o aparelho: não há garantia de redução de latência.
