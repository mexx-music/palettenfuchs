import 'load_row.dart';
import '../logic/trailer_constants.dart';

/// Gespeichertes Lademuster für Wiederverwendung
class SavedLoadPattern {
  final String id;
  final String name;
  final TrailerType trailerType;
  final int euroCount;
  final int industryCount;
  final double kgPerEuro;
  final double kgPerIndustry;
  final List<LoadRow> patternRows;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const SavedLoadPattern({
    required this.id,
    required this.name,
    required this.trailerType,
    required this.euroCount,
    required this.industryCount,
    required this.kgPerEuro,
    required this.kgPerIndustry,
    required this.patternRows,
    required this.createdAt,
    this.lastUsedAt,
  });

  SavedLoadPattern copyWith({
    String? id,
    String? name,
    TrailerType? trailerType,
    int? euroCount,
    int? industryCount,
    double? kgPerEuro,
    double? kgPerIndustry,
    List<LoadRow>? patternRows,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return SavedLoadPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      trailerType: trailerType ?? this.trailerType,
      euroCount: euroCount ?? this.euroCount,
      industryCount: industryCount ?? this.industryCount,
      kgPerEuro: kgPerEuro ?? this.kgPerEuro,
      kgPerIndustry: kgPerIndustry ?? this.kgPerIndustry,
      patternRows: patternRows ?? this.patternRows,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  /// Pattern als neuen Ladeplan laden
  SavedLoadPattern markAsUsed() {
    return copyWith(lastUsedAt: DateTime.now());
  }
}
