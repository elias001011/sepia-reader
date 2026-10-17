# Sépia pelo terminal (2.5)

A CLI usa a biblioteca do servidor de sincronização, com ou sem a interface
web. É um arquivo Python 3.9+ sem dependências externas. A biblioteca do navegador
ou celular precisa estar sincronizada com esse servidor para aparecer na CLI.
A CLI nunca abre os arquivos particulares do sistema operacional do servidor.

## Instalação

No checkout do projeto:

```bash
bash tool/install_cli.sh
```

O comando fica em `~/.local/bin/sepia` no Linux/macOS ou `$PREFIX/bin/sepia` no
Termux. Adicione `~/.local/bin` ao `PATH` se necessário. Também é possível baixar
`sepia-2.5.0-cli.py` da Release e executá-lo com `python3`, sem instalar Flutter.
No Windows, use `python sepia-2.5.0-cli.py ...`.

## Habilitar no servidor

O acesso pela CLI vem desligado e a opção é salva em
`data/server-config.json`, fora das preferências sincronizadas dos leitores.
No diretório do servidor, com as mesmas variáveis de ambiente da instância:

```bash
python3 main.py --cli on
# Para desligar: python3 main.py --cli off
```

Isso altera a configuração sem reiniciar o serviço. A interface 2.5 oferece o
mesmo controle, o interruptor **Permitir acesso pela CLI**, na seção de
sincronização do servidor. O endereço e o token são os informados nessa seção.
Sem token, alterações dessa opção pela API só são aceitas em localhost; para
alterar pela rede configure `SEPIA_TOKEN` no serviço e informe o token no app.

A opção controla o gateway `/api/cli`, usado pelo cliente de terminal. A API
usual de sincronização continua funcionando quando a CLI é desligada.

## Conectar

Os endereços e usuários abaixo são fictícios. Substitua `sepia.example`,
o usuário e as portas pelos valores da sua instalação.

Diretamente na rede local, usando a porta do Sépia:

```bash
sepia -p 8888 sepia.example
```

Por SSH, usando o mesmo login, chave ou senha que você já usa para acessar o
servidor (a porta SSH e a porta do Sépia são diferentes):

```bash
sepia --ssh --ssh-port 22 -p 8888 sepia.example
# Ou, com usuário explícito:
sepia --ssh --ssh-port 22 -p 8888 usuario@sepia.example
```

A CLI abre e fecha o túnel automaticamente. Não precisa abrir SSH primeiro nem
instalar a interface gráfica. Também pode ser executada dentro da própria
sessão SSH: `sepia 127.0.0.1`.

Para um servidor com token, configure `SEPIA_TOKEN` no ambiente do cliente.
O servidor usa a mesma variável para proteger **toda** a API da biblioteca,
incluindo sincronização e CLI. Nos apps, informe o token nas configurações.
Para acesso pela Internet, use HTTPS ou o túnel SSH. O servidor aceita
`SEPIA_HOST=127.0.0.1` para escutar apenas localmente; a instalação existente
mantém o endereço de escuta até que você o altere.

## Comandos

```text
ls [pasta]                listar arquivos e pastas
cd PASTA / pwd             navegar
tree                      árvore da biblioteca
cat ARQUIVO               exibir o texto
mkdir PASTA               criar pasta
upload LOCAL [REMOTO]      importar texto UTF-8 (até 5 MB)
download REMOTO [LOCAL]    exportar para a máquina onde a CLI está rodando
edit REMOTO               editar com $VISUAL ou $EDITOR (padrão: nano)
mv ORIGEM DESTINO          mover ou renomear
rm [-r] CAMINHO [--yes]    excluir; -r inclui conteúdo da pasta
help / exit               ajuda / sair
```

Use aspas em nomes com espaços. Os caminhos remotos são relativos à pasta
atual da CLI; `/` é a raiz da biblioteca. O destino de `mv` é o caminho completo,
incluindo o nome final do arquivo ou pasta.

```bash
sepia -p 8888 sepia.example ls
sepia -p 8888 sepia.example mkdir '/Livros'
sepia -p 8888 sepia.example upload ./texto.md '/Livros/texto.md'
sepia -p 8888 sepia.example download '/Livros/texto.md' ./texto-exportado.md
sepia --json -p 8888 sepia.example tree
```

`download` não sobrescreve arquivos locais. `upload` não sobrescreve documentos
existentes. `edit` compara a revisão que foi aberta com a revisão atual do
servidor: se outra pessoa ou aparelho editou o texto, a CLI recusa a gravação e
preserva a sua edição em um arquivo temporário de recuperação. O caminho é
informado no terminal. Exclusões usam os mesmos tombstones do app, para que
se propaguem na próxima sincronização. Em scripts, `rm` exige `--yes`.
