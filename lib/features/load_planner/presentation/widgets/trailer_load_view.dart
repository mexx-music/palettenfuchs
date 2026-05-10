import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../logic/manual_pallet_service.dart';
import '../../models/load_plan.dart';
import '../../models/placed_pallet.dart';
import 'trailer_painter.dart';

class TrailerLoadView extends StatefulWidget {
  final LoadPlan loadPlan;
  final AppLanguage language;

  const TrailerLoadView({
    super.key,
    required this.loadPlan,
    required this.language,
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
            GestureDetector(
              onTap: _openOverlay,
              child: SizedBox(
                height: 250,
                child: CustomPaint(
                  painter: TrailerPainter(
                    loadPlan: widget.loadPlan,
                    emptyText:
                        AppStrings.get(widget.language, 'enter_pallets'),
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
      spacing: 8.0,
      runSpacing: 8.0,
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
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(12.0),
        color: color.withAlpha(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.0,
            height: 10.0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful overlay with palette selection (red border on tap).
// Layout mirrors TrailerLoadOverlay, extended with GestureDetector + state.
// ---------------------------------------------------------------------------
class _SelectableTrailerOverlay extends StatefulWidget {
  final LoadPlan loadPlan;
  final AppLanguage language;
  final ui.Image? epalImage;

  const _SelectableTrailerOverlay({
    required this.loadPlan,
    required this.language,
    this.epalImage,
  });

  @override
  State<_SelectableTrailerOverlay> createState() =>
      _SelectableTrailerOverlayState();
}

class _SelectableTrailerOverlayState extends State<_SelectableTrailerOverlay> {
  final Set<String> _selectedIds = {};
  late List<PlacedPallet> _pallets;

  @override
  void initState() {
    super.initState();
    _pallets = ManualPalletService.extractPlacedPallets(widget.loadPlan);
  }

  // LayoutBuilder liefert die exakte CustomPaint-Größe synchron –
  // kein GlobalKey-Null-Risiko, kein falscher Dialog-Kontext.
  Widget _buildTrailerArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final localPosition = details.localPosition;
            debugPrint('tap: $localPosition | pallets: ${_pallets.length}');
            if (_pallets.isNotEmpty) {
              final last = _pallets.last;
              final lastRect = ManualPalletService.calculatePalletScreenRect(
                pallet: last,
                loadPlan: widget.loadPlan,
                trailerWidth: size.width,
                trailerHeight: size.height,
              );
              debugPrint('last pallet: ${last.id} rect: $lastRect');
            }
            final pallet = ManualPalletService.findPalletAtPosition(
              position: localPosition,
              pallets: _pallets,
              loadPlan: widget.loadPlan,
              trailerWidth: size.width,
              trailerHeight: size.height,
            );
            debugPrint('hit: ${pallet?.id}');
            if (pallet == null) return;
            setState(() {
              if (_selectedIds.contains(pallet.id)) {
                _selectedIds.remove(pallet.id);
              } else {
                _selectedIds.add(pallet.id);
              }
            });
          },
          child: CustomPaint(
            painter: TrailerPainter(
              loadPlan: widget.loadPlan,
              emptyText: AppStrings.get(widget.language, 'enter_pallets'),
              epalImage: widget.epalImage,
              selectedPalletIds: _selectedIds,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

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
                    width: 48,
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
                            icon: const Icon(Icons.close),
                            tooltip: 'Schließen',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: scheme.outlineVariant),
                  // Centre: trailer graphic with selection.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _buildTrailerArea(),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.get(widget.language, 'trailer_enlarged'),
                        style: textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
                  child: _buildTrailerArea(),
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
