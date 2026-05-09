import 'package:flutter/material.dart';
import '../../models/load_plan.dart';
import '../../models/load_row.dart';
import '../../models/pallet_type.dart';

class TrailerLoadView extends StatelessWidget {
  final LoadPlan loadPlan;

  const TrailerLoadView({
    super.key,
    required this.loadPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sattelzug Draufsicht',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 250,
              child: CustomPaint(
                painter: TrailerPainter(loadPlan: loadPlan),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Innenmaße: ${loadPlan.trailerType.trailerWidthCm.toStringAsFixed(0)} cm × ${loadPlan.trailerType.trailerLengthCm.toStringAsFixed(0)} cm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class TrailerPainter extends CustomPainter {
  final LoadPlan loadPlan;

  const TrailerPainter({required this.loadPlan});

  static const double _padding = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final trailerLengthCm = loadPlan.trailerType.trailerLengthCm;
    final trailerWidthCm = loadPlan.trailerType.trailerWidthCm;

    final drawableWidth = size.width - 2 * _padding;
    final drawableHeight = size.height - 2 * _padding;

    final trailerRect = Rect.fromLTWH(
      _padding,
      _padding,
      drawableWidth,
      drawableHeight,
    );

    // Hintergrund
    canvas.drawRect(trailerRect, Paint()..color = Colors.lightBlue[100]!);

    if (loadPlan.rows.isEmpty) {
      _drawBorder(canvas, trailerRect);
      _drawEmptyState(canvas, size);
      return;
    }

    // Maßstab: X = Trailerlänge, Y = Trailerbreite
    final scaleX = drawableWidth / trailerLengthCm;
    final scaleY = drawableHeight / trailerWidthCm;

    // Clip auf Innenbereich – kein Pallet-Pixel kann herausragen
    canvas.save();
    canvas.clipRect(trailerRect);

    double xCm = 0;
    for (final row in loadPlan.rows) {
      _drawRow(
        canvas,
        row,
        xCm,
        trailerRect.left,
        trailerRect.top,
        scaleX,
        scaleY,
      );
      xCm += row.lengthCm;
    }

    // Mittellinie (zentriert in Trailerbreite)
    canvas.drawLine(
      Offset(trailerRect.left, trailerRect.top + drawableHeight / 2),
      Offset(trailerRect.right, trailerRect.top + drawableHeight / 2),
      Paint()
        ..color = Colors.grey[400]!
        ..strokeWidth = 0.5,
    );

    canvas.restore();

    // Rahmen zuletzt – liegt über den Paletten
    _drawBorder(canvas, trailerRect);
  }

  void _drawBorder(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.blueGrey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawRow(
    Canvas canvas,
    LoadRow row,
    double xCm,
    double trailerLeft,
    double trailerTop,
    double scaleX,
    double scaleY,
  ) {
    final color = _colorFor(row.arrangement);

    for (final p in _palletsFor(row.arrangement, xCm)) {
      // p = [xCm, yCm, wCm, hCm]
      final rect = Rect.fromLTWH(
        trailerLeft + p[0] * scaleX,
        trailerTop + p[1] * scaleY,
        p[2] * scaleX,
        p[3] * scaleY,
      );

      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.black45
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  /// Gibt je Palette [x, y, w, h] in cm zurück.
  /// x/y: Offset ab Trailer-Ursprung (0,0).
  /// w: Ausdehnung entlang Trailerlänge (X-Achse).
  /// h: Ausdehnung entlang Trailerbreite (Y-Achse).
  List<List<double>> _palletsFor(RowArrangement arrangement, double xCm) {
    switch (arrangement) {
      case RowArrangement.euroLongi3:
        // 3 Euro-Paletten längs: 120 × 80 cm, y = 0 / 80 / 160
        return [
          [xCm, 0, 120, 80],
          [xCm, 80, 120, 80],
          [xCm, 160, 120, 80],
        ];
      case RowArrangement.euroTransverse2:
        // 2 Euro-Paletten quer: 80 × 120 cm, y = 0 / 120
        return [
          [xCm, 0, 80, 120],
          [xCm, 120, 80, 120],
        ];
      case RowArrangement.euroTransverseSingle:
        // 1 Euro-Palette quer: 80 × 120 cm, zentriert y = 60
        return [
          [xCm, 60, 80, 120],
        ];
      case RowArrangement.industryLongi2:
        // 2 Industrie-Paletten längs: 120 × 100 cm, y = 20 / 120
        return [
          [xCm, 20, 120, 100],
          [xCm, 120, 120, 100],
        ];
      case RowArrangement.industrySingle:
        // 1 Industrie-Palette längs: 120 × 100 cm, zentriert y = 70
        return [
          [xCm, 70, 120, 100],
        ];
    }
  }

  Color _colorFor(RowArrangement arrangement) {
    switch (arrangement) {
      case RowArrangement.euroLongi3:
        return Colors.green[400]!;
      case RowArrangement.euroTransverse2:
        return Colors.blue[400]!;
      case RowArrangement.euroTransverseSingle:
        return Colors.blue[300]!;
      case RowArrangement.industryLongi2:
        return Colors.orange[400]!;
      case RowArrangement.industrySingle:
        return Colors.orange[300]!;
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Geben Sie Paletten ein',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(TrailerPainter oldDelegate) =>
      loadPlan != oldDelegate.loadPlan;
}
