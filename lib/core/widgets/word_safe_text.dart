import 'package:flutter/material.dart';

/// Wrapping text that never breaks a word in the middle.
///
/// Flutter splits a word between letters when the word alone is wider than the
/// available width (e.g. "Uncategorized" beside a duration on a 320 px phone
/// at 1.5x font size: "Uncategoriz / ed"). This measures the longest word and,
/// only in that case, scales the text down just enough for it to fit. Normal
/// text keeps its size and wraps between words.
class WordSafeText extends StatelessWidget {
  const WordSafeText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle effective = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        TextScaler textScaler = scaler;
        if (constraints.hasBoundedWidth) {
          double widest = 0;
          for (final String word in text.split(RegExp(r'\s+'))) {
            if (word.isEmpty) continue;
            final TextPainter painter = TextPainter(
              text: TextSpan(text: word, style: effective),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            if (painter.width > widest) widest = painter.width;
            painter.dispose();
          }
          if (widest > constraints.maxWidth && widest > 0) {
            final double factor = constraints.maxWidth / widest * 0.98;
            final double base =
                scaler.scale(effective.fontSize ?? 14) /
                (effective.fontSize ?? 14);
            textScaler = TextScaler.linear(base * factor);
          }
        }
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          softWrap: true,
          textScaler: textScaler,
        );
      },
    );
  }
}
