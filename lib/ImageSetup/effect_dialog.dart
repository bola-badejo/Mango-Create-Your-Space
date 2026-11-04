
import 'package:flutter/material.dart';
import 'package:mango/Home/controllers/video_effects.dart';
import 'package:mango/Utils/optimized_lists.dart';

class EffectsDialog extends StatefulWidget {
  final String currentFilter;
  final Function(String) onFilterSelected;

  const EffectsDialog({
    super.key,
    required this.currentFilter,
    required this.onFilterSelected,
  });

  @override
  State<EffectsDialog> createState() => _EffectsDialogState();
}

class _EffectsDialogState extends State<EffectsDialog> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    final availableFilters = VideoEffectsService.getAvailableFilters();
    
    return AlertDialog(
      title: const Text('Select Filter'),
      content: SizedBox(
        width: double.maxFinite,
        child: OptimizedGridView(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemCount: availableFilters.length,
          itemBuilder: (context, index) {
            final filter = availableFilters[index];
            final isSelected = _selectedFilter == filter;
            
            return GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = filter);
                widget.onFilterSelected(filter);
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey,
                    width: 2,
                  ),
                  color: _getFilterColor(filter),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      filter == 'normal' ? 'N' : filter.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Color _getFilterColor(String filter) {
    final colors = {
      'vintage': const Color(0xFF8B7355),
      'cool': const Color(0xFF87CEEB),
      'warm': const Color(0xFFFFA500),
      'cinematic': const Color(0xFF2F4F4F),
      'dramatic': const Color(0xFF4B0082),
      'noir': Colors.black,
      'comic': const Color(0xFFFFD700),
      'pastel': const Color(0xFFFFB6C1),
      'neon': const Color(0xFF39FF14),
      'normal': Colors.grey,
    };
    return colors[filter] ?? Colors.grey.shade700;
  }
}