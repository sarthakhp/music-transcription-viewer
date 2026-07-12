# Music Transcription Viewer

🌐 **Live demo:** https://sarthakhp.github.io/music-transcription-viewer/

An interactive Flutter web app for visualizing music transcription data — vocal pitch contours, instrument note bars, and chord labels — synced with audio playback.

![Flutter](https://img.shields.io/badge/Flutter-^3.10-blue) ![Dart](https://img.shields.io/badge/Dart-^3.10-blue) ![Web](https://img.shields.io/badge/Platform-Web-blue)

---

## Features

### Visualization
- **Vocal pitch contour** — real-time pitch tracking displayed as a scrolling graph with note labels
- **Instrument notes** — bass and other instrument stems rendered as colored bars on the pitch grid
- **Chord labels** — chord recognition overlaid on the timeline
- **Active note highlighting** — Y-axis labels light up with colored pills when a note is playing during playback
- **Sargam notation** — switch between Western note names (C, D, E…) and Indian classical Sargam (Sa, Re, Ga…) with selectable scale root

### Playback & Audio
- **Multi-track switching** — listen to Original, Vocals-only, or Instrumental-only tracks
- **Playback speed control** — preset speeds from 0.5× to 2.0×
- **Pitch transpose** — shift audio and visual display ±12 semitones
- **Reference frequency tuning** — adjustable A4 (400–480 Hz)
- **Scrub bar** with smooth playhead animation and auto-scroll

### Interaction
- **Pan & zoom** — horizontal (time) and vertical (pitch) zoom with trackpad/mouse scroll and pinch gestures
- **Keyboard shortcuts** for fast navigation
- **Confidence filtering** — per-layer sliders to filter low-confidence vocal/instrument data
- **Vocal detail control** — adjust pitch point sampling density
- **Per-job settings persistence** — zoom, transpose, speed, and notation preferences saved per track

### Deployment
- **GitHub Pages** auto-deploy on push to `main` via GitHub Actions
- **Two build modes:**
  - `local` — full app with backend API (upload, process, view)
  - `remote` — read-only hosted viewer reading published artifacts from Firebase Storage (no backend required)

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `←` / `→` | Seek back / forward 1s |
| `+` / `-` | Zoom in / out (vertical) |
| `0` | Reset zoom |
| `[` / `]` | Slow down / speed up |
| `\` | Reset speed to 1× |
| `⌘⇧↑` / `⌘⇧↓` | Pitch up / down 1 semitone |

---

## Getting Started

### Prerequisites
- Flutter SDK (Dart ^3.10)
- Chrome or any modern browser

### Run locally (with backend)
```bash
cd vocal_pitch_viewer
flutter pub get
flutter run -d chrome --profile --web-port 8080
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

### Supported audio formats
MP3, WAV, FLAC, M4A, OGG, WEBM (max 100 MB)

---

## Project Structure

```
vocal_pitch_viewer/
├── lib/
│   ├── config/          # API & build-time configuration
│   ├── models/          # Data classes (pitch, chords, instruments, jobs)
│   ├── providers/       # App state (Provider pattern)
│   ├── screens/         # UI screens + part files for home screen logic
│   ├── services/        # Audio, API, upload, polling, remote data
│   ├── theme/           # Color palette & theming
│   ├── utils/           # Music theory, file, performance utilities
│   └── widgets/         # Reusable widgets + graph renderers
├── web/                 # Web assets & sample data
└── .github/workflows/   # CI/CD (GitHub Pages deployment)
```

---

## Tech Stack

- **Flutter** (Web) — UI framework
- **Provider** — state management
- **just_audio** — native audio playback
- **SoundTouch** — web audio pitch shifting
- **CustomPainter** — high-performance canvas rendering for the pitch graph
- **GitHub Actions** — automated deployment to GitHub Pages
