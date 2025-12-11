double? parseDmsOrDecimal(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;

  // If it contains N/S/E/W or degree symbol or minutes/seconds, parse as DMS
  final hasDmsChars = RegExp(r'[°\x27\x22NSEWnsew]').hasMatch(s);
  if (!hasDmsChars) {
    // Try decimal
    try {
      return double.parse(s);
    } catch (e) {
      return null;
    }
  }

  // Normalize: replace degree, minutes, seconds with spaces
  var t = s.replaceAll('°', ' ').replaceAll("'", ' ').replaceAll('"', ' ').replaceAll('’', ' ');
  // Ensure commas are spaces
  t = t.replaceAll(',', ' ');
  final parts = t.split(RegExp(r"\s+"));
  // Extract direction (N/S/E/W)
  String? dir;
  for (final p in parts.reversed) {
    if (p.isEmpty) continue;
    if (RegExp(r'^[NnSsEeWw]$').hasMatch(p)) {
      dir = p.toUpperCase();
      break;
    }
  }

  // Collect numeric tokens
  final nums = <double>[];
  for (final p in parts) {
    final cleaned = p.replaceAll(RegExp(r'[^0-9\.-]'), '');
    if (cleaned.isEmpty) continue;
    try {
      nums.add(double.parse(cleaned));
    } catch (e) {
      // ignore
    }
  }

  if (nums.isEmpty) return null;
  double deg = nums[0];
  double min = nums.length > 1 ? nums[1] : 0.0;
  double sec = nums.length > 2 ? nums[2] : 0.0;

  double decimal = deg + (min / 60.0) + (sec / 3600.0);
  if (dir != null) {
    if (dir == 'S' || dir == 'W') decimal = -decimal;
  }
  return decimal;
}
