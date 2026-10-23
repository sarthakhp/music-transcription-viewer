<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.

---

# Music Transcription Viewer — Frontend (Flutter Web)

## Targets (always consider all three)
Every feature must work on **desktop browser**, the **macOS DMG** (pywebview/WKWebView: codec, audio, file-picker and cache quirks), and **phone** (touch, portrait + landscape). When changing a control or readout, update both its desktop bar and its `mobile_player/` equivalent.

## Architecture
- **Flutter web app** at `music_transcriber/` — served inside macOS pywebview app and as standalone website
- **State**: `Provider` — `AppState` (job/audio state), `ThemeProvider`
- **Routing**: `go_router` — `/` home, `/jobs/:id` viewer; browser back/forward works
- **Audio**: Web Audio API via `dart:js_interop` + `package:web`; SoundTouchNode AudioWorklet for pitch shifting
- **Tanpura drone**: `TanpuraService` — loads `assets/audio/tanpura_g.mp3` (G-scale, 90s loop), loops via `AudioBufferSourceNode`, shifts pitch with `playbackRate`. Shortcut: `T`.
- **Backend**: FastAPI at `http://localhost:47821` (the phone and hosted site instead read Firebase Storage files; see "Android app")

## Key Files
| File | Purpose |
|------|---------|
| `lib/screens/home_screen.dart` | Main screen, keyboard shortcuts, settings wiring |
| `lib/screens/home_screen_jobs.dart` | Job loading, list, restore-on-reload, URL push |
| `lib/screens/home_screen_audio.dart` | Audio playback, stem switching |
| `lib/screens/home_screen_view_controls.dart` | Keyboard handler (`_handleKeyEvent`) |
| `lib/services/platform_audio_player_web.dart` | Web Audio API player, SoundTouchNode pitch shift |
| `lib/services/tanpura_service.dart` | Tanpura — loads MP3 asset, loops, pitch via playbackRate |
| `lib/screens/widgets/viewer_toolbar.dart` | Top toolbar including editable filename |
| `lib/screens/widgets/tanpura_control.dart` | Tanpura app-bar button + popover |
| `lib/utils/responsive.dart` | `ViewerLayout` (phonePortrait / phoneLandscape / regular) — the single breakpoint for all viewer chrome |
| `lib/widgets/graph_touch_gestures.dart` | Touch pan, fling, axis-aware pinch zoom for the pitch graph |
| `lib/widgets/mobile_player/` | Touch player panel (seek, transport, Speed/Key/Root/Zoom pills) + bottom sheets |
| `lib/widgets/audio_controls.dart` + `audio_controls/control_group.dart` | Desktop player bar; `ControlGroup` = caption + 40px body used by every control |
| `lib/widgets/graph_overlay_controls.dart` | Auto-scroll toggle + reset-zoom button over the graph |
| `lib/screens/widgets/phone_viewer_app_bar.dart` | Touch-layout viewer app bar (track name, stats, ⋮ menu) |
| `lib/models/audio_content_type.dart` | `AudioContentType` (mixed / vocals / instrumental), mirrors backend `audio_type`; `AppState.audioType` + `hasVocalAnalysis` / `hasAccompanimentAnalysis` gate player UI |
| `lib/models/job_settings.dart` + `lib/services/settings_sync_service.dart` | Per-song settings and their cloud sync (see "Per-song settings") |
| `lib/widgets/job_list_card.dart` | Library tiles; `JobStorage` badge (On device / Cloud / Synced) |
| `lib/config/api_config.dart` | API URL — reads `API_BASE_URL` dart-define for dev override |
| `lib/router.dart` | go_router config |
| `assets/audio/tanpura_g.mp3` | 90s seamless loop, G scale, 128kbps MP3 |

## Dev Workflow
```bash
# Hot-reload dev server — open http://localhost:8080 in your own browser
./scripts/dev_chrome.sh

# Build + deploy web, launcher.py AND the backend's api/ to the installed
# MusicTranscriber.app (run it yourself after changes; user then restarts the app)
./scripts/deploy_launchpad.sh
```
- New assets require full server restart — hot-reload won't pick them up
- `API_BASE_URL` dart-define overrides backend URL for dev

