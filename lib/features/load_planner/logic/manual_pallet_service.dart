import 'package:flutter/material.dart';
import '../models/load_plan.dart';
import '../models/load_row.dart';
import '../models/placed_pallet.dart';
import '../models/pallet_type.dart';

/// Service für manuelle Palettenplatzierung und Manipulation
class ManualPalletService {
  ManualPalletService._();

  /// Generiert eindeutige Pallet-IDs für alle Paletten in einem LoadPlan
  static List<PlacedPallet> extractPlacedPallets(LoadPlan loadPlan) {
    final pallets = <PlacedPallet>[];
    for (int rowIdx = 0; rowIdx < loadPlan.rows.length; rowIdx++) {
      final row = loadPlan.rows[rowIdx];
      final arrangement = row.arrangement;
      final palletCountInRow = arrangement.palletCount;

      for (int palletIdx = 0; palletIdx < palletCountInRow; palletIdx++) {
        final palletId = '${rowIdx}_$palletIdx';
        pallets.add(PlacedPallet(
          id: palletId,
          rowIndex: rowIdx,
          palletIndexInRow: palletIdx,
          arrangement: arrangement,
          weight: row.weight,
        ));
      }
    }
    return pallets;
  }

  /// Berechnet die Bildschirm-Koordinaten einer Palette
  static Rect calculatePalletScreenRect({
    required PlacedPallet pallet,
    required LoadPlan loadPlan,
    required double trailerWidth,
    required double trailerHeight,
  }) {
    const padding = 20.0;
    final trailerLengthCm = loadPlan.trailerType.trailerLengthCm;
    final trailerWidthCm = loadPlan.trailerType.trailerWidthCm;

    final drawableWidth = trailerWidth - 2 * padding;
    final drawableHeight = trailerHeight - 2 * padding;

    final scaleX = drawableWidth / trailerLengthCm;
    final scaleY = drawableHeight / trailerWidthCm;

    // Accumulate the x-offset (in cm) for all rows before this pallet's row.
    // PlacedPallet.geometry always uses xCm = 0 (row-relative), so we must
    // add the running row offset here – exactly as TrailerPainter does when drawing.
    double xCm = 0;
    for (int i = 0; i < pallet.rowIndex; i++) {
      xCm += loadPlan.rows[i].lengthCm;
    }

    final geom = pallet.geometry; // [x_rel, y, w, h]; x_rel == 0 (row-relative)
    return Rect.fromLTWH(
      padding + (xCm + geom[0]) * scaleX,
      padding + geom[1] * scaleY,
      geom[2] * scaleX,
      geom[3] * scaleY,
    );
  }

  /// Findet die Palette an einer bestimmten Bildschirm-Position
  static PlacedPallet? findPalletAtPosition({
    required Offset position,
    required List<PlacedPallet> pallets,
    required LoadPlan loadPlan,
    required double trailerWidth,
    required double trailerHeight,
  }) {
    for (final pallet in pallets) {
      final rect = calculatePalletScreenRect(
        pallet: pallet,
        loadPlan: loadPlan,
        trailerWidth: trailerWidth,
        trailerHeight: trailerHeight,
      );
      if (rect.contains(position)) {
        return pallet;
      }
    }
    return null;
  }

  /// Rotiert eine Euro-Palette zwischen längs und quer
  /// Prüft, ob die neue Rotation passt
  static (bool success, String? errorMsg) tryRotatePallet(
    LoadPlan loadPlan,
    int rowIndex,
  ) {
    if (rowIndex < 0 || rowIndex >= loadPlan.rows.length) {
      return (false, 'Ungültige Reihe');
    }

    final currentRow = loadPlan.rows[rowIndex];

    // Nur Euro-Paletten dürfen gedreht werden
    if (!_isEuroRow(currentRow.arrangement)) {
      return (false, 'Industrie-Paletten können nicht gedreht werden');
    }

    // Bestimme neue Anordnung
    final newArrangement = _rotateArrangement(currentRow.arrangement);
    if (newArrangement == null) {
      return (false, 'Rotation nicht möglich');
    }

    // Prüfe, ob neue Länge passt
    final currentLength = currentRow.lengthCm;
    final newLength = newArrangement.lengthCm;
    final usedLength = loadPlan.usedLengthCm - currentLength;

    if (usedLength + newLength > loadPlan.trailerMaxLengthCm) {
      return (false, 'Palette passt nach Rotation nicht mehr in den Trailer');
    }

    return (true, null);
  }

  static bool _isEuroRow(RowArrangement arrangement) {
    return arrangement == RowArrangement.euroLongi3 ||
        arrangement == RowArrangement.euroTransverse2 ||
        arrangement == RowArrangement.euroTransverseSingle;
  }

  static RowArrangement? _rotateArrangement(RowArrangement arrangement) {
    switch (arrangement) {
      case RowArrangement.euroLongi3:
        return RowArrangement.euroTransverse2;
      case RowArrangement.euroTransverse2:
        return RowArrangement.euroLongi3;
      case RowArrangement.euroTransverseSingle:
        return RowArrangement.euroLongi3;
      default:
        return null;
    }
  }

  /// Verschiebt eine Reihe nach hinten
  static LoadPlan moveRowBackward(LoadPlan loadPlan, int rowIndex) {
    if (rowIndex >= loadPlan.rows.length - 1) return loadPlan;
    final updated = List<LoadRow>.from(loadPlan.rows);
    final temp = updated[rowIndex];
    updated[rowIndex] = updated[rowIndex + 1];
    updated[rowIndex + 1] = temp;
    return loadPlan.copyWith(rows: updated);
  }

  /// Verschiebt eine Reihe nach vorne
  static LoadPlan moveRowForward(LoadPlan loadPlan, int rowIndex) {
    if (rowIndex <= 0) return loadPlan;
    final updated = List<LoadRow>.from(loadPlan.rows);
    final temp = updated[rowIndex];
    updated[rowIndex] = updated[rowIndex - 1];
    updated[rowIndex - 1] = temp;
    return loadPlan.copyWith(rows: updated);
  }
}
