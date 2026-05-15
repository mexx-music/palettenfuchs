import '../models/load_plan.dart';
import '../models/load_row.dart';
import '../models/manual_load_seed.dart';
import '../models/pallet_type.dart';
import 'trailer_constants.dart';

/// Engine für Palettenreihen-Berechnung
class PalletLayoutEngine {
  static const int maxEuroPallets = 34;
  static const int maxIndustryPallets = 26;

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

    // Targeted special case: 29 Euro + 3 Industrie (reales Hecklayout).
    // Sequenz von vorn nach hinten: 8× longi3 (960) + 2× euroTransverse2 (160)
    // + 1× industryLongi2 (100) + 1× mixedEuro1Industry1Tail (100) = 1320 cm.
    // Passt in Standard (1360) und Frigo (1340). Heck-Mischzone hält Euro
    // links (80 cm tief, 20 cm Luft hinten) und Industrie rechts (100 cm bis
    // Türkante) auf gleicher Vorderkante.
    if (euroToPlace == 29 && safeIndustry == 3) {
      return _build29Euro3IndustryPlan(
        safeEuro: safeEuro,
        safeIndustry: safeIndustry,
        trailerType: trailerType,
      );
    }

    // Targeted special case: 28 Euro + 4 Industrie (Praxis-Hecklayout).
    // Sequenz von vorn nach hinten: 8× longi3 (960) + 2× industryLongi2 (200)
    // + 2× euroTransverse2 (160) = 1320 cm. Passt in Standard (1360 cm) und
    // Frigo (1340 cm). Hinten zwei 2er-Euro-quer-Reihen, davor zwei
    // Industrie-Doppelreihen, vorne die 3er-Längs-Reihen.
    if (euroToPlace == 28 && safeIndustry == 4) {
      return _build28Euro4IndustryPlan(
        safeEuro: safeEuro,
        safeIndustry: safeIndustry,
        trailerType: trailerType,
      );
    }

    final rows = <LoadRow>[];
    double usedLength = 0;

    // 1. Euro-Paletten verarbeiten
    if (optimizeAxleLoad && euroToPlace > 0) {
      if (kgPerEuro > 0) {
        // Gewichtsbasierte Optimierung: beste Sequenz nach Sattellast wählen
        final seq = _bestEuroSequenceForWeight(
          totalPallets: euroToPlace,
          kgPerEuro: kgPerEuro,
          trailerLengthCm: trailerLengthCm,
          startOffsetCm: 0,
        );
        if (seq != null) {
          for (final arr in seq) {
            rows.add(LoadRow(
                index: rows.length,
                arrangement: arr,
                palletCount: arr.palletCount,
                weight: 0));
            usedLength += arr.lengthCm;
          }
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
  // Frigo-Sonderfall 29 Euro + 3 Industrie
  // ---------------------------------------------------------------------------

  /// Hand-crafted plan for 29 Euro + 3 Industrie (real Frigo-Hecklayout).
  /// Engine row order (front → rear):
  ///   8× euroLongi3                  (960 cm, 24 Euro)
  ///   2× euroTransverse2             (160 cm,  4 Euro)
  ///   1× industryLongi2              (100 cm,  2 Industrie)
  ///   1× mixedEuro1Industry1Tail     (100 cm,  1 Euro + 1 Industrie)
  ///   = 1320 cm. Passt in Standard (1360 cm) und Frigo (1340 cm).
  static LoadPlan _build29Euro3IndustryPlan({
    required int safeEuro,
    required int safeIndustry,
    required TrailerType trailerType,
  }) {
    final rows = <LoadRow>[];
    for (int i = 0; i < 8; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroLongi3,
        palletCount: 3,
        weight: 0,
      ));
    }
    for (int i = 0; i < 2; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroTransverse2,
        palletCount: 2,
        weight: 0,
      ));
    }
    rows.add(LoadRow(
      index: rows.length,
      arrangement: RowArrangement.industryLongi2,
      palletCount: 2,
      weight: 0,
    ));
    rows.add(LoadRow(
      index: rows.length,
      arrangement: RowArrangement.mixedEuro1Industry1Tail,
      palletCount: 2,
      weight: 0,
    ));

