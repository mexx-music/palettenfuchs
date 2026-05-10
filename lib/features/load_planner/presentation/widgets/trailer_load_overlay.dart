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
      barrierColor: Colors.black54,
      builder: (_) => TrailerLoadOverlay(
        loadPlan: loadPlan,
        language: language,
        epalImage: epalImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trailerL = loadPlan.trailerType.trailerLengthCm;
    final trailerW = loadPlan.trailerType.trailerWidthCm;
    final trailerRatio = trailerL / trailerW; // typically ~5.67

    return Dialog(
      // Minimal side margins so the graphic can be as wide as possible.
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        // Cap width on desktop/web at 1100 px.
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
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

            // ── Trailer graphic ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  // Ideal height for a perfectly proportional trailer view.
                  final ideal = availableWidth / trailerRatio;
                  // Clamp: never below 180 px (readable on phone),
                  //         never above 480 px (sensible on large screens).
                  final height = ideal.clamp(180.0, 480.0);

                  return SizedBox(
                    width: availableWidth,
                    height: height,
                    child: CustomPaint(
                      painter: TrailerPainter(
                        loadPlan: loadPlan,
                        emptyText:
                            AppStrings.get(language, 'enter_pallets'),
                        epalImage: epalImage,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),

            // ── Dimensions footer ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Innenmaße: ${trailerW.toStringAsFixed(0)} cm × '
                '${trailerL.toStringAsFixed(0)} cm',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withAlpha(153),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
