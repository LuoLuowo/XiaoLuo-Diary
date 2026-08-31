import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

DefaultStyles readingTextStyles(BuildContext context, double size) {
  final style = TextStyle(
    fontSize: size,
    height: 1.55,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: Theme.of(context).colorScheme.onSurface,
  );
  const horizontal = HorizontalSpacing(0, 0);
  const vertical = VerticalSpacing(0, 0);
  return DefaultStyles(
    paragraph: DefaultTextBlockStyle(
      style,
      horizontal,
      vertical,
      vertical,
      null,
    ),
    lists: DefaultListBlockStyle(
      style,
      horizontal,
      vertical,
      vertical,
      null,
      null,
    ),
    quote: DefaultTextBlockStyle(style, horizontal, vertical, vertical, null),
  );
}
