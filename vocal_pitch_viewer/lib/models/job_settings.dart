import 'dart:convert';

/// Settings for a specific job (track) that should be persisted
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
      transposeAmount: json['transposeAmount'] as int? ?? 0,
      sargamEnabled: json['sargamEnabled'] as bool? ?? false,
      scaleRoot: json['scaleRoot'] as int? ?? 0,
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
    };
  }

  /// Create a copy with some fields replaced
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
