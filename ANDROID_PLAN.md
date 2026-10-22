# Android: upload and transcribe songs from the phone

Written 2026-10-22. Analysis and plan only, nothing implemented.

## 1. What the pipeline costs today (measured on the M1 Pro, 16 GB)

From `~/Library/Application Support/MusicTranscriber` (7 completed jobs):

| Song length | Total time |
|---|---|
| 41 s | 2.6 min |
| 150 s | 9.4 min |
| 169 s | 10.2 min |
| 221 s | 13.1 min |

In the 150 s job log, separation ran in 3 chunks of 60 s. Each chunk took about 3 min on the Mac GPU (MPS), so separation is roughly 3x slower than real time, even on that GPU. It is about 85% of the total.

| Stage | Model | Size | Cost |
|---|---|---|---|
| Separation | BS-RoFormer (2-stem), `bs_roformer_2stem` | ~600 MB ckpt | Dominant: ~3 min per 60 s of audio on MPS |
| Vocal pitch | torchcrepe `full` | ~90 MB | Light on GPU, slow on CPU (100 frames/s, full model) |
| Notes | Basic Pitch (x2: bass and other) | <1 MB | Cheap |
| Chords | BTC transformer | 12 MB | Cheap |
| Tempo | librosa (no NN) | none | Cheap |

Voice-only and music-only jobs already skip separation, so they skip the one expensive stage.

My estimate, not measured: a flagship phone running the same BS-RoFormer would need 30+ minutes per song, 3+ GB peak RAM, and would thermally throttle. A phone is the wrong place for that stage.

## 2. Options considered

| Option | Verdict |
|---|---|
| A. Run the existing Python (PyTorch) on the phone via Termux or Android's Linux Terminal VM | Reject. CPU only, no GPU or NPU. Android 12+ kills "phantom" child processes (cap of 32, signal 9, sources in section 6). Needs `adb` flag hacks. Fragile. |
| B. Convert every model to ONNX / LiteRT and run natively | Possible for the small models, and for a lighter separator. Not for BS-RoFormer. Large engineering effort. |
| C. Phone is the client (upload, track, view); heavy work runs elsewhere | **Recommended.** Fits the existing Firebase architecture. |
| D. Phone talks to the Mac over Tailscale | Quick stopgap, but the Mac must stay on, which is what you want to avoid. |

Recommended shape is C, plus a small on-device slice (B) for the cheap cases, plus an optional later experiment for a fully offline separator.

## 3. Target architecture

```
Phone (Android app)                Firebase                        Workers
 pick file / share sheet  ──►  Storage uploads/<id>/in.mp3
 paste YouTube URL (phone         Firestore jobs/<id> {status,...}  ◄── Worker A: Mac app (when awake)
   downloads audio itself) ─►    (queue + progress)                 ◄── Worker B: Modal GPU (fallback)
 live progress  ◄────────────  jobs/<id>.progress
 view result    ◄────────────  existing index.json + manifest.json + mp3 (unchanged)
```

Key decisions:

1. **Queue in Firestore, workers pull.** A worker claims a job with a lease (`claimedBy`, `leaseUntil`). The Mac app claims jobs while it is running; if nothing claims a job within N minutes, the Modal worker does. This is also how the laptop can stay closed.
2. **Output format does not change.** Workers publish exactly what `storage_publisher.py` publishes today, so the viewer needs no change to display results.
3. **Phone downloads YouTube itself.** YouTube blocks datacenter IPs and needs PO tokens (the repo already carries `bgutil-ytdlp-pot-provider` for this). A phone has a residential IP. It uploads the extracted audio, not the URL. (Fallback: Mac worker downloads when it is the claimer.)
4. **Auth.** Today anonymous writes are denied, which is why the phone is read-only. The service account key must never ship in the app. Use Firebase Auth (Google sign-in with your account) plus Storage and Firestore rules that allow only your UID to write `uploads/` and `jobs/`. This is a deliberate change to the "hosted viewer is read-only" rule in `CLAUDE.md`.
5. **Cloud worker.** Modal (per-second billing, no idle cost). Third-party pages quote about $0.59/h for a T4 and a $30/month free credit; I could not confirm these on Modal's own page, so check before relying on them. My estimate: 1-2 min of GPU plus a cold start per song, so cents per song. Models are baked into the container image. `PipelineWorker` already runs as a standalone CLI (`job_runner.py`), so the Modal function wraps it with `device=cuda` and a Storage download step.

## 4. The phone app

- Today the phone uses the hosted web viewer. The repo has no `android/` folder. Add one (`flutter create --platforms=android`) and ship an APK. `NativeAudioPlayer` (just_audio) already exists, so playback has a native path.
- Web-only code that needs an Android implementation: `web_file_picker.dart` (use `file_picker`), the recorder (`audio_recorder_service.dart`), the SoundTouch pitch shifter (Web Audio worklet; needs a native pitch-shift path, the biggest viewer gap), and the media session.
- Android share target: "Share to Music Transcriber" from any music or file app (`receive_sharing_intent`). This is the main reason to prefer an APK over a PWA.
- The upload runs as a **user-initiated data transfer job** (Android 14+), which is designed for long uploads and survives the app being backgrounded. Use resumable Firebase Storage uploads so a dropped connection resumes.
- Progress and completion come from Firestore listeners, plus an FCM push when a job finishes, so nothing needs the app open.
- Offline library: downloaded jobs stay on the device (same layout as the Mac import path).

