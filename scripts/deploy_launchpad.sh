#!/usr/bin/env bash
# Build Flutter web (release) and deploy to the installed MusicTranscriber.app.
#
# Usage: ./scripts/deploy_launchpad.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/music_transcriber"
LAUNCHPAD_WEB="/Applications/MusicTranscriber.app/Contents/Resources/web"
LAUNCHPAD_RESOURCES="/Applications/MusicTranscriber.app/Contents/Resources"
BACKEND_REPO="$(cd "$REPO_ROOT/../music-transcription" 2>/dev/null && pwd || true)"

if [ ! -d "/Applications/MusicTranscriber.app" ]; then
  echo "ERROR: MusicTranscriber.app not found at /Applications/MusicTranscriber.app"
  exit 1
fi

echo "Building Flutter web (release)..."
cd "$FLUTTER_APP"
# --pwa-strategy=none: this build only ever runs inside the DMG's embedded
# WKWebView against a local server — there's no offline/installable-PWA use
# case. The default service worker was serving stale main.dart.js out of
# WKWebView's persistent cache across app restarts, making every deploy look
# like it silently failed.
flutter build web --release --pwa-strategy=none

echo "Deploying web build to Launchpad..."
rsync -a --delete "$FLUTTER_APP/build/web/" "$LAUNCHPAD_WEB/"

# Also deploy launcher.py from the backend repo if it exists alongside this one
if [ -n "$BACKEND_REPO" ] && [ -f "$BACKEND_REPO/packaging/launcher.py" ]; then
  echo "Deploying launcher.py..."
  cp "$BACKEND_REPO/packaging/launcher.py" "$LAUNCHPAD_RESOURCES/launcher.py"
fi

echo ""
echo "Done. Restart MusicTranscriber.app to see the changes."
