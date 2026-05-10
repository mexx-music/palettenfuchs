import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../logic/manual_pallet_service.dart';
import '../../models/load_plan.dart';
import '../../models/placed_pallet.dart';
import 'free_mode_painter.dart';
import 'trailer_painter.dart';

class TrailerLoadView extends StatefulWidget {
  final LoadPlan loadPlan;
  final AppLanguage language;

  /// Called when the user presses "Übernehmen" in the overlay and the
  /// free-mode pallets pass validation.  The parent should store the list
  /// and pass it back via [loadPlan.manualPallets] so the small view
  /// re-renders accordingly.
  final ValueChanged<List<PlacedPallet>>? onManualPalletsAccepted;

  const TrailerLoadView({
    super.key,
    required this.loadPlan,
    required this.language,
    this.onManualPalletsAccepted,
  });

  @override
  State<TrailerLoadView> createState() => _TrailerLoadViewState();
}

class _TrailerLoadViewState extends State<TrailerLoadView> {
  ui.Image? _epalImage;

  @override
  void initState() {
    super.initState();
    _loadEpalImage();
  }

  Future<void> _loadEpalImage() async {
    try {
      final data = await rootBundle.load('assets/icons/epal_stamp.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _epalImage = frame.image);
    } catch (_) {
      // Asset unavailable – painter falls back to drawn oval stamp.
    }
  }

  @override
  void dispose() {
    _epalImage?.dispose();
    super.dispose();
  }

  void _openOverlay() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _SelectableTrailerOverlay(
        loadPlan: widget.loadPlan,
        language: widget.language,
        epalImage: _epalImage,
        onManualPalletsAccepted: widget.onManualPalletsAccepted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get(widget.language, 'trailer_top_view'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            _buildLegend(context),
            const SizedBox(height: 16),

            // Small view – tap only opens the overlay.
            // Uses FreeModePainter when manualPallets have been accepted,
            // otherwise falls back to the row-based TrailerPainter.
            GestureDetector(
              onTap: _openOverlay,
              child: SizedBox(
                height: 250,
                child: CustomPaint(
                  painter: widget.loadPlan.manualPallets != null
                      ? FreeModePainter(
                          pallets: widget.loadPlan.manualPallets!,
                          loadPlan: widget.loadPlan,
                          emptyText: AppStrings.get(
                              widget.language, 'enter_pallets'),
                          epalImage: _epalImage,
                        )
                      : TrailerPainter(
                          loadPlan: widget.loadPlan,
                          emptyText: AppStrings.get(
                              widget.language, 'enter_pallets'),
                          epalImage: _epalImage,
                        ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Innenmaße: ${widget.loadPlan.trailerType.trailerWidthCm.toStringAsFixed(0)} cm'
                    ' × ${widget.loadPlan.trailerType.trailerLengthCm.toStringAsFixed(0)} cm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Icon(Icons.zoom_in,
                    size: 14, color: scheme.onSurface.withAlpha(120)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    AppStrings.get(widget.language, 'tap_to_enlarge'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withAlpha(120),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      children: [
        _legendChip(
          context,
          AppStrings.get(widget.language, 'legend_euro_transverse'),
          Colors.blue,
        ),
        _legendChip(
          context,
          AppStrings.get(widget.language, 'legend_euro_long'),
          Colors.green,
        ),
        _legendChip(
          context,
          AppStrings.get(widget.language, 'legend_industry'),
          Colors.orange,
        ),
      ],
    );
  }

  Widget _legendChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(10.0),
        color: color.withAlpha(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black87,
                  fontSize: 11.0,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Free-mode overlay: tap = select/deselect, long-press = action menu.
// Pallets are stored as a free List<PlacedPallet> with absolute cm coordinates.
// The original LoadPlan is never modified here (sandbox mode).
// ---------------------------------------------------------------------------
class _SelectableTrailerOverlay extends StatefulWidget {
  final LoadPlan loadPlan;
  final AppLanguage language;
  final ui.Image? epalImage;
  final ValueChanged<List<PlacedPallet>>? onManualPalletsAccepted;

  const _SelectableTrailerOverlay({
    required this.loadPlan,
    required this.language,
    this.epalImage,
    this.onManualPalletsAccepted,
  });

  @override
  State<_SelectableTrailerOverlay> createState() =>
      _SelectableTrailerOverlayState();
}

class _SelectableTrailerOverlayState
    extends State<_SelectableTrailerOverlay> {
  // Free-mode pallet list with absolute cm coordinates.
  // Built once from widget.loadPlan on init; only modified by overlay actions.
  late List<PlacedPallet> _freePallets;

  // Pallet count at init time — used to guard against accidental count changes.
  late int _originalPalletCount;

  // Non-final: replaced with a new Set on each change so FreeModePainter's
  // shouldRepaint (reference equality) correctly triggers.
  Set<String> _selectedIds = {};

  // Incremented on every selection change; drives the TweenAnimationBuilder key.
  int _selectionVersion = 0;

  // Stores the palette hit in onTapDown; consumed by onTap or discarded by
  // onLongPress so the two gesture paths stay independent.
  PlacedPallet? _pendingPallet;

  @override
  void initState() {
    super.initState();
    // Restore previously accepted state when the overlay is re-opened.
    _freePallets = widget.loadPlan.manualPallets != null
        ? List<PlacedPallet>.from(widget.loadPlan.manualPallets!)
        : ManualPalletService.extractFreePallets(widget.loadPlan);
    _originalPalletCount = _freePallets.length;
  }

  // ---- Übernehmen -----------------------------------------------------------

  void _onAccept(BuildContext ctx) {
    // Bounds + overlap check.
    final (valid, errorMsg) = ManualPalletService.validateFreePallets(
      _freePallets,
      widget.loadPlan.trailerType.trailerLengthCm,
      widget.loadPlan.trailerType.trailerWidthCm,
    );
    if (!valid) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(errorMsg ?? 'Ungültiger Plan.')));
      return;
    }
    // Safety: count must not have changed.
    if (_freePallets.length != _originalPalletCount) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Palettenanzahl darf nicht verändert werden.')));
      return;
    }
    widget.onManualPalletsAccepted?.call(List<PlacedPallet>.unmodifiable(_freePallets));
    Navigator.of(ctx).pop();
  }

  // ---- action helpers --------------------------------------------------------

  void _tryRotateSmart(BuildContext ctx, VoidCallback onSuccess) {
    if (_selectedIds.isEmpty) return;
    final (updated, errorMsg) = ManualPalletService.rotateFreePalletSmart(
      _freePallets,
      _selectedIds,
      widget.loadPlan.trailerType.trailerLengthCm,
      widget.loadPlan.trailerType.trailerWidthCm,
    );
    if (errorMsg != null) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(errorMsg)));
      return;
    }
    setState(() {
      _freePallets = updated;
      _selectionVersion++;
    });
    onSuccess();
  }

  void _tryMoveGroup(
    BuildContext ctx, {
    required bool forward,
    required VoidCallback onSuccess,
  }) {
    if (_selectedIds.isEmpty) return;
    final (updated, errorMsg) = ManualPalletService.moveFreePalletsGroup(
      _freePallets,
      _selectedIds,
      forward: forward,
      trailerLengthCm: widget.loadPlan.trailerType.trailerLengthCm,
      trailerWidthCm: widget.loadPlan.trailerType.trailerWidthCm,
    );
    if (errorMsg != null) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(errorMsg)));
      return;
    }
    setState(() {
      _freePallets = updated;
      _selectionVersion++;
    });
    onSuccess();
  }

  // ---- action menu ----------------------------------------------------------

  void _showActionMenu(BuildContext ctx) {
    if (_selectedIds.isEmpty) return;

    showModalBottomSheet<void>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      builder: (_) => StatefulBuilder(
        builder: (_, setSheetState) {
          // Re-derive group range on every sheet rebuild so buttons update
          // after each move.
          final range = ManualPalletService.findSelectionRange(
              _freePallets, _selectedIds);
          final canMoveForward = range.groupStart > 0;
          final canMoveBackward = range.groupEnd >= 0 &&
              range.groupEnd < range.totalSlots - 1;
          final canRotate = _selectedIds.isNotEmpty;

          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _actionTile(
                  icon: Icons.arrow_back,
                  label: AppStrings.get(
                      widget.language, 'pallet_move_forward'),
                  enabled: canMoveForward,
                  onTap: () => _tryMoveGroup(ctx,
                      forward: true,
                      onSuccess: () => setSheetState(() {})),
                ),
                _actionTile(
                  icon: Icons.arrow_forward,
                  label: AppStrings.get(
                      widget.language, 'pallet_move_backward'),
                  enabled: canMoveBackward,
                  onTap: () => _tryMoveGroup(ctx,
                      forward: false,
                      onSuccess: () => setSheetState(() {})),
                ),
                _actionTile(
                  icon: Icons.rotate_right,
                  label: AppStrings.get(widget.language, 'pallet_rotate'),
                  enabled: canRotate,
                  onTap: () =>
                      _tryRotateSmart(ctx, () => setSheetState(() {})),
                ),
                _actionTile(
                  icon: Icons.clear,
                  label: AppStrings.get(
                      widget.language, 'pallet_clear_selection'),
                  enabled: true,
                  onTap: () {
                    setState(() {
                      _selectedIds = {};
                      _selectionVersion++;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? null : Colors.grey;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  // ---- trailer area ---------------------------------------------------------

  Widget _buildTrailerArea(BuildContext outerContext) {
    final trailerL = widget.loadPlan.trailerType.trailerLengthCm;
    final trailerW = widget.loadPlan.trailerType.trailerWidthCm;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _pendingPallet = ManualPalletService.findFreePalletAtPosition(
              position: details.localPosition,
              pallets: _freePallets,
              trailerLengthCm: trailerL,
              trailerWidthCm: trailerW,
              screenWidth: size.width,
              screenHeight: size.height,
            );
          },
          onTap: () {
            final pallet = _pendingPallet;
            _pendingPallet = null;
            if (pallet == null) return;
            final next = Set<String>.from(_selectedIds);
            if (next.contains(pallet.id)) {
              next.remove(pallet.id);
            } else {
              next.add(pallet.id);
            }
            setState(() {
              _selectedIds = next;
              _selectionVersion++;
            });
          },
          onLongPress: () {
            _pendingPallet = null;
            if (_selectedIds.isEmpty) return;
            _showActionMenu(outerContext);
          },
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_selectionVersion),
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (_, opacity, child) =>
                Opacity(opacity: opacity, child: child!),
            child: CustomPaint(
              painter: FreeModePainter(
                pallets: _freePallets,
                loadPlan: widget.loadPlan,
                emptyText: AppStrings.get(widget.language, 'enter_pallets'),
                epalImage: widget.epalImage,
                selectedPalletIds: _selectedIds,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sw = media.size.width;
    final sh = media.size.height;
    final isPortrait = sh > sw;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trailerL = widget.loadPlan.trailerType.trailerLengthCm;
    final trailerW = widget.loadPlan.trailerType.trailerWidthCm;

    if (isPortrait) {
      // Rotate entire panel 90° CW so the trailer appears in landscape.
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: RotatedBox(
          quarterTurns: 1,
          child: SizedBox(
            width: sh,
            height: sw,
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              elevation: 6,
              child: Row(
                children: [
                  // Left strip → TOP in rotated view.
                  SizedBox(
                    width: 56,
                    child: Column(
                      children: [
                        const Spacer(),
                        RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            AppStrings.get(
                                widget.language, 'trailer_enlarged'),
                            style: textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        RotatedBox(
                          quarterTurns: 3,
                          child: IconButton(
                            icon: const Icon(Icons.check, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Übernehmen',
                            onPressed: () => _onAccept(context),
                          ),
                        ),
                        RotatedBox(
                          quarterTurns: 3,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Schließen',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: scheme.outlineVariant),
                  // Centre: trailer graphic with free-mode selection.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _buildTrailerArea(context),
                    ),
                  ),
                  Container(width: 1, color: scheme.outlineVariant),
                  // Right strip → BOTTOM in rotated view.
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          'Innenmaße: ${trailerW.toStringAsFixed(0)} cm'
                          ' × ${trailerL.toStringAsFixed(0)} cm',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withAlpha(153),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Desktop / tablet in landscape: centred, constrained dialog.
    final panelW = (sw - 48).clamp(300.0, 1100.0);
    final panelH = (sh - 80).clamp(300.0, 620.0);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: panelW,
        height: panelH,
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.get(widget.language, 'trailer_enlarged'),
                        style: textTheme.titleSmall,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _onAccept(context),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                      ),
                      child: const Text('Übernehmen'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Schließen',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildTrailerArea(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Innenmaße: ${trailerW.toStringAsFixed(0)} cm'
                    ' × ${trailerL.toStringAsFixed(0)} cm',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withAlpha(153),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
