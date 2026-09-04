import 'package:flutter/material.dart';

import '../../bloc/receiver_state.dart';

class SocialFramingOverlay extends StatelessWidget {
  final SocialFramingMode mode;

  const SocialFramingOverlay({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == SocialFramingMode.none) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FramingPainter(mode: mode),
        );
      },
    );
  }
}

class _FramingPainter extends CustomPainter {
  final SocialFramingMode mode;

  _FramingPainter({required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case SocialFramingMode.none:
        break;

      case SocialFramingMode.reels9x16:
        _drawAspectRatioFrame(
          canvas,
          size,
          aspectRatio: 9.0 / 16.0,
          borderColor: const Color(0xFF00E5FF), // Cyber Cyan
          label: '9:16 REELS / SHORTS SAFE ZONE',
        );
        break;

      case SocialFramingMode.youtube16x9:
        _drawAspectRatioFrame(
          canvas,
          size,
          aspectRatio: 16.0 / 9.0,
          borderColor: const Color(0xFFFF2A6D), // Vibrant Neon Red
          label: '16:9 YOUTUBE / BROADCAST',
        );
        break;

      case SocialFramingMode.square1x1:
        _drawAspectRatioFrame(
          canvas,
          size,
          aspectRatio: 1.0,
          borderColor: const Color(0xFFD355FE), // Instagram Purple
          label: '1:1 SQUARE FEED CROP',
        );
        break;

      case SocialFramingMode.ruleOfThirds:
        _drawRuleOfThirds(canvas, size);
        break;
    }
  }

  void _drawAspectRatioFrame(
    Canvas canvas,
    Size size, {
    required double aspectRatio,
    required Color borderColor,
    required String label,
  }) {
    double frameW, frameH;

    // Calculate crop rectangle to fit within the viewport while matching target aspect ratio
    if (size.width / size.height > aspectRatio) {
      frameH = size.height;
      frameW = frameH * aspectRatio;
    } else {
      frameW = size.width;
      frameH = frameW / aspectRatio;
    }

    final left = (size.width - frameW) / 2.0;
    final top = (size.height - frameH) / 2.0;
    final frameRect = Rect.fromLTWH(left, top, frameW, frameH);

    // 1. Dim mask outside the frame
    final dimPaint = Paint()..color = const Color(0x99000000);

    // Path representing outside area (screen minus frameRect)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // 2. Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(frameRect, borderPaint);

    // 3. Corner tick marks
    final tickLength = frameW * 0.08;
    final tickPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-Left
    canvas.drawLine(
      Offset(left, top),
      Offset(left + tickLength, top),
      tickPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + tickLength),
      tickPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(left + frameW, top),
      Offset(left + frameW - tickLength, top),
      tickPaint,
    );
    canvas.drawLine(
      Offset(left + frameW, top),
      Offset(left + frameW, top + tickLength),
      tickPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(left, top + frameH),
      Offset(left + tickLength, top + frameH),
      tickPaint,
    );
    canvas.drawLine(
      Offset(left, top + frameH),
      Offset(left, top + frameH - tickLength),
      tickPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(left + frameW, top + frameH),
      Offset(left + frameW - tickLength, top + frameH),
      tickPaint,
    );
    canvas.drawLine(
      Offset(left + frameW, top + frameH),
      Offset(left + frameW, top + frameH - tickLength),
      tickPaint,
    );

    // 4. Center Crosshair
    final centerCrosshairPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(
      Offset(cx - 15, cy),
      Offset(cx + 15, cy),
      centerCrosshairPaint,
    );
    canvas.drawLine(
      Offset(cx, cy - 15),
      Offset(cx, cy + 15),
      centerCrosshairPaint,
    );

    // 5. Draw label pill
    _drawLabelBadge(canvas, label, borderColor, Offset(cx, top + 18));
  }

  void _drawRuleOfThirds(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final x1 = size.width / 3.0;
    final x2 = size.width * 2.0 / 3.0;
    final y1 = size.height / 3.0;
    final y2 = size.height * 2.0 / 3.0;

    // Vertical grid lines
    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), linePaint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), linePaint);

    // Horizontal grid lines
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), linePaint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), linePaint);

    // Draw Golden Focal Intersection points
    final dotPaint = Paint()..color = const Color(0xFFFFB300);
    final dotOuterPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final intersections = [
      Offset(x1, y1),
      Offset(x2, y1),
      Offset(x1, y2),
      Offset(x2, y2),
    ];

    for (final point in intersections) {
      canvas.drawCircle(point, 10, dotOuterPaint);
      canvas.drawCircle(point, 3.5, dotPaint);
    }

    // Center Crosshair
    final centerCrosshairPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(
      Offset(cx - 12, cy),
      Offset(cx + 12, cy),
      centerCrosshairPaint,
    );
    canvas.drawLine(
      Offset(cx, cy - 12),
      Offset(cx, cy + 12),
      centerCrosshairPaint,
    );

    _drawLabelBadge(
      canvas,
      'RULE OF THIRDS GRID',
      const Color(0xFFFFB300),
      Offset(cx, 40),
    );
  }

  void _drawLabelBadge(
    Canvas canvas,
    String text,
    Color color,
    Offset centerPos,
  ) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.0,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeW = textPainter.width + 16;
    const badgeH = 22.0;
    final badgeRect = Rect.fromCenter(
      center: centerPos,
      width: badgeW,
      height: badgeH,
    );

    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(11));
    final bgPaint = Paint()..color = const Color(0xCC000000);
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(
        centerPos.dx - textPainter.width / 2,
        centerPos.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FramingPainter oldDelegate) {
    return oldDelegate.mode != mode;
  }
}
