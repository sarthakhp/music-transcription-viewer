import 'dart:convert';

/// Settings for a specific job (track) that should be persisted, locally and
/// (when cloud storage is available) per song across devices.
class JobSettings {
  // View state (zoom/pan)
  final double viewStartTime;
  final double viewWindowSize;
  final double yZoomScale;
  final double yPanOffset;
  final bool autoScroll;

  // Playback settings
  final double playbackSpeed;
  final int transposeAmount;
  final bool sargamEnabled;
  final int scaleRoot;

  // Layers and filtering
  final bool showVocals;
  final bool showBass;
  final bool showOther;
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;

  /// Per-song overrides of app-wide settings. Null means "not set for this
  /// song", so the app-wide value applies.
  final int? vocalDetail;
  final double? referenceFrequency;

  /// Tempo set by the user, replacing the detected one. 0 means "use detected".
  final double bpmOverride;

  /// Cycle (loop) region. Counts as set only when [cycleEnd] > [cycleStart].
  final bool cycleEnabled;
  final double cycleStart;
  final double cycleEnd;

  /// Which audio track was selected: 'original', 'vocal' or 'instrumental'.
  final String? track;

  /// When these settings were last changed (ms since epoch). 0 for settings
  /// saved before this existed. Decides which copy wins when syncing.
  final int updatedAtMs;

  const JobSettings({
    this.viewStartTime = 0,
    this.viewWindowSize = 30,
    this.yZoomScale = 1.0,
    this.yPanOffset = 0.0,
    this.autoScroll = true,
    this.playbackSpeed = 1.0,
    this.transposeAmount = 0,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
    this.showVocals = true,
    this.showBass = true,
    this.showOther = true,
    this.vocalsMinConfidence = 0.0,
    this.bassMinConfidence = 0.0,
    this.otherMinConfidence = 0.0,
    this.vocalDetail,
    this.referenceFrequency,
    this.track,
    this.bpmOverride = 0,
    this.cycleEnabled = false,
    this.cycleStart = 0,
    this.cycleEnd = 0,
    this.updatedAtMs = 0,
  });

  /// Create JobSettings from JSON
  factory JobSettings.fromJson(Map<String, dynamic> json) {
    return JobSettings(
      viewStartTime: (json['viewStartTime'] as num?)?.toDouble() ?? 0,
      viewWindowSize: (json['viewWindowSize'] as num?)?.toDouble() ?? 30,
      yZoomScale: (json['yZoomScale'] as num?)?.toDouble() ?? 1.0,
      yPanOffset: (json['yPanOffset'] as num?)?.toDouble() ?? 0.0,
      autoScroll: json['autoScroll'] as bool? ?? true,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      transposeAmount: (json['transposeAmount'] as num?)?.toInt() ?? 0,
      sargamEnabled: json['sargamEnabled'] as bool? ?? false,
      scaleRoot: (json['scaleRoot'] as num?)?.toInt() ?? 0,
      showVocals: json['showVocals'] as bool? ?? true,
      showBass: json['showBass'] as bool? ?? true,
      showOther: json['showOther'] as bool? ?? true,
      vocalsMinConfidence: (json['vocalsMinConfidence'] as num?)?.toDouble() ?? 0.0,
      bassMinConfidence: (json['bassMinConfidence'] as num?)?.toDouble() ?? 0.0,
      otherMinConfidence: (json['otherMinConfidence'] as num?)?.toDouble() ?? 0.0,
      vocalDetail: (json['vocalDetail'] as num?)?.toInt(),
      referenceFrequency: (json['referenceFrequency'] as num?)?.toDouble(),
      track: json['track'] as String?,
      bpmOverride: (json['bpmOverride'] as num?)?.toDouble() ?? 0,
      cycleEnabled: json['cycleEnabled'] as bool? ?? false,
      cycleStart: (json['cycleStart'] as num?)?.toDouble() ?? 0,
      cycleEnd: (json['cycleEnd'] as num?)?.toDouble() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert JobSettings to JSON
  Map<String, dynamic> toJson() {
    return {
      'viewStartTime': viewStartTime,
      'viewWindowSize': viewWindowSize,
      'yZoomScale': yZoomScale,
      'yPanOffset': yPanOffset,
      'autoScroll': autoScroll,
      'playbackSpeed': playbackSpeed,
      'transposeAmount': transposeAmount,
      'sargamEnabled': sargamEnabled,
      'scaleRoot': scaleRoot,
      'showVocals': showVocals,
      'showBass': showBass,
      'showOther': showOther,
      'vocalsMinConfidence': vocalsMinConfidence,
      'bassMinConfidence': bassMinConfidence,
      'otherMinConfidence': otherMinConfidence,
      if (vocalDetail != null) 'vocalDetail': vocalDetail,
      if (referenceFrequency != null) 'referenceFrequency': referenceFrequency,
      if (track != null) 'track': track,
      'bpmOverride': bpmOverride,
      'cycleEnabled': cycleEnabled,
      'cycleStart': cycleStart,
      'cycleEnd': cycleEnd,
      'updatedAtMs': updatedAtMs,
    };
  }

  /// Create a copy with some fields replaced. The nullable overrides
  /// ([vocalDetail], [referenceFrequency], [track]) can only be set, not cleared.
  JobSettings copyWith({
    double? viewStartTime,
    double? viewWindowSize,
    double? yZoomScale,
    double? yPanOffset,
    bool? autoScroll,
    double? playbackSpeed,
    int? transposeAmount,
    bool? sargamEnabled,
    int? scaleRoot,
    bool? showVocals,
    bool? showBass,
    bool? showOther,
    double? vocalsMinConfidence,
    double? bassMinConfidence,
    double? otherMinConfidence,
    int? vocalDetail,
    double? referenceFrequency,
    String? track,
    double? bpmOverride,
    bool? cycleEnabled,
    double? cycleStart,
    double? cycleEnd,
    int? updatedAtMs,
  }) {
    return JobSettings(
      viewStartTime: viewStartTime ?? this.viewStartTime,
      viewWindowSize: viewWindowSize ?? this.viewWindowSize,
      yZoomScale: yZoomScale ?? this.yZoomScale,
      yPanOffset: yPanOffset ?? this.yPanOffset,
      autoScroll: autoScroll ?? this.autoScroll,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      transposeAmount: transposeAmount ?? this.transposeAmount,
      sargamEnabled: sargamEnabled ?? this.sargamEnabled,
      scaleRoot: scaleRoot ?? this.scaleRoot,
      showVocals: showVocals ?? this.showVocals,
      showBass: showBass ?? this.showBass,
      showOther: showOther ?? this.showOther,
      vocalsMinConfidence: vocalsMinConfidence ?? this.vocalsMinConfidence,
      bassMinConfidence: bassMinConfidence ?? this.bassMinConfidence,
      otherMinConfidence: otherMinConfidence ?? this.otherMinConfidence,
      vocalDetail: vocalDetail ?? this.vocalDetail,
      referenceFrequency: referenceFrequency ?? this.referenceFrequency,
      track: track ?? this.track,
      bpmOverride: bpmOverride ?? this.bpmOverride,
      cycleEnabled: cycleEnabled ?? this.cycleEnabled,
      cycleStart: cycleStart ?? this.cycleStart,
      cycleEnd: cycleEnd ?? this.cycleEnd,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  /// Serialize to JSON string for storage
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from JSON string
  static JobSettings fromJsonString(String jsonString) {
    try {
      return JobSettings.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      // Return defaults if parsing fails
      return const JobSettings();
    }
  }
}
