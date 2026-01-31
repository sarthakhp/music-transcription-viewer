# TranscriptionApiService - Quick Reference Guide

## Initialization

```dart
import 'package:vocal_pitch_viewer/services/transcription_api_service.dart';

final apiService = TranscriptionApiService();

// Don't forget to dispose when done
@override
void dispose() {
  apiService.dispose();
  super.dispose();
}
```

---

## Common Workflows

### 1. Simple Upload → Poll → Fetch

```dart
// Upload
final uploadResponse = await apiService.uploadAudioFile(
  fileBytes: audioBytes,
  fileName: 'song.mp3',
);

if (!uploadResponse.isSuccess) {
  print('Upload failed: ${uploadResponse.error}');
  return;
}

final jobId = uploadResponse.data!.jobId;

// Poll with progress updates
final statusResponse = await apiService.pollUntilComplete(
  jobId: jobId,
  onProgress: (status) {
    print('${status.progress}% - ${status.currentStageDisplay}');
  },
);

if (statusResponse.data!.isComplete) {
  // Fetch data
  final framesResponse = await apiService.getFrames(jobId);
  final chordsResponse = await apiService.getChords(jobId);
  
  if (framesResponse.isSuccess && chordsResponse.isSuccess) {
    final frames = framesResponse.data!;
    final chords = chordsResponse.data!;
    // Use the data...
  }
}
```

### 2. Complete Workflow (Recommended)

```dart
final result = await apiService.processAudioFile(
  fileBytes: audioBytes,
  fileName: 'song.mp3',
  onProgress: (status) {
    setState(() {
      _progress = status.progress;
      _stage = status.currentStageDisplay;
    });
  },
);

result.onSuccess((data) {
  // All data is ready!
  setState(() {
    _frames = data.frames;
    _chords = data.chords;
    _originalAudio = data.originalAudio;
    _vocalAudio = data.vocalAudio;
    _instrumentalAudio = data.instrumentalAudio;
  });
});

result.onError((error) {
  print('Error: $error');
});
```

### 3. Manual Polling

```dart
final jobId = 'your-job-id';

while (true) {
  final response = await apiService.getJobStatus(jobId);
  
  if (!response.isSuccess) break;
  
  final status = response.data!;
  print('Progress: ${status.progress}%');
  
  if (status.isComplete) {
    print('Job completed!');
    break;
  }
  
  if (status.hasFailed) {
    print('Job failed: ${status.errorMessage}');
    break;
  }
  
  await Future.delayed(Duration(seconds: 2));
}
```

### 4. Download Individual Stems

```dart
// Download vocals only
final vocalsResponse = await apiService.downloadStem(
  jobId: jobId,
  stemName: 'vocals',
);

if (vocalsResponse.isSuccess) {
  final audioBytes = vocalsResponse.data!;
  // Use the audio bytes...
}

// Download all stems in parallel
final stems = await apiService.downloadAllStems(jobId);

final original = stems['original']!.data;
final vocals = stems['vocals']!.data;
final instrumental = stems['instrumental']!.data;
```

---

## Error Handling Patterns

### Pattern 1: Check isSuccess

```dart
final response = await apiService.getFrames(jobId);

if (response.isSuccess) {
  final frames = response.data!;
  // Use frames...
} else {
  print('Error: ${response.error}');
  // Show error to user
}
```

### Pattern 2: Use Callbacks

```dart
response.onSuccess((data) {
  // Handle success
});

response.onError((error) {
  // Handle error
});
```

### Pattern 3: Transform Data

```dart
final frameCountResponse = await apiService.getFrames(jobId)
    .then((response) => response.map((frames) => frames.frameCount));

if (frameCountResponse.isSuccess) {
  print('Frame count: ${frameCountResponse.data}');
}
```

---

## Configuration

Edit `lib/config/api_config.dart` to change:

```dart
// Base URL (default: http://localhost:8000)
static const String baseUrl = 'http://localhost:8000';

// Timeouts
static const Duration uploadTimeout = Duration(minutes: 5);
static const Duration requestTimeout = Duration(seconds: 30);

// Polling
static const Duration pollingInterval = Duration(seconds: 2);
static const int maxPollingAttempts = 900; // 30 minutes
```

---

## Available Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `uploadAudioFile()` | POST /api/v1/transcribe | Upload audio file |
| `getJobStatus()` | GET /api/v1/jobs/{id}/status | Get job status |
| `getJobResults()` | GET /api/v1/jobs/{id}/results | Get results summary |
| `listStems()` | GET /api/v1/jobs/{id}/stems | List available stems |
| `downloadStem()` | GET /api/v1/jobs/{id}/stems/{name} | Download stem |
| `getFrames()` | GET /api/v1/jobs/{id}/frames | Get pitch frames |
| `getChords()` | GET /api/v1/jobs/{id}/chords | Get chord data |
| `deleteJob()` | DELETE /api/v1/jobs/{id} | Delete job |
| `healthCheck()` | GET /health | Check API health |

---

## Helper Methods

| Method | Description |
|--------|-------------|
| `pollUntilComplete()` | Poll status until job completes |
| `downloadAllStems()` | Download original, vocals, instrumental |
| `getAllProcessedData()` | Fetch frames + chords together |
| `processAudioFile()` | Complete workflow in one call |

