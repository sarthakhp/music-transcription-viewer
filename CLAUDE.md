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
| `T` | Toggle tanpura drone |

## Gotchas
- **SoundTouchNode lazy init**: re-apply pitch after `ctx.resume()` or first-play transpose is ignored
- **WKWebView codec**: use MP3 for assets — Opus not supported by Safari/WKWebView
- **go_router recreation**: navigating to `/jobs/:id` recreates `HomeScreen` intentionally; `initialJobId` drives auto-load
- **Tanpura pitch**: `playbackRate = 2^((scaleRoot - 7) / 12)`. Root=G → rate 1.0. Only tracks Root, not transpose.
- **Job display name**: `userDisplayName ?? videoTitle ?? inputFilename`. Editable in toolbar, persisted via `PATCH /jobs/:id/rename`.
