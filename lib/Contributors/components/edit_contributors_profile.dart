import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Contributors/controllers/contributor_service.dart';
import 'package:mango/Contributors/models/contributors_profile.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class EditContributorProfileScreen extends StatefulWidget {
  @override
  State<EditContributorProfileScreen> createState() =>
      _EditContributorProfileScreenState();
}

class _EditContributorProfileScreenState
    extends State<EditContributorProfileScreen> {
  final ContributorService _contributorService = ContributorService();
  final _formKey = GlobalKey<FormState>();

  // Controllers for all editable fields
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _portfolioController = TextEditingController();
  final TextEditingController _socialMediaController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();

  // For tags and categories
  List<String> _selectedTags = [];
  List<String> _selectedCategories = [];
  List<String> _selectedSubCategories = [];

  // For image uploads
  Uint8List? _webProfileImageBytes;
  Uint8List? _webBannerImageBytes;
  Uint8List? _webLogoImageBytes;
  XFile? _profileImage;
  XFile? _bannerImage;
  XFile? _logoImage;
  bool _isUploadingImage = false;

  bool _isLoading = false;
  ContributorProfile? _currentProfile;

  // Available options for dropdowns
  final List<String> _availableTags = [
    'Music',
    'Books',
    'Podcasts',
    'Movies',
    'Products',
    'Art',
    'Technology',
    'Fashion',
    'Food',
    'Travel',
    'Sports',
    'Education',
    'Health',
    'Gaming',
    'Photography',
    'Design',
    'Writing',
    'Comedy',
  ];

  final List<String> _availableCategories = [
    'Music',
    'Albums',
    'Singles',
    'Music Videos',
    'Live Performances',
    'Books',
    'Fiction',
    'Non-Fiction',
    'Poetry',
    'Comics',
    'Podcasts',
    'Interview Podcasts',
    'Storytelling',
    'Educational',
    'Movies',
    'Feature Films',
    'Short Films',
    'Documentaries',
    'Art',
    'Digital Art',
    'Traditional Art',
    'Photography',
    'Products',
    'Physical Products',
    'Digital Products',
    'Merchandise',
    'Services',
    'Consulting',
    'Workshops',
    'Events',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final profile = await _contributorService.getContributorByUserId(userId);

    if (profile != null) {
      setState(() {
        _currentProfile = profile;

        // Load all text fields with existing data (handles null/blank values)
        _bioController.text = profile.bio ?? '';
        _portfolioController.text = profile.portfolio ?? '';
        _socialMediaController.text = profile.socialMedia ?? '';
        _locationController.text = profile.location ?? '';
        _companyNameController.text = profile.companyName ?? '';
        _companyAddressController.text = profile.companyAddress ?? '';

        // Load tags and categories (handle null/empty lists)
        _selectedTags = List<String>.from(profile.tags ?? []);
        _selectedCategories = List<String>.from(profile.categories ?? []);
        _selectedSubCategories = List<String>.from(profile.subCategories ?? []);
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _webProfileImageBytes = result.files.first.bytes;
            _profileImage = null;
          });
        }
      } else {
        final ImagePicker _picker = ImagePicker();
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _profileImage = image;
            _webProfileImageBytes = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _webBannerImageBytes = result.files.first.bytes;
            _bannerImage = null;
          });
        }
      } else {
        final ImagePicker _picker = ImagePicker();
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 400,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _bannerImage = image;
            _webBannerImageBytes = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error picking banner: $e');
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _webLogoImageBytes = result.files.first.bytes;
            _logoImage = null;
          });
        }
      } else {
        final ImagePicker _picker = ImagePicker();
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 400,
          maxHeight: 400,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _logoImage = image;
            _webLogoImageBytes = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error picking logo: $e');
    }
  }

  Future<String?> _uploadImage(dynamic image, String path) async {
    try {
      final Reference storageRef = FirebaseStorage.instance.ref().child(path);

      if (kIsWeb) {
        if (image is Uint8List) {
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'platform': 'web'},
          );
          final uploadTask = storageRef.putData(image, metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        }
      } else {
        if (image is XFile) {
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          final uploadTask = storageRef.putFile(File(image.path), metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        }
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final Map<String, dynamic> updates = {};

      // Text field updates (only if changed from original)
      if (_bioController.text.trim() != (_currentProfile?.bio ?? '')) {
        updates['bio'] = _bioController.text.trim();
      }
      if (_portfolioController.text.trim() !=
          (_currentProfile?.portfolio ?? '')) {
        updates['portfolio'] = _portfolioController.text.trim();
      }
      if (_socialMediaController.text.trim() !=
          (_currentProfile?.socialMedia ?? '')) {
        updates['socialMedia'] = _socialMediaController.text.trim();
      }
      if (_locationController.text.trim() !=
          (_currentProfile?.location ?? '')) {
        updates['location'] = _locationController.text.trim();
      }
      if (_companyNameController.text.trim() !=
          (_currentProfile?.companyName ?? '')) {
        updates['companyName'] = _companyNameController.text.trim();
      }
      if (_companyAddressController.text.trim() !=
          (_currentProfile?.companyAddress ?? '')) {
        updates['companyAddress'] = _companyAddressController.text.trim();
      }

      // Tags and categories updates
      if (!_listsEqual(_selectedTags, _currentProfile?.tags ?? [])) {
        updates['tags'] = _selectedTags;
      }
      if (!_listsEqual(
        _selectedCategories,
        _currentProfile?.categories ?? [],
      )) {
        updates['categories'] = _selectedCategories;
      }
      if (!_listsEqual(
        _selectedSubCategories,
        _currentProfile?.subCategories ?? [],
      )) {
        updates['subCategories'] = _selectedSubCategories;
      }

      // Image uploads
      setState(() => _isUploadingImage = true);

      if (_webProfileImageBytes != null || _profileImage != null) {
        final imageUrl = await _uploadImage(
          kIsWeb ? _webProfileImageBytes! : _profileImage!,
          'contributors/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (imageUrl != null) {
          updates['profileImageUrl'] = imageUrl;
        }
      }

      if (_webBannerImageBytes != null || _bannerImage != null) {
        final imageUrl = await _uploadImage(
          kIsWeb ? _webBannerImageBytes! : _bannerImage!,
          'contributors/$userId/banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (imageUrl != null) {
          updates['bannerImageUrl'] = imageUrl;
        }
      }

      if (_webLogoImageBytes != null || _logoImage != null) {
        final imageUrl = await _uploadImage(
          kIsWeb ? _webLogoImageBytes! : _logoImage!,
          'contributors/$userId/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (imageUrl != null) {
          updates['logoImageUrl'] = imageUrl;
        }
      }

      setState(() => _isUploadingImage = false);

      // Only update if there are changes
      if (updates.isNotEmpty) {
        await _contributorService.updateContributorProfile(userId, updates);
      }

      Get.back(result: true);
      UtilsService().showSnackbar(
        'Success',
        'Profile updated successfully',
        backgroundColor: MangoPalette.green500,
        context: context,
        colorText: Colors.white,
      );
    } catch (e) {
      _showErrorSnackbar('Failed to update profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    final sortedList1 = List<String>.from(list1)..sort();
    final sortedList2 = List<String>.from(list2)..sort();

    return sortedList1.toString() == sortedList2.toString();
  }

  void _showErrorSnackbar(String message) {
    UtilsService().showSnackbar(
      'Error',
      message,
      context: context,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  Widget _buildImagePickerCard(
    String title,
    String? currentImageUrl,
    VoidCallback onPick,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = _profileImage != null ||
        _webProfileImageBytes != null ||
        (currentImageUrl != null && currentImageUrl.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : MangoPalette.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Icon(icon, size: 20, color: MangoPalette.green500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasImage ? 'Tap to change image' : 'No image uploaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ],
            ),
          ),
          MangoPressable(
            onTap: onPick,
            child: Container(
              height: title.contains('Banner') ? 140 : 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                color: isDark ? MangoPalette.black : MangoPalette.grey50,
              ),
              child: _isUploadingImage
                  ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))
                  : _webProfileImageBytes != null && title == 'Profile Image'
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.memory(
                            _webProfileImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : _profileImage != null && title == 'Profile Image'
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.file(
                            File(_profileImage!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : _webBannerImageBytes != null && title == 'Banner Image'
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.memory(
                            _webBannerImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : _bannerImage != null && title == 'Banner Image'
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.file(
                            File(_bannerImage!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : _webLogoImageBytes != null && title == 'Logo Image'
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.memory(
                            _webLogoImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : _logoImage != null && title == 'Logo Image'
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.file(
                            File(_logoImage!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : currentImageUrl != null && currentImageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Image.network(
                            currentImageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload ${title.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isFirst = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 24, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: MangoPalette.green500,
              borderRadius: BorderRadius.circular(MangoRadius.xs),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : MangoPalette.black.withOpacity(0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : MangoPalette.black.withOpacity(0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: const BorderSide(color: MangoPalette.green500, width: 2),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildTagsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = _currentProfile?.roleColor ?? MangoPalette.green500;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Skills & Interests'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : MangoPalette.black.withOpacity(0.04),
              width: 1,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : roleColor,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
                selectedColor: roleColor,
                backgroundColor: isDark ? MangoPalette.grey800 : MangoPalette.grey200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                  side: BorderSide(
                    color: isSelected ? roleColor : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = _currentProfile?.roleColor ?? MangoPalette.green500;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Content Categories'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : MangoPalette.black.withOpacity(0.04),
              width: 1,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(
                  category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : roleColor,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
                selectedColor: roleColor,
                backgroundColor: isDark ? MangoPalette.grey800 : MangoPalette.grey200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                  side: BorderSide(
                    color: isSelected ? roleColor : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = _currentProfile?.roleColor ?? MangoPalette.green500;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: isDark ? MangoPalette.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: TextButton.styleFrom(
                backgroundColor: roleColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(roleColor),
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? MangoPalette.black : Colors.white,
      body: _currentProfile == null
          ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Banner Image Section
                  _buildImagePickerCard(
                    'Banner Image',
                    _currentProfile?.bannerImageUrl,
                    _pickBannerImage,
                    Icons.panorama,
                  ),
                  
                  // Profile Image Section (Overlapping)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Transform.translate(
                      offset: const Offset(0, -40),
                      child: Row(
                        children: [
                          MangoPressable(
                            onTap: _pickProfileImage,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? MangoPalette.black : Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: MangoPalette.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: roleColor.withOpacity(0.2),
                                backgroundImage: _webProfileImageBytes != null
                                    ? MemoryImage(_webProfileImageBytes!)
                                    : _profileImage != null
                                    ? FileImage(File(_profileImage!.path))
                                    : (_currentProfile?.profileImageUrl != null &&
                                            _currentProfile!.profileImageUrl!.isNotEmpty)
                                        ? NetworkImage(_currentProfile!.profileImageUrl!)
                                        : const AssetImage('asset/images/mango-13.jpg') as ImageProvider,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: roleColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? MangoPalette.black : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentProfile?.displayName ?? 'Contributor',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(MangoRadius.md),
                                  ),
                                  child: Text(
                                    _currentProfile?.roleTitle ?? 'Contributor',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_currentProfile?.isVendor ?? false)
                            MangoPressable(
                              onTap: _pickLogoImage,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
                                  borderRadius: BorderRadius.circular(MangoRadius.md),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : MangoPalette.black.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.business_center,
                                      size: 24,
                                      color: roleColor,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Logo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information
                        _buildSectionHeader('Basic Information', isFirst: true),
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio',
                          icon: Icons.description,
                          hint: 'Tell us about yourself...',
                          maxLines: 4,
                        ),
                        _buildTextField(
                          controller: _locationController,
                          label: 'Location',
                          icon: Icons.location_on_outlined,
                          hint: 'City, Country',
                        ),
                        _buildTextField(
                          controller: _portfolioController,
                          label: 'Portfolio URL',
                          icon: Icons.link,
                          hint: 'https://your-portfolio.com',
                          keyboardType: TextInputType.url,
                        ),
                        _buildTextField(
                          controller: _socialMediaController,
                          label: 'Social Media',
                          icon: Icons.share,
                          hint: '@username or full URL',
                        ),
                        
                        // Company Information (for vendors and signed creators)
                        if ((_currentProfile?.isVendor ?? false) ||
                            (_currentProfile?.creatorType == 'Signed')) ...[
                          _buildSectionHeader('Company Information'),
                          _buildTextField(
                            controller: _companyNameController,
                            label: 'Company Name',
                            icon: Icons.business,
                            hint: 'Your company name',
                          ),
                          _buildTextField(
                            controller: _companyAddressController,
                            label: 'Company Address',
                            icon: Icons.location_city,
                            hint: 'Full company address',
                            maxLines: 2,
                          ),
                        ],
                        
                        // Tags and Categories
                        _buildTagsSection(),
                        const SizedBox(height: 24),
                        _buildCategoriesSection(),
                        
                        const SizedBox(height: 32),
                        
                        // Save Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 32),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: roleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(MangoRadius.md),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Save Profile Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    _portfolioController.dispose();
    _socialMediaController.dispose();
    _locationController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }
}