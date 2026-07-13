import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_settings.dart';

class UserSettings {
  static const _keyPlaybackSpeed = 'playbackSpeed';
  static const _keyTransposeAmount = 'transposeAmount';
  static const _keySargamEnabled = 'sargamEnabled';
  static const _keyScaleRoot = 'scaleRoot';
  static const _keyReferenceFrequency = 'referenceFrequency';
  static const _keyVocalDetail = 'vocalDetail';
  static const _keyLastJobId = 'lastJobId';
  static const _keyJobSettings = 'jobSettings'; // Map of jobId -> settings JSON
  static const _keyThemeMode = 'themeMode';

  static const double defaultPlaybackSpeed = 1.0;
  static const int defaultTransposeAmount = 0;
  static const bool defaultSargamEnabled = false;
  static const int defaultScaleRoot = 0;
  static const double defaultReferenceFrequency = 440.0;
  static const int defaultVocalDetail = 10;
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  late final SharedPreferences _prefs;

  double playbackSpeed = defaultPlaybackSpeed;
  int transposeAmount = defaultTransposeAmount;
  bool sargamEnabled = defaultSargamEnabled;
  int scaleRoot = defaultScaleRoot;
  double referenceFrequency = defaultReferenceFrequency;
  int vocalDetail = defaultVocalDetail;
  ThemeMode themeMode = defaultThemeMode;

  /// The job that was open in the viewer, so a page reload can restore it
  /// instead of dropping back to the home screen. Null when no job is open.
  String? lastJobId;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    playbackSpeed = _prefs.getDouble(_keyPlaybackSpeed) ?? defaultPlaybackSpeed;
    transposeAmount = _prefs.getInt(_keyTransposeAmount) ?? defaultTransposeAmount;
    sargamEnabled = _prefs.getBool(_keySargamEnabled) ?? defaultSargamEnabled;
    scaleRoot = _prefs.getInt(_keyScaleRoot) ?? defaultScaleRoot;
    referenceFrequency = _prefs.getDouble(_keyReferenceFrequency) ?? defaultReferenceFrequency;
    vocalDetail = _prefs.getInt(_keyVocalDetail) ?? defaultVocalDetail;
    lastJobId = _prefs.getString(_keyLastJobId);

    // Load theme mode
    final themeModeIndex = _prefs.getInt(_keyThemeMode);
    themeMode = themeModeIndex != null
        ? ThemeMode.values[themeModeIndex]
        : defaultThemeMode;
  }

  void savePlaybackSpeed(double value) {
    playbackSpeed = value;
    _prefs.setDouble(_keyPlaybackSpeed, value);
  }

  void saveTransposeAmount(int value) {
    transposeAmount = value;
    _prefs.setInt(_keyTransposeAmount, value);
  }

  void saveSargamEnabled(bool value) {
    sargamEnabled = value;
    _prefs.setBool(_keySargamEnabled, value);
  }

  void saveScaleRoot(int value) {
    scaleRoot = value;
    _prefs.setInt(_keyScaleRoot, value);
  }

  void saveReferenceFrequency(double value) {
    referenceFrequency = value;
    _prefs.setDouble(_keyReferenceFrequency, value);
  }

  void saveVocalDetail(int value) {
    vocalDetail = value;
    _prefs.setInt(_keyVocalDetail, value);
  }

  void saveThemeMode(ThemeMode value) {
    themeMode = value;
    _prefs.setInt(_keyThemeMode, value.index);
  }

  void saveLastJobId(String? jobId) {
    lastJobId = jobId;
    if (jobId == null) {
      _prefs.remove(_keyLastJobId);
    } else {
      _prefs.setString(_keyLastJobId, jobId);
    }
  }

  // --- Per-job settings ----------------------------------------------------

  /// Load settings for a specific job. Returns defaults if not found.
  JobSettings loadJobSettings(String jobId) {
    final allSettingsJson = _prefs.getString(_keyJobSettings);
    if (allSettingsJson == null) return const JobSettings();

    try {
      final allSettings = jsonDecode(allSettingsJson) as Map<String, dynamic>;
      final jobSettingsJson = allSettings[jobId];
      if (jobSettingsJson == null) return const JobSettings();

      return JobSettings.fromJson(jobSettingsJson as Map<String, dynamic>);
    } catch (e) {
      return const JobSettings();
    }
  }

  /// Save settings for a specific job
  void saveJobSettings(String jobId, JobSettings settings) {
    final allSettingsJson = _prefs.getString(_keyJobSettings);
    Map<String, dynamic> allSettings = {};

    if (allSettingsJson != null) {
      try {
        allSettings = jsonDecode(allSettingsJson) as Map<String, dynamic>;
      } catch (e) {
        // If parsing fails, start fresh
        allSettings = {};
      }
    }

    allSettings[jobId] = settings.toJson();
    _prefs.setString(_keyJobSettings, jsonEncode(allSettings));
  }

  /// Clear settings for a specific job
  void clearJobSettings(String jobId) {
    final allSettingsJson = _prefs.getString(_keyJobSettings);
    if (allSettingsJson == null) return;

    try {
      final allSettings = jsonDecode(allSettingsJson) as Map<String, dynamic>;
      allSettings.remove(jobId);
      _prefs.setString(_keyJobSettings, jsonEncode(allSettings));
    } catch (e) {
      // Ignore errors
    }
  }
}
