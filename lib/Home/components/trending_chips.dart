import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class _CompactTrendingChip extends StatelessWidget {
  final String label;

  const _CompactTrendingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MangoPalette.grey100,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: MangoPalette.grey300),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }
}