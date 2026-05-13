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
                            widget.language,
                            'enter_pallets',
                          ),
                          epalImage: _epalImage,
                        )
                      : TrailerPainter(
                          loadPlan: widget.loadPlan,
                          emptyText: AppStrings.get(
                            widget.language,
                            'enter_pallets',
                          ),
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
                Icon(
                  Icons.zoom_in,
                  size: 14,
                  color: scheme.onSurface.withAlpha(120),
                ),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

class _OverlayUndoSnapshot {
  final List<PlacedPallet> freePallets;
  final Set<String> selectedIds;

  const _OverlayUndoSnapshot({
    required this.freePallets,
    required this.selectedIds,
  });
}

class _SelectableTrailerOverlayState extends State<_SelectableTrailerOverlay> {
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

  final List<_OverlayUndoSnapshot> _undoHistory = [];

  // Stores the pallet hit in onTapDown; consumed by onTap/onPanStart or
  // discarded by onLongPress so the gesture paths stay independent.
  PlacedPallet? _pendingPallet;

  // Drag-and-Drop state (prepared — actual position change not yet implemented).
  Offset? _dragStartPosition;
  Offset? _dragCurrentPosition;
  Set<String> _draggedPalletIds = {};
  bool get _isDragging => _dragStartPosition != null;

  @override
  void initState() {
    super.initState();
    // Restore previously accepted state when the overlay is re-opened.
    _freePallets = widget.loadPlan.manualPallets != null
        ? List<PlacedPallet>.from(widget.loadPlan.manualPallets!)
        : ManualPalletService.extractFreePallets(widget.loadPlan);
    _originalPalletCount = _freePallets.length;
  }

  void _pushUndoSnapshot() {
    _undoHistory.add(
      _OverlayUndoSnapshot(
        freePallets: List<PlacedPallet>.from(_freePallets),
        selectedIds: Set<String>.from(_selectedIds),
      ),
    );
  }

  void _undoLastChange() {
    if (_undoHistory.isEmpty) return;
    final previous = _undoHistory.removeLast();
    setState(() {
      _freePallets = previous.freePallets;
      _selectedIds = previous.selectedIds;
      _selectionVersion++;
    });
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
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text(errorMsg ?? 'Ungültiger Plan.')));
      return;
    }
    // Safety: count must not have changed.
    if (_freePallets.length != _originalPalletCount) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Palettenanzahl darf nicht verändert werden.'),
        ),
      );
      return;
    }
    widget.onManualPalletsAccepted?.call(
      List<PlacedPallet>.unmodifiable(_freePallets),
    );
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(errorMsg)));
      return;
    }
    _pushUndoSnapshot();
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(errorMsg)));
      return;
    }
    _pushUndoSnapshot();
    setState(() {
      _freePallets = updated;
      _selectionVersion++;
    });
    onSuccess();
  }

  // ---- action menu (long-press bottom sheet) --------------------------------

  void _showActionMenu(BuildContext ctx) {
    if (_selectedIds.isEmpty) return;

    showModalBottomSheet<void>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: const BoxConstraints(maxHeight: 360),
      builder: (_) => StatefulBuilder(
        builder: (_, setSheetState) {
          final range = ManualPalletService.findSelectionRange(
            _freePallets,
            _selectedIds,
          );
          final canMoveForward = range.groupStart > 0;
          final canMoveBackward =
              range.groupEnd >= 0 && range.groupEnd < range.totalSlots - 1;
          final canRotate = _selectedIds.isNotEmpty;

          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _primaryActionButton(
                          icon: Icons.arrow_upward,
                          label: AppStrings.get(
                            widget.language,
                            'pallet_move_forward',
                          ),
                          enabled: canMoveForward,
                          onTap: () => _tryMoveGroup(
                            ctx,
                            forward: true,
                            onSuccess: () => setSheetState(() {}),
                          ),
                        ),
                        _primaryActionButton(
                          icon: Icons.refresh,
                          label: AppStrings.get(
                            widget.language,
                            'pallet_rotate',
                          ),
                          enabled: canRotate,
                          onTap: () =>
                              _tryRotateSmart(ctx, () => setSheetState(() {})),
                        ),
                        _primaryActionButton(
                          icon: Icons.arrow_downward,
                          label: AppStrings.get(
                            widget.language,
                            'pallet_move_backward',
                          ),
                          enabled: canMoveBackward,
                          onTap: () => _tryMoveGroup(
                            ctx,
                            forward: false,
                            onSuccess: () => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  indent: 24,
                  endIndent: 24,
                  color: Colors.grey[300],
                ),
                _dangerActionButton(
                  label: AppStrings.get(
                    widget.language,
                    'pallet_clear_selection',
                  ),
                  onTap: () {
                    _pushUndoSnapshot();
                    setState(() {
                      _selectedIds = {};
                      _selectionVersion++;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _primaryActionButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled ? colorScheme.primary : Colors.grey;

    return SizedBox(
      width: 112,
      height: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? colorScheme.primary.withAlpha(120)
                  : Colors.grey[300]!,
            ),
            color: enabled
                ? colorScheme.primaryContainer.withAlpha(90)
                : Colors.grey[100],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: foreground),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dangerActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    final danger = Colors.red.shade700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 21, color: danger),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- side panels ----------------------------------------------------------

  /// Collapsible help sheet for portrait/mobile mode.
  void _showHelpSheet(BuildContext ctx) {
    final hints = <(IconData, String)>[
      (Icons.touch_app_outlined, 'Tippen: Palette markieren'),
      (Icons.select_all, 'Mehrfachauswahl möglich'),
      (Icons.touch_app, 'Lange drücken: Aktionen öffnen'),
      (Icons.refresh, 'Drehen: Palette umstellen'),
      (Icons.check_circle_outline, 'Übernehmen: Korrektur speichern'),
    ];
    showModalBottomSheet<void>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Bedienhilfe',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              ...hints.map(
                (h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(h.$1, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(h.$2, style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Left help panel — shown in landscape/desktop next to the trailer.
  Widget _buildHelpPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hints = <(IconData, String)>[
      (Icons.touch_app_outlined, 'Tippen: Palette markieren'),
      (Icons.select_all, 'Mehrfachauswahl möglich'),
      (Icons.touch_app, 'Lange drücken: Aktionen öffnen'),
      (Icons.refresh, 'Drehen: Palette umstellen'),
      (Icons.check_circle_outline, 'Übernehmen: Korrektur speichern'),
    ];
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bedienhilfe',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withAlpha(160),
            ),
          ),
          const SizedBox(height: 10),
          ...hints.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      h.$1,
                      size: 14,
                      color: scheme.onSurface.withAlpha(130),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h.$2,
                      style: textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Right selection/action panel — shown in landscape/desktop next to the trailer.
  Widget _buildSelectionPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSelection = _selectedIds.isNotEmpty;

    Widget content;
    if (!hasSelection) {
      content = Text(
        'Palette antippen\num sie zu markieren.',
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withAlpha(120),
          height: 1.4,
        ),
      );
    } else {
      final range = ManualPalletService.findSelectionRange(
        _freePallets,
        _selectedIds,
      );
      final canForward = range.groupStart > 0;
      final canBackward =
          range.groupEnd >= 0 && range.groupEnd < range.totalSlots - 1;

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_selectedIds.length} Palette${_selectedIds.length > 1 ? 'n' : ''} markiert',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _sideActionButton(
            context,
            icon: Icons.arrow_upward,
            label: AppStrings.get(widget.language, 'pallet_move_forward'),
            enabled: canForward,
            onTap: () => _tryMoveGroup(context, forward: true, onSuccess: () {}),
          ),
          const SizedBox(height: 6),
          _sideActionButton(
            context,
            icon: Icons.refresh,
            label: AppStrings.get(widget.language, 'pallet_rotate'),
            enabled: true,
            onTap: () => _tryRotateSmart(context, () {}),
          ),
          const SizedBox(height: 6),
          _sideActionButton(
            context,
            icon: Icons.arrow_downward,
            label: AppStrings.get(widget.language, 'pallet_move_backward'),
            enabled: canBackward,
            onTap: () =>
                _tryMoveGroup(context, forward: false, onSuccess: () {}),
          ),
          const SizedBox(height: 14),
          _sideActionButton(
            context,
            icon: Icons.deselect,
            label: AppStrings.get(widget.language, 'pallet_clear_selection'),
            enabled: true,
            danger: true,
            onTap: () => setState(() {
              _selectedIds = {};
              _selectionVersion++;
            }),
          ),
        ],
      );
    }

    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auswahl',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withAlpha(160),
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _sideActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger
        ? Colors.red.shade700
        : (enabled ? scheme.primary : Colors.grey.shade400);
    final bg = enabled
        ? (danger
            ? Colors.red.withAlpha(18)
            : scheme.primaryContainer.withAlpha(60))
        : Colors.grey[100]!;
    final borderColor = enabled ? color.withAlpha(100) : Colors.grey[300]!;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
          color: bg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

        // Pre-compute the uniform-scale transform the painter uses so the
        // hit test stays pixel-accurate even when the trailer is centred.
        final t = FreeModePainter.computeTransform(size, trailerL, trailerW);
        final effectiveW = t.scale * trailerL + 2 * FreeModePainter.padding;
        final effectiveH = t.scale * trailerW + 2 * FreeModePainter.padding;

        // Shared hit-test helper: adjusts raw canvas position to the
        // coordinate space ManualPalletService expects (padding-relative origin).
        PlacedPallet? hitTest(Offset localPos) {
          final adjusted = Offset(
            localPos.dx - (t.offsetX - FreeModePainter.padding),
            localPos.dy - (t.offsetY - FreeModePainter.padding),
          );
          return ManualPalletService.findFreePalletAtPosition(
            position: adjusted,
            pallets: _freePallets,
            trailerLengthCm: trailerL,
            trailerWidthCm: trailerW,
            screenWidth: effectiveW,
            screenHeight: effectiveH,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // ---- tap: select / deselect -----------------------------------------
          onTapDown: (details) {
            _pendingPallet = hitTest(details.localPosition);
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
          // ---- long press: action menu ----------------------------------------
          onLongPress: () {
            _pendingPallet = null;
            if (_selectedIds.isEmpty) return;
            _showActionMenu(outerContext);
          },
          // ---- pan: drag-and-drop (state only — no position change yet) --------
          onPanStart: (details) {
            final pallet = _pendingPallet;
            _pendingPallet = null;
            if (pallet == null) return;
            setState(() {
              _dragStartPosition = details.localPosition;
              _dragCurrentPosition = details.localPosition;
              // Drag the whole selection if the hit pallet is part of it,
              // otherwise drag only the hit pallet.
              _draggedPalletIds = _selectedIds.contains(pallet.id)
                  ? Set<String>.from(_selectedIds)
                  : {pallet.id};
            });
          },
          onPanUpdate: (details) {
            if (!_isDragging) return;
            setState(() => _dragCurrentPosition = details.localPosition);
          },
          onPanEnd: (_) {
            if (!_isDragging) return;
            setState(() {
              _dragStartPosition = null;
              _dragCurrentPosition = null;
              _draggedPalletIds = {};
            });
          },
          onPanCancel: () {
            if (!_isDragging) return;
            setState(() {
              _dragStartPosition = null;
              _dragCurrentPosition = null;
              _draggedPalletIds = {};
            });
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
                draggedPalletIds: _draggedPalletIds,
                dragCurrentPosition: _dragCurrentPosition,
                uniformScale: true,
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
                  // Left strip → TOP in rotated view: title + help + actions.
                  SizedBox(
                    width: 56,
                    child: Column(
                      children: [
                        const Spacer(),
                        RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            AppStrings.get(widget.language, 'trailer_enlarged'),
                            style: textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        RotatedBox(
                          quarterTurns: 3,
                          child: IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Bedienhilfe',
                            onPressed: () => _showHelpSheet(context),
                          ),
                        ),
                        RotatedBox(
                          quarterTurns: 3,
                          child: IconButton(
                            icon: const Icon(Icons.undo, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: AppStrings.get(widget.language, 'undo'),
                            onPressed: _undoHistory.isEmpty
                                ? null
                                : _undoLastChange,
                          ),
                        ),
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
                  // Right strip → BOTTOM in rotated view: dimensions.
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

    // Desktop / tablet in landscape: centred, constrained dialog with side panels.
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
              // Top header bar.
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
                    OutlinedButton.icon(
                      onPressed: _undoHistory.isEmpty ? null : _undoLastChange,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text(AppStrings.get(widget.language, 'undo')),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () => _onAccept(context),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
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
              // Main area: help panel | trailer | selection panel.
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 150,
                      child: _buildHelpPanel(context),
                    ),
                    Container(width: 1, color: scheme.outlineVariant),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildTrailerArea(context),
                      ),
                    ),
                    Container(width: 1, color: scheme.outlineVariant),
                    SizedBox(
                      width: 150,
                      child: _buildSelectionPanel(context),
                    ),
                  ],
                ),
              ),
              // Bottom: trailer dimensions.
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
