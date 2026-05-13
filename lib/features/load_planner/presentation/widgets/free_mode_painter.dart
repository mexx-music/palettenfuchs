import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../models/load_plan.dart';
import '../../models/placed_pallet.dart';
import '../../models/pallet_type.dart';

/// Paints a free-mode pallet list (absolute cm coordinates per pallet).
/// Drop-in replacement for TrailerPainter in the sandbox overlay.
///
/// When [uniformScale] is true the painter uses a single px/cm factor for
/// both axes (BoxFit.contain equivalent), so every pallet is drawn with its
/// real physical proportions.  The trailer is centred inside the canvas.
/// When false (default) the old stretch-to-fill behaviour is preserved –
/// suitable for the small thumbnail view.
class FreeModePainter extends CustomPainter {
  final List<PlacedPallet> pallets;
  final LoadPlan loadPlan;
  final Set<String> selectedPalletIds;
  final ui.Image? epalImage;
  final String emptyText;
  final bool uniformScale;

  const FreeModePainter({
    required this.pallets,
    required this.loadPlan,
    this.selectedPalletIds = const {},
    this.epalImage,
    this.emptyText = '',
    this.uniformScale = false,
  });

  /// Padding between the canvas edge and the trailer border (px).
  static const double padding = 20.0;
  static const Color _epalStampColor = Color(0x69503214);

  // ---------------------------------------------------------------------------
  // Public geometry helper – called by the overlay to align its hit test.
  // ---------------------------------------------------------------------------

  /// Returns the uniform scale factor and the top-left origin of the trailer
  /// rectangle inside a canvas of [size].
  ///
  /// The trailer is scaled down uniformly to fit within the drawable area
  /// (canvas minus [padding] on every side) and then centred.
  static ({double scale, double offsetX, double offsetY}) computeTransform(
    Size size,
    double trailerLengthCm,
    double trailerWidthCm,
  ) {
    final drawableW = size.width - 2 * padding;
    final drawableH = size.height - 2 * padding;
    final scale =
        min(drawableW / trailerLengthCm, drawableH / trailerWidthCm);
    final offsetX = padding + (drawableW - scale * trailerLengthCm) / 2;
    final offsetY = padding + (drawableH - scale * trailerWidthCm) / 2;
    return (scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    final trailerLengthCm = loadPlan.trailerType.trailerLengthCm;
    final trailerWidthCm = loadPlan.trailerType.trailerWidthCm;

    final double sx, sy, originX, originY;

    if (uniformScale) {
      final t = computeTransform(size, trailerLengthCm, trailerWidthCm);
      sx = t.scale;
      sy = t.scale;
      originX = t.offsetX;
      originY = t.offsetY;
    } else {
      final drawableW = size.width - 2 * padding;
      final drawableH = size.height - 2 * padding;
      sx = drawableW / trailerLengthCm;
      sy = drawableH / trailerWidthCm;
      originX = padding;
      originY = padding;
    }

    final trailerPixelW = sx * trailerLengthCm;
    final trailerPixelH = sy * trailerWidthCm;
    final trailerRect =
        Rect.fromLTWH(originX, originY, trailerPixelW, trailerPixelH);

    canvas.drawRect(trailerRect, Paint()..color = Colors.lightBlue[100]!);

    if (pallets.isEmpty) {
      _drawBorder(canvas, trailerRect);
      _drawEmptyState(canvas, trailerRect);
      return;
    }

    canvas.save();
    canvas.clipRect(trailerRect);

    // Centre line (trailer mid-axis, running front-to-rear).
    canvas.drawLine(
      Offset(trailerRect.left, trailerRect.top + trailerPixelH / 2),
      Offset(trailerRect.right, trailerRect.top + trailerPixelH / 2),
      Paint()
        ..color = Colors.grey[400]!
        ..strokeWidth = 0.5,
    );

    for (final pallet in pallets) {
      if (!pallet.isFreeMode) continue;

      final rect = Rect.fromLTWH(
        originX + pallet.xCm! * sx,
        originY + pallet.yCm! * sy,
        pallet.widthCm! * sx,
        pallet.heightCm! * sy,
      );

      final color = _colorFor(pallet.arrangement);
      canvas.drawRect(
          rect, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black45
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);

      if (selectedPalletIds.contains(pallet.id)) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0x40FFFFFF)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5,
        );
      }

      final isEuro = pallet.arrangement == RowArrangement.euroLongi3 ||
          pallet.arrangement == RowArrangement.euroTransverse2 ||
          pallet.arrangement == RowArrangement.euroTransverseSingle;
      if (isEuro) _drawEpalStamp(canvas, rect);
    }

    canvas.restore();
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

  void _drawEmptyState(Canvas canvas, Rect trailerRect) {
    final tp = TextPainter(
      text: TextSpan(
        text: emptyText,
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: trailerRect.width);
    tp.paint(
      canvas,
      Offset(
        trailerRect.center.dx - tp.width / 2,
        trailerRect.center.dy - tp.height / 2,
      ),
    );
  }

  void _drawEpalStamp(Canvas canvas, Rect palletRect) {
    if (epalImage != null) {
      _drawEpalAsset(canvas, palletRect, epalImage!);
    } else {
      _drawEpalOval(canvas, palletRect);
    }
  }

  void _drawEpalAsset(Canvas canvas, Rect palletRect, ui.Image image) {
    if (palletRect.width < 12 || palletRect.height < 8) return;
    final stampW = (palletRect.width * 0.45).clamp(0.0, 38.0);
    final stampH = (palletRect.height * 0.26).clamp(0.0, 16.0);
    final destRect = Rect.fromCenter(
        center: palletRect.center, width: stampW, height: stampH);
    final srcRect = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(
      image,
      srcRect,
      destRect,
      Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0xE0000000),
          BlendMode.srcIn,
        ),
    );
  }

  void _drawEpalOval(Canvas canvas, Rect palletRect) {
    if (palletRect.width < 12 || palletRect.height < 8) return;
    final stampW = (palletRect.width * 0.45).clamp(0.0, 38.0);
    final stampH = (palletRect.height * 0.26).clamp(0.0, 16.0);
    final stampRect = Rect.fromCenter(
        center: palletRect.center, width: stampW, height: stampH);
    canvas.drawOval(
      stampRect,
      Paint()
        ..color = _epalStampColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    if (palletRect.width < 16 || palletRect.height < 10) return;
    final fontSize = (stampH * 0.52).clamp(4.0, 8.0);
    final tp = TextPainter(
      text: TextSpan(
        text: 'EPAL',
        style: TextStyle(
          color: _epalStampColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: stampW);
    tp.paint(
      canvas,
      Offset(
        palletRect.center.dx - tp.width / 2,
        palletRect.center.dy - tp.height / 2,
      ),
    );
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

  @override
  bool shouldRepaint(FreeModePainter oldDelegate) =>
      pallets != oldDelegate.pallets ||
      loadPlan != oldDelegate.loadPlan ||
      selectedPalletIds != oldDelegate.selectedPalletIds ||
      epalImage != oldDelegate.epalImage ||
      uniformScale != oldDelegate.uniformScale;
}
