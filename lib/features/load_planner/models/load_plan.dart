import '../logic/trailer_constants.dart';
import 'load_row.dart';
import 'placed_pallet.dart';

/// Ladeplan für einen Sattelzug
class LoadPlan {
  final List<LoadRow> rows;
  final int requestedEuroPallets;
  final int requestedIndustryPallets;
  final int placedEuroPallets;
  final int placedIndustryPallets;
  final TrailerType trailerType;
  final bool hasManualSeedWarning;
  final String manualSeedWarningText;

  /// Free-mode pallets accepted from the overlay editor.
  /// When non-null, the trailer small view renders these instead of [rows].
  final List<PlacedPallet>? manualPallets;

  const LoadPlan({
    required this.rows,
    this.requestedEuroPallets = 0,
    this.requestedIndustryPallets = 0,
    this.placedEuroPallets = 0,
    this.placedIndustryPallets = 0,
    this.trailerType = TrailerType.standard,
    this.hasManualSeedWarning = false,
    this.manualSeedWarningText = '',
    this.manualPallets,
  });

  double get trailerMaxLengthCm => trailerType.trailerLengthCm;

  /// Theoretische Maximallast des Trailer-Typs
  double get maxPayload => trailerType.theoreticalMaxPayloadKg;

  /// Nicht platzierbare Paletten (Typgrenze oder Länge überschritten)
  int get unplacedEuroPallets =>
      (requestedEuroPallets - placedEuroPallets).clamp(0, requestedEuroPallets);

  int get unplacedIndustryPallets =>
      (requestedIndustryPallets - placedIndustryPallets)
          .clamp(0, requestedIndustryPallets);

  bool get hasUnplaced =>
      unplacedEuroPallets > 0 || unplacedIndustryPallets > 0;

  /// Gesamtgewicht aller Reihen (nur wenn Gewicht gesetzt)
  double get totalWeight => rows.fold(0, (sum, row) => sum + row.totalWeight);

  /// Anzahl aller platzierten Paletten
  int get totalPallets => rows.fold(0, (sum, row) => sum + row.palletCount);

  /// Gesamtlänge aller Reihen in cm
  double get usedLengthCm => rows.fold(0, (sum, row) => sum + row.lengthCm);

  /// Verbleibende Länge in cm
  double get remainingLengthCm =>
      (trailerMaxLengthCm - usedLengthCm).clamp(0, double.infinity);

  /// Überschreitet den Ladeplan das Längenlimit?
  bool get isOverLimit => usedLengthCm > trailerMaxLengthCm;

  /// [clearManualPallets] = true explicitly sets manualPallets to null
  /// (needed because null in [manualPallets] would otherwise mean "keep current").
  LoadPlan copyWith({
    List<LoadRow>? rows,
    int? requestedEuroPallets,
    int? requestedIndustryPallets,
    int? placedEuroPallets,
    int? placedIndustryPallets,
    TrailerType? trailerType,
    bool? hasManualSeedWarning,
    String? manualSeedWarningText,
    List<PlacedPallet>? manualPallets,
    bool clearManualPallets = false,
  }) {
    return LoadPlan(
      rows: rows ?? this.rows,
      requestedEuroPallets:
          requestedEuroPallets ?? this.requestedEuroPallets,
      requestedIndustryPallets:
          requestedIndustryPallets ?? this.requestedIndustryPallets,
      placedEuroPallets: placedEuroPallets ?? this.placedEuroPallets,
      placedIndustryPallets:
          placedIndustryPallets ?? this.placedIndustryPallets,
      trailerType: trailerType ?? this.trailerType,
      hasManualSeedWarning:
          hasManualSeedWarning ?? this.hasManualSeedWarning,
      manualSeedWarningText:
          manualSeedWarningText ?? this.manualSeedWarningText,
      manualPallets:
          clearManualPallets ? null : (manualPallets ?? this.manualPallets),
    );
  }

  /// Leerer Ladeplan
  static const LoadPlan empty = LoadPlan(rows: []);
}
