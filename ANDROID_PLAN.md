# Android: upload and transcribe songs from the phone

Originally written 2026-10-22 as a plan; updated 2026-10-23 to describe what was built. Day-to-day developer notes are in `CLAUDE.md` ("Android app").

## Why the phone does not run the models

Measured on the M1 Pro: a 150 s song takes about 9.4 min, about 85% of it in BS-RoFormer separation (~3 min per 60 s chunk even on the Mac GPU). A phone would need an estimated 30+ minutes per song, 3+ GB of RAM and would throttle. So the phone only submits songs and views results; processing runs on a worker.

## Architecture (as built)

```
Phone (Android app)                 Firebase Storage                    Workers
 file / recording / phone audio  -> uploads/<id>/<file>
 link (shared or pasted)         -> queue/<id>.json  (status, progress)  <- Mac app (first pick)
 trim range, song type, topic                                            <- Modal GPU (after 90 s)
 status polling  <---------------- queue/<id>.json
 library         <---------------- index.json + jobs/<id>/* (public get)
 push notification <-------------- FCM topic, sent by the worker
```

- **Queue in Cloud Storage, not Firestore.** Firestore was not enabled and adds nothing the polled JSON files don't. Workers claim an entry with an atomic generation-matched write and hold a 120 s lease.
- **Auth**: Google sign-in; Storage rules allow only allow-listed emails to write `uploads/` and `queue/` (size and type limits), and public reads are `get` only, never `list`. Add someone with `scripts/allow_uploader.py` in the backend repo.
- **Trimming** is done by the worker with ffmpeg, so any file type can be trimmed from the phone's waveform view.
- **Links** go to the Mac worker only (YouTube blocks datacenter addresses).
- **Cloud worker**: `cloud/modal_worker.py` in the backend repo (Modal, L4 GPU). Guards: 20 min max per run, 40 GPU-minutes per day, no public endpoint.

## Cost (measured on Modal, 41 s song)

About 3.5 cents per song (GPU about 134 s including cold start and the 30 s idle tail). Rates: L4 $0.80/h. All test runs plus failures: $0.09, covered by the $30 free credit. The Mac worker costs nothing.

## Status

| Item | State |
|---|---|
| Android app: library, playback, transpose via player pitch | Built; transpose verified only by reading code, check on device |
| Upload: file, record (mic or other apps' audio), link, trim and review | Built; recording and review not yet exercised on a device |
| Share to the app (audio, links) | Built; being tested by hand |
| On-device cache and background refresh | Built |
| Finished-song notification (FCM topic) | Built; end-to-end delivery not yet confirmed |
| Mac worker, Modal worker | Built and deployed; Modal processing verified on the isolated test queue |
| Release APK with its own signing key | Not done (debug build only; needs its SHA-1 registered in Firebase) |

## Not done / ideas

- Fully offline processing on the phone (voice-only recordings could run CREPE/pYIN on device; separation could not).
- A true spend ceiling on Google Cloud is impossible for Cloud Storage; budgets only alert.
- Flute accuracy has only been checked as agreement between trackers; a benchmark with known notes would settle it.
