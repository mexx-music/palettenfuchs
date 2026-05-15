import 'package:flutter/material.dart';
import '../models/load_plan.dart';
import '../models/load_row.dart';
import '../models/placed_pallet.dart';
import '../models/pallet_type.dart';

/// Service für manuelle Palettenplatzierung und Manipulation
class ManualPalletService {
  ManualPalletService._();

  // ---------------------------------------------------------------------------
  // Arrangement-mode helpers (used by the original engine path)
  // ---------------------------------------------------------------------------

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

  /// Wendet die Rotation tatsächlich an und gibt den neuen LoadPlan zurück.
  /// Gibt (originalPlan, Fehlermeldung) zurück, wenn Rotation nicht möglich.
  static (LoadPlan, String?) applyRotateRow(LoadPlan loadPlan, int rowIndex) {
    final (valid, errorMsg) = tryRotatePallet(loadPlan, rowIndex);
    if (!valid) {
      return (loadPlan, errorMsg ?? 'Drehen für diese Reihe noch nicht möglich.');
    }

    final currentRow = loadPlan.rows[rowIndex];
    final newArrangement = _rotateArrangement(currentRow.arrangement);
    if (newArrangement == null) {
      return (loadPlan, 'Drehen einzelner Paletten ist noch nicht möglich.');
    }

    // Guard: rotation must never create or remove pallets.
    // All current _rotateArrangement mappings change palletCount, so this
    // check blocks them all until a same-count rotation is modelled.
    if (newArrangement.palletCount != currentRow.arrangement.palletCount) {
      return (loadPlan, 'Drehen einzelner Paletten ist noch nicht möglich.');
    }

    final updated = List<LoadRow>.from(loadPlan.rows);
    updated[rowIndex] = currentRow.copyWith(
      arrangement: newArrangement,
      palletCount: newArrangement.palletCount,
    );
    return (loadPlan.copyWith(rows: updated), null);
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

  // ---------------------------------------------------------------------------
  // Free-mode helpers (sandbox overlay – does not touch LoadPlan rows)
  // ---------------------------------------------------------------------------

  /// Builds a free pallet list with absolute cm coordinates from a LoadPlan.
  /// These pallets are independent of the row/arrangement engine.
  static List<PlacedPallet> extractFreePallets(LoadPlan loadPlan) {
    final pallets = <PlacedPallet>[];
    double xOffset = 0;
    for (int rowIdx = 0; rowIdx < loadPlan.rows.length; rowIdx++) {
      final row = loadPlan.rows[rowIdx];
      final geomList = _palletsForArrangement(row.arrangement, xOffset);
      for (int palletIdx = 0; palletIdx < geomList.length; palletIdx++) {
        final g = geomList[palletIdx];
        pallets.add(PlacedPallet(
          id: '${rowIdx}_$palletIdx',
          rowIndex: rowIdx,
          palletIndexInRow: palletIdx,
          arrangement: row.arrangement,
          weight: row.weight,
          xCm: g[0],
          yCm: g[1],
          widthCm: g[2],
          heightCm: g[3],
        ));
      }
      xOffset += row.lengthCm;
    }
    return pallets;
  }

  static List<List<double>> _palletsForArrangement(
      RowArrangement arrangement, double xCm) {
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

  /// Screen rect for a free-mode pallet using its absolute cm coordinates.
  static Rect calculateFreeScreenRect({
    required PlacedPallet pallet,
    required double trailerLengthCm,
    required double trailerWidthCm,
    required double screenWidth,
    required double screenHeight,
  }) {
    const padding = 20.0;
    final scaleX = (screenWidth - 2 * padding) / trailerLengthCm;
    final scaleY = (screenHeight - 2 * padding) / trailerWidthCm;
    return Rect.fromLTWH(
      padding + pallet.xCm! * scaleX,
      padding + pallet.yCm! * scaleY,
      pallet.widthCm! * scaleX,
      pallet.heightCm! * scaleY,
    );
  }

  /// Hit test for the free-mode pallet list.
  static PlacedPallet? findFreePalletAtPosition({
    required Offset position,
    required List<PlacedPallet> pallets,
    required double trailerLengthCm,
    required double trailerWidthCm,
    required double screenWidth,
    required double screenHeight,
  }) {
    for (final pallet in pallets) {
      if (!pallet.isFreeMode) continue;
      final rect = calculateFreeScreenRect(
        pallet: pallet,
        trailerLengthCm: trailerLengthCm,
        trailerWidthCm: trailerWidthCm,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      if (rect.contains(position)) return pallet;
    }
    return null;
  }

  /// Moves pallets in [movedIds] by [deltaCm] without any validation.
  /// Used for live drag preview — positions may temporarily exceed trailer bounds.
  static List<PlacedPallet> applyDragDelta(
    List<PlacedPallet> pallets,
    Set<String> movedIds,
    Offset deltaCm,
  ) {
    return pallets.map((p) {
      if (!movedIds.contains(p.id)) return p;
      return p.copyWith(
        xCm: p.xCm! + deltaCm.dx,
        yCm: p.yCm! + deltaCm.dy,
      );
    }).toList();
  }

  /// Applies [deltaCm] to [movedIds], validates the result (bounds + overlap)
  /// and returns the updated list.  On failure returns the original list
  /// together with an error message so the caller can roll back and show a
  /// SnackBar.
  static (List<PlacedPallet>, String?) movePalletsByDelta(
    List<PlacedPallet> pallets,
    Set<String> movedIds,
    Offset deltaCm,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    final moved = applyDragDelta(pallets, movedIds, deltaCm);
    final (valid, errorMsg) =
        validateFreePallets(moved, trailerLengthCm, trailerWidthCm);
    return valid ? (moved, null) : (pallets, errorMsg ?? 'Position ungültig.');
  }

  // ===========================================================================
  // Snap-to-slot insert — called on drag end instead of free positioning
  // ===========================================================================

  /// On drag-end: removes dragged pallets from their original slot(s),
  /// repairs the vacated source slot(s), determines the target insert index
  /// from [dropXCm] (left edge of the dragged group in trailer-cm at drop
  /// time), inserts the group there and repacks every slot gap-free from
  /// x = 0.
  ///
  /// [pallets]    — pre-drag snapshot (_dragStartPallets)
  /// [draggedIds] — IDs of the pallets being dragged
  /// [dropXCm]    — leftmost xCm of the dragged group at drop time
  ///                (determines insert ORDER only, not raw position)
  static (List<PlacedPallet>, String?) snapDragToSlot(
    List<PlacedPallet> pallets,
    Set<String> draggedIds,
    double dropXCm,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    // --- Debug: log pre-snap state ------------------------------------------
    for (final id in draggedIds) {
      final p = pallets.firstWhere((p) => p.id == id,
          orElse: () => throw StateError('snapDragToSlot: id $id not in pallets'));
      debugPrint('[Snap] BEFORE id=$id '
          'x=${p.xCm?.toStringAsFixed(1)} y=${p.yCm?.toStringAsFixed(1)} '
          'w=${p.widthCm?.toStringAsFixed(1)} h=${p.heightCm?.toStringAsFixed(1)} '
          'arr=${p.arrangement.name}');
    }
    debugPrint('[Snap] dropXCm=${dropXCm.toStringAsFixed(1)}');

    final dragged = pallets.where((p) => draggedIds.contains(p.id)).toList();
    if (dragged.isEmpty) return (pallets, 'Keine Palette ausgewählt.');

    final nonDragged =
        pallets.where((p) => !draggedIds.contains(p.id)).toList();

    // Repair source slot(s) after removing the dragged pallets.
    final origSlots = _groupIntoSlots(pallets);
    final repaired = _repairAfterRemoval(nonDragged, origSlots, draggedIds);

    // Prepare the dragged pallets as sub-slots ready for insertion.
    final dragSubSlots = _buildDragSubSlots(dragged, trailerWidthCm);

    // Find target index in the remaining (repaired) slots.
    final remainSlots = _groupIntoSlots(repaired);
    final clampedDropX = dropXCm.clamp(0.0, trailerLengthCm);
    final targetIdx = _targetInsertIdx(remainSlots, clampedDropX);
    debugPrint('[Snap] targetIndex=$targetIdx slotCountBefore=${remainSlots.length} '
        'slotWidths=[${remainSlots.map((s) => _slotWidth(s).toStringAsFixed(0)).join(', ')}] '
        'clampedDropX=${clampedDropX.toStringAsFixed(1)}');

    // Merge detection: single pallet dropped onto another single pallet of the
    // same type → combine both into a 2-pallet slot instead of inserting.
    //   euroTransverseSingle + euroTransverseSingle → euroTransverse2 (80×120)
    //   industrySingle       + industrySingle       → industryLongi2  (100×120)
    final mergeSlotIdx = _findMergeSlot(remainSlots, clampedDropX);
    final isSingleDrag = dragSubSlots.length == 1 && dragSubSlots[0].length == 1;
    final dragArr = isSingleDrag ? dragSubSlots[0][0].arrangement : null;
    final canMerge = isSingleDrag &&
        mergeSlotIdx >= 0 &&
        remainSlots[mergeSlotIdx].length == 1 &&
        _isMergeCompatible(dragArr!, remainSlots[mergeSlotIdx][0].arrangement);

    // Build the final slot order and assign gap-free xCm + canonical yCm.
    final List<List<PlacedPallet>> newSlots;
    if (canMerge) {
      final existing = remainSlots[mergeSlotIdx][0];
      final incoming = dragSubSlots[0][0];
      final bool isEuroMerge = dragArr == RowArrangement.euroTransverseSingle;
      final merged = [
        existing.copyWith(
          arrangement: isEuroMerge
              ? RowArrangement.euroTransverse2
              : RowArrangement.industryLongi2,
          widthCm: isEuroMerge ? 80.0 : 100.0,
          heightCm: 120.0,
          yCm: 0.0,
        ),
        incoming.copyWith(
          arrangement: isEuroMerge
              ? RowArrangement.euroTransverse2
              : RowArrangement.industryLongi2,
          widthCm: isEuroMerge ? 80.0 : 100.0,
          heightCm: 120.0,
          yCm: 120.0,
        ),
      ];
      newSlots = [
        ...remainSlots.sublist(0, mergeSlotIdx),
        merged,
        ...remainSlots.sublist(mergeSlotIdx + 1),
      ];
      debugPrint('[Snap] MERGE → ${isEuroMerge ? "2er-quer" : "industryLongi2"} '
          'at mergeSlotIdx=$mergeSlotIdx');
    } else {
      newSlots = [
        ...remainSlots.sublist(0, targetIdx),
        ...dragSubSlots,
        ...remainSlots.sublist(targetIdx),
      ];
    }
    final result = _repackExplicitSlots(newSlots);

    if (result.length != pallets.length) {
      debugPrint('[Snap] INVALID: count changed '
          '${pallets.length} → ${result.length}');
      return (pallets, 'Palettenanzahl hat sich verändert.');
    }
    final (valid, errorMsg) =
        validateFreePallets(result, trailerLengthCm, trailerWidthCm);

    if (!valid) {
      debugPrint('[Snap] INVALID: $errorMsg');
      return (pallets, errorMsg ?? 'Position ungültig.');
    }

    // --- Debug: log post-snap state -----------------------------------------
    for (final id in draggedIds) {
      final p = result.firstWhere((p) => p.id == id);
      debugPrint('[Snap] AFTER  id=$id '
          'x=${p.xCm?.toStringAsFixed(1)} y=${p.yCm?.toStringAsFixed(1)} '
          'w=${p.widthCm?.toStringAsFixed(1)} h=${p.heightCm?.toStringAsFixed(1)} '
          'arr=${p.arrangement.name} finalSlots=${_groupIntoSlots(result).length}');
    }
    return (result, null);
  }

  /// Repairs slot(s) that lost pallets to the drag gesture:
  ///
  /// • 3-pallet euro-longi loses ≥1 → remaining 2 become euro-quer 2
  ///   (80×120, y = 0 / 120); remaining 1 becomes euro-quer 1 (80×120, y=60).
  /// • 2-pallet euro-quer loses 1 → remaining 1 becomes euro-quer 1
  ///   (80×120, y=60).
  /// All other configurations are left unchanged.
  static List<PlacedPallet> _repairAfterRemoval(
    List<PlacedPallet> nonDragged,
    List<List<PlacedPallet>> origSlots,
    Set<String> draggedIds,
  ) {
    var result = List<PlacedPallet>.from(nonDragged);

    for (final slot in origSlots) {
      final hadDragged = slot.any((p) => draggedIds.contains(p.id));
      if (!hadDragged) continue;

      final kept = slot
          .where((p) => !draggedIds.contains(p.id))
          .toList()
        ..sort((a, b) => a.yCm!.compareTo(b.yCm!));
      if (kept.isEmpty) continue;

      final was3Longi = slot.length == 3 &&
          slot.every((p) => p.widthCm == 120.0 && p.heightCm == 80.0);
      final was2Quer = slot.length == 2 &&
          slot.every((p) => p.widthCm == 80.0 && p.heightCm == 120.0);
      final was2Industry = slot.length == 2 &&
          slot.every((p) => p.widthCm == 100.0 && p.heightCm == 120.0);

      if (was3Longi && kept.length == 2) {
        result = result.map((p) {
          final ki = kept.indexWhere((k) => k.id == p.id);
          if (ki < 0) return p;
          return p.copyWith(
            arrangement: RowArrangement.euroTransverse2,
            widthCm: 80.0,
            heightCm: 120.0,
            yCm: ki == 0 ? 0.0 : 120.0,
          );
        }).toList();
      } else if ((was3Longi && kept.length == 1) ||
          (was2Quer && kept.length == 1)) {
        result = result.map((p) {
          if (p.id != kept[0].id) return p;
          return p.copyWith(
            arrangement: RowArrangement.euroTransverseSingle,
            widthCm: 80.0,
            heightCm: 120.0,
            yCm: 60.0,
          );
        }).toList();
      } else if (was2Industry && kept.length == 1) {
        // Preserve the pallet's own dims (100×120 from the pair) and recentre.
        final keptH = kept[0].heightCm!;
        result = result.map((p) {
          if (p.id != kept[0].id) return p;
          return p.copyWith(
            arrangement: RowArrangement.industrySingle,
            yCm: (240.0 - keptH) / 2.0,
          );
        }).toList();
      }
    }
    return result;
  }

  /// Converts the dragged pallets into ready-to-insert sub-slots:
  ///
  /// • Single Euro pallet → euro-quer-single (80×120, y=60, xCm=0).
  /// • Single non-Euro pallet → original size, centred vertically, xCm=0.
  /// • Multiple pallets → relative xCm normalised to start at 0, grouped
  ///   into sub-slots (preserves the original slot structure).
  static List<List<PlacedPallet>> _buildDragSubSlots(
    List<PlacedPallet> dragged,
    double trailerWidthCm,
  ) {
    if (dragged.length == 1) {
      final p = dragged[0];
      final isEuro = p.arrangement == RowArrangement.euroLongi3 ||
          p.arrangement == RowArrangement.euroTransverse2 ||
          p.arrangement == RowArrangement.euroTransverseSingle;
      // Keep actual dims for all industry pallets (may be rotated or from a split).
      // Only reassign arrangement to industrySingle and recentre vertically.
      final isIndustry = p.arrangement == RowArrangement.industryLongi2 ||
          p.arrangement == RowArrangement.industrySingle;
      final newArr = isEuro
          ? RowArrangement.euroTransverseSingle
          : isIndustry
              ? RowArrangement.industrySingle
              : p.arrangement;
      final newW = isEuro ? 80.0 : p.widthCm!;
      final newH = isEuro ? 120.0 : p.heightCm!;
      final newY = isEuro ? 60.0 : (trailerWidthCm - newH) / 2.0;
      return [
        [
          p.copyWith(
            arrangement: newArr,
            widthCm: newW,
            heightCm: newH,
            yCm: newY,
            xCm: 0.0,
          ),
        ],
      ];
    }

    // Multiple pallets: shift all xCm so the leftmost starts at 0,
    // then group into sub-slots to preserve the original slot structure.
    final minX = dragged.fold(
      double.infinity,
      (v, p) => p.xCm! < v ? p.xCm! : v,
    );
    final normalised = dragged.map((p) => p.copyWith(xCm: p.xCm! - minX)).toList();
    return _groupIntoSlots(normalised);
  }

  /// Returns the index in [slots] before which the dragged group should be
  /// inserted, using slot start/end boundaries rather than midpoints alone:
  ///
  ///   • [dropXCm] before a slot's startX  → insert before that slot (in gap).
  ///   • [dropXCm] within a slot (startX…endX):
  ///       – left half  (< midX) → insert before the slot.
  ///       – right half (≥ midX) → insert after the slot.
  ///   • [dropXCm] past all slots → append at end.
  static int _targetInsertIdx(
    List<List<PlacedPallet>> slots,
    double dropXCm,
  ) {
    if (slots.isEmpty) return 0;
    for (int i = 0; i < slots.length; i++) {
      final startX = slots[i].first.xCm!;
      final w = _slotWidth(slots[i]);
      final endX = startX + w;
      final midX = startX + w / 2.0;
      if (dropXCm < startX) return i;             // in gap before this slot
      if (dropXCm < endX) {                       // within this slot
        return dropXCm < midX ? i : i + 1;
      }
      // dropXCm >= endX → continue to next slot
    }
    return slots.length;
  }

  /// Returns true when [a] and [b] are considered the same "single" pallet type
  /// for merge purposes.  Industry subtypes (industrySingle / industryLongi2)
  /// are treated as equivalent because existing state may carry either label.
  static bool _isMergeCompatible(RowArrangement a, RowArrangement b) {
    if (a == RowArrangement.euroTransverseSingle) {
      return b == RowArrangement.euroTransverseSingle;
    }
    final industryTypes = {
      RowArrangement.industrySingle,
      RowArrangement.industryLongi2,
    };
    return industryTypes.contains(a) && industryTypes.contains(b);
  }

  /// Returns the index of the slot whose [startX, endX) range contains
  /// [dropXCm], or -1 when the drop lands in a gap between slots.
  static int _findMergeSlot(List<List<PlacedPallet>> slots, double dropXCm) {
    for (int i = 0; i < slots.length; i++) {
      final startX = slots[i].first.xCm!;
      final endX = startX + _slotWidth(slots[i]);
      if (dropXCm >= startX && dropXCm < endX) return i;
    }
    return -1;
  }

  /// Assigns gap-free xCm values from x = 0 and canonical yCm values for
  /// each slot.  All pallets within the same slot get the same xCm; yCm is
  /// normalised by [_normalizeYPositions] so every pallet ends up at a clean,
  /// arrangement-correct position.
  static List<PlacedPallet> _repackExplicitSlots(
    List<List<PlacedPallet>> slots,
  ) {
    double x = 0;
    final result = <PlacedPallet>[];
    for (final slot in slots) {
      final w = _slotWidth(slot);
      final ys = _normalizeYPositions(slot); // canonical yCm per index
      for (int i = 0; i < slot.length; i++) {
        result.add(slot[i].copyWith(xCm: x, yCm: ys[i]));
      }
      x += w;
    }
    return result;
  }

  /// Returns canonical yCm values for every pallet in [slot], sorted by the
  /// pallets' original yCm order so relative vertical positioning is
  /// preserved.
  ///
  /// Canonical values per arrangement:
  ///   euroTransverseSingle (1 pallet) → [60]
  ///   euroTransverse2      (2 pallets) → [0, 120]
  ///   euroLongi3           (3 pallets) → [0, 80, 160]
  ///   industryLongi2       (2 pallets) → [0, 120]
  ///   industrySingle       (1 pallet)  → [70]
  ///
  /// Falls back to the pallets' current yCm if the slot's arrangement is
  /// mixed or the count doesn't match the canonical count.
  static List<double> _normalizeYPositions(List<PlacedPallet> slot) {
    if (slot.isEmpty) return [];

    // Sort slot indices by current yCm to determine vertical rank.
    final byY = List.generate(slot.length, (i) => i)
      ..sort((a, b) => slot[a].yCm!.compareTo(slot[b].yCm!));

    final result = List<double>.filled(slot.length, 0.0);

    // If arrangements are mixed in the slot, keep original yCm values.
    final arr0 = slot.first.arrangement;
    if (slot.any((p) => p.arrangement != arr0)) {
      for (int i = 0; i < slot.length; i++) {
        result[i] = slot[i].yCm!;
      }
      return result;
    }

    final canonical = switch (arr0) {
      RowArrangement.euroTransverseSingle => [60.0],
      RowArrangement.euroTransverse2 => [0.0, 120.0],
      RowArrangement.euroLongi3 => [0.0, 80.0, 160.0],
      RowArrangement.industryLongi2 => [0.0, 120.0],
      // Centre dynamically: works for canonical 120×100 (→ 70) and
      // rotated 100×120 (→ 60) without hardcoding a single value.
      RowArrangement.industrySingle => [
          (240.0 - slot.first.heightCm!) / 2.0
        ],
      // Mixed zone splits across two x-slots (industry+euro at x, second euro
      // at x+80); no single canonical Y vector applies — keep original yCm.
      RowArrangement.mixedEuro2Industry1 => <double>[],
    };

    if (canonical.length != slot.length) {
      // Count/arrangement mismatch — keep original yCm.
      for (int i = 0; i < slot.length; i++) {
        result[i] = slot[i].yCm!;
      }
      return result;
    }

    // Assign canonical value at each yCm-rank position.
    for (int rank = 0; rank < byY.length; rank++) {
      result[byY[rank]] = canonical[rank];
    }
    return result;
  }

  /// Rotates a free-mode pallet by swapping widthCm ↔ heightCm.
  static PlacedPallet rotateFreePallet(PlacedPallet pallet) {
    return pallet.copyWith(
      widthCm: pallet.heightCm,
      heightCm: pallet.widthCm,
    );
  }

  /// Validates that all free-mode pallets are within trailer bounds
  /// and do not overlap each other.
  static (bool, String?) validateFreePallets(
    List<PlacedPallet> pallets,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    final rects = <Rect>[];
    for (final p in pallets) {
      if (!p.isFreeMode) continue;
      if (p.xCm! < -0.01 ||
          p.yCm! < -0.01 ||
          p.xCm! + p.widthCm! > trailerLengthCm + 0.01 ||
          p.yCm! + p.heightCm! > trailerWidthCm + 0.01) {
        return (false, 'Palette liegt außerhalb des Trailers.');
      }
      final rect = Rect.fromLTWH(p.xCm!, p.yCm!, p.widthCm!, p.heightCm!);
      for (final other in rects) {
        // Deflate by 0.5 cm so touching edges are allowed; overlaps are caught.
        if (rect.deflate(0.5).overlaps(other.deflate(0.5))) {
          return (false, 'Paletten überschneiden sich.');
        }
      }
      rects.add(rect);
    }
    return (true, null);
  }

  // ---- slot-based move -------------------------------------------------------

  // Pallets with xCm within this tolerance (cm) are considered the same slot.
  static const double _slotTolerance = 1.0;

  // Effective width of a slot = max widthCm across all its pallets
  // (individual pallets may differ after rotation).
  static double _slotWidth(List<PlacedPallet> slot) {
    var w = 0.0;
    for (final p in slot) {
      if (p.widthCm! > w) w = p.widthCm!;
    }
    return w;
  }

  // Groups free-mode pallets into positional slots sorted front-to-back.
  // Pallets whose xCm values are within _slotTolerance of a slot's first
  // pallet are placed in that slot.
  static List<List<PlacedPallet>> _groupIntoSlots(
      List<PlacedPallet> pallets) {
    final sorted = pallets.where((p) => p.isFreeMode).toList()
      ..sort((a, b) {
        final cx = a.xCm!.compareTo(b.xCm!);
        return cx != 0 ? cx : a.yCm!.compareTo(b.yCm!);
      });

    final slots = <List<PlacedPallet>>[];
    for (final p in sorted) {
      if (slots.isEmpty ||
          (p.xCm! - slots.last.first.xCm!).abs() > _slotTolerance) {
        slots.add([p]);
      } else {
        slots.last.add(p);
      }
    }
    return slots;
  }

  /// Returns the slot index that contains the selected pallets and the total
  /// slot count. Returns slotIdx = -1 when the selection spans multiple slots
  /// or contains no free-mode pallets.
  static ({int slotIdx, int totalSlots}) findSelectedSlot(
    List<PlacedPallet> pallets,
    Set<String> selectedIds,
  ) {
    final slots = _groupIntoSlots(pallets);
    int? found;
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].any((p) => selectedIds.contains(p.id))) {
        if (found != null) return (slotIdx: -1, totalSlots: slots.length);
        found = i;
      }
    }
    return (slotIdx: found ?? -1, totalSlots: slots.length);
  }

