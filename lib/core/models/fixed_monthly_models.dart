/// פריט חודשי קבוע — הוצאה (עצמאי) או תוספת שכר (שכיר).
class FixedMonthlyItem {
  final String id;
  final String name;
  final double amount;
  /// `expense` | `addition`
  final String type;

  const FixedMonthlyItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
  });

  bool get isExpense => type == 'expense';
  bool get isAddition => type == 'addition';

  factory FixedMonthlyItem.fromMap(Map<String, dynamic> map) {
    return FixedMonthlyItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'type': type,
    };
  }
}

class FixedMonthlySnapshot {
  final String name;
  final double amount;
  final String type;

  const FixedMonthlySnapshot({
    required this.name,
    required this.amount,
    required this.type,
  });

  bool get isExpense => type == 'expense';
  bool get isAddition => type == 'addition';

  factory FixedMonthlySnapshot.fromMap(Map<String, dynamic> map) {
    return FixedMonthlySnapshot(
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'type': type,
    };
  }
}

List<FixedMonthlyItem> fixedMonthlyItemsFromFirestore(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => FixedMonthlyItem.fromMap(Map<String, dynamic>.from(item)))
      .where((item) => item.id.isNotEmpty && item.name.trim().isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> fixedMonthlyItemsToFirestore(
  List<FixedMonthlyItem> items,
) {
  return items.map((item) => item.toMap()).toList();
}

List<FixedMonthlySnapshot> fixedMonthlySnapshotsFromFirestore(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) => FixedMonthlySnapshot.fromMap(Map<String, dynamic>.from(item)),
      )
      .toList();
}

List<FixedMonthlyItem> fixedExpenses(List<FixedMonthlyItem> items) {
  return items.where((item) => item.isExpense && item.amount > 0).toList();
}

List<FixedMonthlyItem> fixedAdditions(List<FixedMonthlyItem> items) {
  return items.where((item) => item.isAddition && item.amount > 0).toList();
}

double totalFixedExpenseAmount(List<FixedMonthlyItem> items) {
  return fixedExpenses(items).fold<double>(0, (sum, item) => sum + item.amount);
}

double totalFixedAdditionAmount(List<FixedMonthlyItem> items) {
  return fixedAdditions(items).fold<double>(0, (sum, item) => sum + item.amount);
}

List<FixedMonthlySnapshot> snapshotsFromItems(List<FixedMonthlyItem> items) {
  return items
      .where((item) => item.amount > 0 && item.name.trim().isNotEmpty)
      .map(
        (item) => FixedMonthlySnapshot(
          name: item.name.trim(),
          amount: item.amount,
          type: item.type,
        ),
      )
      .toList();
}
