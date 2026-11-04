import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';

class NavigationButtons extends StatelessWidget {
  final int currentStep;
  final UserDetailsController controller;

  const NavigationButtons({
    super.key,
    required this.currentStep,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (currentStep > 0) ... [  ] else const Spacer(),
          if (currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              final canProceed = controller.canProceedToNextStep();
              return ElevatedButton(
                onPressed: canProceed
                    ? () {
                        if (currentStep == 2) {
                          if (controller.areAllStepsComplete) {
                            controller.saveAllData(context);
                          }
                        } else {
                          controller.nextStep();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canProceed ? Colors.orange : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: controller.isSaving.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        currentStep == 2
                            ? (controller.areAllStepsComplete
                                  ? 'Complete Setup'
                                  : 'Fix Issues')
                            : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class ValidationSummary extends StatelessWidget {
  final UserDetailsController controller;

  const ValidationSummary({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final issues = <String>[];

    final displayName = controller.displayNameController.text.trim();
    final username = controller.usernameController.text.trim();

    if (displayName.isEmpty) {
      issues.add('Display name is required');
    }

    if (username.isEmpty) {
      issues.add('Username is required');
    } else if (controller.validateUsername(username)) {
      issues.add(
        'Username must be 3-30 chars, use only letters, numbers, . and _',
      );
    }

    if (controller.dateController.text.isEmpty) {
      issues.add('Date of birth is required');
    }

    if (controller.selectedTags.isEmpty) {
      issues.add('Select at least one hobby/interest');
    }

    if (controller.phoneCompleteNumber.value.isEmpty) {
      issues.add('Phone number is required');
    } else if (!controller.validatePhoneNumber(
      controller.phoneCompleteNumber.value,
    )) {
      issues.add('Valid phone number is required');
    }

    if (controller.countryController.text.isEmpty) {
      issues.add('Country is required');
    }

    if (controller.cityController.text.isEmpty) {
      issues.add('City is required');
    }

    if (issues.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please fix the following issues:',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $issue', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
