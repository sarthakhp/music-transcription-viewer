# Music Transcriber

**Live demo:** https://sarthakhp.github.io/music-transcription-viewer/

Music Transcriber is an interactive Flutter web app for breaking down, analyzing, and practicing music. It turns a song into a scrolling view of vocal pitch, instrument notes, and chords, synced with audio playback, and gives you the tools to practice along: slow it down, change the key, loop a tanpura drone, and read notes in Western or Sargam notation.

It runs in the browser on desktop and phone, and as a macOS app (DMG) that bundles the processing backend.

![Flutter](https://img.shields.io/badge/Flutter-^3.10-blue) ![Dart](https://img.shields.io/badge/Dart-^3.10-blue) ![Web](https://img.shields.io/badge/Platform-Web-blue)

---

## Features

### Visualization
- **Vocal pitch contour**: pitch tracking drawn as a scrolling graph with note labels
- **Instrument notes**: bass and other instrument stems shown as colored bars on the pitch grid, each toggleable as a layer
- **Chord labels**: recognized chords along the top of the graph, with the chord under the playhead highlighted
- **Active note highlighting**: axis labels light up as a pill while that note is sounding
- **Western or Sargam notation**: switch between note names (C, D, E) and Sargam (Sa, Re, Ga), with a selectable root note
- **Light, dark, and system themes**: high-contrast palettes for both

### Playback and audio
- **Track switching**: listen to the Original, Vocals only, or Instrumental only
- **Playback speed**: 0.25x to 2x, by stepping or picking from a menu
- **Key transpose**: shift audio and graph up or down by up to 12 semitones
- **Tuning**: adjustable reference pitch (A4, 400 to 480 Hz)
- **Tanpura drone**: a looping G-scale tanpura whose pitch follows the selected root note
- **Seek tools**: seek bar, jump to start, and 1s or 5s skips
- **Lock screen and media keys**: title, icon, and play, pause, seek controls in the phone notification, lock screen, and keyboard media keys
- **Download**: export the original, vocals, or instrumental stem as MP3, right in the browser
- **Rename tracks** in place

### Getting audio in
- **Upload** an audio or video file
- **Paste a URL**, with optional start and end trimming
- **Record** audio from the microphone
- **Practice Mode**: load any audio or video file and change its key or speed entirely in the browser, with no transcription needed
- **Library**: browse previous jobs, retry failed ones, and delete old ones

### Pan and zoom
- **Two zoom axes**: zoom time and pitch separately, each with its own readout (seconds visible, notes visible) and reset
- **Trackpad**: pinch zooms time, `Shift` + pinch zooms pitch
- **Touch**: one finger pans (with momentum), two fingers pinch. A sideways pinch zooms time, an up and down pinch zooms pitch, and a diagonal pinch zooms both
- **Tap the graph to seek**, and use auto-scroll to keep the playhead centered
- **Confidence filtering**: per-layer sliders to hide low-confidence data
- **Vocal detail**: adjust how densely pitch points are sampled
- **Per-track settings**: zoom, transpose, speed, and notation are remembered for each track
- **Shortcut hints**: hover any control to see its keyboard shortcut

### Works on desktop, phone, and the Mac app
- **Desktop browser**: labelled single-row controls, a title bar with stats, and full keyboard shortcuts
- **Phone**: a touch layout below 760px wide, with a track bar, a scrollable layer row, and a player panel whose Speed, Key, Root, and Zoom pills open large bottom sheets. Portrait and landscape are both supported
- **Installable web app**: proper app icon, Apple touch icon, theme colors, and safe-area support for the iPhone notch
- **macOS DMG**: the same app in a native window with the local processing backend bundled

### Deployment
- **GitHub Pages** auto-deploy on push to `main` via GitHub Actions
- **Two build modes:**
  - `local`: full app with the backend API (upload, process, view)
  - `remote`: read-only hosted viewer that reads published results from Firebase Storage (no backend required)

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `←` / `→` | Seek back / forward 1s (hold `⌘` for 5s) |
| `↑` / `↓` | Pan the pitch view up / down |
| `⌘⇧↑` / `⌘⇧↓` | Transpose up / down 1 semitone |
| `+` / `-` | Zoom pitch (vertical) in / out |
| `⇧+` / `⇧-` | Zoom time (horizontal) in / out |
| `0` | Seek to start |
| `1` to `9` | Seek to 10% to 90% of the track |
| `A` | Toggle auto-scroll |
| `[` / `]` | Slow down / speed up one preset |
| `\` | Reset speed to 1x |
| `T` | Toggle the tanpura drone |
| Trackpad pinch | Zoom time |
| `Shift` + trackpad pinch | Zoom pitch |

Shortcuts are ignored while you are typing in a text field.

### Touch gestures

| Gesture | Action |
|---------|--------|
| Tap the graph | Seek to that time |
| Drag with one finger | Pan time and pitch (flick for momentum) |
| Pinch sideways | Zoom time |
| Pinch up and down | Zoom pitch |
| Pinch diagonally | Zoom both |

---

## Getting Started

### Prerequisites
- Flutter SDK (Dart ^3.10)
- Chrome or any modern browser

### Run locally (with backend)
```bash
cd music_transcriber
flutter pub get
flutter run -d chrome --profile --web-port 8080
```

Or use the helper script, which points the app at the local API on port 47821:
```bash
./scripts/dev_chrome.sh
```

### Build for production
```bash
# Local mode (requires backend API)
flutter build web --release

# Hosted read-only viewer (Firebase Storage)
flutter build web --release \
  --base-href /music-transcription-viewer/ \
  --dart-define=DATA_SOURCE=remote \
  --dart-define=FIREBASE_INDEX_URL="<your-firebase-index-json-url>"
```

### Run the tests
```bash
cd music_transcriber
flutter test
```

### Supported audio formats
MP3, WAV, FLAC, M4A, OGG, WEBM (max 100 MB)

---

## Project Structure

```
music_transcriber/
├── lib/
│   ├── config/          # API and build-time configuration
│   ├── models/          # Data classes (pitch, chords, instruments, jobs, view state)
│   ├── providers/       # App state (Provider pattern)
│   ├── screens/         # Screens, plus part files for home screen logic
│   ├── services/        # Audio, API, upload, polling, media session, remote data
│   ├── theme/           # Color palettes and theming
│   ├── utils/           # Music theory, responsive layout, file utilities
│   └── widgets/         # Player controls, graph, renderers, mobile player panel
├── test/                # Unit tests (gestures, zoom math)
├── web/                 # Web assets, icons, audio worklets
└── third_party/         # Vendored just_audio
scripts/                 # Dev server and Mac app deploy scripts
.github/workflows/       # CI/CD (GitHub Pages deployment)
```

---

## Tech Stack

- **Flutter** (Web): UI framework
- **Provider** and **go_router**: state management and routing
- **Web Audio API** with **SoundTouch**: pitch shifting without changing speed
- **just_audio**: native audio playback
- **CustomPainter**: high-performance canvas rendering for the pitch graph
- **Media Session API**: notification, lock screen, and media key controls
- **lamejs**: in-browser MP3 export
- **GitHub Actions**: automated deployment to GitHub Pages
