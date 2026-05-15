import 'pallet_type.dart';

/// Repräsentiert eine einzelne positionierte Palette
class PlacedPallet {
  final String id;
  final int rowIndex;
  final int palletIndexInRow;
  final RowArrangement arrangement;
  final double weight;

  /// Absolute position in free-editing mode (null = arrangement-derived geometry).
  final double? xCm;
  final double? yCm;
  final double? widthCm;
  final double? heightCm;

  const PlacedPallet({
    required this.id,
    required this.rowIndex,
    required this.palletIndexInRow,
    required this.arrangement,
    this.weight = 0.0,
    this.xCm,
    this.yCm,
    this.widthCm,
    this.heightCm,
  });

  /// True when absolute cm coordinates are set (free-editing mode).
  bool get isFreeMode =>
      xCm != null && yCm != null && widthCm != null && heightCm != null;

  /// Geometrie: [x, y, width, height] in cm (x always 0, row-relative).
  /// Only meaningful in arrangement mode (isFreeMode == false).
  List<double> get geometry {
    final pallets = _palletsFor(arrangement, 0);
    if (palletIndexInRow >= pallets.length) return [0, 0, 0, 0];
    return pallets[palletIndexInRow];
  }

  List<List<double>> _palletsFor(RowArrangement arrangement, double xCm) {
    switch (arrangement) {
      case RowArrangement.euroLongi3:
        return [
          [xCm, 0, 120, 80],
          [xCm, 80, 120, 80],
          [xCm, 160, 120, 80],
        ];
      case RowArrangement.euroTransverse2:
        return [
          [xCm, 0, 80, 120],
          [xCm, 120, 80, 120],
        ];
      case RowArrangement.euroTransverseSingle:
        return [[xCm, 60, 80, 120]];
      case RowArrangement.industryLongi2:
        return [
          [xCm, 0, 100, 120],
          [xCm, 120, 100, 120],
        ];
      case RowArrangement.industrySingle:
        return [[xCm, 70, 120, 100]];
      case RowArrangement.mixedEuro2Industry1:
        return [
          [xCm, 0, 100, 120],
          [xCm, 120, 80, 120],
          [xCm + 80, 120, 80, 120],
        ];
    }
  }

  PlacedPallet copyWith({
    String? id,
    int? rowIndex,
    int? palletIndexInRow,
    RowArrangement? arrangement,
    double? weight,
    double? xCm,
    double? yCm,
    double? widthCm,
    double? heightCm,
  }) {
    return PlacedPallet(
      id: id ?? this.id,
      rowIndex: rowIndex ?? this.rowIndex,
      palletIndexInRow: palletIndexInRow ?? this.palletIndexInRow,
      arrangement: arrangement ?? this.arrangement,
      weight: weight ?? this.weight,
      xCm: xCm ?? this.xCm,
      yCm: yCm ?? this.yCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
    );
  }
}
