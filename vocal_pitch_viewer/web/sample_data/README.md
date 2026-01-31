# Sample Data Directory

This directory contains sample pitch data and audio files that are automatically loaded by the Vocal Pitch Viewer app.

## File Structure

```
sample_data/
├── file_manifest.json          # Manifest file listing all available files
├── pitch_data.json             # Pitch analysis data (or any .json file)
├── original/                   # Original audio track
│   └── *.mp3, *.wav, etc.
├── vocal/                      # Vocal-only track (optional)
│   └── *.mp3, *.wav, etc.
└── instrumental/               # Instrumental-only track (optional)
    └── *.mp3, *.wav, etc.
```

## How It Works

The app uses `file_manifest.json` to dynamically discover which files to load. This allows you to add new audio files without modifying the app code.

### Manifest Format

```json
{
  "pitch_data": [
    "pitch_data.json"
  ],
  "audio": {
    "original": [
      "your-song.mp3"
    ],
    "vocal": [
      "your-song-vocals.wav"
    ],
    "instrumental": [
      "your-song-instrumental.wav"
    ]
  }
}
```

## Adding New Files

1. **Add your pitch data JSON file** to the `sample_data/` directory
2. **Add your audio files** to the appropriate subdirectories:
   - `original/` - The original/full mix audio
   - `vocal/` - Vocal-only track (optional)
   - `instrumental/` - Instrumental-only track (optional)
3. **Update `file_manifest.json`** to reference your new files

### Example: Adding a New Song

1. Place files:
   ```
   sample_data/my_song_pitch.json
   sample_data/original/my_song.mp3
   sample_data/vocal/my_song_vocals.wav
   sample_data/instrumental/my_song_instrumental.wav
   ```

2. Update `file_manifest.json`:
   ```json
   {
     "pitch_data": [
       "my_song_pitch.json"
     ],
     "audio": {
       "original": [
         "my_song.mp3"
       ],
       "vocal": [
         "my_song_vocals.wav"
       ],
       "instrumental": [
         "my_song_instrumental.wav"
       ]
     }
   }
   ```

## Supported Audio Formats

- MP3 (`.mp3`)
- WAV (`.wav`)
- OGG (`.ogg`)
- M4A (`.m4a`)
- AAC (`.aac`)
- FLAC (`.flac`)

## Notes

- The app loads the **first file** listed in each array
- If a track type (vocal/instrumental) is missing or empty, it will be skipped
- At minimum, you need a pitch data JSON file and an original audio file
- The vocal and instrumental tracks are optional and enable track switching in the UI

