#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"

echo "=== Starting Meowmin Backend ==="

# Ensure PORT=4000 in .env
if grep -q "^PORT=" "$ENV_FILE" 2>/dev/null; then
  sed -i 's/^PORT=.*/PORT=4000/' "$ENV_FILE"
else
  echo "PORT=4000" >> "$ENV_FILE"
fi

# Kill any lingering pm2 process
pm2 delete meowmin 2>/dev/null || true

# Start the backend
cd "$BACKEND_DIR"
pm2 start db2.js --name meowmin --update-env
sleep 3

# Show status
pm2 list

# Show LAN IP
LAN_IP=$(ipconfig | grep -i "IPv4" | head -1 | awk '{print $NF}')
echo ""
echo "======================================"
echo "  Backend: http://localhost:4000"
echo "  LAN:     http://$LAN_IP:4000"
echo "  ADB:     adb reverse tcp:4000 tcp:4000"
echo "======================================"
echo ""
echo "Flutter run with:"
echo "  flutter run --dart-define=BACKEND_BASE_URL=http://localhost:4000/api/v2"
echo "  (Phone via ADB reverse) OR"
echo "  flutter run --dart-define=BACKEND_BASE_URL=http://$LAN_IP:4000/api/v2"
echo "  (Phone on same LAN, no ADB needed)"
