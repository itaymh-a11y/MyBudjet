class PersonalCycleRange {
  final DateTime start;
  final DateTime end;
  final String id;

  const PersonalCycleRange({
    required this.start,
    required this.end,
    required this.id,
  });
}

PersonalCycleRange currentPersonalCycle(DateTime now) {
  final normalizedNow = DateTime(now.year, now.month, now.day);

  if (normalizedNow.day >= 10) {
    final start = DateTime(normalizedNow.year, normalizedNow.month, 10);
    final endMonth = normalizedNow.month == 12 ? 1 : normalizedNow.month + 1;
    final endYear = normalizedNow.month == 12 ? normalizedNow.year + 1 : normalizedNow.year;
    final end = DateTime(endYear, endMonth, 9, 23, 59, 59);
    final id = '${start.year}-${start.month.toString().padLeft(2, '0')}-10';
    return PersonalCycleRange(start: start, end: end, id: id);
  } else {
    final prevMonth = normalizedNow.month == 1 ? 12 : normalizedNow.month - 1;
    final prevYear = normalizedNow.month == 1 ? normalizedNow.year - 1 : normalizedNow.year;
    final start = DateTime(prevYear, prevMonth, 10);
    final end = DateTime(normalizedNow.year, normalizedNow.month, 9, 23, 59, 59);
    final id = '${start.year}-${start.month.toString().padLeft(2, '0')}-10';
    return PersonalCycleRange(start: start, end: end, id: id);
  }
}

class PensionMonthKey {
  final int year;
  final int month;

  const PensionMonthKey({required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PensionMonthKey &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}

PensionMonthKey currentPensionMonth(DateTime now) {
  return PensionMonthKey(year: now.year, month: now.month);
}

/// מחזיר את מזהה המחזור הקודם (למשל להעתקת תקציב). קלט: "2026-03-10".
String previousPersonalCycleId(String cycleId) {
  final parts = cycleId.split('-');
  if (parts.length < 3) return cycleId;
  int year = int.tryParse(parts[0]) ?? DateTime.now().year;
  int month = int.tryParse(parts[1]) ?? 1;
  if (month > 1) {
    month--;
  } else {
    month = 12;
    year--;
  }
  return '$year-${month.toString().padLeft(2, '0')}-10';
}

/// מחזיר את טווח המחזור לפי מזהה שמור ב-Firestore (למשל `2026-03-10`).
PersonalCycleRange? personalCycleRangeFromId(String cycleId) {
  final parts = cycleId.split('-');
  if (parts.length < 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return null;
  }
  final start = DateTime(year, month, 10);
  final endMonth = month == 12 ? 1 : month + 1;
  final endYear = month == 12 ? year + 1 : year;
  final end = DateTime(endYear, endMonth, 9, 23, 59, 59);
  return PersonalCycleRange(start: start, end: end, id: cycleId);
}

/// רשימת מחזורים אחורה מהתאריך הנתון (ללא כפילויות), מהחדש לישן.
List<PersonalCycleRange> recentPersonalCycleRanges({
  DateTime? from,
  int count = 36,
}) {
  final List<PersonalCycleRange> out = [];
  final seen = <String>{};
  var cursor = from ?? DateTime.now();
  for (var i = 0; i < count; i++) {
    final range = currentPersonalCycle(cursor);
    if (seen.add(range.id)) {
      out.add(range);
    }
    cursor = range.start.subtract(const Duration(days: 1));
  }
  return out;
}