## Keyboard Shortcuts
Source of truth: `_handleKeyEvent` in `home_screen_view_controls.dart` (keep `keyboard_shortcuts_dialog.dart`, hover tooltips and README in sync).
| Key | Action |
|-----|--------|
| `Space` | Play/pause (counts in first when count-in is on) |
| `Enter` | Seek to start (playhead to 0, keeps playing state) |
| `←` / `→` | Seek ±1s (`⌘` held: ±5s) |
| `↑` / `↓` | Pan the pitch view up/down |
| `⌘⇧↑` / `⌘⇧↓` | Transpose ±1 semitone |
| `+` / `-` | Zoom pitch (vertical) in/out |
| `⇧+` / `⇧-` | Zoom time (horizontal) in/out |
| `0` | Seek to start |
| `1`-`9` | Seek to 10%-90% of the track |
| `A` | Toggle auto-scroll |
| `[` / `]` | Speed down/up one preset |
| `\` | Reset speed to 1x |
| `T` | Toggle tanpura drone |
| Trackpad pinch / `Shift` + pinch | Zoom time / zoom pitch |

## Cycle, tempo and GarageBand-style keys
- **Cycle (loop)**: `CycleState` (`models/cycle_state.dart`) holds the region; `CycleBar` (`widgets/graph_renderers/cycle_renderer.dart`) draws it in the strip above the plot (top inset) and tints the plot. `PitchGraph` owns the drag gestures (drag empty strip = new region, drag edges = resize, drag body = move, click body = on/off); strip pointers never pan or seek. Looping happens in the playhead ticker (`home_screen_cycle.dart`): it wraps only when the previous tick was inside the region, and `_seekTo` resets `_lastTickPosition` so a seek never looks like crossing the end. Starting playback outside an active region jumps to its start. Region + on/off persist and sync in `JobSettings` (`cycleEnabled/Start/End`).
- **Editable BPM**: detection is often half/double, so the BPM stat opens a dialog (type, ½×, 2×, tap tempo, use detected). The override lives in `AppState.bpmOverride` (`effectiveBpm` = override ?? detected), is saved in `JobSettings.bpmOverride` (0 = none) and drives the count-in.
- Keys: `C` cycle, `I`/`O` set cycle start/end at playhead, `K` count-in on/off (remembers last click count).

## Count-in
`CountInService` (Web Audio clicks scheduled on the audio clock, interval = `60 / (bpm × speed)`, first click accented) + `CountInButton` in the app bar next to the tanpura (Off/1-4 clicks, saved in `UserSettings.countInBeats`, app-wide not per song) + `CountInOverlay` (big beat number over the graph). **All play paths go through `_togglePlayback()`** (`home_screen_count_in.dart`): Space, desktop and phone play buttons, and the media-session `play` handler. Never call `_audioService.togglePlayPause()` directly from UI, or that path skips the count-in. Pressing play during a count cancels it. `handleLoadNew` cancels it too.

## Gotchas
- **SoundTouchNode lazy init**: re-apply pitch after `ctx.resume()` or first-play transpose is ignored
- **WKWebView codec**: use MP3 for assets — Opus not supported by Safari/WKWebView
- **go_router recreation**: navigating to `/jobs/:id` recreates `HomeScreen` intentionally; `initialJobId` drives auto-load
- **Tanpura pitch**: `playbackRate = 2^((scaleRoot - 7) / 12)`. Root=G → rate 1.0. Only tracks Root, not transpose.
- **Job display name**: `userDisplayName ?? videoTitle ?? inputFilename`. Editable in toolbar, persisted via `PATCH /jobs/:id/rename`.
- **File picker in DMG**: `lib/utils/web_file_picker.dart` calls `window.__pickFile(hint)` (defined in `web/index.html`), which fetches `http://127.0.0.1:47823/pick-file?hint=audio` — a local HTTP server in `launcher.py`. If that server returns a non-2xx, the JS catch returns `{_unavailable: true}` and Dart falls back to HTML `<input>` — but programmatic `input.click()` is blocked by WKWebView without a live gesture context, so the button silently does nothing. Always check `launcher.log` first when file picking breaks.
- **Audio loading failure = infinite overlay**: `_loadAudio` in `home_screen_audio.dart` must always clear `_isLoadingAudio` and call `appState.setPreparingAudio(false)` on both success AND failure paths. If `success = false` goes unhandled, the loading overlay freezes permanently. On web, `platform_audio_player_web.dart` catches all `player.load()` exceptions and returns `false` — so failures are silent and this cleanup is critical.

