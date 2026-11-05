import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class HighlightedMultilineText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color highlightColor;

  const HighlightedMultilineText({
    super.key,
    required this.text,
    required this.style,
    this.highlightColor = MangoPalette.black,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final words = text.split(' ');
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: constraints.maxWidth);

      final lineTexts = <String>[];
      String current = '';

      for (var word in words) {
        final test = (current.isEmpty ? word : '$current $word');
        final t = TextPainter(
          text: TextSpan(text: test, style: style),
          textDirection: TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: constraints.maxWidth);

        if (t.computeLineMetrics().length > lineTexts.length + 1) {
          lineTexts.add(current);
          current = word;
        } else {
          current = test;
        }
      }
      if (current.isNotEmpty) lineTexts.add(current);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lineTexts
            .map((line) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                  child: Text(line, style: style),
                ))
            .toList(),
      );
    });
  }
}
