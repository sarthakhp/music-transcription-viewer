import 'package:flutter/widgets.dart';

/// How the viewer should lay itself out for the current window.
enum ViewerLayout {
  /// Phone held upright: one-column, touch-first controls.
  phonePortrait,

  /// Phone on its side: very little height, so everything shares one row.
  phoneLandscape,

  /// Tablet / desktop: the original toolbar + keyboard-driven controls.
  regular;

  bool get isPhone => this != regular;

  static const double _phoneMaxWidth = 600;
  static const double _landscapeMaxHeight = 500;

  static ViewerLayout of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < _phoneMaxWidth) return phonePortrait;
    if (size.height < _landscapeMaxHeight) return phoneLandscape;
    return regular;
  }
}
