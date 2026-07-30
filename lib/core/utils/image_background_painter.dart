import 'package:flutter/material.dart';

import '../constants/image_background.dart';

class ImageBackgroundPainter extends CustomPainter {
  final ImageBackground type;

  const ImageBackgroundPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case ImageBackground.checkerboard:
        _paintCheckerboard(
          canvas,
          size,
          const Color(0xFFD4D4D4),
          const Color(0xFFA8A8A8),
        );
        break;
      case ImageBackground.darkCheckerboard:
        _paintCheckerboard(
          canvas,
          size,
          const Color(0xFF3A3A3A),
          const Color(0xFF555555),
        );
        break;
      case ImageBackground.solidWhite:
        _paintSolid(canvas, size, Colors.white);
        break;
      case ImageBackground.solidBlack:
        _paintSolid(canvas, size, Colors.black);
        break;
      case ImageBackground.solidLightGray:
        _paintSolid(canvas, size, const Color(0xFFE8E8E8));
        break;
      case ImageBackground.solidGray:
        _paintSolid(canvas, size, const Color(0xFF808080));
        break;
      case ImageBackground.solidDarkGray:
        _paintSolid(canvas, size, const Color(0xFF404040));
        break;
    }
  }

  void _paintSolid(Canvas canvas, Size size, Color color) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  void _paintCheckerboard(Canvas canvas, Size size, Color a, Color b) {
    const cell = 16.0;
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    final paint = Paint();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        paint.color = (x + y).isEven ? a : b;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ImageBackgroundPainter oldDelegate) =>
      oldDelegate.type != type;
}
