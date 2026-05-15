import '../models/load_plan.dart';
import '../models/pallet_type.dart';
import '../models/placed_pallet.dart';

class PayloadCheckResult {
  final double totalCargoKg;
  final double practicalMaxPayloadKg;
  final bool isWarning;
  final bool isCritical;

  const PayloadCheckResult({
    required this.totalCargoKg,
    required this.practicalMaxPayloadKg,
    required this.isWarning,
    required this.isCritical,
  });
}

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

  /// Hebelmodell: Jede Reihe / Palette trägt anteilig zur Hinterachslast bei
  /// (Mittelpunkt-X / Trailerlänge).  Sattellast = Gesamtgewicht − Hinterachslast.
  ///
  /// When [loadPlan.manualPallets] is set the lever calculation uses individual
  /// pallet positions instead of row-centre approximations so the result reflects
  /// any manual position corrections made in the overlay editor.
  static WeightDistributionResult calculateDistribution({
    required LoadPlan loadPlan,
    required int kgPerEuro,
    required int kgPerIndustry,
  }) {
    final trailerLength = loadPlan.trailerType.trailerLengthCm;

    if (loadPlan.manualPallets != null) {
      return _fromFreePallets(
        pallets: loadPlan.manualPallets!,
        trailerLengthCm: trailerLength,
        kgPerEuro: kgPerEuro,
        kgPerIndustry: kgPerIndustry,
      );
    }

    double rearLoad = 0;
    double totalWeight = 0;
    double usedCm = 0;

    for (final row in loadPlan.rows) {
      if (row.arrangement == RowArrangement.mixedEuro2Industry1) {
        // Mixed zone (160 cm): 1 industrie quer (center @ usedCm + 50)
        // + 2 euro quer stacked along length (centers @ usedCm + 40 / +120).
        final indW = kgPerIndustry.toDouble();
        final euroW = kgPerEuro.toDouble();
        rearLoad += indW * (usedCm + 50) / trailerLength;
        rearLoad += euroW * (usedCm + 40) / trailerLength;
        rearLoad += euroW * (usedCm + 120) / trailerLength;
        totalWeight += indW + 2 * euroW;
        usedCm += row.lengthCm;
        continue;
      }

      if (row.arrangement == RowArrangement.mixedEuro1Industry1Tail) {
        // Tail mix zone (100 cm): 1 euro quer (80 cm tief, center @ usedCm+40)
        // + 1 industrie quer (100 cm tief, center @ usedCm+50, reaches rear).
        final indW = kgPerIndustry.toDouble();
        final euroW = kgPerEuro.toDouble();
        rearLoad += euroW * (usedCm + 40) / trailerLength;
        rearLoad += indW * (usedCm + 50) / trailerLength;
        totalWeight += euroW + indW;
        usedCm += row.lengthCm;
        continue;
      }

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

    return _result(totalWeight: totalWeight, rearLoad: rearLoad);
  }

  static WeightDistributionResult _fromFreePallets({
    required List<PlacedPallet> pallets,
    required double trailerLengthCm,
    required int kgPerEuro,
    required int kgPerIndustry,
  }) {
    double rearLoad = 0;
    double totalWeight = 0;

    for (final p in pallets) {
      if (!p.isFreeMode) continue;
      final isEuroByArrangement =
          p.arrangement == RowArrangement.euroLongi3 ||
              p.arrangement == RowArrangement.euroTransverse2 ||
              p.arrangement == RowArrangement.euroTransverseSingle;
      // Mixed zones share one arrangement across both pallet types;
      // distinguish by footprint (100×120 = industrie, 80×120 = euro).
      final isMixedArrangement =
          p.arrangement == RowArrangement.mixedEuro2Industry1 ||
              p.arrangement == RowArrangement.mixedEuro1Industry1Tail;
      final isMixedEuro = isMixedArrangement &&
          p.widthCm == 80.0 &&
          p.heightCm == 120.0;
      final isEuro = isEuroByArrangement || isMixedEuro;
      final w = (isEuro ? kgPerEuro : kgPerIndustry).toDouble();
      final centerX = p.xCm! + p.widthCm! / 2;
      rearLoad += w * centerX / trailerLengthCm;
      totalWeight += w;
    }

    return _result(totalWeight: totalWeight, rearLoad: rearLoad);
  }

  static WeightDistributionResult _result({
    required double totalWeight,
    required double rearLoad,
  }) {
    final frontLoad = totalWeight - rearLoad;
    final frontPercent =
        totalWeight > 0 ? (frontLoad / totalWeight * 100) : 0.0;
    final rearPercent =
        totalWeight > 0 ? (rearLoad / totalWeight * 100) : 0.0;
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

  /// Nutzlastprüfung gegen die praxisnahen Schwellwerte des Trailer-Typs.
  /// [totalCargoKg] ist das reine Ladegewicht (Paletten), ohne Fahrzeugeigengewicht.
  static PayloadCheckResult checkPayload(LoadPlan plan, double totalCargoKg) {
    final type = plan.trailerType;
    return PayloadCheckResult(
      totalCargoKg: totalCargoKg,
      practicalMaxPayloadKg: type.practicalMaxPayloadKg,
      isWarning: totalCargoKg >= type.payloadWarningKg &&
          totalCargoKg < type.payloadCriticalKg,
      isCritical: totalCargoKg >= type.payloadCriticalKg,
    );
  }

  /// Prüft, ob die Praxisgrenze des Trailer-Typs überschritten ist.
  static bool isOverweight(LoadPlan plan, double totalCargoKg) {
    return totalCargoKg > plan.trailerType.practicalMaxPayloadKg;
  }
}
