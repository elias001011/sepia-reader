## Sépia 2.5.6

Esta versão concentra as mudanças na leitura em voz alta.

- Supertonic 2 e Supertonic 3, com vozes M1 e M2 e escolha de idioma. Supertonic 3 M2 aparece como recomendada; as escolhas anteriores são preservadas.
- Downloads opcionais dos modelos originais FP32: aproximadamente 252 MiB para o Supertonic 2 e 381 MiB para o 3. Os pesos não estão no APK; cada modelo é baixado uma única vez para suas vozes e idiomas.
- Preparação da próxima fala durante a reprodução, com fila limitada e descarte de resultados antigos após pausa, salto ou alteração de velocidade.
- Extração de texto do Markdown por estrutura: separadores, marcações e blocos de código deixam de chegar à voz como texto cru. Supertonic preserva pontuação expressiva; as outras vozes recebem pontuação normalizada.
- Controles de velocidade e, para a voz do sistema, tom. A Lite recebe as melhorias da voz nativa, dos controles e da navegação de leitura.
- Carregamento dos modelos sob demanda, liberação cooperativa de memória e proteção contra falhas de inicialização/reprodução.
- Downloads Supertonic fixados por revisão, com tamanho e SHA-256 verificados; licença do modelo acessível na tela de vozes e conservada na instalação.

Piper, Kokoro e a voz do sistema continuam disponíveis. A Lite conserva apenas o TTS do sistema, sem as dependências neurais. Na web, a leitura em voz alta continua usando a voz do navegador.

Pronúncias e entonação dependem do modelo e do idioma. Os modelos foram avaliados em CPU de computador; não há medição em aparelho Android físico nesta rodada. O Supertonic 3 exige mais processamento que o 2.
