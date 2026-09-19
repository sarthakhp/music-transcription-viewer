#!/usr/bin/env bash
# Start Flutter web dev server with hot-reload, pointing at the local API backend.
#
# Usage: ./scripts/dev_chrome.sh
#
# Assumes the FastAPI backend is already running on port 47821.
# To start the backend separately, run:
#   cd packaging && python launcher.py
# OR open the MusicTranscriber.app and leave it running.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/music_transcriber"
API_PORT=47821

echo "Starting Flutter dev server (Chrome, hot-reload)..."
echo "API backend expected at: http://localhost:$API_PORT"
echo "Press 'r' to hot-reload, 'R' to hot-restart, 'q' to quit."
echo ""

cd "$FLUTTER_APP"
flutter run \
  -d chrome \
  --dart-define=API_BASE_URL=http://localhost:$API_PORT
