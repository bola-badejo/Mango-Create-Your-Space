import 'package:flutter/material.dart';

class _CompactTrendingChip extends StatelessWidget {
  final String label;

  const _CompactTrendingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.black87)),
    );
  }
}