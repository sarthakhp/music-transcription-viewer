import 'dart:ui' show Rect, Size;

/// Shared constants for the pitch graph components
class GraphConstants {
  // Layout constants
  static const double leftPadding = 60.0;
  static const double rightPadding = 20.0;
  static const double topPadding = 20.0;
  static const double bottomPadding = 40.0;

  // Voiced point appearance
  static const double voicedPointRadius = 4.5;
  static const double voicedPointBorderWidth = 1.0;
  static const double voicedPointBorderAlpha = 0.7;
  static const double voicedMinAlpha = 0.45;
  static const double voicedMaxAlpha = 1.0;

  // Unvoiced point appearance
  static const double unvoicedPointRadius = 2.0;

  // Line widths
  static const double playheadWidth = 2.0;
  static const double gridLineWidth = 1.0;
  static const double hoverLineWidth = 1.0;

  // Frequency grid values
  static const List<double> frequencyGridValues = [
    100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 800.0, 1000.0
  ];

  // Time step calculation
  static double calculateTimeStep(double range) {
    if (range < 10.5) return 1;
    if (range < 31) return 5;
    if (range < 61) return 10;
    if (range < 121) return 15;
    if (range < 301) return 30;
    return 60;
  }
}


/// Padding around the plotted area (room for axis labels).
///
/// Phones get tighter insets so the graph keeps most of the screen width;
/// [forWidth] picks between them.
class GraphInsets {
  final double left;
  final double right;
  final double top;
  final double bottom;

  /// Largest axis-label font that still fits inside [left].
  final double maxLabelFontSize;

  const GraphInsets({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    this.maxLabelFontSize = 14,
  });

  static const regular = GraphInsets(
    left: GraphConstants.leftPadding,
    right: GraphConstants.rightPadding,
    top: GraphConstants.topPadding,
    bottom: GraphConstants.bottomPadding,
  );

  static const compact = GraphInsets(
    left: 46,
    right: 10,
    top: 22,
    bottom: 28,
    maxLabelFontSize: 11,
  );

  static const double compactBreakpoint = 600;

  static GraphInsets forWidth(double width) =>
      width < compactBreakpoint ? compact : regular;

  /// The plot rectangle inside a canvas of [size].
  Rect rectFor(Size size) => Rect.fromLTRB(
        left,
        top,
        size.width - right,
        size.height - bottom,
      );
}
