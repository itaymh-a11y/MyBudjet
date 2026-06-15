class FixedGrossDeduction {
  final String id;
  final String name;
  /// אחוז מהברוטו (0–100).
  final double percentage;

  const FixedGrossDeduction({
    required this.id,
    required this.name,
    required this.percentage,
  });

  factory FixedGrossDeduction.fromMap(Map<String, dynamic> map) {
    return FixedGrossDeduction(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'percentage': percentage,
    };
  }
}

class GrossDeductionSnapshot {
  final String name;
  final double percentage;
  final double amount;

  const GrossDeductionSnapshot({
    required this.name,
    required this.percentage,
    required this.amount,
  });

  factory GrossDeductionSnapshot.fromMap(Map<String, dynamic> map) {
    return GrossDeductionSnapshot(
      name: map['name'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'percentage': percentage,
      'amount': amount,
    };
  }
}

List<GrossDeductionSnapshot> computeGrossDeductionSnapshots({
  required double gross,
  required List<FixedGrossDeduction> deductions,
}) {
  if (gross <= 0 || deductions.isEmpty) return const [];

  return deductions
      .where((d) => d.name.trim().isNotEmpty && d.percentage > 0)
      .map(
        (d) => GrossDeductionSnapshot(
          name: d.name.trim(),
          percentage: d.percentage,
          amount: gross * (d.percentage / 100.0),
        ),
      )
      .toList();
}

double totalGrossDeductionAmount(List<GrossDeductionSnapshot> snapshots) {
  return snapshots.fold<double>(0, (sum, item) => sum + item.amount);
}

List<FixedGrossDeduction> fixedGrossDeductionsFromFirestore(
  dynamic raw,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => FixedGrossDeduction.fromMap(Map<String, dynamic>.from(item)))
      .where((d) => d.id.isNotEmpty && d.name.trim().isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> fixedGrossDeductionsToFirestore(
  List<FixedGrossDeduction> deductions,
) {
  return deductions.map((d) => d.toMap()).toList();
}

List<GrossDeductionSnapshot> grossDeductionSnapshotsFromFirestore(
  dynamic raw,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) => GrossDeductionSnapshot.fromMap(Map<String, dynamic>.from(item)),
      )
      .toList();
}