- **just_audio `play()` future** completes only when playback pauses/ends. Never `await player.play()` before `pause()` (e.g. when priming) or `load()` hangs and the loading overlay freezes. `NativeAudioPlayer` primes muted with an un-awaited `play()` + 80ms delay and suppresses events via `_priming`.
- **Don't route speed through SoundTouch `tempo`**: the media element feeds the worklet in real time, so tempo != 1 buffers/starves (audio keeps playing after pause, speed changes lag, playhead desyncs). Speed = `HTMLMediaElement.playbackRate`; SoundTouch is for pitch only. WKWebView's choppy slow playback is a separate, unsolved problem.
- **`PlatformAudioPlayer` is `implements`-ed, not extended**: base-class getter defaults are not inherited; new getters must be added to both players.
- **Hot reload**: removing a field/const from a const class (e.g. `AudioControls`) is rejected — use hot restart. Changes to `web/index.html` or assets need a full restart.

## Audio type (Song / Voice only / Music only)
Selector sits under the File/URL/Record tabs in `upload_section.dart` and is sent as `audio_type` by both upload paths. Player UI adapts from `AppState.audioType`: voice-only hides the Layers group, chord strip and chord/note counts; music-only hides the Vocals chip. Music-only jobs have **empty vocal frames**, so the pitch-range maths in `home_screen.dart` must not use `frequencyRange` (it falls back to `(0, 2000)`) and starts from the instrument range instead.

## Cloud library (local app)
Home list = local jobs ∪ cloud index (`GET /cloud/jobs`, fetched in the background after the local list renders). Tags: Cloud (cloud only), Synced, On device. Opening a Cloud job calls `POST /cloud/jobs/{id}/import` first, then loads it like any local job. Cloud-only jobs have no delete; deleting a Synced job removes only the local copy. No tags when the cloud is unconfigured/unreachable. The hosted viewer uses `RemoteDataSource` instead and ignores all this.

## Per-song settings (local + cloud)
- `JobSettings` is persisted per job in localStorage (`UserSettings`) and synced via `SettingsSyncService`. It covers view/zoom, speed, key, root/notation, layer toggles + confidence sliders, plus nullable per-song overrides (vocalDetail, referenceFrequency, track).
- **Live changes never wait on the cloud**: apply + local save first; the cloud push is debounced (2s), fire-and-forget, errors swallowed. Opening a song applies local immediately, then fetches the cloud copy and applies it only if its `updatedAtMs` is newer.
- `_saveCurrentJobSettings` stamps `updatedAtMs` and pushes **only when something other than the scroll position changed** (`_differsIgnoringPlayhead`). After any restore call `_rebaselineSettings`, or the restore looks like an edit and overwrites the cloud copy with defaults (this bug happened). Restoring the track must use `_switchTrack(..., persist: false)`.
- Hosted viewer/phone can only read settings (public URL built from the job id via `settingsToken`); writes need the backend. The backend's cloud rules and token gotchas are in the backend repo's CLAUDE.md.
- The confidence sliders in Display Settings are inverted in the UI (right = show everything); the stored value is still a minimum-confidence threshold.

