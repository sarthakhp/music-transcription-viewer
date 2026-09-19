#!/usr/bin/env bash
# Build Flutter web (release) and deploy to the installed MusicTranscriber.app.
#
# Usage: ./scripts/deploy_launchpad.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/music_transcriber"
LAUNCHPAD_WEB="/Applications/MusicTranscriber.app/Contents/Resources/web"

if [ ! -d "/Applications/MusicTranscriber.app" ]; then
  echo "ERROR: MusicTranscriber.app not found at /Applications/MusicTranscriber.app"
  exit 1
fi

echo "Building Flutter web (release)..."
cd "$FLUTTER_APP"
flutter build web --release

echo "Deploying to Launchpad..."
rsync -a --delete "$FLUTTER_APP/build/web/" "$LAUNCHPAD_WEB/"

echo ""
echo "Done. Restart MusicTranscriber.app to see the changes."
