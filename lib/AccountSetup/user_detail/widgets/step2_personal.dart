import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class Step2Personal extends StatelessWidget {
  Step2Personal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final cardColor = isDark ? MangoPalette.black : Colors.white;
    
    
    final controller = Get.find<UserDetailsController>(
      tag: UserDetailsController.tag,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Section(
            icon: Icons.person_outline,
            title: "Personal Details",
            children: [
              _buildDateField(context, controller, isDark, textColor),
            ],
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context,
    UserDetailsController controller,
    bool isDark,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: TextField(
        controller: controller.dateController,
        readOnly: true,
        onTap: () async {
          await controller.selectDate(context);
          
          
        },
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: "Date of Birth",
          hintText: "Select your date of birth",
          labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.calendar_today, color: MangoPalette.green500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: BorderSide(color: MangoPalette.grey300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: BorderSide(color: MangoPalette.grey300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: const BorderSide(color: MangoPalette.green500),
          ),
          filled: true,
          fillColor: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        ),
      ),
    );
  }
}


class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: MangoPalette.green500, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}