import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/AccountSetup/skip_setup.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/Models/cloud/user_services.dart';
import 'package:mango/Models/customModel/mango_tags.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class ControllerHelper {
  static UserDetailsController get userDetailsController {
    try {
      if (Get.isRegistered<UserDetailsController>(
        tag: UserDetailsController.tag,
      )) {
        return Get.find<UserDetailsController>(tag: UserDetailsController.tag);
      }

      return Get.put(
        UserDetailsController(),
        tag: UserDetailsController.tag,
        permanent: true,
      );
    } catch (e) {
      debugPrint('ControllerHelper Error: $e');
      return UserDetailsController();
    }
  }
}

class UserDetailsController extends GetxController {
  static String get tag => 'UserDetailsController';

  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  UserService get userService => _userService;
  final UtilsService _utilsService = UtilsService();

  var profileImage = Rxn<dynamic>();
  var bannerImage = Rxn<dynamic>();
  var profileImageBytes = Rxn<Uint8List>();
  var bannerImageBytes = Rxn<Uint8List>();
  var selectedTags = <MangoTags>[].obs;
  var selectedProfession = ''.obs;

  var webProfileFileName = Rxn<String>();
  var webBannerFileName = Rxn<String>();

  late TextEditingController displayNameController;
  late TextEditingController usernameController;
  late TextEditingController bioController;
  late TextEditingController dateController;
  late TextEditingController countryController;
  late TextEditingController stateController;
  late TextEditingController cityController;
  late TextEditingController phoneController;
  late TextEditingController searchTextController;

  var isStep1Complete = false.obs;
  var isStep2Complete = false.obs;
  var isStep3Complete = false.obs;
  var currentStep = 0.obs;
  var isSaving = false.obs;
  final bioLength = 0.obs;

  var phoneCountryCode = 'NG'.obs;
  var phoneNationalNumber = ''.obs;
  var phoneCompleteNumber = ''.obs;

  var isProfileImageSelected = false.obs;
  var isBannerImageSelected = false.obs;

  final _userData = Rxn<MangoUser>();
  MangoUser? get userData => _userData.value;

  UserDetailsController() {
    _initializeControllers();
  }

  @override
  void onInit() {
    super.onInit();
    countryController.addListener(_onAddressChanged);
    stateController.addListener(_onAddressChanged);
    cityController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    _validateStep3();
    update(['address']);
  }

  BuildContext? get context {
    try {
      return Get.context;
    } catch (e) {
      return null;
    }
  }

  void _initializeControllers() {
    displayNameController = TextEditingController();
    usernameController = TextEditingController();
    bioController = TextEditingController();
    dateController = TextEditingController();
    countryController = TextEditingController();
    stateController = TextEditingController();
    cityController = TextEditingController();
    phoneController = TextEditingController();
    searchTextController = TextEditingController();
  }

