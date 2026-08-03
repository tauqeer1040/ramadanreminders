#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIDFILE="$SCRIPT_DIR/.server.pid"
PORT=${PORT:-4000}

case "${1:-start}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Server already running (PID $(cat "$PIDFILE")) on port $PORT"
      exit 0
    fi
    cd "$SCRIPT_DIR"
    node db2.js &
    echo $! > "$PIDFILE"
    echo "Server started (PID $(cat "$PIDFILE")) on port $PORT"
    ;;
  stop)
    if [ ! -f "$PIDFILE" ]; then
      echo "No PID file found. Trying pkill..."
      pkill -f "node db2.js" 2>/dev/null && echo "Server stopped" || echo "No server running"
      exit 0
    fi
    PID=$(cat "$PIDFILE")
    kill "$PID" 2>/dev/null && echo "Server stopped (PID $PID)" || echo "No server running"
    rm -f "$PIDFILE"
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Server running (PID $(cat "$PIDFILE")) on port $PORT"
    else
      echo "Server not running"
    fi
    ;;
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart}"
    exit 1
    ;;
esac
