#!/usr/bin/env python3
"""Sépia 2.5 terminal client. Python 3.9+, no third-party dependencies."""

import argparse
import contextlib
import json
import os
import posixpath
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

VERSION = "2.5.9"
HELP = """ls [pasta]                listar arquivos e pastas
cd PASTA / pwd             navegar (use aspas para nomes com espaços)
tree                      árvore da biblioteca
cat ARQUIVO               exibir conteúdo
mkdir PASTA               criar pasta
upload LOCAL [REMOTO]      importar texto UTF-8, sem sobrescrever
download REMOTO [LOCAL]    exportar para o computador
edit REMOTO               editar com $VISUAL ou $EDITOR (padrão: nano)
mv ORIGEM DESTINO          mover ou renomear (destino é o caminho completo)
rm [-r] CAMINHO [--yes]    excluir; -r inclui conteúdo da pasta
help / exit               ajuda / sair
"""


class NoApiRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        # A sync endpoint must never redirect a bearer credential elsewhere.
        return None


class Client:
    def __init__(self, base, token=""):
        self.base = base.rstrip("/")
        self.token = token
        self.cwd = "/"
        self._http = urllib.request.build_opener(NoApiRedirects())

    def path(self, value):
        return posixpath.normpath(posixpath.join(self.cwd, value))

    def request(self, command, path="/", **kwargs):
        payload = {"command": command, "path": self.path(path), **kwargs}
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        request = urllib.request.Request(self.base + "/api/cli", json.dumps(payload).encode(), headers, method="POST")
        try:
            with self._http.open(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            try:
                message = json.load(error).get("error", str(error))
            except (ValueError, AttributeError):
                message = str(error)
            error.close()
            raise ValueError(message) from error

    def execute(self, args, interactive=False, json_output=False):
        if not args:
            return True
        command, *values = args
        result = None
        if command in ("exit", "quit"):
            return False
        if command == "help":
            print(HELP)
            return True
        if command == "pwd":
            print(self.cwd)
            return True
        if command in ("ls", "cd"):
            if len(values) > 1 or command == "cd" and not values:
                raise ValueError(command + " [pasta]" if command == "ls" else "cd PASTA")
            target = values[0] if values else self.cwd
            result = self.request("ls", target)
            if command == "cd":
                self.cwd = self.path(target)
                return True
            if not json_output:
                for entry in result["entries"]:
                    suffix = "/" if entry["type"] == "folder" else ""
                    print(entry["name"] + suffix)
        elif command == "tree":
            result = self.request("tree")
            if not json_output:
                folders = result["folders"]
                documents = result["documents"]
                def walk(parent, prefix="", seen=None):
                    seen = set() if seen is None else seen
                    for folder in sorted((f for f in folders if f.get("parentId") == parent), key=lambda f: f["name"]):
                        print(prefix + folder["name"] + "/")
                        if folder["id"] not in seen:
                            seen.add(folder["id"])
                            walk(folder["id"], prefix + "  ", seen)
                    for doc in sorted((d for d in documents if d.get("folderId") == parent), key=lambda d: d["title"]):
                        print(prefix + doc["title"] + "." + doc.get("extension", "md"))
                walk(None)
        elif command in ("cat", "download", "edit"):
            if not values or len(values) > (2 if command == "download" else 1):
                raise ValueError(command + " REMOTO" + (" [LOCAL]" if command == "download" else ""))
            record = self.request("get", values[0])
            if command == "cat":
                result = record
                if not json_output:
                    print(record["content"], end="")
            elif command == "download":
                # Exclusive creation avoids overwriting local files/symlinks.
                target = Path(values[1] if len(values) == 2 else posixpath.basename(values[0]))
                with target.open("x", encoding="utf-8", newline="") as handle:
                    handle.write(record["content"])
                result = {"saved": str(target)}
            else:
                with tempfile.TemporaryDirectory(prefix="sepia-edit-") as directory:
                    target = Path(directory) / "document.txt"
                    target.write_bytes(record["content"].encode("utf-8"))
                    editor = shlex.split(os.environ.get("VISUAL") or os.environ.get("EDITOR") or "nano")
                    try:
                        subprocess.run([*editor, str(target)], check=True)
                        content = target.read_bytes().decode("utf-8")
                        if content != record["content"]:
                            result = self.request("put", values[0], content=content, expectedUpdatedAt=record["updatedAt"])
                        else:
                            result = {"unchanged": True}
                    except Exception:
                        # Preserve raw edits on conflict, network/encoding errors
                        # and size limits, before the temporary editor closes.
                        if target.exists():
                            fd, recovery = tempfile.mkstemp(prefix="sepia-recovered-", suffix=".txt")
                            os.close(fd)
                            shutil.copyfile(target, recovery)
                            print("Edição preservada em " + recovery, file=sys.stderr)
                        raise
        elif command == "upload":
            if not 1 <= len(values) <= 2:
                raise ValueError("upload LOCAL [REMOTO]")
            source = Path(values[0])
            if source.stat().st_size > 5 * 1024 * 1024:
                raise ValueError("limite de 5 MB por arquivo")
            result = self.request("put", values[1] if len(values) == 2 else source.name, content=source.read_bytes().decode("utf-8"))
        elif command == "mkdir":
            if len(values) != 1:
                raise ValueError("mkdir PASTA")
            result = self.request("mkdir", values[0])
        elif command in ("mv", "rename"):
            if len(values) != 2:
                raise ValueError("mv ORIGEM DESTINO")
            result = self.request("mv", values[0], destination=self.path(values[1]))
        elif command in ("rm", "rmdir"):
            recursive = "-r" in values
            yes = "--yes" in values
            paths = [v for v in values if v not in ("-r", "--yes")]
            if len(paths) != 1:
                raise ValueError("rm [-r] CAMINHO [--yes]")
            if not yes:
                if not interactive:
                    raise ValueError("use --yes para confirmar a exclusão")
                if input("Excluir " + self.path(paths[0]) + "? [s/N] ").lower() not in ("s", "sim", "y", "yes"):
                    return True
            result = self.request("rm", paths[0], recursive=recursive)
        else:
            raise ValueError("comando desconhecido: " + command + "; use help")
        if result is not None and (json_output or command not in ("ls", "tree", "cat")):
            print(json.dumps(result, ensure_ascii=False, indent=2))
        return True


@contextlib.contextmanager
def ssh_tunnel(host, port, ssh_port):
    if host.startswith("-") or any(c.isspace() for c in host):
        raise ValueError("invalid SSH host")
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        local = reservation.getsockname()[1]
    process = subprocess.Popen([
        "ssh", "-N", "-o", "ExitOnForwardFailure=yes", "-o", "ServerAliveInterval=30",
        "-L", f"127.0.0.1:{local}:127.0.0.1:{port}", "-p", str(ssh_port), host,
    ])
    try:
        # Password/passphrase prompts remain on the terminal, exactly as in SSH.
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise ValueError("conexão SSH encerrada")
            try:
                with socket.create_connection(("127.0.0.1", local), timeout=.2):
                    break
            except OSError:
                time.sleep(.1)
        else:
            raise ValueError("tempo de conexão SSH excedido")
        yield f"http://127.0.0.1:{local}"
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, epilog=HELP, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", action="version", version=VERSION)
    parser.add_argument("-p", "--port", type=int, default=8888)
    parser.add_argument("--ssh", action="store_true", help="conectar por túnel SSH, sem expor a API")
    parser.add_argument("--ssh-port", type=int, default=22)
    parser.add_argument("--json", action="store_true", help="resultado em JSON para scripts")
    parser.add_argument("host", nargs="?", default="127.0.0.1")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    token = os.environ.get("SEPIA_TOKEN", "")
    base = args.host if "://" in args.host else f"http://{args.host}:{args.port}"
    try:
        with ssh_tunnel(args.host, args.port, args.ssh_port) if args.ssh else contextlib.nullcontext(base) as url:
            client = Client(url, token)
            if args.command:
                client.execute(args.command, json_output=args.json)
            else:
                client.execute(["ls"])
                print("Sépia " + VERSION + " · help para comandos, exit para sair")
                while True:
                    try:
                        line = input("sepia:" + client.cwd + "> ")
                        if not client.execute(shlex.split(line), interactive=True, json_output=args.json):
                            break
                    except (ValueError, OSError, subprocess.SubprocessError) as error:
                        print("sepia: " + str(error), file=sys.stderr)
    except (KeyboardInterrupt, EOFError):
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print("sepia: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
