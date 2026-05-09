import '../models/load_plan.dart';
import '../models/load_row.dart';
import '../models/manual_load_seed.dart';
import '../models/pallet_type.dart';
import 'trailer_constants.dart';

/// Engine für Palettenreihen-Berechnung
class PalletLayoutEngine {
  static const int maxEuroPallets = 34;
  static const int maxIndustryPallets = 26;

  // Sattellast-Schwellwert für den Gewichts-Optimierer (kg)
  static const double _frontWarningKg = 10800.0;

  /// Berechnet einen Ladeplan basierend auf Euro- und Industrie-Paletten.
  /// [kgPerEuro] > 0 aktiviert die gewichtsbasierte Achslast-Optimierung.
  static LoadPlan calculateBasicPlan({
    required int euroPallets,
    required int industryPallets,
    bool optimizeAxleLoad = false,
    required TrailerType trailerType,
    int kgPerEuro = 0,
  }) {
    final safeEuro = euroPallets.clamp(0, maxEuroPallets);
    final euroToPlace = safeEuro.clamp(0, trailerType.maxEuroPallets);
    final safeIndustry = industryPallets.clamp(0, maxIndustryPallets);
    final trailerLengthCm = trailerType.trailerLengthCm;

    final rows = <LoadRow>[];
    double usedLength = 0;

    // 1. Euro-Paletten verarbeiten
    if (optimizeAxleLoad && euroToPlace > 0) {
      if (kgPerEuro > 0) {
        // Gewichtsbasierte Optimierung: bestes Muster nach Sattellast wählen
        final best = _bestEuroPatternForWeight(
          totalPallets: euroToPlace,
          kgPerEuro: kgPerEuro,
          trailerLengthCm: trailerLengthCm,
          startOffsetCm: 0,
        );
        if (best != null) {
          usedLength =
              _buildEuroRows(rows, best.n3, best.n2, best.n1, usedLength);
        } else {
          usedLength = _addEuroPallets(
              rows, euroToPlace, rows.length, usedLength, trailerLengthCm);
        }
      } else {
        // Kein Gewicht: geometrische Näherung (bestehende Logik)
        final euroResult = _addEuroPalletsExact(
          rows,
          euroToPlace,
          rows.length,
          usedLength,
          trailerLengthCm,
        );
        if (euroResult['fallback'] == true) {
          usedLength = _addEuroPallets(
              rows, euroToPlace, rows.length, usedLength, trailerLengthCm);
        } else {
          usedLength = euroResult['usedLength'] as double;
        }
      }
    } else {
      usedLength = _addEuroPallets(
          rows, euroToPlace, rows.length, usedLength, trailerLengthCm);
    }

    final placedEuro = rows.fold(0, (s, r) => s + r.palletCount);

    // 2. Industrie-Paletten verarbeiten
    usedLength = _addIndustryPallets(
        rows, safeIndustry, rows.length, usedLength, trailerLengthCm);

    final placedIndustry =
        rows.fold(0, (s, r) => s + r.palletCount) - placedEuro;

    return LoadPlan(
      rows: rows,
      requestedEuroPallets: safeEuro,
      requestedIndustryPallets: safeIndustry,
      placedEuroPallets: placedEuro,
      placedIndustryPallets: placedIndustry,
      trailerType: trailerType,
    );
  }

  // ---------------------------------------------------------------------------
  // Gewichtsbasierter Optimierer für Euro-Paletten
  // ---------------------------------------------------------------------------

  /// Testet n1 ∈ {0, 1, 2} Einzelpaletten vorne und wählt das Muster mit der
  /// niedrigsten Sattellast. Vorzugsweise unter [_frontWarningKg].
  static ({int n3, int n2, int n1})? _bestEuroPatternForWeight({
    required int totalPallets,
    required int kgPerEuro,
    required double trailerLengthCm,
    required double startOffsetCm,
  }) {
    ({int n3, int n2, int n1})? best;
    double bestFront = double.infinity;

    for (int n1 = 0; n1 <= 2; n1++) {
      final remaining = totalPallets - n1;
      if (remaining < 0) continue;

      final split = _splitEuro(remaining);
      if (split == null) continue;

      final rowLen = split.n3 * TrailerConstants.euroLengthCm +
          (split.n2 + n1) * TrailerConstants.euroWidthCm;
      if (startOffsetCm + rowLen > trailerLengthCm) continue;

      final frontLoad = _computeEuroFrontLoad(
        n3: split.n3,
        n2: split.n2,
        n1: n1,
        kgPerEuro: kgPerEuro,
        trailerLengthCm: trailerLengthCm,
        startOffsetCm: startOffsetCm,
      );

      // Besser wenn: bisher über Schwelle und dieser darunter ODER einfach kleiner
      final isBetter = best == null ||
          (bestFront >= _frontWarningKg && frontLoad < bestFront) ||
          (frontLoad < _frontWarningKg && frontLoad < bestFront);

      if (isBetter) {
        best = (n3: split.n3, n2: split.n2, n1: n1);
        bestFront = frontLoad;
      }
    }

    return best;
  }

