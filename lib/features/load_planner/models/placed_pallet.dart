import 'pallet_type.dart';

/// Repräsentiert eine einzelne positionierte Palette
class PlacedPallet {
  final String id;
  final int rowIndex;
  final int palletIndexInRow;
  final RowArrangement arrangement;
  final double weight;

  const PlacedPallet({
    required this.id,
    required this.rowIndex,
    required this.palletIndexInRow,
    required this.arrangement,
    this.weight = 0.0,
  });

  /// Geometrie: [x, y, width, height] in cm
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
          [xCm, 20, 120, 100],
          [xCm, 120, 120, 100],
        ];
      case RowArrangement.industrySingle:
        return [[xCm, 70, 120, 100]];
    }
  }

  PlacedPallet copyWith({
    String? id,
    int? rowIndex,
    int? palletIndexInRow,
    RowArrangement? arrangement,
    double? weight,
  }) {
    return PlacedPallet(
      id: id ?? this.id,
      rowIndex: rowIndex ?? this.rowIndex,
      palletIndexInRow: palletIndexInRow ?? this.palletIndexInRow,
      arrangement: arrangement ?? this.arrangement,
      weight: weight ?? this.weight,
    );
  }
}
