import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Keeps saved rich-text colors readable after an app theme changes.
InlineSpan readableRichTextSpan(
  BuildContext context,
  Node node,
  int nodeOffset,
  String text,
  TextStyle? style,
  GestureRecognizer? recognizer,
) {
  final scheme = Theme.of(context).colorScheme;
  final background = style?.backgroundColor ?? scheme.surface;
  final color = _ensureContrast(
    style?.color ?? scheme.onSurface,
    background,
    scheme.onSurface,
  );
  return TextSpan(
    text: text,
    style: style?.copyWith(color: color) ?? TextStyle(color: color),
    recognizer: recognizer,
    mouseCursor: recognizer == null ? null : SystemMouseCursors.click,
  );
}

Color _ensureContrast(Color color, Color background, Color fallback) {
  if (_contrast(color, background) >= 4.5) return color;
  final hsl = HSLColor.fromColor(color);
  final brighten = background.computeLuminance() < .5;
  for (var step = 1; step <= 100; step++) {
    final lightness =
        (brighten
                ? (hsl.lightness + step / 100).clamp(0.0, 1.0)
                : (hsl.lightness - step / 100).clamp(0.0, 1.0))
            .toDouble();
    final candidate = hsl.withLightness(lightness).toColor();
    if (_contrast(candidate, background) >= 4.5) return candidate;
  }
  return fallback;
}

double _contrast(Color first, Color second) {
  final firstLum = first.computeLuminance();
  final secondLum = second.computeLuminance();
  final light = firstLum > secondLum ? firstLum : secondLum;
  final dark = firstLum > secondLum ? secondLum : firstLum;
  return (light + .05) / (dark + .05);
}
