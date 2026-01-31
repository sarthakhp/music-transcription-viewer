/// Shared constants for the pitch graph components
class GraphConstants {
  // Layout constants
  static const double leftPadding = 60.0;
  static const double rightPadding = 20.0;
  static const double topPadding = 20.0;
  static const double bottomPadding = 40.0;

  // Point sizes
  static const double voicedPointRadius = 3.0;
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
    if (range <= 10) return 1;
    if (range <= 30) return 5;
    if (range <= 60) return 10;
    if (range <= 120) return 15;
    if (range <= 300) return 30;
    return 60;
  }
}