  Future<MangoUser?> getUserInfoOnce(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return MangoUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user info once: $e');
      return null;
    }
  }

  bool validateUsername(String username) {
    if (username.isEmpty) return false;
    if (username.length < 3) return false;
    if (username.length > 30) return false;

    if (username.startsWith('.') || username.startsWith('_')) return false;

    final pattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._]*$');
    return pattern.hasMatch(username);
  }

  void _validateStep1() {
    try {
      final displayName = displayNameController.text.trim();
      final username = usernameController.text.trim();

      final displayNameValid = displayName.isNotEmpty;
      final usernameValid = validateUsername(username);

      isStep1Complete.value = displayNameValid && usernameValid;
      update(['step_validation', 'navigation']);
    } catch (e) {
      isStep1Complete.value = false;
      update(['step_validation', 'navigation']);
    }
  }

  void _validateStep2() {
    try {
      final dateValid = dateController.text.isNotEmpty;
      
      isStep2Complete.value = dateValid;
      update(['step_validation', 'navigation']);
    } catch (e) {
      isStep2Complete.value = false;
      update(['step_validation', 'navigation']);
    }
  }

  void _validateStep3() {
    try {
      final phoneValid =
          phoneCompleteNumber.value.isNotEmpty &&
          validatePhoneNumber(phoneCompleteNumber.value);

      final countryValid = countryController.text.trim().isNotEmpty;
      final cityValid = cityController.text.trim().isNotEmpty;

      isStep3Complete.value = phoneValid && countryValid && cityValid;
      update(['step_validation', 'navigation']);
    } catch (e) {
      isStep3Complete.value = false;
      update(['step_validation', 'navigation']);
    }
  }

  bool validatePhoneNumber(String phone) {
    try {
      if (phone.isEmpty) return false;

      final cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (!phone.startsWith('+')) return false;

      return cleanedPhone.length >= 8 && cleanedPhone.length <= 19;
    } catch (e) {
      return false;
    }
  }

  bool get areAllStepsComplete {
    return isStep1Complete.value &&
        isStep2Complete.value &&
        isStep3Complete.value;
  }

  bool canProceedToNextStep() {
    try {
      switch (currentStep.value) {
        case 0:
          return isStep1Complete.value;
        case 1:
          return isStep2Complete.value;
        case 2:
          return isStep3Complete.value && !isSaving.value;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  void onUsernameChanged(String value) {
    try {
      final filtered = value.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');

      final cleaned = filtered.startsWith('.') || filtered.startsWith('_')
          ? filtered.substring(1)
          : filtered;

      if (value != cleaned) {
        usernameController.text = cleaned;
        usernameController.selection = TextSelection.collapsed(
          offset: cleaned.length,
        );
      }

      _validateStep1();
      update(['user_info']);
    } catch (e) {
      debugPrint('Error in onUsernameChanged: $e');
    }
  }

  Future<void> loadUserData(MangoUser? user) async {
    try {
      if (user == null) {
        debugPrint('loadUserData called with null user');
        return;
      }

      _userData.value = user;

      if (user.phone != null && user.phone!.isNotEmpty) {
        _parseExistingPhoneNumber(user.phone!);
      }

      _populateControllers(user);

      _validateAllSteps();

      update(['user_info', 'profile_picture', 'banner_image']);
    } catch (e, stack) {
      debugPrint('Error loading user data: $e\n$stack');
    }
  }

  void _parseExistingPhoneNumber(String phone) {
    try {
      if (phone.startsWith('+')) {
        final withoutPlus = phone.substring(1);

        if (withoutPlus.startsWith('234')) {
          phoneCountryCode.value = 'NG';
          phoneNationalNumber.value = withoutPlus.substring(3);
        } else if (withoutPlus.startsWith('1')) {
          phoneCountryCode.value = 'US';
          phoneNationalNumber.value = withoutPlus.substring(1);
        } else if (withoutPlus.startsWith('44')) {
          phoneCountryCode.value = 'GB';
          phoneNationalNumber.value = withoutPlus.substring(2);
        } else {
          phoneCountryCode.value = 'NG';
          phoneNationalNumber.value = withoutPlus;
        }

        phoneCompleteNumber.value = phone;
        phoneController.text = phoneNationalNumber.value;
      } else {
        phoneCountryCode.value = 'NG';
        phoneNationalNumber.value = phone;
        phoneCompleteNumber.value = '+234$phone';
        phoneController.text = phone;
      }
    } catch (e) {
      debugPrint('Error parsing phone number: $e');
    }
  }

  void _populateControllers(MangoUser user) {
    try {
      if (displayNameController.text.isEmpty &&
          (user.displayName?.isNotEmpty ?? false)) {
        displayNameController.text = user.displayName!;
      }

      if (usernameController.text.isEmpty &&
          (user.username?.isNotEmpty ?? false)) {
        usernameController.text = user.username!;
      }

      if (bioController.text.isEmpty && (user.bio?.isNotEmpty ?? false)) {
        bioController.text = user.bio!;
      }

      if (dateController.text.isEmpty && (user.dob?.isNotEmpty ?? false)) {
        dateController.text = user.dob!;
      }

      if (countryController.text.isEmpty &&
          (user.country?.isNotEmpty ?? false)) {
        countryController.text = user.country!;
      }

      if (stateController.text.isEmpty && (user.state?.isNotEmpty ?? false)) {
        stateController.text = user.state!;
      }

      if (cityController.text.isEmpty && (user.city?.isNotEmpty ?? false)) {
        cityController.text = user.city!;
      }

      if (phoneController.text.isEmpty && (user.phone?.isNotEmpty ?? false)) {
        phoneController.text = user.phone!;
      }

      if (selectedProfession.value.isEmpty &&
          (user.profession?.isNotEmpty ?? false)) {
        selectedProfession.value = user.profession!;
      }
    } catch (e, stack) {
      debugPrint('Error populating controllers: $e\n$stack');
    }
  }

  void _validateAllSteps() {
    _validateStep1();
    _validateStep2();
    _validateStep3();
  }

  void updatePhoneNumber({
    required String countryCode,
    required String nationalNumber,
    required String completeNumber,
  }) {
    phoneCountryCode.value = countryCode;
    phoneNationalNumber.value = nationalNumber;
    phoneCompleteNumber.value = completeNumber;
    _validateStep3();
    update(['phone_field']);
  }

  void updateCountryCode(String countryCode) {
    phoneCountryCode.value = countryCode;
    update(['phone_field']);
  }

  void onPhoneChanged(String value) {}

  void updatePhoneData({
    required String completeNumber,
    required String countryCode,
    required String nationalNumber,
  }) {
    
    phoneCompleteNumber.value = completeNumber;
    phoneCountryCode.value = countryCode;
    phoneNationalNumber.value = nationalNumber;

    
    _validateStep3();

    
    update(['step_validation', 'navigation']);
  }

  /// Picks a profile picture (type 0, square) or banner (type 1, wide)
  /// through the Mango composer: crop, filters and adjustments, then uploads
  /// in the background.
  Future<void> pickImage(
    ImageSource source,
    int type,
    BuildContext context,
  ) async {
    try {
      final media = await MangoComposer.pick(
        context,
        source: source == ImageSource.camera ? 'camera' : 'gallery',
        crop: type == 0 ? CropShape.square : CropShape.landscape,
        allowCaption: false,
        actionLabel: 'Use',
      );
      if (media == null) return;
      final bytes = media.bytes;
      if (type == 0) {
        profileImage.value = bytes;
        profileImageBytes.value = bytes;
        webProfileFileName.value = media.name;
        isProfileImageSelected.value = true;
        update(['profile_image', 'user_info', 'current_step']);
        _uploadProfileImageInBackgroundForWeb(bytes, media.name, context);
      } else {
        bannerImage.value = bytes;
        bannerImageBytes.value = bytes;
        webBannerFileName.value = media.name;
        isBannerImageSelected.value = true;
        update(['banner_image', 'current_step']);
        _uploadBannerImageInBackgroundForWeb(bytes, media.name, context);
      }
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        "Couldn't use that picture. Try another.",
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget getProfileImageWidget(double radius) {
    if (kIsWeb) {
      final bytes = profileImageBytes.value;
      if (bytes != null) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      }
    } else {
      final image = profileImage.value;
      if (image is File) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(image));
      } else if (image is Uint8List) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(image),
        );
      }
    }

    if (_userData.value?.profileImage?.isNotEmpty ?? false) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_userData.value!.profileImage!),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: MangoPalette.grey300,
      child: Icon(Icons.person, size: radius, color: MangoPalette.grey600),
    );
  }

  bool get hasProfileImageToUpload => isProfileImageSelected.value;
  bool get hasBannerImageToUpload => isBannerImageSelected.value;

  Widget getBannerImageWidget(double width, double height) {
    if (kIsWeb) {
      final bytes = bannerImageBytes.value;
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    } else {
      final image = bannerImage.value;
      if (image is File) {
        return Image.file(
          image,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      } else if (image is Uint8List) {
        return Image.memory(
          image,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    }

    if (_userData.value?.bannerImageUrl?.isNotEmpty ?? false) {
      return Image.network(
        _userData.value!.bannerImageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: width,
      height: height,
      color: MangoPalette.grey300,
      child: Icon(Icons.photo, size: 40, color: MangoPalette.grey600),
    );
  }

  Future<void> _uploadProfileImageInBackgroundForWeb(
    Uint8List fileBytes,
    String? fileName,
    BuildContext context,
  ) async {
    try {
      await _userService.updateProfileImage(fileBytes, fileName);
      update(['profile_image']);

      if (_userData.value != null) {
        final updatedUser = await _userService.getUserInfoOnce(
          _userData.value!.id,
        );
        if (updatedUser != null) {
          _userData.value = updatedUser;
        }
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload profile image',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _uploadBannerImageInBackgroundForWeb(
    Uint8List fileBytes,
    String? fileName,
    BuildContext context,
  ) async {
    try {
      await _userService.updateBannerImage(fileBytes, fileName);
      update(['banner_image']);

      if (_userData.value != null) {
        final updatedUser = await _userService.getUserInfoOnce(
          _userData.value!.id,
        );
        if (updatedUser != null) {
          _userData.value = updatedUser;
        }
      }
    } catch (e) {
      print('Error uploading banner image: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload banner image',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _uploadProfileImageInBackground(
    File file,
    BuildContext context,
  ) async {
    try {
      await _userService.updateProfileImage(file);
      update(['profile_image']);

      if (_userData.value != null) {
        final updatedUser = await _userService.getUserInfoOnce(
          _userData.value!.id,
        );
        if (updatedUser != null) {
          _userData.value = updatedUser;
        }
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload profile image',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _uploadBannerImageInBackground(File file, context) async {
    try {
      await _userService.updateBannerImage(file);
      update(['banner_image']);

      if (_userData.value != null) {
        final updatedUser = await _userService.getUserInfoOnce(
          _userData.value!.id,
        );
        if (updatedUser != null) {
          _userData.value = updatedUser;
        }
      }
    } catch (e) {
      print('Error uploading banner image: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload banner image',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<Uint8List> _compressImageForWeb(Uint8List imageBytes) async {
    try {
      return await _utilsService.compressImageForWeb(
        imageBytes,
        maxWidth: 1080,
        quality: 85,
      );
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes;
    }
  }

  Future<void> saveAllData(context) async {
    if (isSaving.value) return;

    isSaving.value = true;
    update(['navigation', 'save_button']);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final updates = <Future>[];

      // Pictures upload as soon as they're picked (pickImage); nothing to redo here.

      // Pictures upload as soon as they're picked (pickImage); nothing to redo here.

      if (displayNameController.text.trim().isNotEmpty) {
        updates.add(
          _userService.updateDisplayName(displayNameController.text.trim()),
        );
      }

      if (usernameController.text.trim().isNotEmpty) {
        updates.add(
          _userService.updateUsername(usernameController.text.trim()),
        );
      }

      if (bioController.text.trim().isNotEmpty) {
        updates.add(_userService.updateBio(bioController.text.trim()));
      }

      if (dateController.text.isNotEmpty) {
        updates.add(_userService.updateDOB(dateController.text));
      }

      if (selectedProfession.value.isNotEmpty) {
        updates.add(_userService.updateProfession(selectedProfession.value));
      }

      if (countryController.text.isNotEmpty) {
        updates.add(_userService.updateCountry(countryController.text));
      }

      if (stateController.text.isNotEmpty) {
        updates.add(_userService.updateState(stateController.text));
      }

      if (cityController.text.isNotEmpty) {
        updates.add(_userService.updateCity(cityController.text));
      }

      if (phoneCompleteNumber.value.isNotEmpty) {
        updates.add(_userService.updatePhone(phoneCompleteNumber.value));
      }

      await Future.wait(updates);

      Get.offAll(
        () => SkipSetup(uid: currentUser.uid),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );

      UtilsService().showSnackbar(
        '🎉 Profile Complete!',
        'Your profile has been successfully updated',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e, stack) {
      debugPrint('Error saving user data: $e\n$stack');

      UtilsService().showSnackbar(
        'Save Failed',
        'Please check your connection and try again',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isSaving.value = false;
      update(['navigation', 'save_button']);
    }
  }

  void clearProfileImage() {
    profileImage.value = null;
    profileImageBytes.value = null;
    webProfileFileName.value = null;
    isProfileImageSelected.value = false;
    update(['profile_image']);
  }

  void clearBannerImage() {
    bannerImage.value = null;
    bannerImageBytes.value = null;
    webBannerFileName.value = null;
    isBannerImageSelected.value = false;
    update(['banner_image']);
  }

  dynamic getProfileImageForUpload() {
    if (kIsWeb) {
      return profileImageBytes.value;
    } else {
      return profileImage.value;
    }
  }

  dynamic getBannerImageForUpload() {
    if (kIsWeb) {
      return bannerImageBytes.value;
    } else {
      return bannerImage.value;
    }
  }

  Future<void> selectDate(BuildContext context) async {
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
        firstDate: DateTime(1900),
        lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: MangoPalette.green500,
                onPrimary: Colors.white,
                surface: Theme.of(context).cardColor,
                onSurface:
                    Theme.of(context).textTheme.bodyLarge?.color ??
                    MangoPalette.black,
              ),
              dialogBackgroundColor: Theme.of(context).cardColor,
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        _validateStep2();

        
        update(['step_validation', 'navigation', 'date_field']);

        
        Future.microtask(() {
          update(['step_validation', 'navigation', 'date_field']);
        });
      }
    } catch (e) {
      debugPrint('Error selecting date: $e');
    }
  }

  void addTag(MangoTags tag) {
    try {
      if (!selectedTags.contains(tag) && selectedTags.length < 10) {
        selectedTags.add(tag);
        _validateStep2();

        update(['hobbies_section', 'step_validation', 'navigation']);
      }
    } catch (e) {
      debugPrint('Error adding tag: $e');
    }
  }

  void removeTag(MangoTags tag) {
    try {
      selectedTags.remove(tag);
      _validateStep2();

      update(['hobbies_section', 'step_validation', 'navigation']);
    } catch (e) {
      debugPrint('Error removing tag: $e');
    }
  }

  void onDisplayNameChanged(String value) {
    try {
      _validateStep1();
      update(['user_info']);
    } catch (e) {
      debugPrint('Error in onDisplayNameChanged: $e');
    }
  }

  void onBioChanged(String value) {
    try {
      bioLength.value = value.length;
      _validateStep1();
      update(['user_info', 'bio_length']);
    } catch (e) {
      debugPrint('Error in onBioChanged: $e');
    }
  }

  final usernameError = ''.obs;

  void nextStep() {
    try {
      if (currentStep.value < 2 && canProceedToNextStep()) {
        currentStep.value++;
        update([
          'current_step',
          'step_${currentStep.value}',
          'step_${currentStep.value - 1}',
        ]);
      }
    } catch (e) {
      debugPrint('Error in nextStep: $e');
    }
  }

  void previousStep() {
    try {
      if (currentStep.value > 0) {
        currentStep.value--;
        update([
          'current_step',
          'step_${currentStep.value}',
          'step_${currentStep.value + 1}',
        ]);
      }
    } catch (e) {
      debugPrint('Error in previousStep: $e');
    }
  }

  void goToStep(int step) {
    try {
      if (step >= 0 && step <= 2 && step <= currentStep.value) {
        currentStep.value = step;
        update(['current_step']);
      }
    } catch (e) {
      debugPrint('Error in goToStep: $e');
    }
  }

  @override
  void onClose() {
    countryController.removeListener(_onAddressChanged);
    stateController.removeListener(_onAddressChanged);
    cityController.removeListener(_onAddressChanged);
    _disposeControllers();
    super.onClose();
  }

  void _disposeControllers() {
    try {
      displayNameController.dispose();
      usernameController.dispose();
      bioController.dispose();
      dateController.dispose();
      countryController.dispose();
      stateController.dispose();
      cityController.dispose();
      phoneController.dispose();
      searchTextController.dispose();
    } catch (e) {
      debugPrint('Error disposing controllers: $e');
    }
  }
}

class ValidationPatterns {
  static final usernamePattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._]*$');
  static const int maxUsernameLength = 30;
  static const int minUsernameLength = 3;
}