    return LoadPlan(
      rows: rows,
      requestedEuroPallets: safeEuro,
      requestedIndustryPallets: safeIndustry,
      placedEuroPallets: 29,
      placedIndustryPallets: 3,
      trailerType: trailerType,
    );
  }

  /// Hand-crafted plan for 28 Euro + 4 Industrie (real Frigo-Hecklayout).
  /// Engine row order (front → rear):
  ///   8× euroLongi3      (960 cm, 24 Euro – front)
  ///   2× industryLongi2  (200 cm, 4 Industrie – middle)
  ///   2× euroTransverse2 (160 cm, 4 Euro – rear)
  ///   = 1320 cm gesamt. Passt in Standard (1360 cm) und Frigo (1340 cm).
  static LoadPlan _build28Euro4IndustryPlan({
    required int safeEuro,
    required int safeIndustry,
    required TrailerType trailerType,
  }) {
    final rows = <LoadRow>[];
    for (int i = 0; i < 8; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroLongi3,
        palletCount: 3,
        weight: 0,
      ));
    }
    for (int i = 0; i < 2; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.industryLongi2,
        palletCount: 2,
        weight: 0,
      ));
    }
    for (int i = 0; i < 2; i++) {
      rows.add(LoadRow(
        index: rows.length,
        arrangement: RowArrangement.euroTransverse2,
        palletCount: 2,
        weight: 0,
      ));
    }

    return LoadPlan(
      rows: rows,
      requestedEuroPallets: safeEuro,
      requestedIndustryPallets: safeIndustry,
      placedEuroPallets: 28,
      placedIndustryPallets: 4,
      trailerType: trailerType,
    );
  }

  // ---------------------------------------------------------------------------
  // Gewichtsbasierter Optimierer für Euro-Paletten
  // ---------------------------------------------------------------------------

  /// Findet die beste Ladereihenfolge für Euro-Paletten.
  /// Erzeugt Kandidaten-Sequenzen (mit 3er-Reihen zwischen Querreihen)
  /// und wählt nach Sattellast-Score.
  static List<RowArrangement>? _bestEuroSequenceForWeight({
    required int totalPallets,
    required int kgPerEuro,
    required double trailerLengthCm,
    required double startOffsetCm,
  }) {
    final maxN1 = _maxSinglesForWeight(kgPerEuro);
    // Extremlast (≥ 950 kg): bis zu 3 Singles in Folge erlaubt.
    final maxGroupSize = kgPerEuro >= 950 ? 3 : 2;

    List<RowArrangement>? best;
    double bestScore = double.infinity;

    for (int n1 = 0; n1 <= maxN1; n1++) {
      final remaining = totalPallets - n1;
      if (remaining <= 0) continue;

      for (final split in _splitEuroVariants(remaining)) {
        final rowLen = split.n3 * TrailerConstants.euroLengthCm +
            (split.n2 + n1) * TrailerConstants.euroWidthCm;
        if (startOffsetCm + rowLen > trailerLengthCm) continue;

        for (final seq in _generateEuroSequences(
            n1: n1, n2: split.n2, n3: split.n3,
            maxGroupSize: maxGroupSize)) {
          if (!_isValidHeavySequence(seq, kgPerEuro)) continue;
          final score = _scoreEuroSequence(
            seq: seq,
            kgPerEuro: kgPerEuro,
            trailerLengthCm: trailerLengthCm,
            startOffsetCm: startOffsetCm,
          );
          if (score < bestScore) {
            bestScore = score;
            best = seq;
          }
        }
      }
    }

    return best;
  }

  /// Maximale Einzelreihen nach Gewichtskategorie.
  /// ≥ 950 kg → 5 (extrem schwer, Last stark strecken)
  /// ≥ 900 kg → 3
  /// ≥ 700 kg → 2
  /// sonst    → 1
  static int _maxSinglesForWeight(int kgPerEuro) {
    if (kgPerEuro >= 950) return 5;
    if (kgPerEuro >= 900) return 3;
    if (kgPerEuro >= 700) return 2;
    return 1;
  }

  // ---------------------------------------------------------------------------
  // Debug-Hilfsmethode – formatiert Testfälle für die Konsole.
  // ---------------------------------------------------------------------------

  /// Berechnet einen Testfall und gibt einen formatierten Bericht zurück.
  /// Nur zur Entwicklungszeit / Verifikation gedacht.
  static String debugReport({
    required int euroPallets,
    required int kgPerEuro,
    TrailerType trailerType = TrailerType.standard,
  }) {
    final plan = calculateBasicPlan(
      euroPallets: euroPallets,
      industryPallets: 0,
      optimizeAxleLoad: true,
      trailerType: trailerType,
      kgPerEuro: kgPerEuro,
    );

    final seq = plan.rows;
    int c1 = 0, c2 = 0, c3 = 0;
    double rearLoad = 0;
    double pos = 0;
    final patternParts = <String>[];

    for (final row in seq) {
      rearLoad += row.palletCount *
          kgPerEuro *
          (pos + row.lengthCm / 2) /
          trailerType.trailerLengthCm;
      pos += row.lengthCm;
      switch (row.arrangement) {
        case RowArrangement.euroTransverseSingle:
          c1++;
          patternParts.add('1');
        case RowArrangement.euroTransverse2:
          c2++;
          patternParts.add('2');
        case RowArrangement.euroLongi3:
          c3++;
          patternParts.add('3');
        default:
          break;
      }
    }

    final totalWeight = euroPallets * kgPerEuro.toDouble();
    final frontLoad = (totalWeight - rearLoad).round();
    final usedCm = plan.usedLengthCm.round();
    final freeCm = plan.remainingLengthCm.round();
    final pattern = patternParts.join(' · ');

    return '=== $euroPallets Euro × $kgPerEuro kg'
        ' [${trailerType.label}] ===\n'
        'Muster:    $pattern\n'
        'Counts:    1er=$c1  2er=$c2  3er=$c3'
        '  (Σ=${c1 + c2 * 2 + c3 * 3} Pal.)\n'
        'Länge:     $usedCm cm genutzt · $freeCm cm frei\n'
        'Frontlast: ≈ $frontLoad kg\n';
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

  /// Zerlegungsvarianten von [remaining] — greedy zuerst, dann genau eine Alternante.
  /// Die Alternante ersetzt 2 Dreier durch 3 Zweier (6 Paletten konstant) und
  /// schafft genügend 2er-Puffer für die Schwerlast-Transitregel — ohne 3er-Reihen
  /// vollständig zu eliminieren.
  static List<({int n3, int n2})> _splitEuroVariants(int remaining) {
    final base = _splitEuro(remaining);
    if (base == null) return [];
    final variants = <({int n3, int n2})>[base];
    if (base.n3 >= 2) {
      variants.add((n3: base.n3 - 2, n2: base.n2 + 3));
    }
    return variants;
  }

  /// Schwerlast-Transitregel (kgPerEuro >= 900):
  /// Nach einer Einzelreihe (1er) darf nie direkt eine 3er-Längsreihe folgen —
  /// es muss zuerst eine 2er-Querreihe kommen.
  /// Verletzende Kandidaten werden verworfen, nicht nur bestraft.
  static bool _isValidHeavySequence(
      List<RowArrangement> seq, int kgPerEuro) {
    if (kgPerEuro < 900) return true;
    for (int i = 0; i < seq.length - 1; i++) {
      if (seq[i] == RowArrangement.euroTransverseSingle &&
          seq[i + 1] == RowArrangement.euroLongi3) {
        return false;
      }
    }
    return true;
  }

  /// Erzeugt diverse Kandidaten-Sequenzen für (n1, n2, n3).
  ///
  /// n1 Singles werden in Gruppen à 1–maxGroupSize zerlegt (→ _singleGroupings).
  /// Jede Gruppe trennt zwei Pool-Segmente aus abwechselnden 2er-/3er-Reihen.
  /// maxGroupSize=2 (normal), maxGroupSize=3 (Extremlast ≥ 950 kg).
  /// Größere Gruppen werden zuerst enumeriert, damit Front-loading-Muster
  /// auch bei 100-Kandidaten-Cap sicher enthalten sind.
  static List<List<RowArrangement>> _generateEuroSequences({
    required int n1,
    required int n2,
    required int n3,
    int maxGroupSize = 2,
  }) {
    const limit = 100;
    final results = <List<RowArrangement>>[];

    // Sortiertes Basismuster [1er…][2er…][3er…]: gültig wenn ≤ maxGroupSize Singles vorne.
    if (n1 <= maxGroupSize) {
      results.add([
        for (int i = 0; i < n1; i++) RowArrangement.euroTransverseSingle,
        for (int i = 0; i < n2; i++) RowArrangement.euroTransverse2,
        for (int i = 0; i < n3; i++) RowArrangement.euroLongi3,
      ]);
    }

    if (n1 == 0) {
      results.add(_buildAlternatingPool(n2, n3, start2er: true));
      if (n2 > 0 && n3 > 0) {
        results.add(_buildAlternatingPool(n2, n3, start2er: false));
      }
      return results;
    }

    // Größere Gruppen zuerst → Dreifach-/Doppel-Single-Muster bevorzugt.
    for (final grouping in _singleGroupings(n1, maxGroupSize: maxGroupSize)) {
      if (results.length >= limit) break;
      for (final start2er in [true, if (n2 > 0 && n3 > 0) false]) {
        if (results.length >= limit) break;
        final pool = _buildAlternatingPool(n2, n3, start2er: start2er);
        _enumSegGrouped(
          pool: pool,
          grouping: grouping,
          segIdx: 0,
          sizes: [],
          results: results,
          limit: limit,
        );
      }
    }

    return results;
  }

  /// Alle Zerlegungen von [n1] in Gruppen à 1…maxGroupSize, größere zuerst.
  /// Beispiel (max=2): 3 → [[2,1], [1,2], [1,1,1]]
  /// Beispiel (max=3): 3 → [[3], [2,1], [1,2], [1,1,1]]
  static List<List<int>> _singleGroupings(int n1, {int maxGroupSize = 2}) {
    final result = <List<int>>[];
    _enumGroupings(n1, [], result, maxGroupSize: maxGroupSize);
    return result;
  }

  static void _enumGroupings(
      int remaining, List<int> current, List<List<int>> result,
      {int maxGroupSize = 2}) {
    if (remaining == 0) {
      result.add(List.of(current));
      return;
    }
    for (int g = maxGroupSize; g >= 1; g--) {
      if (remaining >= g) {
        current.add(g);
        _enumGroupings(remaining - g, current, result, maxGroupSize: maxGroupSize);
        current.removeLast();
      }
    }
  }

  /// Abwechselnder Pool aus 2er- und 3er-Reihen.
  static List<RowArrangement> _buildAlternatingPool(
      int n2, int n3, {required bool start2er}) {
    final pool = <RowArrangement>[];
    int rem2 = n2, rem3 = n3;
    bool use2er = start2er;
    while (rem2 > 0 || rem3 > 0) {
      if (use2er && rem2 > 0) {
        pool.add(RowArrangement.euroTransverse2);
        rem2--;
      } else if (!use2er && rem3 > 0) {
        pool.add(RowArrangement.euroLongi3);
        rem3--;
      } else if (rem2 > 0) {
        pool.add(RowArrangement.euroTransverse2);
        rem2--;
      } else {
        pool.add(RowArrangement.euroLongi3);
        rem3--;
      }
      use2er = !use2er;
    }
    return pool;
  }

  /// Rekursive Segmentverteilung mit Gruppen-Trennern.
  /// Pool wird in (grouping.length + 1) Segmente aufgeteilt;
  /// zwischen Segment i und i+1 stehen grouping[i] Singles (1 oder 2).
  /// Regeln: erstes Segment ≥ 0, mittlere/letztes Segment ≥ 1 Reihe.
  static void _enumSegGrouped({
    required List<RowArrangement> pool,
    required List<int> grouping,
    required int segIdx,
    required List<int> sizes,
    required List<List<RowArrangement>> results,
    required int limit,
  }) {
    if (results.length >= limit) return;

    final totalSegs = grouping.length + 1;
    final used = sizes.fold(0, (a, b) => a + b);
    final remaining = pool.length - used;
    final segsLeft = totalSegs - segIdx;

    if (segsLeft == 1) {
      if (remaining <= 0) return; // Letztes Segment muss ≥ 1 Reihe haben.
      final seq = <RowArrangement>[];
      int idx = 0;
      for (int i = 0; i < totalSegs; i++) {
        final count = i < sizes.length ? sizes[i] : remaining;
        for (int j = 0; j < count; j++) {
          seq.add(pool[idx++]);
        }
        if (i < grouping.length) {
          for (int k = 0; k < grouping[i]; k++) {
            seq.add(RowArrangement.euroTransverseSingle);
          }
        }
      }
      results.add(seq);
      return;
    }

    final minSize = segIdx == 0 ? 0 : 1;
    final maxSize = remaining - (segsLeft - 1);

    for (int size = minSize; size <= maxSize; size++) {
      sizes.add(size);
      _enumSegGrouped(
        pool: pool,
        grouping: grouping,
        segIdx: segIdx + 1,
        sizes: sizes,
        results: results,
        limit: limit,
      );
      sizes.removeLast();
      if (results.length >= limit) return;
    }
  }

  /// Bewertet eine Sequenz (kleiner = besser).
  /// Primär: Sattellast (Hebelmodell).
  /// Sekundär: wenige Einzelreihen (+1 pro 1er).
  /// Tertiär:  2er-/3er-Wechsel maximieren (−0.5 pro Wechselpaar).
  static double _scoreEuroSequence({
    required List<RowArrangement> seq,
    required int kgPerEuro,
    required double trailerLengthCm,
    required double startOffsetCm,
  }) {
    double rearLoad = 0;
    double pos = startOffsetCm;
    int mixCount = 0;
    int n1 = 0;
    RowArrangement? prev;

    for (final arr in seq) {
      rearLoad += arr.palletCount *
          kgPerEuro *
          (pos + arr.lengthCm / 2) /
          trailerLengthCm;
      pos += arr.lengthCm;
      if (arr == RowArrangement.euroTransverseSingle) {
        n1++;
      } else if (prev != null &&
          prev != RowArrangement.euroTransverseSingle &&
          prev != arr) {
        mixCount++;
      }
      prev = arr;
    }

    final totalWeight =
        seq.fold(0, (s, r) => s + r.palletCount) * kgPerEuro.toDouble();
    return totalWeight - rearLoad + n1 * 1.0 - mixCount * 0.5;
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
        usedLength + TrailerConstants.industryWidthCm <= trailerLengthCm) {
      rows.add(LoadRow(
        index: rowIndex++,
        arrangement: RowArrangement.industryLongi2,
        palletCount: 2,
        weight: 0,
      ));
      usedLength += TrailerConstants.industryWidthCm;
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
        final seq = _bestEuroSequenceForWeight(
          totalPallets: remainingEuro,
          kgPerEuro: kgPerEuro,
          trailerLengthCm: trailerLengthCm,
          startOffsetCm: usedLength,
        );
        if (seq != null) {
          for (final arr in seq) {
            rows.add(LoadRow(
                index: rows.length,
                arrangement: arr,
                palletCount: arr.palletCount,
                weight: 0));
            usedLength += arr.lengthCm;
          }
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
