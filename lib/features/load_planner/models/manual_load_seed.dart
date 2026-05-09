import 'pallet_type.dart';

/// Manuelle Startreihen für den Ladeplan.
/// Die Engine fügt diese Reihen zuerst ein und vervollständigt den Rest automatisch.
class ManualLoadSeed {
  final List<RowArrangement> fixedRows;
  final bool enabled;

  const ManualLoadSeed({
    this.fixedRows = const [],
    this.enabled = false,
  });

  ManualLoadSeed copyWith({
    List<RowArrangement>? fixedRows,
    bool? enabled,
  }) {
    return ManualLoadSeed(
      fixedRows: fixedRows ?? this.fixedRows,
      enabled: enabled ?? this.enabled,
    );
  }

  static const ManualLoadSeed empty = ManualLoadSeed();
}
