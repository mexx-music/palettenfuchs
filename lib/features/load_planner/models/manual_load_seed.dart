import 'pallet_type.dart';

/// Manuelle Startreihen für den Ladeplan.
/// Die Engine fügt diese Reihen zuerst ein und vervollständigt den Rest automatisch.
class ManualLoadSeed {
  final List<RowArrangement> fixedRows;
  final bool enabled;
  final Set<String> selectedPalletIds;
  final DateTime lastModified;

  const ManualLoadSeed({
    this.fixedRows = const [],
    this.enabled = false,
    this.selectedPalletIds = const {},
    required this.lastModified,
  });

  ManualLoadSeed copyWith({
    List<RowArrangement>? fixedRows,
    bool? enabled,
    Set<String>? selectedPalletIds,
    DateTime? lastModified,
  }) {
    return ManualLoadSeed(
      fixedRows: fixedRows ?? this.fixedRows,
      enabled: enabled ?? this.enabled,
      selectedPalletIds: selectedPalletIds ?? this.selectedPalletIds,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  /// Palette zur Auswahl hinzufügen/entfernen
  ManualLoadSeed togglePalletSelection(String palletId) {
    final updated = Set<String>.from(selectedPalletIds);
    if (updated.contains(palletId)) {
      updated.remove(palletId);
    } else {
      updated.add(palletId);
    }
    return copyWith(selectedPalletIds: updated, lastModified: DateTime.now());
  }

  /// Alle Auswahl löschen
  ManualLoadSeed clearSelection() {
    return copyWith(selectedPalletIds: {}, lastModified: DateTime.now());
  }

  static ManualLoadSeed empty() => ManualLoadSeed(lastModified: DateTime.now());
}