  /// Zerlegt [remaining] Paletten in n3 (3er-Reihen) und n2 (2er-Reihen).
  /// Maximiert n3. Gibt null zurück wenn keine Zerlegung möglich (z. B. 1).
  static ({int n3, int n2})? _splitEuro(int remaining) {
    if (remaining == 0) return (n3: 0, n2: 0);
    if (remaining == 1) return null;
    final r = remaining % 3;
    if (r == 0) return (n3: remaining ~/ 3, n2: 0);
    if (r == 2) return (n3: remaining ~/ 3, n2: 1);
    // r == 1: eine 3er-Reihe durch zwei 2er-Reihen ersetzen
    if (remaining >= 4) return (n3: (remaining - 4) ~/ 3, n2: 2);
    return null;
  }

  /// Hebelmodell für ein Euro-Muster: Anordnung [n1×1er vorne][n2×2er][n3×3er hinten].
  static double _computeEuroFrontLoad({
    required int n3,
    required int n2,
    required int n1,
    required int kgPerEuro,
    required double trailerLengthCm,
    required double startOffsetCm,
  }) {
    double rearLoad = 0;
    double pos = startOffsetCm;

    for (int i = 0; i < n1; i++) {
      rearLoad += kgPerEuro *
          (pos + TrailerConstants.euroWidthCm / 2) /
          trailerLengthCm;
      pos += TrailerConstants.euroWidthCm;
    }
    for (int i = 0; i < n2; i++) {
      rearLoad += 2 *
          kgPerEuro *
          (pos + TrailerConstants.euroWidthCm / 2) /
          trailerLengthCm;
      pos += TrailerConstants.euroWidthCm;
    }
    for (int i = 0; i < n3; i++) {
      rearLoad += 3 *
          kgPerEuro *
          (pos + TrailerConstants.euroLengthCm / 2) /
          trailerLengthCm;
      pos += TrailerConstants.euroLengthCm;
    }

    final totalWeight = (n3 * 3 + n2 * 2 + n1) * kgPerEuro.toDouble();
    return totalWeight - rearLoad;
  }

