#!/bin/sh
# start_dashboard.sh — Inicia o dashboard de acompanhamento localmente.
#
# Serve scripts/dashboard/ com um servidor HTTP estático (Python stdlib) e
# abre o navegador. O dashboard faz polling de session.json a cada 1s.
#
# Uso:
#   ./scripts/start_dashboard.sh        # inicia e abre o navegador
#   ./scripts/start_dashboard.sh --stop # encerra o servidor do dashboard
#
# Não depende de serviços externos, APIs pagas ou servidores na nuvem.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DASH_DIR="$SCRIPT_DIR/dashboard"
PID_FILE="$DASH_DIR/.dashboard.pid"
PORT_FILE="$DASH_DIR/.dashboard.port"
LOG_FILE="$DASH_DIR/.dashboard.log"
DEFAULT_PORT="8765"

if [ "${1:-}" = "--stop" ]; then
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      echo "Dashboard encerrado (PID $PID)."
    else
      echo "Nenhum servidor do dashboard em execução."
    fi
    rm -f "$PID_FILE" "$PORT_FILE" "$LOG_FILE"
  else
    echo "Nenhum servidor do dashboard em execução."
  fi
  exit 0
fi

# Se já estiver rodando, apenas abre o navegador (idempotente).
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    PORT=$(cat "$PORT_FILE" 2>/dev/null || echo "$DEFAULT_PORT")
    echo "Dashboard já está rodando na porta $PORT (PID $PID)."
    if command -v firefox >/dev/null 2>&1; then
      firefox "http://localhost:$PORT/dashboard.html" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "http://localhost:$PORT/dashboard.html" >/dev/null 2>&1 &
    fi
    exit 0
  fi
  rm -f "$PID_FILE" "$PORT_FILE" "$LOG_FILE"
fi

# Escolher porta livre.
PORT="$DEFAULT_PORT"
while python3 -c "import socket,sys; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); sys.exit(0 if s.connect_ex(('127.0.0.1',$PORT))==0 else 1)" 2>/dev/null; do
  PORT=$((PORT + 1))
done

mkdir -p "$DASH_DIR"

# Iniciar servidor HTTP estático em background (rastreado por background_process não se aplica aqui; usamos nohup via shell padrão é evitado por policy, então usamos a ferramenta apropriada do chamador). Aqui iniciamos diretamente e gravamos o PID.
( cd "$DASH_DIR" && python3 -m http.server "$PORT" --bind 127.0.0.1 > "$LOG_FILE" 2>&1 & echo $! > "$PID_FILE" )

echo "$PORT" > "$PORT_FILE"

# Aguardar o servidor responder (máximo ~10s).
for i in $(seq 1 50); do
  if python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:$PORT/session.json', timeout=1)" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

PID=$(cat "$PID_FILE")
echo "Dashboard iniciado: http://localhost:$PORT/dashboard.html (PID $PID)"
echo "Para encerrar: ./scripts/start_dashboard.sh --stop"

if command -v firefox >/dev/null 2>&1; then
  firefox "http://localhost:$PORT/dashboard.html" >/dev/null 2>&1 &
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "http://localhost:$PORT/dashboard.html" >/dev/null 2>&1 &
else
  echo "Abra manualmente: http://localhost:$PORT/dashboard.html"
fi
