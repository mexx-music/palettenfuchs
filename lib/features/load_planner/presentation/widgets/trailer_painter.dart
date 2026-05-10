import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../models/load_plan.dart';
import '../../models/load_row.dart';
import '../../models/pallet_type.dart';

class TrailerPainter extends CustomPainter {
  final LoadPlan loadPlan;
  final String emptyText;
  final ui.Image? epalImage;

  const TrailerPainter({
    required this.loadPlan,
    this.emptyText = '',
    this.epalImage,
  });

  static const double _padding = 20.0;

  // Dark brown at ~41 % opacity – used for the fallback drawn oval stamp.
  static const Color _epalStampColor = Color(0x69503214);

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

    canvas.drawRect(trailerRect, Paint()..color = Colors.lightBlue[100]!);

    if (loadPlan.rows.isEmpty) {
      _drawBorder(canvas, trailerRect);
      _drawEmptyState(canvas, size);
      return;
    }

    final scaleX = drawableWidth / trailerLengthCm;
    final scaleY = drawableHeight / trailerWidthCm;

    canvas.save();
    canvas.clipRect(trailerRect);

    double xCm = 0;
    for (final row in loadPlan.rows) {
      _drawRow(canvas, row, xCm, trailerRect.left, trailerRect.top, scaleX,
          scaleY);
      xCm += row.lengthCm;
    }

    canvas.drawLine(
      Offset(trailerRect.left, trailerRect.top + drawableHeight / 2),
      Offset(trailerRect.right, trailerRect.top + drawableHeight / 2),
      Paint()
        ..color = Colors.grey[400]!
        ..strokeWidth = 0.5,
    );

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
    final isEuro = row.arrangement == RowArrangement.euroLongi3 ||
        row.arrangement == RowArrangement.euroTransverse2 ||
        row.arrangement == RowArrangement.euroTransverseSingle;

    for (final p in _palletsFor(row.arrangement, xCm)) {
      final rect = Rect.fromLTWH(
        trailerLeft + p[0] * scaleX,
        trailerTop + p[1] * scaleY,
        p[2] * scaleX,
        p[3] * scaleY,
      );

      canvas.drawRect(rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);
      canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black45
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);

      if (isEuro) _drawEpalStamp(canvas, rect);
    }
  }

  // ---------- EPAL stamp --------------------------------------------------

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
      center: palletRect.center,
      width: stampW,
      height: stampH,
    );
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
      center: palletRect.center,
      width: stampW,
      height: stampH,
    );

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

  // ---------- geometry helpers --------------------------------------------

  List<List<double>> _palletsFor(RowArrangement arrangement, double xCm) {
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
          [xCm, 20, 120, 100],
          [xCm, 120, 120, 100],
        ];
      case RowArrangement.industrySingle:
        return [[xCm, 70, 120, 100]];
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
    final tp = TextPainter(
      text: TextSpan(
        text: emptyText,
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        size.width / 2 - tp.width / 2,
        size.height / 2 - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(TrailerPainter oldDelegate) =>
      loadPlan != oldDelegate.loadPlan ||
      emptyText != oldDelegate.emptyText ||
      epalImage != oldDelegate.epalImage;
}
