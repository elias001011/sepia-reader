# Modelos Supertonic

O Sépia oferece downloads opcionais dos pesos FP32 originais, sem quantização,
com os estilos M1 e M2. Uma instalação serve a todos os idiomas do respectivo
modelo: cinco no Supertonic 2 e 31 no Supertonic 3. Português é identificado como
`pt`, sem promessa de sotaque brasileiro. As vozes já configuradas não são
substituídas automaticamente.

A licença dos modelos é a **BigScience Open RAIL-M**, separada da licença do
aplicativo, com as condições e restrições de uso do próprio modelo. O link
“Licença do modelo” aparece junto ao download e o arquivo `LICENSE` original é
baixado e mantido junto aos pesos. Consulte os termos antes de utilizar o modelo:

- [Supertonic 2: licença e modelo](https://huggingface.co/supertone-oss-archive/supertonic-2/blob/7edbcd0bba8cd579100a353a9e0b2b49cad7c875/LICENSE).
- [Supertonic 3: licença e modelo](https://huggingface.co/supertone-oss-archive/supertonic-3/blob/aafc6e32416a594460b32413efc49d7fe4ce6d46/LICENSE).

Os arquivos são obtidos diretamente dessas revisões. `supertonic_catalog.dart`
registra o SHA-256 e o tamanho de cada arquivo; a instalação verifica ambos e
revalida os arquivos já presentes ao retomar um download. Somente os arquivos
necessários são baixados. Os pesos ONNX não são modificados.

O instalador serializa as tabelas JSON de índices Unicode e estilos para o
formato binário consumido por sherpa-onnx, em outro isolate. M1 tem speaker ID 0
e M2 tem ID 1. A ordem independe da apresentação na interface.

A implementação usa o suporte Supertonic de sherpa-onnx já incluído no aplicativo,
com duas threads de CPU, oito passos de geração e idioma explícito. A síntese
continua no worker de voz. A fila mantém apenas a fala atual e uma antecipada,
com cache de até três arquivos WAV, liberados ao parar ou trocar a configuração.
Não há síntese nem envio do texto a um serviço externo.

Reticências e travessões são preservados para o frontend Supertonic. O texto
continua passando pelo parser Markdown e pela limpeza de elementos de layout.
As falas são limitadas por palavras e pontuação: 200 caracteres para o modelo 2
e 300 para o modelo 3, evitando fragmentar cada frase curta de um diálogo.
Silêncio de 120 ms antes e 60 ms depois protege a abertura da saída de áudio,
sem apagar amostras produzidas pelo modelo. Isso não corrige um fonema omitido
pelo modelo nem garante a ausência de repetições ou sotaques indesejados.

Referências de implementação:

- [API e modelos Supertonic do sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/tts/supertonic.html).
- [Serialização de estilos](https://github.com/k2-fsa/sherpa-onnx/blob/master/scripts/supertonic/generate_voices_bin.py).
- [Serialização do índice Unicode](https://github.com/k2-fsa/sherpa-onnx/blob/master/scripts/supertonic/generate_indexer_bin.py).

As prévias anteriores foram produzidas pelo helper Python upstream. A integração
é também validada com os mesmos pesos no worker Dart/sherpa-onnx. Os resultados
podem variar entre frontends e sementes. Testes de computador não substituem
medições de latência, bateria, memória e qualidade por escuta no celular.
