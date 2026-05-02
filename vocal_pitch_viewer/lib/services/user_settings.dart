import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  static const _keyPlaybackSpeed = 'playbackSpeed';
  static const _keyTransposeAmount = 'transposeAmount';
  static const _keySargamEnabled = 'sargamEnabled';
  static const _keyScaleRoot = 'scaleRoot';
  static const _keyReferenceFrequency = 'referenceFrequency';
  static const _keyVocalDetail = 'vocalDetail';

  static const double defaultPlaybackSpeed = 1.0;
  static const int defaultTransposeAmount = 0;
  static const bool defaultSargamEnabled = false;
  static const int defaultScaleRoot = 0;
  static const double defaultReferenceFrequency = 440.0;
  static const int defaultVocalDetail = 10;

  late final SharedPreferences _prefs;

  double playbackSpeed = defaultPlaybackSpeed;
  int transposeAmount = defaultTransposeAmount;
  bool sargamEnabled = defaultSargamEnabled;
  int scaleRoot = defaultScaleRoot;
  double referenceFrequency = defaultReferenceFrequency;
  int vocalDetail = defaultVocalDetail;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    playbackSpeed = _prefs.getDouble(_keyPlaybackSpeed) ?? defaultPlaybackSpeed;
    transposeAmount = _prefs.getInt(_keyTransposeAmount) ?? defaultTransposeAmount;
    sargamEnabled = _prefs.getBool(_keySargamEnabled) ?? defaultSargamEnabled;
    scaleRoot = _prefs.getInt(_keyScaleRoot) ?? defaultScaleRoot;
    referenceFrequency = _prefs.getDouble(_keyReferenceFrequency) ?? defaultReferenceFrequency;
    vocalDetail = _prefs.getInt(_keyVocalDetail) ?? defaultVocalDetail;
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
}
