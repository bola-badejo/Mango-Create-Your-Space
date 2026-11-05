import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Contributors/controllers/upload_product_controller.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class UploadProductPage extends StatefulWidget {
  final String? contributorId;

  const UploadProductPage({super.key, required this.contributorId});

  @override
  State<UploadProductPage> createState() => _UploadProductPageState();
}

class _UploadProductPageState extends State<UploadProductPage>
    with SingleTickerProviderStateMixin {
  late final UploadProductController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      UploadProductController(
        contributorId: widget.contributorId,
        userId: FirebaseAuth.instance.currentUser?.uid,
      ),
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    Get.delete<UploadProductController>();
    super.dispose();
  }

  void _updateStepValidation() {
    switch (_controller.currentStep.value) {
      case 0:
        _controller.isStepValid.value = _controller.areImagesSelected.value;
        break;
      case 1:
        _controller.isStepValid.value = _controller.areDetailsComplete.value;
        break;
      case 2:
        _controller.isStepValid.value = _controller.areVariantsComplete.value;
        break;
      case 3:
        _controller.isStepValid.value = true;
        break;
    }
  }

  void _goToNextStep(context) {
    if (_controller.currentStep.value < 3 && _controller.isStepValid.value) {
      _controller.currentStep.value++;
      _updateStepValidation();
    } else if (_controller.currentStep.value == 3) {
      _controller.uploadProduct(context);
    }
  }

  void _goToPreviousStep() {
    if (_controller.currentStep.value > 0) {
      _controller.currentStep.value--;
      _updateStepValidation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? MangoPalette.grey900 : MangoPalette.grey50;
    final cardColor = isDark ? MangoPalette.grey800 : Colors.white;
    final textColor = isDark ? Colors.white : MangoPalette.black;

    return WillPopScope(
      onWillPop: () async => await _showExitDialog(context),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(isDark, textColor),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildHorizontalStepper(isDark),
                const SizedBox(height: 32),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _buildStepContent(isDark, cardColor, textColor),
                  ),
                ),
                _buildNavigationButtons(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, Color textColor) {
    return AppBar(
      title: const Text(
        'Upload Mango Product',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textColor),
      actions: [
        Obx(
          () => _controller.isUploading.value
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Lottie.asset(
                    'assets/loading.json',
                    width: 30,
                    height: 30,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildHorizontalStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStep(0, 'Images', Icons.photo_library, isDark),
          _buildStepDivider(isDark),
          _buildStep(1, 'Details', Icons.description, isDark),
          _buildStepDivider(isDark),
          _buildStep(2, 'Variants', Icons.style, isDark),
          _buildStepDivider(isDark),
          _buildStep(3, 'Review', Icons.task_alt, isDark),
        ],
      ),
    );
  }

  Widget _buildStep(int stepNumber, String title, IconData icon, bool isDark) {
    return Obx(() {
      final isActive = _controller.currentStep.value == stepNumber;
      final isCompleted = _controller.currentStep.value > stepNumber;
      final isAccessible = _controller.currentStep.value >= stepNumber;

      bool isStepValid = false;
      switch (stepNumber) {
        case 0:
          isStepValid = _controller.areImagesSelected.value;
          break;
        case 1:
          isStepValid = _controller.areDetailsComplete.value;
          break;
        case 2:
          isStepValid = _controller.areVariantsComplete.value;
          break;
        case 3:
          isStepValid = true;
          break;
      }

      return MangoPressable(
        onTap: isAccessible
            ? () {
                _controller.currentStep.value = stepNumber;
                _updateStepValidation();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? MangoPalette.green500.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: isActive
                ? Border.all(color: MangoPalette.green500.withOpacity(0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? MangoPalette.green500
                      : (isActive
                            ? MangoPalette.green500
                            : (isStepValid &&
                                      stepNumber < _controller.currentStep.value
                                  ? MangoPalette.green500.withOpacity(0.5)
                                  : MangoPalette.grey500.withOpacity(0.2))),
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
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isDark ? Colors.white : MangoPalette.black,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStepDivider(bool isDark) {
    return Container(
      width: 12,
      height: 1,
      color: isDark ? MangoPalette.grey700 : MangoPalette.grey300,
    );
  }

  Widget _buildStepContent(bool isDark, Color cardColor, Color textColor) {
    return Obx(() {
      switch (_controller.currentStep.value) {
        case 0:
          return _buildImagesStep(isDark, cardColor);
        case 1:
          return _buildDetailsStep(isDark, cardColor, textColor);
        case 2:
          return _buildVariantsStep(isDark, cardColor, textColor);
        case 3:
          return _buildReviewStep(isDark, cardColor, textColor);
        default:
          return const SizedBox();
      }
    });
  }

  Widget _buildImagesStep(bool isDark, Color cardColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Obx(
                  () => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _controller.areImagesSelected.value
                          ? MangoPalette.green500.withOpacity(0.1)
                          : MangoPalette.green500.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                      border: Border.all(
                        color: _controller.areImagesSelected.value
                            ? MangoPalette.green500
                            : MangoPalette.green500,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _controller.areImagesSelected.value
                              ? Icons.check_circle
                              : Icons.photo_library,
                          size: 48,
                          color: _controller.areImagesSelected.value
                              ? MangoPalette.green500
                              : MangoPalette.green500,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _controller.areImagesSelected.value
                              ? '${_controller.selectedImages.length} Images Ready!'
                              : 'Add Product Images',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : MangoPalette.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.areImagesSelected.value
                              ? 'Your product images have been selected'
                              : 'Choose multiple images to showcase your product from different angles',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _controller.pickImages(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MangoPalette.green500,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                  ),
                  icon: const Icon(
                    Icons.add_photo_alternate,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Select Images',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => _controller.selectedImages.isNotEmpty
                      ? _buildImageGrid(isDark)
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Selected Images (${_controller.selectedImages.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : MangoPalette.black,
          ),
        ),
        const SizedBox(height: 12),
        OptimizedGridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _controller.selectedImages.length,
          itemBuilder: (context, index) {
            return _buildImageThumbnail(
              _controller.selectedImages[index],
              index,
              isDark,
            );
          },
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(XFile image, int index, bool isDark) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            color: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            child: Image.file(
              File(image.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: MangoPressable(
            onTap: () => _controller.removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: MangoPalette.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(MangoRadius.sm),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Product Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  'Product Title *',
                  Icons.title,
                  (value) => _controller.setTitle(value),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Description',
                  Icons.description,
                  _controller.setDescription,
                  maxLines: 3,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Brand *',
                  Icons.business,
                  _controller.setBrand,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'SKU *',
                  Icons.confirmation_number,
                  _controller.setSku,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Category *',
                  Icons.category,
                  _controller.categories,
                  _controller.category,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        'Price *',
                        Icons.attach_money,
                        _controller.setPrice,
                        isDark: isDark,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernTextField(
                        'Sale Price',
                        Icons.local_offer,
                        _controller.setSalePrice,
                        isDark: isDark,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        'Stock *',
                        Icons.inventory_2,
                        _controller.setStock,
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernTextField(
                        'Weight (kg)',
                        Icons.scale,
                        _controller.setWeight,
                        isDark: isDark,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTagsSection(isDark, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Icon(Icons.local_offer, color: MangoPalette.green500, size: 20),
            const SizedBox(width: 8),
            Text(
              'Product Tags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select tags to help customers find your product',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _controller.availableTags.map((tag) {
              final isSelected = _controller.tags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) => _controller.toggleTag(tag),
                backgroundColor: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
                selectedColor: MangoPalette.green500.withOpacity(0.2),
                checkmarkColor: MangoPalette.green500,
                labelStyle: TextStyle(
                  color: isSelected
                      ? MangoPalette.green500
                      : (isDark ? Colors.white : MangoPalette.black),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => _controller.tags.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Selected: ${_controller.tags.join(", ")}',
                    style: TextStyle(
                      fontSize: 12,
                      color: MangoPalette.green500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildVariantsStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
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
                Text(
                  'Product Variants',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add colors and sizes to create product variants',
                  style: TextStyle(
                    color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
                const SizedBox(height: 24),

                _buildVariantSection(
                  'Colors',
                  Icons.palette,
                  _controller.colorOptions,
                  _controller.selectedColors,
                  _controller.toggleColor,
                  isDark,
                ),
                const SizedBox(height: 24),

                _buildVariantSection(
                  'Sizes',
                  Icons.straighten,
                  _controller.sizeOptions,
                  _controller.selectedSizes,
                  _controller.toggleSize,
                  isDark,
                ),
                const SizedBox(height: 24),

                Obx(
                  () => _controller.hasVariants
                      ? _buildVariantsList(isDark, textColor)
                      : _buildSimpleProductNotice(isDark, textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSection(
    String title,
    IconData icon,
    List<String> options,
    RxList<String> selectedOptions,
    Function(String) onToggle,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: MangoPalette.green500),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : MangoPalette.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedOptions.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) => onToggle(option),
              backgroundColor: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
              selectedColor: MangoPalette.green500.withOpacity(0.2),
              checkmarkColor: MangoPalette.green500,
              labelStyle: TextStyle(
                color: isSelected
                    ? MangoPalette.green500
                    : (isDark ? Colors.white : MangoPalette.black),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVariantsList(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generated Variants (${_controller.variants.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        ..._controller.variants.map(
          (variant) => _buildVariantCard(variant, isDark, textColor),
        ),
      ],
    );
  }

  Widget _buildVariantCard(
    ProductVariant variant,
    bool isDark,
    Color textColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? MangoPalette.grey700 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  variant.attributes.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(' | '),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: variant.inStock
                        ? MangoPalette.green500.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                  ),
                  child: Text(
                    variant.inStock ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      color: variant.inStock ? MangoPalette.green500 : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'SKU: ${variant.sku}',
              style: TextStyle(
                color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                      text: variant.stockQuantity.toString(),
                    ),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Stock',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                    ),
                    onChanged: (value) {
                      final stock = int.tryParse(value) ?? 0;
                      _controller.updateVariantStock(variant.id, stock);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                      text: variant.price.toStringAsFixed(2),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                    ),
                    onChanged: (value) {
                      final price = double.tryParse(value) ?? 0.0;
                      _controller.updateVariantPrice(variant.id, price);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleProductNotice(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This will be a simple product without variants. '
              'Select colors or sizes above to create variants with different SKUs and pricing.',
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Obx(
              () => Column(
                children: [
                  Icon(Icons.task_alt, size: 64, color: MangoPalette.green500),
                  const SizedBox(height: 16),
                  Text(
                    'Ready to Upload!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Review your Mango product details before uploading',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildImagesPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    'Title',
                    _controller.title.value,
                    Icons.title,
                  ),
                  _buildReviewItem(
                    'Brand',
                    _controller.brand.value,
                    Icons.business,
                  ),
                  _buildReviewItem(
                    'SKU',
                    _controller.sku.value,
                    Icons.confirmation_number,
                  ),
                  _buildReviewItem(
                    'Category',
                    _controller.category.value,
                    Icons.category,
                  ),
                  _buildReviewItem(
                    'Price',
                    '₦${_controller.price.value.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                  if (_controller.onSale)
                    _buildReviewItem(
                      'Sale Price',
                      '₦${_controller.salePrice.value.toStringAsFixed(2)}',
                      Icons.local_offer,
                    ),
                  _buildReviewItem(
                    'Stock',
                    _controller.stockQuantity.value.toString(),
                    Icons.inventory_2,
                  ),
                  if (_controller.weight.value > 0)
                    _buildReviewItem(
                      'Weight',
                      '${_controller.weight.value} kg',
                      Icons.scale,
                    ),
                  if (_controller.description.value.isNotEmpty)
                    _buildReviewItem(
                      'Description',
                      _controller.description.value,
                      Icons.description,
                    ),
                  if (_controller.tags.isNotEmpty)
                    _buildReviewItem(
                      'Tags',
                      _controller.tags.join(', '),
                      Icons.local_offer,
                    ),
                  if (_controller.hasVariants) ...[
                    const SizedBox(height: 16),
                    _buildVariantsSummary(isDark, textColor),
                  ],
                  const SizedBox(height: 32),
                  if (_controller.isUploading.value)
                    Column(
                      children: [
                        LinearProgressIndicator(semanticsLabel: 'Loading', 
                          value: _controller.uploadProgress.value,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uploading... ${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSummary(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey700 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variants Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_controller.variants.length} variants generated',
            style: TextStyle(
              color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _controller.variants.take(5).map((variant) {
              return Chip(
                label: Text(
                  variant.attributes.entries.map((e) => e.value).join(' / '),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: MangoPalette.green500.withOpacity(0.1),
              );
            }).toList(),
          ),
          if (_controller.variants.length > 5)
            Text(
              '+ ${_controller.variants.length - 5} more variants...',
              style: TextStyle(
                color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagesPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: _controller.selectedImages.isNotEmpty
                ? MangoPalette.green500.withOpacity(0.3)
                : MangoPalette.grey500.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library,
                  color: _controller.selectedImages.isNotEmpty
                      ? MangoPalette.green500
                      : MangoPalette.grey500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Product Images',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_controller.selectedImages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MangoPalette.green500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check, color: MangoPalette.green500, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          '${_controller.selectedImages.length} images',
                          style: TextStyle(
                            fontSize: 12,
                            color: MangoPalette.green500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_controller.selectedImages.isEmpty)
              _buildImagesEmptyState(isDark, textColor)
            else
              _buildImagesGridPreview(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesGridPreview(bool isDark) {
    return OptimizedGridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: _controller.selectedImages.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            image: DecorationImage(
              image: FileImage(File(_controller.selectedImages[index].path)),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagesEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            border: Border.all(
              color: MangoPalette.grey500.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            Icons.photo_library,
            color: MangoPalette.grey500.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No images selected',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep.value > 0)
            ElevatedButton(
              onPressed: _goToPreviousStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  color: isDark ? Colors.white : MangoPalette.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 100),

          ElevatedButton(
            onPressed:
                _controller.isStepValid.value && !_controller.isUploading.value
                ? () => _goToNextStep(context)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _controller.isStepValid.value &&
                      !_controller.isUploading.value
                  ? MangoPalette.green500
                  : MangoPalette.grey500,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
            ),
            child: Text(
              _controller.currentStep.value == 3
                  ? (_controller.isUploading.value
                        ? 'Uploading...'
                        : 'Upload 🚀')
                  : 'Continue',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    IconData icon,
    Function(String) onChanged, {
    int maxLines = 1,
    bool isDark = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      onChanged: (value) {
        onChanged(value);
        _updateStepValidation();
      },
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : MangoPalette.black,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
        ),
        prefixIcon: Icon(icon, color: MangoPalette.green500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: BorderSide(color: MangoPalette.grey400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: const BorderSide(color: MangoPalette.green500),
        ),
        filled: true,
        fillColor: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
      ),
    );
  }

  Widget _buildModernDropdown(
    String label,
    IconData icon,
    List<String> items,
    RxString selectedValue, {
    bool isDark = false,
  }) {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: selectedValue.value.isEmpty ? null : selectedValue.value,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : MangoPalette.black,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          selectedValue.value = newValue ?? '';
          _controller.validateDetails();
          _updateStepValidation();
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
          ),
          prefixIcon: Icon(icon, color: MangoPalette.green500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            borderSide: BorderSide(color: MangoPalette.grey400),
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

  Widget _buildReviewItem(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MangoPalette.grey100,
        borderRadius: BorderRadius.circular(MangoRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: MangoPalette.green500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: MangoPalette.grey500),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: MangoPalette.black.withOpacity(0.4),
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(MangoRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: MangoPalette.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Discard Upload?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your progress will be lost. This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.md),
                            ),
                            side: BorderSide(
                              color: MangoPalette.grey500.withOpacity(0.3),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back, size: 14),
                          label: Text(
                            'Continue',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _controller.reset();
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.md),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.delete,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Discard',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }
}