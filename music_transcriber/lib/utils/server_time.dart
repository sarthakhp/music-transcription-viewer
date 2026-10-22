/// Parses a timestamp from the backend. It stores UTC without a timezone
/// marker ("2026-10-22T08:57:55"), which Dart would read as local time and
/// show hours off. A marker (Z or +hh:mm), when present, is respected.
DateTime parseServerTime(String value) {
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  return DateTime.parse(hasZone ? value : '${value}Z').toLocal();
}