  /// Returns the index range [groupStart, groupEnd] of all slots that contain
  /// at least one selected pallet, plus the total slot count.
  /// groupStart = groupEnd = -1 when nothing is selected.
  static ({int groupStart, int groupEnd, int totalSlots}) findSelectionRange(
    List<PlacedPallet> pallets,
    Set<String> selectedIds,
  ) {
    final slots = _groupIntoSlots(pallets);
    int? minIdx;
    int? maxIdx;
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].any((p) => selectedIds.contains(p.id))) {
        minIdx ??= i;
        maxIdx = i;
      }
    }
    return (
      groupStart: minIdx ?? -1,
      groupEnd: maxIdx ?? -1,
      totalSlots: slots.length,
    );
  }

  // Reassigns xCm for every free-mode pallet so all slots are tightly packed
  // starting at x = 0.  Used after splits that change slot count or width.
  static List<PlacedPallet> _repackSlots(List<PlacedPallet> pallets) {
    final slots = _groupIntoSlots(pallets);
    double x = 0;
    final result = <PlacedPallet>[];
    for (final slot in slots) {
      final w = _slotWidth(slot);
      for (final p in slot) {
        result.add(p.copyWith(xCm: x));
      }
      x += w;
    }
    return result;
  }

  // Case A helper: splits a 3-pallet euro-longi slot into 2er-quer + 1er-quer.
  static (List<PlacedPallet>, String?) _extractFromLongi3(
    List<PlacedPallet> pallets,
    PlacedPallet selected,
    List<PlacedPallet> slot,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    final others = slot.where((p) => p.id != selected.id).toList()
      ..sort((a, b) => a.yCm!.compareTo(b.yCm!));

    final xSlot = slot.first.xCm!;

    // Remaining 2 → 2er-quer at original slot xCm.
    final r0 = others[0].copyWith(
      arrangement: RowArrangement.euroTransverse2,
      widthCm: 80.0,
      heightCm: 120.0,
      yCm: 0.0,
      xCm: xSlot,
    );
    final r1 = others[1].copyWith(
      arrangement: RowArrangement.euroTransverse2,
      widthCm: 80.0,
      heightCm: 120.0,
      yCm: 120.0,
      xCm: xSlot,
    );

    // Extracted pallet → 1er-quer.  Offset by 2× tolerance so _groupIntoSlots
    // places it in its own slot directly after the 2er; _repackSlots then
    // assigns a clean gap-free xCm to both new slots.
    final extracted = selected.copyWith(
      arrangement: RowArrangement.euroTransverseSingle,
      widthCm: 80.0,
      heightCm: 120.0,
      yCm: 60.0,
      xCm: xSlot + 2 * _slotTolerance,
    );

    final interim = pallets.map((p) {
      if (p.id == others[0].id) return r0;
      if (p.id == others[1].id) return r1;
      if (p.id == selected.id) return extracted;
      return p;
    }).toList();

    final repacked = _repackSlots(interim);
    final (valid, errorMsg) =
        validateFreePallets(repacked, trailerLengthCm, trailerWidthCm);
    return valid ? (repacked, null) : (pallets, errorMsg);
  }

  // Case D helper: extracts one pallet from a 2-pallet euro-transverse slot.
  // The extracted pallet becomes a 1er-quer inserted one slot BEFORE the
  // remaining 1er-quer.  Both end up tightly packed after _repackSlots.
  static (List<PlacedPallet>, String?) _extractFromTransverse2(
    List<PlacedPallet> pallets,
    PlacedPallet selected,
    List<PlacedPallet> slot,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    final remaining = slot.firstWhere((p) => p.id != selected.id);
    final xSlot = slot.first.xCm!;

    // Remaining pallet → centered 1er-quer at original slot position.
    final r = remaining.copyWith(
      arrangement: RowArrangement.euroTransverseSingle,
      widthCm: 80.0,
      heightCm: 120.0,
      yCm: 60.0,
      xCm: xSlot,
    );

    // Extracted pallet → 1er-quer, offset by −2× tolerance so after sorting
    // it forms its own slot directly BEFORE the remaining; _repackSlots then
    // assigns gap-free positions to the whole list (including this
    // temporarily-negative xCm if the slot was at the front of the trailer).
    final extracted = selected.copyWith(
      arrangement: RowArrangement.euroTransverseSingle,
      widthCm: 80.0,
      heightCm: 120.0,
      yCm: 60.0,
      xCm: xSlot - 2 * _slotTolerance,
    );

    final interim = pallets.map((p) {
      if (p.id == remaining.id) return r;
      if (p.id == selected.id) return extracted;
      return p;
    }).toList();

    final repacked = _repackSlots(interim);
    final (valid, errorMsg) =
        validateFreePallets(repacked, trailerLengthCm, trailerWidthCm);
    return valid ? (repacked, null) : (pallets, errorMsg);
  }

  /// Smart rotate / Achslast-Korrektur for free-mode pallets.
  ///
  /// Case A – single pallet from a 3-pallet euro-longi slot (all 120×80 cm):
  ///   Extracts it as 1er-quer (widthCm 80, heightCm 120, yCm 60).
  ///   The remaining 2 become 2er-quer (yCm 0 / 120).
  ///   All slots are repacked with no gaps.
  ///
  /// Case D – single pallet from a 2-pallet euro-transverse slot (all 80×120 cm):
  ///   Extracts it as 1er-quer inserted one slot forward.
  ///   The remaining pallet becomes a centred 1er-quer (yCm 60).
  ///   All slots are repacked with no gaps.
  ///
  /// Case B – single pallet, any other configuration:
  ///   Simple widthCm ↔ heightCm swap; validated before applying.
  ///
  /// Case C – multiple pallets selected:
  ///   Returns error message without modifying anything.
  static (List<PlacedPallet>, String?) rotateFreePalletSmart(
    List<PlacedPallet> pallets,
    Set<String> selectedIds,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    if (selectedIds.length != 1) {
      return (pallets, 'Bitte nur eine Palette zum Drehen auswählen.');
    }

    final selId = selectedIds.first;
    final selPallet = pallets.firstWhere((p) => p.id == selId);

    final slots = _groupIntoSlots(pallets);
    final slotPallets = slots.firstWhere(
      (s) => s.any((p) => p.id == selId),
      orElse: () => [],
    );

    // Case A: 3-pallet euro-longi slot (all exactly 120 cm wide, 80 cm tall).
    if (slotPallets.length == 3 &&
        slotPallets.every((p) => p.widthCm == 120.0 && p.heightCm == 80.0)) {
      return _extractFromLongi3(
          pallets, selPallet, slotPallets, trailerLengthCm, trailerWidthCm);
    }

    // Case D: 2-pallet euro-transverse slot (all exactly 80 cm wide, 120 cm tall).
    if (slotPallets.length == 2 &&
        slotPallets.every((p) => p.widthCm == 80.0 && p.heightCm == 120.0)) {
      return _extractFromTransverse2(
          pallets, selPallet, slotPallets, trailerLengthCm, trailerWidthCm);
    }

    // Case B: simple dimension swap + vertical recentre.
    var rotated = rotateFreePallet(selPallet);
    // After swapping dimensions the pallet must be recentred so it stays in the
    // middle of the trailer width (new height may differ from old height).
    if (selPallet.arrangement == RowArrangement.industrySingle) {
      rotated = rotated.copyWith(
        yCm: (trailerWidthCm - rotated.heightCm!) / 2.0,
      );
    }
    final updated =
        pallets.map((p) => p.id == selId ? rotated : p).toList();
    final (valid, errorMsg) =
        validateFreePallets(updated, trailerLengthCm, trailerWidthCm);
    return valid
        ? (updated, null)
        : (pallets, errorMsg ?? 'Rotation nicht möglich.');
  }

  /// Moves the group of slots that contain selected pallets forward or backward
  /// by one slot, displacing the adjacent outside slot to the other side.
  ///
  /// Works for any selection that spans one or more consecutive/non-consecutive
  /// slots.  The displaced slot is the neighbour immediately outside the group's
  /// leading edge (forward) or trailing edge (backward).
  ///
  /// [forward] = true moves toward the front (lower xCm).
  static (List<PlacedPallet>, String?) moveFreePalletsGroup(
    List<PlacedPallet> pallets,
    Set<String> selectedIds, {
    required bool forward,
    required double trailerLengthCm,
    required double trailerWidthCm,
  }) {
    if (selectedIds.isEmpty) return (pallets, 'Keine Palette ausgewählt.');

    final slots = _groupIntoSlots(pallets);
    final range = findSelectionRange(pallets, selectedIds);
    final groupStart = range.groupStart;
    final groupEnd = range.groupEnd;

    if (groupStart < 0) return (pallets, 'Keine gültige Palette ausgewählt.');

    if (forward && groupStart == 0) {
      return (pallets, 'Palette ist bereits ganz vorne.');
    }
    if (!forward && groupEnd == slots.length - 1) {
      return (pallets, 'Palette ist bereits ganz hinten.');
    }

    // Build new slot order: displace the one adjacent slot to the opposite side.
    //
    // forward  (group moves left):  [..., group, displaced, ...]
    //   before: [0..groupStart-2] [groupStart-1] [groupStart..groupEnd] [groupEnd+1..]
    //   after:  [0..groupStart-2] [groupStart..groupEnd] [groupStart-1] [groupEnd+1..]
    //
    // backward (group moves right): [..., displaced, group, ...]
    //   before: [0..groupStart-1] [groupStart..groupEnd] [groupEnd+1] [groupEnd+2..]
    //   after:  [0..groupStart-1] [groupEnd+1] [groupStart..groupEnd] [groupEnd+2..]
    final List<List<PlacedPallet>> newSlots;
    if (forward) {
      newSlots = [
        ...slots.sublist(0, groupStart - 1),
        ...slots.sublist(groupStart, groupEnd + 1),
        slots[groupStart - 1],
        ...slots.sublist(groupEnd + 1),
      ];
    } else {
      newSlots = [
        ...slots.sublist(0, groupStart),
        slots[groupEnd + 1],
        ...slots.sublist(groupStart, groupEnd + 1),
        ...slots.sublist(groupEnd + 2),
      ];
    }

    // Compact all slots tightly from x = 0.
    double x = 0;
    final result = <PlacedPallet>[];
    for (final slot in newSlots) {
      final w = _slotWidth(slot);
      for (final p in slot) {
        result.add(p.copyWith(xCm: x));
      }
      x += w;
    }

    final (valid, errorMsg) =
        validateFreePallets(result, trailerLengthCm, trailerWidthCm);
    return valid ? (result, null) : (pallets, errorMsg);
  }

  /// Swaps the slot containing the selected pallets with the adjacent slot
  /// and repositions both so they stay tightly packed.
  ///
  /// [forward] = true moves toward the front (lower xCm).
  /// Returns (updatedPallets, null) on success or (originalPallets, errorMsg)
  /// on failure (rollback).
  static (List<PlacedPallet>, String?) moveFreePalletSlot(
    List<PlacedPallet> pallets,
    Set<String> selectedIds, {
    required bool forward,
    required double trailerLengthCm,
    required double trailerWidthCm,
  }) {
    if (selectedIds.isEmpty) {
      return (pallets, 'Keine Palette ausgewählt.');
    }

    final slots = _groupIntoSlots(pallets);

    // Find the single slot that contains all selected pallets.
    int? k;
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].any((p) => selectedIds.contains(p.id))) {
        if (k != null) {
          return (pallets, 'Bitte nur Paletten aus einer Reihe auswählen.');
        }
        k = i;
      }
    }
    if (k == null) return (pallets, 'Keine gültige Palette ausgewählt.');

    if (forward && k == 0) {
      return (pallets, 'Palette ist bereits ganz vorne.');
    }
    if (!forward && k == slots.length - 1) {
      return (pallets, 'Palette ist bereits ganz hinten.');
    }

    final slotSel = slots[k];
    final slotAdj = forward ? slots[k - 1] : slots[k + 1];

    final xSel = slotSel.first.xCm!;
    final xAdj = slotAdj.first.xCm!;
    final wSel = _slotWidth(slotSel);
    final wAdj = _slotWidth(slotAdj);

    // After the swap the two slots sit tightly next to each other, starting
    // at min(xSel, xAdj).  All other slots are untouched.
    //
    //  forward  → slotSel moves to xAdj,        slotAdj moves to xAdj + wSel
    //  backward → slotAdj moves to xSel,        slotSel moves to xSel + wAdj
    final double newXSel = forward ? xAdj : xSel + wAdj;
    final double newXAdj = forward ? xAdj + wSel : xSel;

    final selIds = {for (final p in slotSel) p.id};
    final adjIds = {for (final p in slotAdj) p.id};

    final updated = pallets.map((p) {
      if (selIds.contains(p.id)) return p.copyWith(xCm: newXSel);
      if (adjIds.contains(p.id)) return p.copyWith(xCm: newXAdj);
      return p;
    }).toList();

    final (valid, errorMsg) =
        validateFreePallets(updated, trailerLengthCm, trailerWidthCm);
    return valid ? (updated, null) : (pallets, errorMsg);
  }
}
