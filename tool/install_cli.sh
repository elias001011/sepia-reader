#!/usr/bin/env bash
set -euo pipefail
# No pip, Flutter or root required. Override destination with SEPIA_BIN_DIR.
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
sepia_bin_dir="${SEPIA_BIN_DIR:-${PREFIX:+$PREFIX/bin}}"
sepia_bin_dir="${sepia_bin_dir:-$HOME/.local/bin}"
mkdir -p "$sepia_bin_dir"
install -m 755 "$source_dir/server/sepia.py" "$sepia_bin_dir/sepia"
"$sepia_bin_dir/sepia" --version
printf 'CLI instalada em %s/sepia\n' "$sepia_bin_dir"
