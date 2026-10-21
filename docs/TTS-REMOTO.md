# TTS remoto

Disponível no Sépia e no Sépia Lite a partir da versão 2.5.7. O cliente usa HTTP,
reprodução de áudio e armazenamento seguro, sem modelos de IA adicionais na Lite.
A voz do sistema e as opções locais continuam disponíveis.

## No aplicativo

Abra **Configurações → Leitura em voz alta → Voz por API ou servidor → Configurar
TTS remoto**. Selecione o destino e informe seus dados. A autorização de envio é
local a este aparelho. “Conectar e listar vozes” consulta as vozes disponíveis;
também é possível informar um identificador manualmente. A prévia gera uma fala
e pode consumir cota.

- **Azure Speech:** chave de um recurso Speech, região correspondente (por
  exemplo, `brazilsouth`), voz e idioma. Um exemplo de voz brasileira é
  `pt-BR-AntonioNeural`, com idioma `pt-BR`.
- **ElevenLabs:** chave da conta, identificador de uma voz disponível para ela
  e modelo. O valor inicial é `eleven_multilingual_v2`. A lista consulta até
  100 vozes; um ID que não apareça nela pode ser informado no campo de voz.
  O Multilingual v2 detecta o idioma automaticamente; outros modelos recebem
  `language_code` quando compatível. O sotaque depende também da voz escolhida.
- **Servidor Sépia:** endereço e token do servidor que executará a síntese.
  Endereço vazio usa o servidor da sincronização ou, no navegador, a origem
  da página. O token da sincronização só é herdado quando o endereço também é
  herdado. Um endereço próprio exige seu próprio token; credenciais da
  biblioteca não são encaminhadas automaticamente a outro servidor.

**O texto sai do aparelho neste modo.** O Sépia envia somente os trechos de fala
preparados pelo leitor e as consultas de vozes necessárias. As políticas de
tratamento e retenção dos provedores se aplicam. Não há promessa de retenção zero.

Configuração e chave ficam no armazenamento seguro nativo, separadas das
preferências sincronizadas, exportações da biblioteca e backups Android da
biblioteca. No navegador, duram somente na sessão atual. É possível apagá-las
pela própria configuração. No iOS, a chave usa Keychain restrito ao aparelho. A seleção do motor pode sincronizar; as credenciais e
a autorização de envio não sincronizam.

“Preparar a próxima fala” começa desligado: mesmo um áudio antecipado que seja
cancelado pode consumir cota no provedor. Quando ligado, reutiliza o buffer de
até três áudios e evita solicitar duas vezes um mesmo trecho já preparado.
Pausar, pular e alterar velocidade invalidam respostas antigas. Cancelar a
requisição não garante que o provedor interrompa a geração ou deixe de cobrar.
Não há repetição automática de chamadas que falhem.

## Gratuidade e cobrança

Consulta em **21/10/2026**; verifique as condições atuais na conta do provedor:

