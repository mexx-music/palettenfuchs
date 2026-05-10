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
      // On a portrait phone: rotate the entire panel 90° clockwise so the
      // trailer appears in landscape – long axis across the full screen width.
      // The panel is sized for landscape (width = sh, height = sw) and
      // RotatedBox maps it back onto the portrait screen.
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: RotatedBox(
          quarterTurns: 1,
          child: SizedBox(
            width: sh,
            height: sw,
            child: _buildPanel(context),
          ),
        ),
      );
    }

    // Desktop / tablet already in landscape: centred, constrained dialog.
    final panelW = (sw - 48).clamp(300.0, 1100.0);
    final panelH = (sh - 80).clamp(300.0, 620.0);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: panelW,
        height: panelH,
        child: _buildPanel(context),
      ),
    );
  }

  /// Content panel shared by both orientations.
  /// Parent always provides a fixed height, so [Expanded] works for the graphic.
  Widget _buildPanel(BuildContext context) {
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
        // mainAxisSize defaults to max → fills the fixed-height SizedBox.
        children: [
          // ── Header ────────────────────────────────────────────────────
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

          // ── Trailer graphic – fills all remaining height ─────────────
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

          // ── Footer ────────────────────────────────────────────────────
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
