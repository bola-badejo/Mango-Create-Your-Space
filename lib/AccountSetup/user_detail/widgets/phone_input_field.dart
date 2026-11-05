import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class PhoneInputField extends StatefulWidget {
  final UserDetailsController controller;
  final bool isDark;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late final TextEditingController _controller;
  String _lastCompleteNumber = '';
  String _lastCountryCode = 'NG'; 

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.controller.phoneNationalNumber.value,
    );
    _lastCompleteNumber = widget.controller.phoneCompleteNumber.value;
    _lastCountryCode = widget.controller.phoneCountryCode.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      controller: _controller,
      initialCountryCode: _lastCountryCode,
      onChanged: (PhoneNumber phone) {
        
        if (_lastCompleteNumber != phone.completeNumber) {
          _lastCompleteNumber = phone.completeNumber;
          _lastCountryCode = phone.countryCode;
          
          widget.controller.updatePhoneData(
            completeNumber: phone.completeNumber,
            countryCode: phone.countryCode,
            nationalNumber: phone.number,
          );
        }
      },
      style: TextStyle(
        color: widget.isDark ? Colors.white : MangoPalette.black,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: "Phone Number",
        hintText: "Enter phone number",
        labelStyle: TextStyle(
          color: widget.isDark ? Colors.white70 : Colors.black54,
        ),
        hintStyle: TextStyle(
          color: widget.isDark ? Colors.white54 : Colors.black38,
        ),
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
        fillColor: widget.isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      dropdownTextStyle: TextStyle(
        color: widget.isDark ? Colors.white : MangoPalette.black,
      ),
      dropdownIcon: Icon(
        Icons.arrow_drop_down,
        color: widget.isDark ? Colors.white : MangoPalette.black,
      ),
      searchText: 'Search country',
      invalidNumberMessage: 'Please enter a valid phone number',
      flagsButtonPadding: const EdgeInsets.only(left: 16),
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      disableLengthCheck: false,
    );
  }
}