## 5. On-device processing (phase 3, optional)

What can run on the phone at low cost:

| Case | On-device? |
|---|---|
| Voice-only recording (no separation) | Yes. CREPE tiny/small or `full` as ONNX/LiteRT, plus tempo, notes, chords. Small models, minutes at worst. |
| Music-only recording | Yes, same, using Basic Pitch and BTC. |
| Full song (needs separation) | Only with a lighter separator. |

For separation on device, the realistic candidates are HT-Demucs ONNX (about 166 MB in fp16) or Open-Unmix. [Demixr](https://github.com/demixr/demixr-app) already ships Demucs v4 on Android via ExecuTorch (Vulkan) with an ONNX Runtime CPU option. Quality will be below BS-RoFormer (SDR 12.98 per the model name), so this is a speed-and-offline tradeoff, not a replacement. Benchmark one 60 s clip on your actual phone before committing.

Runtime choice: NNAPI is deprecated since Android 15, so avoid it. LiteRT's CompiledModel API (GPU and NPU acceleration reported as production in January 2026, from a secondary source) or ONNX Runtime Mobile for CPU. Needs the vendor-specific NPU path per SoC, which is the costly part.

### Memory management (applies to any on-device stage)
- Run stages sequentially, never concurrently. The backend's `max_concurrent_jobs=3` would be fatal on a phone; use 1.
- One model resident at a time; load with memory-mapped weights; fp16 or int8 weights.
- Process in 30-60 s chunks (already how separation works) and write each chunk result to disk. A kill then resumes at the last chunk instead of restarting.
- React to `onTrimMemory`, free the model and bitmaps first.
- Watch thermals (`PowerManager` thermal status and headroom); drop to fewer threads or pause rather than let the OS throttle or kill.

### Process management and not being interrupted
- Long on-device work runs in a **foreground service with type `mediaProcessing`** (Android 15+). Caveat: the budget is 6 hours per 24 hours per type, and the system calls `onTimeout`; you must stop within seconds or the app crashes. Fine for a few songs; checkpoint chunks anyway.
- Partial wake lock while a stage runs; require "battery not low" for batch work.
- OEM killers (Xiaomi, Samsung, Oppo) are the real risk beyond AOSP rules. Prompt the user to exempt the app from battery optimisation, and make every stage resumable so a kill is an inconvenience, not a loss.
- For the cloud path none of this applies: the phone only uploads and listens.

## 6. Phases

| Phase | Deliverable | Rough size |
|---|---|---|
| 0 | Stopgap: Android APK pointed at the Mac API over Tailscale, to test the app shell | 1-2 days |
| 1 | Android app: share target, upload job, native pitch shift, recorder, library | 1-2 weeks (pitch shift is the unknown) |
| 2 | Firestore queue + Auth + rules; Mac worker claim loop; progress and FCM | ~1 week |
| 3 | Modal GPU worker as fallback | 2-4 days |
| 4 | On-device voice-only and music-only pipeline | 1-2 weeks |
| 5 | Optional: on-device separator spike (Demucs ONNX/ExecuTorch) | benchmark first |

## 7. Open questions for you

1. Which phone (SoC and RAM)? It was not connected over `adb` when I checked, so section 5 is device-agnostic.
2. Is a small monthly cloud cost acceptable, or must everything stay on your own hardware? If the latter, the Mac worker stays primary and the queue still lets the phone submit while the laptop is closed, as long as it wakes (or use an always-on mini PC as worker A).
3. Do you need fully offline processing, or only offline playback of finished songs?
4. YouTube downloads on the phone: OK to rely on an on-device yt-dlp build, which needs PO-token handling and breaks when YouTube changes?

## Sources
- Foreground service timeouts: https://developer.android.com/develop/background-work/services/fgs/timeout
- User-initiated data transfer: https://developer.android.google.cn/develop/background-work/background-tasks/uidt?hl=en
- LiteRT Android APIs: https://developers.google.com/edge/litert/next/overview
- NNAPI migration guide: https://developer.android.google.cn/ndk/guides/neuralnetworks/migration-guide?hl=zh-tw
- HT-Demucs ONNX: https://pypi.org/project/demucs-onnx/ and https://huggingface.co/StemSplitio/htdemucs-onnx
- Demixr: https://github.com/demixr/demixr-app
- Phantom process killer: https://github.com/agnostic-apollo/Android-Docs/blob/master/en/docs/apps/processes/phantom-cached-and-empty-processes.md
- yt-dlp PO tokens: https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
- Modal pricing (third-party): https://www.spheron.network/blog/modal-gpu-pricing-2026-per-second-billing/
