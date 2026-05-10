import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../models/load_plan.dart';
import 'trailer_painter.dart';

class TrailerLoadOverlay extends StatelessWidget {
  final LoadPlan loadPlan;
  final AppLanguage language;
  final ui.Image? epalImage;

  const TrailerLoadOverlay({
    super.key,
    required this.loadPlan,
    required this.language,
    this.epalImage,
  });

  static void show(
    BuildContext context, {
    required LoadPlan loadPlan,
    required AppLanguage language,
    ui.Image? epalImage,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => TrailerLoadOverlay(
        loadPlan: loadPlan,
        language: language,
        epalImage: epalImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sw = media.size.width;
    final sh = media.size.height;
    final isPortrait = sh > sw;

    if (isPortrait) {
      // Rotate entire panel 90° CW so the trailer appears in landscape.
      // Panel is built for landscape (width = sh, height = sw), then rotated.
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: RotatedBox(
          quarterTurns: 1,
          child: SizedBox(
            width: sh,
            height: sw,
            child: _buildRotatedPanel(context),
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
        child: _buildDesktopPanel(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Portrait-rotated panel
  //
  // Layout is a ROW (not Column) so that after the outer 90° CW rotation:
  //   LEFT strip  → appears at the TOP of the landscape view
  //   CENTER      → trailer graphic (Expanded)
  //   RIGHT strip → appears at the BOTTOM of the landscape view
  //
  // Text inside the strips is counter-rotated 90° CCW (quarterTurns: 3) so
  // that outer +90° CW + inner -90° CCW = 0° → text reads horizontally.
  // ---------------------------------------------------------------------------
  Widget _buildRotatedPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trailerL = loadPlan.trailerType.trailerLengthCm;
    final trailerW = loadPlan.trailerType.trailerWidthCm;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      child: Row(
        children: [
          // ── Left strip → TOP in rotated view ─────────────────────────
          SizedBox(
            width: 48,
            child: Column(
              children: [
                const Spacer(),
                // Title – counter-rotated so it reads left-to-right at top.
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    AppStrings.get(language, 'trailer_enlarged'),
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                // Close button at far end → top-right corner in rotated view.
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

          // ── Centre: trailer graphic ───────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CustomPaint(
                painter: TrailerPainter(
                  loadPlan: loadPlan,
                  emptyText: AppStrings.get(language, 'enter_pallets'),
                  epalImage: epalImage,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          Container(width: 1, color: scheme.outlineVariant),

          // ── Right strip → BOTTOM in rotated view ─────────────────────
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
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop / landscape panel – standard Column layout unchanged.
  // ---------------------------------------------------------------------------
  Widget _buildDesktopPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trailerL = loadPlan.trailerType.trailerLengthCm;
    final trailerW = loadPlan.trailerType.trailerWidthCm;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.get(language, 'trailer_enlarged'),
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
          // Graphic
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CustomPaint(
                painter: TrailerPainter(
                  loadPlan: loadPlan,
                  emptyText: AppStrings.get(language, 'enter_pallets'),
                  epalImage: epalImage,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Footer
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
    );
  }
}
