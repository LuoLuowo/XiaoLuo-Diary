import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Kept behind the Navigator. It never intercepts gestures and never draws
/// over content, dialogs or black photo/video viewers.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    this.imagePath = '',
    this.strength = .18,
    this.decoration = 'paper',
  });
  final String imagePath;
  final double strength;
  final String decoration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surface),
            if (imagePath.isNotEmpty)
              Opacity(
                opacity: strength.clamp(.08, .28),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  cacheWidth: 1600,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: dark ? .18 : .38),
                    scheme.surface.withValues(alpha: .04),
                    scheme.tertiaryContainer.withValues(
                      alpha: dark ? .10 : .30,
                    ),
                  ],
                  stops: const [0, .52, 1],
                ),
              ),
            ),
            CustomPaint(
              painter: _DecorativePainter(
                color: scheme.primary.withValues(alpha: dark ? .18 : .11),
                style: decoration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativePainter extends CustomPainter {
  const _DecorativePainter({required this.color, required this.style});
  final Color color;
  final String style;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (style == 'stars') {
      final random = math.Random(41);
      final fill = Paint()..color = color;
      for (var i = 0; i < 42; i++) {
        final point = Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        );
        canvas.drawCircle(point, i % 3 == 0 ? 1.8 : .8, fill);
        if (i % 8 == 0) {
          canvas.drawLine(
            point - const Offset(4, 0),
            point + const Offset(4, 0),
            pen,
          );
          canvas.drawLine(
            point - const Offset(0, 4),
            point + const Offset(0, 4),
            pen,
          );
        }
      }
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width - 12, 70), radius: 72),
        .3,
        3.4,
        false,
        pen,
      );
    } else if (style == 'leaves') {
      for (final mirrored in [false, true]) {
        canvas.save();
        if (mirrored) {
          canvas.translate(size.width, size.height);
          canvas.rotate(math.pi);
        }
        canvas.drawPath(
          Path()
            ..moveTo(-15, 225)
            ..quadraticBezierTo(40, 115, 115, -5),
          pen,
        );
        for (var i = 0; i < 6; i++) {
          final y = 30.0 + i * 30;
          final x = 90.0 - i * 18;
          canvas.drawPath(
            Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(x - 42, y - 35, x - 38, y - 5)
              ..quadraticBezierTo(x - 23, y + 6, x, y),
            pen,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(x + 28, y - 8, x + 36, y - 36)
              ..quadraticBezierTo(x + 3, y - 33, x, y),
            pen,
          );
        }
        canvas.restore();
      }
    } else {
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(Offset(size.width + 36, 110), 92 + i * 23, pen);
      }
      final path = Path()
        ..moveTo(-30, size.height - 90)
        ..cubicTo(
          size.width * .20,
          size.height - 170,
          size.width * .30,
          size.height + 28,
          size.width * .72,
          size.height - 36,
        );
      canvas.drawPath(path, pen);
      canvas.drawPath(path.shift(const Offset(0, 16)), pen);
      final dot = Paint()..color = color;
      for (var i = 0; i < 12; i++) {
        canvas.drawCircle(
          Offset(18 + (i % 3) * 9, size.height * .55 + (i ~/ 3) * 9),
          1,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DecorativePainter oldDelegate) =>
      color != oldDelegate.color || style != oldDelegate.style;
}
