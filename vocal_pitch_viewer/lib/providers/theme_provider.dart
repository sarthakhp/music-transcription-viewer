import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Provider for managing app theme (light/dark mode)
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  /// Get the appropriate palette based on current theme mode and system brightness
  AppPalette getPalette(Brightness systemBrightness) {
    switch (_themeMode) {
      case ThemeMode.light:
        return minimalistPalette;
      case ThemeMode.dark:
        return indigoPalette;
      case ThemeMode.system:
        return systemBrightness == Brightness.dark 
            ? indigoPalette 
            : minimalistPalette;
    }
  }
  
  /// Set theme mode and notify listeners
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
  
  /// Cycle through theme modes: light → dark → system
  void cycleThemeMode() {
    switch (_themeMode) {
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        setThemeMode(ThemeMode.light);
        break;
    }
  }
  
  /// Get icon for current theme mode
  IconData get themeModeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }
  
  /// Get tooltip text for current theme mode
  String get themeModeTooltip {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light mode (click for dark)';
      case ThemeMode.dark:
        return 'Dark mode (click for system)';
      case ThemeMode.system:
        return 'System mode (click for light)';
    }
  }
}
