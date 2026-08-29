#!/data/data/com.termux/files/usr/bin/bash
set -eu
cd "$HOME/sepia-server"
ts=$(date +%Y%m%d-%H%M%S)
test -f web-2.0.3.tar.gz
mv web "web.$ts.bak"
mkdir web
tar -xzf web-2.0.3.tar.gz -C web
rm web-2.0.3.tar.gz
echo "old web backed up to web.$ts.bak"
grep -o '"version":"[^"]*"' web/version.json || true
ls web | head
