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
- **Backend**: FastAPI at `http://localhost:47821`

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
| `lib/config/api_config.dart` | API URL — reads `API_BASE_URL` dart-define for dev override |
| `lib/router.dart` | go_router config |
| `assets/audio/tanpura_g.mp3` | 90s seamless loop, G scale, 128kbps MP3 |

## Dev Workflow
```bash
# Hot-reload dev server — open http://localhost:8080 in your own browser
./scripts/dev_chrome.sh

# Deploy release build to installed MusicTranscriber.app
./scripts/deploy_launchpad.sh
```
- New assets require full server restart — hot-reload won't pick them up
- `API_BASE_URL` dart-define overrides backend URL for dev

## Keyboard Shortcuts
| Key | Action |
|-----|--------|
| `Space` | Play/pause |
| `←` / `→` | Seek ±5s |
| `↑` / `↓` | Volume |
| `+` / `-` | Transpose up/down |
| `0` | Reset transpose |
| `[` / `]` | Speed down/up |
| `\` | Reset speed to 1× |
| `A` | Toggle auto-scroll |
| Trackpad pinch / `Shift` + pinch | Zoom time / zoom pitch |
| `T` | Toggle tanpura drone |

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
- Pre-existing, unrelated: `test/widget_test.dart` is the stale counter template and fails.

## Loading Overlay Logic
The overlay (`LoadingOverlay`) in `home_screen.dart` is visible when:
```
(shell.isLoading && !shell.isReady) || shell.isPreparingAudio
```
- `isReady = audioBytes != null` — becomes true once `_downloadAudioStems` calls `setAudioData`
- `isPreparingAudio` is set true in both `_downloadAudioStems` (start) and `_loadAudio` (start); only `_loadAudio` clears it on completion
- `_buildViewerLayout` triggers `_loadAudio` via `addPostFrameCallback` whenever `!_audioLoaded && !_isLoadingAudio && audioBytes != null`
- Error UI: audio load failure shows a SnackBar ("Audio could not be loaded. Playback is unavailable.") — the pitch visualization remains accessible

## MCP / Tooling
- **code-review-graph binary**: installed at `~/.local/bin/code-review-graph` (v2.3.7). `.mcp.json` uses the direct path — do NOT switch back to `uvx code-review-graph` (fails due to SSL cert issue on this machine).
- **Rebuilding the graph**: run `code-review-graph build` from the repo root. Graph lives in `.code-review-graph/graph.db`.
