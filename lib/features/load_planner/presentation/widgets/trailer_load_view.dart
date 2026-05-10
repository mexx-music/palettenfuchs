import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../models/load_plan.dart';
import 'trailer_load_overlay.dart';
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
    TrailerLoadOverlay.show(
      context,
      loadPlan: widget.loadPlan,
      language: widget.language,
      epalImage: _epalImage,
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
            const SizedBox(height: 16),

            // Tappable trailer graphic
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

            // Dimensions + tap hint on the same row
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
                    size: 14,
                    color: scheme.onSurface.withAlpha(120)),
                const SizedBox(width: 3),
                Text(
                  AppStrings.get(widget.language, 'tap_to_enlarge'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withAlpha(120),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