- [Azure Speech](https://azure.microsoft.com/en-us/pricing/details/speech/): o
  nível **Free F0** informa 500 mil caracteres neurais por mês. O recurso
  precisa estar nesse nível; não se deve presumir que uma chave de um recurso
  pago receba a mesma franquia. Há limite de solicitações no F0.
- [ElevenLabs](https://elevenlabs.io/pricing/api): a oferta gratuita informa
  10 mil créditos mensais; conversão por modelo, vozes acessíveis e permissões
  de uso dependem do plano. Consulte também os termos da conta.

O aplicativo não cria uma conta nem contrata um plano e não controla o saldo
remoto. O serviço pode cobrar conforme a configuração de cobrança do usuário.
Erros de autenticação, cota, indisponibilidade e servidor ocupado são exibidos
sem incluir texto privado ou a chave na mensagem.

## Síntese no próprio servidor

O servidor básico continua usando apenas a biblioteca padrão Python. O backend
opcional usa **Supertonic 3 FP32**, estilos M1/M2, oito passos e CPU. Requer um
ambiente com NumPy e ONNX Runtime compatíveis. Os pesos ocupam aproximadamente
381 MiB e são carregados somente na primeira fala. O modelo permanece no processo
para acelerar falas seguintes; reinicie o servidor para liberar esse runtime.
O desempenho depende do processador, memória e rede; ele pode ser inferior ao
aparelho que está lendo.

Baixe e extraia o arquivo `sepia-<versão>-tts-server.tar.gz` da release no diretório
do servidor. Ele contém `main.py`, backend, manifesto e código de suporte; os
pesos não estão incluídos. Preserve os arquivos de dados e as variáveis existentes.

Em Linux com Python 3.11 ou mais recente e wheels compatíveis:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-tts.txt
.venv/bin/python server_tts.py --install "$HOME/.local/share/sepia/tts-supertonic-3"
export SEPIA_TTS_MODEL_DIR="$HOME/.local/share/sepia/tts-supertonic-3"
export SEPIA_TTS_ENABLED=1
# Configure SEPIA_TOKEN com seu token privado antes de expor a síntese à rede.
.venv/bin/python main.py
```

No Termux, quando os pacotes estiverem disponíveis no repositório configurado:

```sh
pkg install python-onnxruntime python-numpy
python3 server_tts.py --install "$HOME/.local/share/sepia/tts-supertonic-3"
export SEPIA_TTS_MODEL_DIR="$HOME/.local/share/sepia/tts-supertonic-3"
export SEPIA_TTS_ENABLED=1
python3 main.py
```

Em páginas HTTPS, o navegador exige um destino HTTPS para servidores remotos;
CORS e a política da hospedagem também precisam permitir o destino. O pacote web
permite conexões HTTP(S) e áudio em memória; scripts e fontes continuam locais.

Os pesos são obtidos de uma revisão fixa, verificados por tamanho e SHA-256. A
licença Open RAIL-M original acompanha os arquivos; veja [SUPERTONIC.md](SUPERTONIC.md).
O helper Python upstream conserva sua licença MIT em `vendor/`.

Depois de instalar runtime/modelo e configurar o diretório, também se pode usar
**Habilitar TTS no servidor** no aplicativo, autenticado com o token do servidor.
A flag é local ao servidor, separada da biblioteca. O comando de ativação não
instala pacotes nem baixa modelos automaticamente.

Endpoints autenticados:

- `GET /api/tts/voices`: informa disponibilidade, idiomas e vozes. Não carrega
  os modelos nem gera áudio.
- `POST /api/tts/speech`: JSON com `text`, `voice` (`M1`/`M2`), `language` (`pt`,
  por exemplo) e `speed` (0,5–2); devolve WAV. Máximo de 1.200 caracteres.
- `PUT /api/server-config`: aceita `{"ttsEnabled": true}` ou `false`, com as
  mesmas regras de administração usadas para a CLI.

Uma síntese ocupa o backend; outra recebe HTTP 429, sem fila ilimitada. A síntese
não mantém o lock da biblioteca. Áudio e texto são processados em memória e não
são gravados pelo backend. O endpoint de síntese exige `SEPIA_TOKEN` para clientes
fora do loopback. Use HTTPS ou um túnel em redes não confiáveis.

## Validação

Contratos Azure/ElevenLabs são conferidos com documentação oficial e respostas
simuladas; é preciso uma chave própria para verificar acesso e qualidade reais
na respectiva conta. O backend Sépia é validado com geração real e cliente
Flutter, incluindo autenticação, limites, cancelamento e navegação. Essas
verificações não são um benchmark de celular nem de todos os provedores.

Referências: [REST Azure](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-text-to-speech),
[API ElevenLabs](https://elevenlabs.io/docs/api-reference/text-to-speech/convert),
[limites Azure](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-services-quotas-and-limits).
