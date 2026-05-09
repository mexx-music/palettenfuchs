import '../models/load_plan.dart';
import '../models/pallet_type.dart';
import 'trailer_constants.dart';

class WeightDistributionResult {
  final double totalWeightKg;
  final double frontLoadKg;
  final double rearLoadKg;
  final double frontPercent;
  final double rearPercent;
  final bool isFrontWarning;
  final bool isFrontCritical;

  const WeightDistributionResult({
    required this.totalWeightKg,
    required this.frontLoadKg,
    required this.rearLoadKg,
    required this.frontPercent,
    required this.rearPercent,
    required this.isFrontWarning,
    required this.isFrontCritical,
  });
}

class WeightEngine {
  static const double frontWarningKg = 10800;
  static const double frontCriticalKg = 11500;

  /// Hebelmodell: Jede Reihe trägt anteilig zur Hinterachslast bei
  /// (Mittelpunkt-X der Reihe / Trailerlänge).
  /// Sattellast = Gesamtgewicht − Hinterachslast.
  static WeightDistributionResult calculateDistribution({
    required LoadPlan loadPlan,
    required int kgPerEuro,
    required int kgPerIndustry,
  }) {
    final trailerLength = loadPlan.trailerType.trailerLengthCm;
    double rearLoad = 0;
    double totalWeight = 0;
    double usedCm = 0;

    for (final row in loadPlan.rows) {
      final isEuro = row.arrangement == RowArrangement.euroLongi3 ||
          row.arrangement == RowArrangement.euroTransverse2 ||
          row.arrangement == RowArrangement.euroTransverseSingle;
      final palletWeight =
          row.palletCount * (isEuro ? kgPerEuro : kgPerIndustry).toDouble();
      final centerX = usedCm + row.lengthCm / 2;
      rearLoad += palletWeight * centerX / trailerLength;
      totalWeight += palletWeight;
      usedCm += row.lengthCm;
    }

    final frontLoad = totalWeight - rearLoad;
    final frontPercent =
        totalWeight > 0 ? (frontLoad / totalWeight * 100) : 0.0;
    final rearPercent = totalWeight > 0 ? (rearLoad / totalWeight * 100) : 0.0;

    return WeightDistributionResult(
      totalWeightKg: totalWeight,
      frontLoadKg: frontLoad,
      rearLoadKg: rearLoad,
      frontPercent: frontPercent,
      rearPercent: rearPercent,
      isFrontWarning:
          frontLoad >= frontWarningKg && frontLoad < frontCriticalKg,
      isFrontCritical: frontLoad >= frontCriticalKg,
    );
  }

  /// Prüft, ob das Gewichtslimit überschritten ist
  static bool isOverweight(LoadPlan plan) {
    return plan.totalWeight > TrailerConstants.maxPayload;
  }
}
