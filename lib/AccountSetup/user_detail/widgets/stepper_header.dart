import 'package:flutter/material.dart';

class StepperHeader extends StatelessWidget {
  final int currentStep;
  
  const StepperHeader({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStep(0, 'Profile', Icons.person, currentStep, isDark, textColor),
          _buildStepDivider(isDark),
          _buildStep(1, 'Personal', Icons.favorite, currentStep, isDark, textColor),
          _buildStepDivider(isDark),
          _buildStep(2, 'Contact', Icons.contact_page, currentStep, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildStep(
    int stepNumber, 
    String title, 
    IconData icon, 
    int currentStep, 
    bool isDark, 
    Color textColor,
  ) {
    final isActive = currentStep == stepNumber;
    final isCompleted = currentStep > stepNumber;
    final isAccessible = currentStep >= stepNumber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.orange.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Colors.orange.withOpacity(0.3))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green
                  : (isActive
                        ? Colors.orange
                        : Colors.grey.withOpacity(0.2)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(bool isDark) {
    return Container(
      width: 16,
      height: 1,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }
}