# Segurança

## Relatando uma vulnerabilidade

Não abra issue pública com detalhes exploráveis, dados de usuários, tokens ou
documentos reais. Use o canal privado de relato na aba **Security** do repositório
(Private vulnerability reporting). Se ele não estiver disponível, peça ao
mantenedor um canal privado antes de enviar detalhes.

Inclua: versão e plataforma, passos de reprodução com dados fictícios, impacto
esperado e, se houver, sugestão de correção.

## Como o Sépia trata dados

- A biblioteca fica no dispositivo. Nada é enviado a servidor algum por padrão.
- Sincronização é opcional e acontece apenas com a URL e o token que o próprio
  usuário configura. Ao desligar a sincronização, o app pergunta se a cópia do
  servidor deve ser apagada.
- Leitura em voz alta remota envia trechos do texto ao provedor escolhido, e só
  depois de consentimento explícito na tela de configuração. A voz do sistema e os
  modelos locais não saem do aparelho.
- Tokens e chaves ficam no armazenamento local do app; nunca aparecem em telas de
  exportação nem em mensagens de erro.

## Se você expõe o servidor de sincronização

O diretório `server/` inclui um servidor opcional. Se ele for exposto à internet,
configure o token de acesso e use HTTPS em um proxy reverso. Sem token, qualquer
pessoa que alcance a porta lê e escreve a biblioteca.

## Escopo das verificações automáticas

`dart format`, `flutter analyze` e `flutter test` ajudam a manter qualidade e a
pegar regressões, mas **não** constituem auditoria de segurança. Não trate o CI
verde como prova de que uma integração é segura.

## Versões

Correções de segurança são aplicadas na branch `main` e registradas no
`CHANGELOG.md` quando o impacto justificar uma nota.
