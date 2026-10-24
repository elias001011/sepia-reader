#!/usr/bin/env bash
set -euo pipefail
# Instala o Sépia para o usuário atual, sem root: ~/.local/opt/sepia e um
# atalho em ~/.local/share/applications. Desinstalar: bash install.sh --remove
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
prefix="${SEPIA_PREFIX:-$HOME/.local/opt}"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
bin="$HOME/.local/bin"

if [[ "${1:-}" == "--remove" ]]; then
  rm -rf "$prefix/sepia" "$apps/sepia.desktop" "$bin/sepia-desktop"
  echo "Sépia removido."
  exit 0
fi

rm -rf "$prefix/sepia"
mkdir -p "$prefix" "$apps" "$bin"
cp -r "$here/sepia" "$prefix/sepia"
cp "$here/sepia.png" "$prefix/sepia/sepia.png"
sed "s#@PREFIX@#$prefix#g" "$here/sepia.desktop" > "$apps/sepia.desktop"
ln -sf "$prefix/sepia/sepia_reader" "$bin/sepia-desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$apps" || true
echo "Sépia instalado em $prefix/sepia. Abra pelo menu ou com: sepia-desktop"
