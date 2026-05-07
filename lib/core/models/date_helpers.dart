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

int normalizeCycleStartDay(int day) {
  if (day < 1) return 1;
  if (day > 28) return 28;
  return day;
}

PersonalCycleRange currentPersonalCycle(DateTime now, {int startDay = 10}) {
  final cycleStartDay = normalizeCycleStartDay(startDay);
  final normalizedNow = DateTime(now.year, now.month, now.day);

  if (normalizedNow.day >= cycleStartDay) {
    final start = DateTime(normalizedNow.year, normalizedNow.month, cycleStartDay);
    final endMonth = normalizedNow.month == 12 ? 1 : normalizedNow.month + 1;
    final endYear =
        normalizedNow.month == 12 ? normalizedNow.year + 1 : normalizedNow.year;
    final endDay = cycleStartDay - 1;
    final end = DateTime(endYear, endMonth, endDay, 23, 59, 59);
    final id =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${cycleStartDay.toString().padLeft(2, '0')}';
    return PersonalCycleRange(start: start, end: end, id: id);
  } else {
    final prevMonth = normalizedNow.month == 1 ? 12 : normalizedNow.month - 1;
    final prevYear = normalizedNow.month == 1 ? normalizedNow.year - 1 : normalizedNow.year;
    final start = DateTime(prevYear, prevMonth, cycleStartDay);
    final endDay = cycleStartDay - 1;
    final end = DateTime(normalizedNow.year, normalizedNow.month, endDay, 23, 59, 59);
    final id =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${cycleStartDay.toString().padLeft(2, '0')}';
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

PensionMonthKey currentPensionMonth(DateTime now, {int startDay = 1}) {
  final cycleStartDay = normalizeCycleStartDay(startDay);
  final normalizedNow = DateTime(now.year, now.month, now.day);
  if (normalizedNow.day >= cycleStartDay) {
    return PensionMonthKey(year: normalizedNow.year, month: normalizedNow.month);
  }
  final prevMonth = normalizedNow.month == 1 ? 12 : normalizedNow.month - 1;
  final prevYear = normalizedNow.month == 1 ? normalizedNow.year - 1 : normalizedNow.year;
  return PensionMonthKey(year: prevYear, month: prevMonth);
}

/// מחזיר את מזהה המחזור הקודם (למשל להעתקת תקציב). קלט: "2026-03-10".
String previousPersonalCycleId(String cycleId) {
  final parts = cycleId.split('-');
  if (parts.length < 3) return cycleId;
  int year = int.tryParse(parts[0]) ?? DateTime.now().year;
  int month = int.tryParse(parts[1]) ?? 1;
  final day = normalizeCycleStartDay(int.tryParse(parts[2]) ?? 10);
  if (month > 1) {
    month--;
  } else {
    month = 12;
    year--;
  }
  return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// מחזיר את טווח המחזור לפי מזהה שמור ב-Firestore (למשל `2026-03-10`).
PersonalCycleRange? personalCycleRangeFromId(String cycleId) {
  final parts = cycleId.split('-');
  if (parts.length < 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  final cycleStartDay = normalizeCycleStartDay(day ?? 10);
  if (year == null || month == null || month < 1 || month > 12 || day == null) {
    return null;
  }
  final start = DateTime(year, month, cycleStartDay);
  final endMonth = month == 12 ? 1 : month + 1;
  final endYear = month == 12 ? year + 1 : year;
  final end = DateTime(endYear, endMonth, cycleStartDay - 1, 23, 59, 59);
  return PersonalCycleRange(start: start, end: end, id: cycleId);
}

/// רשימת מחזורים אחורה מהתאריך הנתון (ללא כפילויות), מהחדש לישן.
List<PersonalCycleRange> recentPersonalCycleRanges({
  DateTime? from,
  int count = 36,
  int startDay = 10,
}) {
  final List<PersonalCycleRange> out = [];
  final seen = <String>{};
  var cursor = from ?? DateTime.now();
  for (var i = 0; i < count; i++) {
    final range = currentPersonalCycle(cursor, startDay: startDay);
    if (seen.add(range.id)) {
      out.add(range);
    }
    cursor = range.start.subtract(const Duration(days: 1));
  }
  return out;
}

PersonalCycleRange businessCycleRangeFromKey(
  PensionMonthKey key, {
  int startDay = 1,
}) {
  final cycleStartDay = normalizeCycleStartDay(startDay);
  final start = DateTime(key.year, key.month, cycleStartDay);
  final endMonth = key.month == 12 ? 1 : key.month + 1;
  final endYear = key.month == 12 ? key.year + 1 : key.year;
  final end = DateTime(endYear, endMonth, cycleStartDay - 1, 23, 59, 59, 999);
  return PersonalCycleRange(
    start: start,
    end: end,
    id: '${key.year}-${key.month.toString().padLeft(2, '0')}',
  );
}

