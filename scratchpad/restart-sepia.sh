#!/data/data/com.termux/files/usr/bin/bash
# Restart just the Sepia sync server. Run as: bash ~/restart-sepia.sh
set -u
PATTERN='sepia-server/main.py'
pkill -f "$PATTERN" 2>/dev/null || true
sleep 2
cd "$HOME/sepia-server" || exit 1
setsid nohup python3 -u "$HOME/sepia-server/main.py" >> "$HOME/sepia-server/server.log" 2>&1 < /dev/null &
sleep 3
if pgrep -f "$PATTERN" >/dev/null; then
  echo "sepia: RUNNING pid=$(pgrep -f "$PATTERN" | tr '\n' ' ')"
else
  echo "sepia: NOT RUNNING"
  tail -8 "$HOME/sepia-server/server.log"
  exit 1
fi