## Mobile / Responsive UI
- **One breakpoint**: `ViewerLayout.of(context)` — width < 760 = phonePortrait, height < 500 = phoneLandscape, else regular. It switches the app bar (`PhoneViewerAppBar`), layer row, player panel (`MobilePlayerPanel`) together. Don't add separate per-widget width checks. Desktop player bar: transport joins the settings row at width >= 1200 (`AudioControls.wideBreakpoint`), otherwise transport shares the seek-bar line.
- **Controls never shift under the cursor**: no layout change on click (reserved space, or put dots/reset icons in the caption row, not beside the control). Reset buttons appear in the `ControlGroup` caption only when the value is non-default; in sheets they are hidden with `Visibility(maintainSize)`.
- `ControlGroup(modified:, onReset:)`: teal caption + dot + outline marks a non-default value. Its body must hug content (`Align(widthFactor: 1)`), or it stretches to full width inside `Wrap`.
- **Touch gestures** live in `TouchGraphGestures` (not `GestureDetector` scale): 1 finger pans (axis-locks when straight) + flings; 2 fingers pinch, axis chosen once per gesture by `PinchAxisResolver` (sideways = time, up/down = pitch, diagonal = both), anchored under fingers via `ViewState.zoomXByFactor/zoomYAtFocal`. `suppressTap` stops a drag/pinch ending in a seek. Mouse drag and trackpad/wheel paths in `pitch_graph.dart` are separate and unchanged.
- Graph padding is `GraphInsets.forWidth` (tighter < 600); painters take `insets`.
- Phone pills show current values (Root pill shows the root note; caption says "Sa" in Sargam mode, "Root" in Western). Root note also sets the tanpura pitch in Western mode.
- `index.html`: `user-scalable=no` (so the browser doesn't steal the pinch; costs page-zoom a11y), `viewport-fit=cover`, dark/light `theme-color`, dark body background.
- Icons: `web/icons/*`, `favicon.png` are generated (equalizer bars, teal on dark); iOS reads `icons/apple-touch-icon.png` (180px, opaque). iOS caches Home Screen icons — re-add the page to see a change.
- Dialog/sheet controllers: own `TextEditingController`s in a `StatefulWidget` (disposing right after `showDialog` returns crashes the exit animation).

## Verifying UI changes
- The in-app browser is a mouse-only pane; for touch, dispatch synthetic `PointerEvent`s (`pointerType:'touch'`, distinct `pointerId`s) at `flt-glass-pane`. Screenshots can lag one frame behind — take a second one before concluding.
- Run the dev server in the background (`flutter run -d web-server --web-port=8080 ...`) with stdin from a FIFO so `r`/`R` can be sent for hot reload/restart; reload the page afterwards. The user prefers to test interactions themselves — launch/reload, then wait for feedback instead of clicking through flows.
- `flutter test` passes (the stale counter-template test was removed).
- Preview the release build against a scratch backend: `MT_WEB_DIR=music_transcriber/build/web` on the backend (it serves with `no-store`). Changing only the URL hash in the browser pane does NOT reload the app, so after rebuilding do `location.reload()`. Flutter web prefs live in localStorage (`flutter.*`); `localStorage.clear()` simulates a new device.

## Loading Overlay Logic
The overlay (`LoadingOverlay`) in `home_screen.dart` is visible when:
```
(shell.isLoading && !shell.isReady) || shell.isPreparingAudio
```
- `isReady = audioBytes != null` — becomes true once `_downloadAudioStems` calls `setAudioData`
- `isPreparingAudio` is set true in both `_downloadAudioStems` (start) and `_loadAudio` (start); only `_loadAudio` clears it on completion
- `_buildViewerLayout` triggers `_loadAudio` via `addPostFrameCallback` whenever `!_audioLoaded && !_isLoadingAudio && audioBytes != null`
- Error UI: audio load failure shows a SnackBar ("Audio could not be loaded. Playback is unavailable.") — the pitch visualization remains accessible

## Android app (phone)
Built from the same Flutter code: `android/` project under `music_transcriber/`, package `com.sarthak.musictranscriber.music_transcriber`. It runs in **remote mode** (reads the Firebase library, like the hosted site) plus phone-only features.
```bash
IDX=<public index.json URL>   # the FIREBASE_INDEX_URL CI variable
flutter build apk --debug --dart-define=DATA_SOURCE=remote --dart-define=FIREBASE_INDEX_URL="$IDX"
adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk   # retry: wireless adb is flaky
```
- **`android/app/google-services.json` is gitignored** (the secret scanner flags it). Re-download from the Firebase console after a fresh clone. Sign-in is registered for the **debug** SHA-1 only; a release build needs its own SHA-1 added in Firebase.
- **Platform split**: web-only code lives behind conditional imports. A barrel `foo.dart` does `export 'foo_native.dart' if (dart.library.js_interop) 'foo_web.dart';` (or a `_stub`). Used for: `web_file_picker`, `tanpura_service`, `count_in_service`, `audio_recorder_service`, `audio_trim_service`, `download_helper`, `audio_export_interop`, `preview_audio`, `cloud_upload`, `cache/disk_cache`. When adding web-only code, add the native twin or the Android build breaks.
- **Phone upload** (`screens/widgets/phone_upload/`): `PhoneUploadPanel` orchestrates; `SubmissionTracker` (remembered submissions + polling), `SubmissionList`, `RecordControls`, `ClipReview` (waveform, trim handles, playhead), `AccountBar`. Clip state and cleanup live in `services/phone_audio/` (`AudioDraft` deletes the previous file whenever it is replaced or disposed; recordings go to disk, never memory).
- **Queue protocol** (`services/cloud_upload/`): the phone uploads `uploads/<id>/<file>` and writes `queue/<id>.json` (`audio_type`, optional `trim_start/trim_end`, `source_url` for links, `notify_topic`). Workers (Mac app, Modal) claim it and report `claimed -> processing -> done|failed` plus `job_id`. Trimming happens on the worker (ffmpeg), so it works for any file type. Backend side: the backend repo's CLAUDE.md.
- **Sign-in**: Google via the in-app account sheet; if that fails within 2s (Google not yet honouring the app's SHA-1) it falls back to Firebase's browser flow. Storage rules allow only allow-listed emails to write (`scripts/allow_uploader.py` in the backend repo).
- **Phone audio recording** (`SystemAudioService.kt`, channel `music_transcriber/system_audio`): Android playback capture through a `mediaProjection` foreground service, mono 44.1 kHz WAV. Apps may opt out of capture; the result then has a low `peak` and the UI warns.
- **Share to the app** (`ShareReceiver.kt` + `services/share_intake/`): audio files (copied to cache) and links in shared text land in the upload panel; a share that arrives before the panel exists waits in `ShareIntake.takePending()`.
- **Website upload** (hosted site, remote mode, after Google sign-in): `WebUploadPanel` in `screens/widgets/web_upload/` uses the same queue as the phone. Pieces shared with the phone live in `screens/widgets/upload_shared/` (`UploadCard`, `SourceSelector`, `AudioTypeChips`, `LinkField`, `UploadSubmit`, `ClipReview`, tracker/list, `BusyGuard` mixin); `ClipReview` works on the `ClipDraft` interface (`services/clip/`), implemented by `AudioDraft` (phone, files) and `WebClipDraft` (browser, bytes + page audio element). `CloudUpload` has three implementations behind one barrel (`_native`, `_web`, `_stub`), all writing entries through `queue_protocol.dart`. The web build needs `--dart-define=FIREBASE_WEB_API_KEY=...` (CI variable `FIREBASE_WEB_API_KEY`); without it `CloudUpload.isSupported` is false and the site stays read-only. The Firebase web app id/domain constants are in `cloud_upload_web.dart`; `sarthakhp.github.io` must be in Firebase Auth's authorized domains, and the key should be restricted to that site in Google Cloud. Trimming is server-side (the worker applies `trim_start/trim_end`), so the browser uploads the original bytes. Phone-audio recording is Android only.
- **Instrument picker** (`screens/widgets/upload_shared/instrument_picker.dart`, catalogue in `models/instrument_catalog.dart`): optional, searchable, grouped chips; nothing ticked means the backend works the instruments out itself. Hidden for voice-only. The ids must match the backend's `muscriptor_instruments.py`. It is used by the phone panel, the website panel and the Mac app's `UploadSection`, and travels as `instruments` in the queue entry or upload form.
- **Notifications**: FCM topic subscription (`job_notifications.dart`); the worker sends when a song finishes.
- **On-device cache** (`services/cache/`): the song list is served from the saved copy and refreshed in the background (`RemoteIndexStore`, `LibrarySync` on resume). Pitch/chord/audio files are cached by URL (immutable: a reprocessed song gets new tokens, hence new URLs); audio is capped at 500 MB, least recently used deleted first.
- **Gotchas**: `usesCleartextTraffic` must stay on, because just_audio's in-memory sources play through a localhost HTTP proxy. The vendored `third_party/just_audio` needs its `android/` folder (it was missing). Backend timestamps are UTC without a zone marker: always parse with `parseServerTime`. `ChoiceChip` with an avatar icon needs `showCheckmark: false` or the tick overlaps the icon. The launcher can keep showing the old Flutter icon until the phone restarts.
- **Pitch/transpose on Android** uses the player's `setPitch` (independent of speed); there is no SoundTouch worklet.

## MCP / Tooling
- **code-review-graph binary**: installed at `~/.local/bin/code-review-graph` (v2.3.7). `.mcp.json` uses the direct path — do NOT switch back to `uvx code-review-graph` (fails due to SSL cert issue on this machine).
- **Rebuilding the graph**: run `code-review-graph build` from the repo root. Graph lives in `.code-review-graph/graph.db`.
