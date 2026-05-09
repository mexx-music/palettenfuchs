import 'pallet_type.dart';

/// Eine Palettenreihe im Sattelzug
class LoadRow {
  final int index;
  final RowArrangement arrangement;
  final int palletCount; // Einzelne Paletten in dieser Reihe
  final double weight; // Gewicht pro Palette

  const LoadRow({
    required this.index,
    required this.arrangement,
    required this.palletCount,
    required this.weight,
  });

  /// Länge dieser Reihe in cm
  double get lengthCm => arrangement.lengthCm;

  /// Gesamtgewicht dieser Reihe
  double get totalWeight => weight * palletCount;

  LoadRow copyWith({
    int? index,
    RowArrangement? arrangement,
    int? palletCount,
    double? weight,
  }) {
    return LoadRow(
      index: index ?? this.index,
      arrangement: arrangement ?? this.arrangement,
      palletCount: palletCount ?? this.palletCount,
      weight: weight ?? this.weight,
    );
  }
}
