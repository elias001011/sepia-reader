#!/data/data/com.termux/files/usr/bin/bash
# Restart the Sépia sync server, waiting for the old process to actually let
# go of the port before starting the new one. The previous version started
# the replacement after a fixed `sleep 2`, which raced a process that was
# still winding down and died with "address already in use".
#
# Run as: bash ~/sepia-server/restart-sepia.sh
set -u

SERVER_DIR="${SEPIA_SERVER_DIR:-$HOME/sepia-server}"
PATTERN="${SEPIA_PATTERN:-sepia-server/main.py}"
PORT="${SEPIA_PORT:-8888}"

cd "$SERVER_DIR" || { echo "sepia: no $SERVER_DIR"; exit 1; }

pkill -f "$PATTERN" 2>/dev/null || true

# Wait up to ~10s for every matching process to exit; then force it.
for _ in $(seq 1 50); do
  pgrep -f "$PATTERN" >/dev/null || break
  sleep 0.2
done
if pgrep -f "$PATTERN" >/dev/null; then
  echo "sepia: old process ignored SIGTERM, sending SIGKILL"
  pkill -9 -f "$PATTERN" 2>/dev/null || true
  sleep 1
fi

setsid nohup python3 -u "$SERVER_DIR/main.py" \
  >> "$SERVER_DIR/server.log" 2>&1 < /dev/null &

# Give it a moment to bind, then confirm it is actually serving.
for _ in $(seq 1 25); do
  curl -fs "http://localhost:$PORT/version.json" >/dev/null 2>&1 && break
  sleep 0.2
done

if curl -fs "http://localhost:$PORT/version.json" >/dev/null 2>&1; then
  echo "sepia: RUNNING pid=$(pgrep -f "$PATTERN" | tr '\n' ' ')"
  curl -s "http://localhost:$PORT/version.json" | grep -o '"version":"[^"]*"' || true
else
  echo "sepia: NOT SERVING on :$PORT"
  tail -12 "$SERVER_DIR/server.log"
  exit 1
fi
