## Sépia 2.5.5

- Biblioteca com ordenação e índice reutilizados, menos trabalho na sincronização e gravação de documentos grandes fora da interface nas plataformas nativas.
- Menus e controles de configurações padronizados; fontes importadas carregadas sob demanda e opção de removê-las.
- Seleção de leitura libera os blocos retidos após copiar.
- Endereço e token consistentes por requisição; API e CLI recusam redirecionamentos.
- Compatibilidade entre datas antigas locais e UTC; edições e exclusões protegidas contra relógios adiantados.
- CLI aceita `.text`; servidor e cliente exibem a versão correta. Documentação usa exemplos genéricos.

A versão Lite recebe as mesmas correções de biblioteca, leitura, aparência, sincronização e CLI, mantendo a separação das dependências de TTS.

Para atualizar o servidor, preserve os arquivos de dados e as variáveis de ambiente existentes. Instalações com registros sem fuso podem definir `SEPIA_LEGACY_TIMEZONE` conforme descrito em `docs/CLI.md`.