  /// Fügt Euro-Reihen nach Muster [n1×1er][n2×2er][n3×3er] in [rows] ein.
  static double _buildEuroRows(
    List<LoadRow> rows,
    int n3,
    int n2,
    int n1,
    double startUsedLength,
  ) {
    double usedLength = startUsedLength;

    for (int i = 0; i < n1; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroTransverseSingle,
        palletCount: 1,
        weight: 0,
      ));
      usedLength += TrailerConstants.euroWidthCm;
    }
    for (int i = 0; i < n2; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroTransverse2,
        palletCount: 2,
        weight: 0,
      ));
      usedLength += TrailerConstants.euroWidthCm;
    }
    for (int i = 0; i < n3; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroLongi3,
        palletCount: 3,
        weight: 0,
      ));
      usedLength += TrailerConstants.euroLengthCm;
    }

    return usedLength;
  }

  // ---------------------------------------------------------------------------
  // Bestehende Hilfsmethoden
  // ---------------------------------------------------------------------------

  /// Fügt Euro-Paletten ohne Gewichtskenntnis ein (3er → 2er → 1er).
  static double _addEuroPallets(
    List<LoadRow> rows,
    int totalPallets,
    int startIndex,
    double startUsedLength,
    double trailerLengthCm,
  ) {
    double usedLength = startUsedLength;
    int rowIndex = startIndex;
    int remaining = totalPallets;

    while (remaining >= 3 &&
        usedLength + TrailerConstants.euroLengthCm <= trailerLengthCm) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.euroLongi3,
        palletCount: 3,
        weight: 0,
      ));
      usedLength += TrailerConstants.euroLengthCm;
      remaining -= 3;
    }

    if (remaining >= 2 &&
        usedLength + TrailerConstants.euroWidthCm <= trailerLengthCm) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.euroTransverse2,
        palletCount: 2,
        weight: 0,
      ));
      usedLength += TrailerConstants.euroWidthCm;
      remaining -= 2;
    }

    if (remaining == 1 &&
        usedLength + TrailerConstants.euroWidthCm <= trailerLengthCm) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.euroTransverseSingle,
        palletCount: 1,
        weight: 0,
      ));
      usedLength += TrailerConstants.euroWidthCm;
    }

    return usedLength;
  }

  /// Geometrische Achslast-Optimierung ohne Gewicht (ab 25 Paletten).
  /// Scoring: a) max Paletten  b) max 3er  c) min 1er  d) min 2er  e) max Länge.
  /// Anordnung: [1er vorne][2er vorne][3er Haupt-Body].
  static Map<String, dynamic> _addEuroPalletsExact(
    List<LoadRow> rows,
    int totalPallets,
    int startIndex,
    double startUsedLength,
    double trailerLengthCm,
  ) {
    if (totalPallets < 25) {
      return {'usedLength': startUsedLength, 'fallback': true};
    }

    final maxLength = trailerLengthCm;
    const l3 = TrailerConstants.euroLengthCm;
    const l2 = TrailerConstants.euroWidthCm;
    const l1 = TrailerConstants.euroWidthCm;

    final available = maxLength - startUsedLength;
    final maxN3 = (available / l3).floor().clamp(0, totalPallets ~/ 3);

    bool found = false;
    int bestN3 = 0, bestN2 = 0, bestN1 = 0;
    int bestPallets = 0;
    double bestLength = -1;

    for (int n3 = 0; n3 <= maxN3; n3++) {
      final used3 = n3 * l3;
      final remPal2 = totalPallets - 3 * n3;
      final remSpace2 = available - used3;
      final maxN2 =
          (remSpace2 / l2).floor().clamp(0, remPal2 ~/ 2).clamp(0, 4);

      for (int n2 = 0; n2 <= maxN2; n2++) {
        final used23 = used3 + n2 * l2;
        final remPal1 = remPal2 - 2 * n2;
        final remSpace1 = available - used23;
        final maxN1 =
            (remSpace1 / l1).floor().clamp(0, remPal1).clamp(0, 2);

        for (int n1 = 0; n1 <= maxN1; n1++) {
          final palletsUsed = 3 * n3 + 2 * n2 + n1;
          if (palletsUsed == 0) continue;
          if (n1 > 0 && (n3 + n2) < 4) continue;

          final totalUsed = startUsedLength + used23 + n1 * l1;

          final better = palletsUsed > bestPallets ||
              (palletsUsed == bestPallets && n3 > bestN3) ||
              (palletsUsed == bestPallets && n3 == bestN3 && n1 < bestN1) ||
              (palletsUsed == bestPallets &&
                  n3 == bestN3 &&
                  n1 == bestN1 &&
                  n2 < bestN2) ||
              (palletsUsed == bestPallets &&
                  n3 == bestN3 &&
                  n1 == bestN1 &&
                  n2 == bestN2 &&
                  totalUsed > bestLength);

          if (better) {
            bestN3 = n3;
            bestN2 = n2;
            bestN1 = n1;
            bestPallets = palletsUsed;
            bestLength = totalUsed;
            found = true;
          }
        }
      }
    }

    if (!found) {
      return {'usedLength': startUsedLength, 'fallback': true};
    }

    int rowIndex = startIndex;
    for (int i = 0; i < bestN1; i++) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.euroTransverseSingle,
        palletCount: 1,
        weight: 0,
      ));
    }
    for (int i = 0; i < bestN2; i++) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.euroTransverse2,
        palletCount: 2,
        weight: 0,
      ));
    }
    for (int i = 0; i < bestN3; i++) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.euroLongi3,
        palletCount: 3,
        weight: 0,
      ));
    }

    return {'usedLength': bestLength};
  }

  /// Fügt Industrie-Paletten optimiert hinzu (2er, Rest einzeln).
  static double _addIndustryPallets(
    List<LoadRow> rows,
    int totalPallets,
    int startIndex,
    double startUsedLength,
    double trailerLengthCm,
  ) {
    double usedLength = startUsedLength;
    int rowIndex = startIndex;
    int remaining = totalPallets;

    while (remaining >= 2 &&
        usedLength + TrailerConstants.industryLengthCm <= trailerLengthCm) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.industryLongi2,
        palletCount: 2,
        weight: 0,
      ));
      usedLength += TrailerConstants.industryLengthCm;
      remaining -= 2;
    }

    if (remaining == 1 &&
        usedLength + TrailerConstants.industryLengthCm <= trailerLengthCm) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.industrySingle,
        palletCount: 1,
        weight: 0,
      ));
      usedLength += TrailerConstants.industryLengthCm;
    }

    return usedLength;
  }

  // ---------------------------------------------------------------------------
  // Seed-basierter Plan
  // ---------------------------------------------------------------------------

  /// Berechnet einen Ladeplan mit manuell vorgegebenen Startreihen (Seed).
  static LoadPlan calculatePlanWithSeed({
    required int euroPallets,
    required int industryPallets,
    required TrailerType trailerType,
    required ManualLoadSeed seed,
    bool optimizeAxleLoad = false,
    int kgPerEuro = 0,
  }) {
    if (!seed.enabled || seed.fixedRows.isEmpty) {
      return calculateBasicPlan(
        euroPallets: euroPallets,
        industryPallets: industryPallets,
        optimizeAxleLoad: optimizeAxleLoad,
        trailerType: trailerType,
        kgPerEuro: kgPerEuro,
      );
    }

    final safeEuro =
        euroPallets.clamp(0, maxEuroPallets).clamp(0, trailerType.maxEuroPallets);
    final safeIndustry = industryPallets.clamp(0, maxIndustryPallets);
    final trailerLengthCm = trailerType.trailerLengthCm;

    final rows = <LoadRow>[];
    double usedLength = 0;
    int remainingEuro = safeEuro;
    int remainingIndustry = safeIndustry;
    final skippedLabels = <String>[];

    // Phase 1: Seed-Reihen einfügen
    for (final arrangement in seed.fixedRows) {
      final isEuro = _isEuroArrangement(arrangement);
      final needed = arrangement.palletCount;
      final available = isEuro ? remainingEuro : remainingIndustry;

      if (available < needed) {
        skippedLabels.add(arrangement.label);
        continue;
      }
      if (usedLength + arrangement.lengthCm > trailerLengthCm) {
        skippedLabels.add(arrangement.label);
        continue;
      }

      rows.add(LoadRow(
        index: rows.length,
        arrangement: arrangement,
        palletCount: needed,
        weight: 0,
      ));
      usedLength += arrangement.lengthCm;
      if (isEuro) {
        remainingEuro -= needed;
      } else {
        remainingIndustry -= needed;
      }
    }

    // Phase 2: Verbleibende Euro-Paletten auffüllen
    if (remainingEuro > 0) {
      if (optimizeAxleLoad && kgPerEuro > 0) {
        final best = _bestEuroPatternForWeight(
          totalPallets: remainingEuro,
          kgPerEuro: kgPerEuro,
          trailerLengthCm: trailerLengthCm,
          startOffsetCm: usedLength,
        );
        if (best != null) {
          usedLength =
              _buildEuroRows(rows, best.n3, best.n2, best.n1, usedLength);
        } else {
          usedLength = _addEuroPallets(
              rows, remainingEuro, rows.length, usedLength, trailerLengthCm);
        }
      } else if (optimizeAxleLoad) {
        final result = _addEuroPalletsExact(
            rows, remainingEuro, rows.length, usedLength, trailerLengthCm);
        if (result['fallback'] == true) {
          usedLength = _addEuroPallets(
              rows, remainingEuro, rows.length, usedLength, trailerLengthCm);
        } else {
          usedLength = result['usedLength'] as double;
        }
      } else {
        usedLength = _addEuroPallets(
            rows, remainingEuro, rows.length, usedLength, trailerLengthCm);
      }
    }

    final placedEuro = rows
        .where((r) => _isEuroArrangement(r.arrangement))
        .fold(0, (s, r) => s + r.palletCount);

    // Phase 3: Verbleibende Industrie-Paletten auffüllen
    if (remainingIndustry > 0) {
      usedLength = _addIndustryPallets(
          rows, remainingIndustry, rows.length, usedLength, trailerLengthCm);
    }

    final placedIndustry = rows
        .where((r) => !_isEuroArrangement(r.arrangement))
        .fold(0, (s, r) => s + r.palletCount);

    final reindexed = [
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(index: i),
    ];

    final seedWarning = skippedLabels.isNotEmpty;

    return LoadPlan(
      rows: reindexed,
      requestedEuroPallets: safeEuro,
      requestedIndustryPallets: safeIndustry,
      placedEuroPallets: placedEuro,
      placedIndustryPallets: placedIndustry,
      trailerType: trailerType,
      hasManualSeedWarning: seedWarning,
      manualSeedWarningText: seedWarning
          ? 'Folgende Seed-Reihen konnten nicht platziert werden: '
              '${skippedLabels.join(', ')}'
          : '',
    );
  }

  static bool _isEuroArrangement(RowArrangement a) =>
      a == RowArrangement.euroLongi3 ||
      a == RowArrangement.euroTransverse2 ||
      a == RowArrangement.euroTransverseSingle;

  /// Validiert, ob ein Ladeplan physikalisch möglich ist.
  static bool validateLayout(LoadPlan plan) {
    return !plan.isOverLimit;
  }
}
