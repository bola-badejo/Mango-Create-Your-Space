import 'package:country_state_city_pro/country_state_city_pro.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'package:mango/AccountSetup/user_detail/widgets/phone_input_field.dart';

class Step3Contact extends StatelessWidget {
  final UserDetailsController controller;

  Step3Contact({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final cardColor = theme.cardColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Section(
            icon: Icons.contact_mail,
            title: "Contact Details",
            children: [
              _buildPhoneField(context, isDark),
            ],
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          const SizedBox(height: 16),
          
          GetBuilder<UserDetailsController>(
            id: 'address',
            builder: (_) => _Section(
              icon: Icons.location_on_outlined,
              title: "Address",
              children: [_buildAddressFields(controller, isDark, context)],
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
            ),
          ),
        ],
      ),
    );
  }

  
Widget _buildPhoneField(BuildContext context, bool isDark) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: PhoneInputField(
      controller: controller,
      isDark: isDark,
      key: ValueKey('phone_field_${controller.phoneCompleteNumber.value}'),
    ),
  );
}

  
  Widget _buildAddressFields(UserDetailsController controller, bool isDark, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountryField(controller, isDark, context),
          const SizedBox(height: 16),
          if (controller.countryController.text.isNotEmpty)
            _buildStateField(controller, isDark, context),
          if (controller.countryController.text.isNotEmpty)
            const SizedBox(height: 16),
          if (controller.stateController.text.isNotEmpty)
            _buildCityField(controller, isDark, context),
        ],
      ),
    );
  }

  Widget _buildCountryField(UserDetailsController controller, bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Country',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        CountryStateCityPicker(
          country: controller.countryController,
          state: controller.stateController,
          city: controller.cityController,
          textFieldDecoration: InputDecoration(
            hintText: 'Select your country',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.orange),
          ),
        ),
      ],
    );
  }

  Widget _buildStateField(UserDetailsController controller, bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'State/Region',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        CountryStateCityPicker(
          country: controller.countryController,
          state: controller.stateController,
          city: controller.cityController,
          textFieldDecoration: InputDecoration(
            hintText: 'Select your state',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: const Icon(Icons.map_outlined, color: Colors.orange),
          ),
        ),
      ],
    );
  }

  Widget _buildCityField(UserDetailsController controller, bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'City',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        CountryStateCityPicker(
          country: controller.countryController,
          state: controller.stateController,
          city: controller.cityController,
          textFieldDecoration: InputDecoration(
            hintText: 'Select your city',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: const Icon(Icons.location_city_outlined, color: Colors.orange),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.orange, size: 20),
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