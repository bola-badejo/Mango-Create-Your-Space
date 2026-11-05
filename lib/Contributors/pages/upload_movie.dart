import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Contributors/controllers/movies_upload_controller.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class UploadMoviePage extends StatefulWidget {
  final String? contributorId;

  const UploadMoviePage({super.key, this.contributorId});

  @override
  State<UploadMoviePage> createState() => _UploadMoviePageState();
}

class _UploadMoviePageState extends State<UploadMoviePage>
    with SingleTickerProviderStateMixin {
  late final UploadMovieController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(UploadMovieController(
      contributorId: widget.contributorId,
      userId: FirebaseAuth.instance.currentUser?.uid,
    ));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? MangoPalette.grey900 : MangoPalette.grey50;
    final cardColor = isDark ? MangoPalette.grey800 : Colors.white;
    final textColor = isDark ? Colors.white : MangoPalette.black;

    return WillPopScope(
      onWillPop: () async {
        return await _showExitDialog(context);
      },
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
        'Upload Your Movie',
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
          _buildStep(0, 'Poster', Icons.movie_filter, isDark),
          _buildStepDivider(isDark),
          _buildStep(1, 'Video', Icons.videocam, isDark),
          _buildStepDivider(isDark),
          _buildStep(2, 'Details', Icons.description, isDark),
          _buildStepDivider(isDark),
          _buildStep(3, 'Upload', Icons.cloud_upload, isDark),
        ],
      ),
    );
  }

  Widget _buildStep(int stepNumber, String title, IconData icon, bool isDark) {
    return Obx(() {
      final isActive = _controller.currentStep.value == stepNumber;
      final isCompleted = _controller.currentStep.value > stepNumber;
      final isAccessible = _controller.currentStep.value >= stepNumber;

      return MangoPressable(
        onTap: isAccessible
            ? () => _controller.currentStep.value = stepNumber
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
                            : MangoPalette.grey500.withOpacity(0.2)),
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
      width: 16,
      height: 1,
      color: isDark ? MangoPalette.grey700 : MangoPalette.grey300,
    );
  }

  Widget _buildStepContent(bool isDark, Color cardColor, Color textColor) {
    return Obx(() {
      switch (_controller.currentStep.value) {
        case 0:
          return _buildPosterStep(isDark, cardColor);
        case 1:
          return _buildVideoStep(isDark, cardColor, textColor);
        case 2:
          return _buildDetailsStep(isDark, cardColor, textColor);
        case 3:
          return _buildReviewStep(isDark, cardColor, textColor);
        default:
          return const SizedBox();
      }
    });
  }

  Widget _buildPosterStep(bool isDark, Color cardColor) {
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
                  () => MangoPressable(
                    onTap: _showPosterPicker,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 200,
                      height: 280,
                      decoration: BoxDecoration(
                        color: _controller.isPosterSelected.value
                            ? Colors.transparent
                            : MangoPalette.grey200,
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                        border: Border.all(
                          color: _controller.isPosterSelected.value
                              ? MangoPalette.green500
                              : MangoPalette.grey300,
                          width: 2,
                        ),
                        image: _controller.selectedPoster.value != null
                            ? DecorationImage(
                                image: FileImage(
                                  File(_controller.selectedPoster.value!.path),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _controller.selectedPoster.value == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.movie_filter,
                                  size: 48,
                                  color: MangoPalette.grey400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Add Movie Poster',
                                  style: TextStyle(
                                    color: MangoPalette.grey600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
        tooltip: 'Close',
                                      icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                      onPressed: _controller.removePoster,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Upload Movie Poster',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a high-quality poster image for best results',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildBackdropUploadSection(isDark, cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropUploadSection(bool isDark, Color cardColor) {
    return Obx(
      () => Column(
        children: [
          Text(
            'Optional: Backdrop Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : MangoPalette.black,
            ),
          ),
          const SizedBox(height: 16),
          MangoPressable(
            onTap: () => _controller.pickBackdrop(context),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: _controller.selectedBackdrop.value != null
                    ? Colors.transparent
                    : MangoPalette.grey100,
                borderRadius: BorderRadius.circular(MangoRadius.md),
                border: Border.all(
                  color: _controller.selectedBackdrop.value != null
                      ? MangoPalette.green500
                      : MangoPalette.grey300,
                  width: 2,
                ),
                image: _controller.selectedBackdrop.value != null
                    ? DecorationImage(
                        image: FileImage(
                          File(_controller.selectedBackdrop.value!.path),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _controller.selectedBackdrop.value == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 32,
                          color: MangoPalette.grey400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Backdrop (16:9)',
                          style: TextStyle(
                            color: MangoPalette.grey600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: IconButton(
        tooltip: 'Close',
                              icon: const Icon(Icons.close, size: 14, color: Colors.white),
                              onPressed: _controller.removeBackdrop,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoStep(bool isDark, Color cardColor, Color textColor) {
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
                      color: _controller.isVideoSelected.value
                          ? MangoPalette.green500.withOpacity(0.1)
                          : MangoPalette.green500.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                      border: Border.all(
                        color: _controller.isVideoSelected.value
                            ? MangoPalette.green500
                            : MangoPalette.green500,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _controller.isVideoSelected.value
                              ? Icons.check_circle
                              : Icons.videocam,
                          size: 48,
                          color: _controller.isVideoSelected.value
                              ? MangoPalette.green500
                              : MangoPalette.green500,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _controller.isVideoSelected.value
                              ? 'Video Ready!'
                              : 'Upload Your Movie',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.isVideoSelected.value
                              ? 'Your movie has been selected and processed'
                              : 'Choose your video file to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                          ),
                        ),
                        if (_controller.uploadProgress.value > 0 && _controller.uploadProgress.value < 1) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(semanticsLabel: 'Loading', 
                            value: _controller.uploadProgress.value,
                            backgroundColor: MangoPalette.grey300,
                            color: MangoPalette.green500,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: MangoPalette.green500,
                            ),
                          ),
                        ],
                        if (_controller.downloadUrl.value.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MangoPalette.green500.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(MangoRadius.sm),
                            ),
                            child: const Text(
                              'Upload Complete ✓',
                              style: TextStyle(
                                fontSize: 12,
                                color: MangoPalette.green500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _controller.isUploading.value || (_controller.isVideoSelected.value && _controller.downloadUrl.value.isNotEmpty)
                      ? null
                      : () => _controller.pickAndUploadVideo(context),
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
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    _controller.isUploading.value
                        ? 'Uploading...'
                        : (_controller.isVideoSelected.value && _controller.downloadUrl.value.isNotEmpty
                            ? 'Video Uploaded ✓'
                            : 'Choose Video File'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported: MP4, MOV, MKV, AVI (Max: 5GB)',
                  style: TextStyle(
                    color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildTrailerUploadSection(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailerUploadSection(bool isDark) {
    return Obx(
      () => Column(
        children: [
          Text(
            'Optional: Trailer Video',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : MangoPalette.black,
            ),
          ),
          const SizedBox(height: 16),
          MangoPressable(
            onTap: () => _controller.pickTrailer(context),
            child: Container(
              width: double.infinity,
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _controller.selectedTrailer.value != null
                    ? MangoPalette.green500.withOpacity(0.1)
                    : MangoPalette.grey100,
                borderRadius: BorderRadius.circular(MangoRadius.md),
                border: Border.all(
                  color: _controller.selectedTrailer.value != null
                      ? MangoPalette.green500
                      : MangoPalette.grey300,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill,
                    size: 32,
                    color: _controller.selectedTrailer.value != null
                        ? MangoPalette.green500
                        : MangoPalette.grey400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _controller.selectedTrailer.value != null
                              ? 'Trailer Selected'
                              : 'Add Trailer Video',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : MangoPalette.black,
                          ),
                        ),
                        Text(
                          _controller.selectedTrailer.value != null
                              ? 'Ready to upload'
                              : 'Optional promotional video',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_controller.selectedTrailer.value != null)
                    IconButton(
        tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: _controller.removeTrailer,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                  'Movie Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  'Movie Title *',
                  Icons.title,
                  _controller.titleController,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Description',
                  Icons.description,
                  _controller.descriptionController,
                  maxLines: 3,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Director *',
                  Icons.person,
                  _controller.directorController,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Genre *',
                  Icons.category,
                  _controller.genres,
                  _controller.genreController,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Release Year *',
                  Icons.calendar_today,
                  _controller.releaseYearController,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Language',
                  Icons.language,
                  _controller.languages,
                  _controller.languageController,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Runtime (minutes)',
                  Icons.timer,
                  _controller.runtimeController,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildRatingDropdown(isDark),
                const SizedBox(height: 16),
                _buildAdvancedDetailsSection(isDark, textColor),
                const SizedBox(height: 24),
                _buildCreditsSection(isDark, textColor),
                const SizedBox(height: 8),
                Text(
                  '* Required fields',
                  style: TextStyle(
                    color: MangoPalette.grey600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedDetailsSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildModernDropdown(
          'Video Quality',
          Icons.hd,
          _controller.videoQualities,
          _controller.videoQualityController,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          'Production Company',
          Icons.business,
          _controller.productionCompanyController,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                'Budget',
                Icons.attach_money,
                _controller.budgetController,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernTextField(
                'Revenue',
                Icons.money,
                _controller.revenueController,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildModernDropdown(
          'Country',
          Icons.flag,
          _controller.countries,
          _controller.countryController,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          'Audio Language',
          Icons.audiotrack,
          _controller.audioLanguageController,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildSubtitlesSection(isDark, textColor),
        const SizedBox(height: 16),
        _buildSwitchTile(
          'Feature this movie',
          Icons.featured_play_list,
          _controller.isFeatured.value,
          (value) => _controller.isFeatured.value = value,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSubtitlesSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSwitchTile(
          'Has Subtitles',
          Icons.subtitles,
          _controller.hasSubtitles.value,
          (value) => _controller.hasSubtitles.value = value,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        if (_controller.hasSubtitles.value) ...[
          Text(
            'Available Subtitle Languages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _controller.languages.map((language) {
              final isSelected = _controller.subtitles.contains(language);
              return FilterChip(
                label: Text(language),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _controller.addSubtitle(language);
                  } else {
                    _controller.removeSubtitle(language);
                  }
                },
                checkmarkColor: Colors.white,
                selectedColor: MangoPalette.green500,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : textColor,
                ),
              );
            }).toList(),
          ),
          if (_controller.subtitles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Selected: ${_controller.subtitles.join(', ')}',
              style: TextStyle(fontSize: 12, color: MangoPalette.green500),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRatingDropdown(bool isDark) {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: _controller.ratingController.text.isEmpty
            ? null
            : _controller.ratingController.text,
        items: _controller.popularRatings.map((String value) {
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
          _controller.ratingController.text = newValue ?? '';
          _controller.validateDetails();
        },
        decoration: InputDecoration(
          labelText: 'Rating',
          labelStyle: TextStyle(
            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
          ),
          prefixIcon: const Icon(Icons.star, color: MangoPalette.green500),
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

  Widget _buildModernTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool isDark = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => _controller.validateDetails(),
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
    TextEditingController controller, {
    bool isDark = false,
  }) {
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? null : controller.text,
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
        controller.text = newValue ?? '';
        _controller.validateDetails();
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
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: MangoPalette.grey400),
      ),
      child: Row(
        children: [
          Icon(icon, color: MangoPalette.green500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : MangoPalette.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: MangoPalette.green500,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cast & Crew',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  'Add actors, producers,\nand crew members',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddCreditModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: MangoPalette.green500,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Member'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(
          () => _controller.credits.isEmpty
              ? _buildEmptyCreditsState(isDark, textColor)
              : _buildCreditsList(isDark, textColor),
        ),
      ],
    );
  }

  Widget _buildEmptyCreditsState(bool isDark, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: MangoPalette.grey500.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.people, size: 48, color: MangoPalette.grey500.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No cast & crew added yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add actors, directors, and crew members',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsList(bool isDark, Color textColor) {
    return Column(
      children: _controller.credits.asMap().entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: Key('credit-${entry.key}'),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            confirmDismiss: (direction) async {
              return await _showDeleteConfirmation(entry.key);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? MangoPalette.grey800 : Colors.white,
                borderRadius: BorderRadius.circular(MangoRadius.md),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRoleIcon(entry.value['role'] ?? ''),
                      color: Colors.blue,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value['role'] ?? 'Unknown Role',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value['name'] ?? 'Unknown Name',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
        tooltip: 'Edit',
                    icon: Icon(
                      Icons.edit,
                      size: 16,
                      color: MangoPalette.grey500.withOpacity(0.6),
                    ),
                    onPressed: () => _editCredit(entry.key),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddCreditModal() {
    final roleController = TextEditingController();
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MangoPalette.grey500.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(MangoRadius.xs),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Cast/Crew Member',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  hintText: 'Actor, Director, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Person name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final role = roleController.text.trim();
                    final name = nameController.text.trim();

                    if (role.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill both fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    _controller.addCredit(role, name);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MangoPalette.green500,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Add Member'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _editCredit(int index) {
    final credit = _controller.credits[index];
    final roleController = TextEditingController(text: credit['role'] ?? '');
    final nameController = TextEditingController(text: credit['name'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MangoPalette.grey500.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(MangoRadius.xs),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Member',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final role = roleController.text.trim();
                    final name = nameController.text.trim();

                    if (role.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill both fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    _controller.updateCredit(index, role, name);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MangoPalette.green500,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Update Member'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Remove ${_controller.credits[index]['name']} as ${_controller.credits[index]['role']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      _controller.removeCredit(index);
    }
    return result ?? false;
  }

  IconData _getRoleIcon(String role) {
    final roleLower = role.toLowerCase();
    if (roleLower.contains('director')) return Icons.movie_creation;
    if (roleLower.contains('actor') || roleLower.contains('actress'))
      return Icons.person;
    if (roleLower.contains('producer')) return Icons.business_center;
    if (roleLower.contains('writer')) return Icons.edit;
    if (roleLower.contains('cinematographer')) return Icons.camera;
    if (roleLower.contains('editor')) return Icons.cut;
    if (roleLower.contains('composer')) return Icons.music_note;
    return Icons.person;
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
                  const Icon(Icons.task_alt, size: 64, color: MangoPalette.green500),
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
                  Text(
                    'Review your movie details before uploading',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPosterPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildVideoPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    'Title',
                    _controller.titleController.text,
                    Icons.title,
                  ),
                  _buildReviewItem(
                    'Director',
                    _controller.directorController.text,
                    Icons.person,
                  ),
                  _buildReviewItem(
                    'Genre',
                    _controller.genreController.text,
                    Icons.category,
                  ),
                  _buildReviewItem(
                    'Release Year',
                    _controller.releaseYearController.text,
                    Icons.calendar_today,
                  ),
                  _buildReviewItem(
                    'Language',
                    _controller.languageController.text,
                    Icons.language,
                  ),
                  if (_controller.runtimeController.text.isNotEmpty)
                    _buildReviewItem(
                      'Runtime',
                      '${_controller.runtimeController.text} minutes',
                      Icons.timer,
                    ),
                  if (_controller.ratingController.text.isNotEmpty)
                    _buildReviewItem(
                      'Rating',
                      _controller.ratingController.text,
                      Icons.star,
                    ),
                  if (_controller.videoQualityController.text.isNotEmpty)
                    _buildReviewItem(
                      'Video Quality',
                      _controller.videoQualityController.text,
                      Icons.hd,
                    ),
                  if (_controller.credits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Cast & Crew',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._controller.credits.map(
                      (credit) => _buildReviewItem(
                        credit['role']!,
                        credit['name']!,
                        Icons.person,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_controller.isUploading.value)
                    Column(
                      children: [
                        LinearProgressIndicator(semanticsLabel: 'Loading', value: _controller.uploadProgress.value),
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

  Widget _buildPosterPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: _controller.selectedPoster.value != null
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
                  Icons.movie_filter,
                  color: _controller.selectedPoster.value != null
                      ? MangoPalette.green500
                      : MangoPalette.grey500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Movie Poster',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_controller.selectedPoster.value != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MangoPalette.green500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, color: MangoPalette.green500, size: 10),
                        SizedBox(width: 4),
                        Text(
                          'Ready',
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
            if (_controller.selectedPoster.value != null)
              _buildPosterImagePreview(isDark)
            else
              _buildPosterEmptyState(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterImagePreview(bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            image: DecorationImage(
              image: FileImage(File(_controller.selectedPoster.value!.path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _controller.selectedPoster.value!.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Poster selected',
                style: TextStyle(fontSize: 12, color: MangoPalette.grey600),
              ),
            ],
          ),
        ),
        IconButton(
        tooltip: 'Delete',
          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
          onPressed: _controller.removePoster,
        ),
      ],
    );
  }

  Widget _buildPosterEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 112,
          decoration: BoxDecoration(
            color: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            border: Border.all(color: MangoPalette.grey500.withOpacity(0.3)),
          ),
          child: Icon(
            Icons.movie_filter,
            color: MangoPalette.grey500.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No poster selected',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildVideoPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: _controller.selectedVideoFilePath.value.isNotEmpty || _controller.downloadUrl.value.isNotEmpty
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
                  Icons.videocam,
                  color: _controller.selectedVideoFilePath.value.isNotEmpty || _controller.downloadUrl.value.isNotEmpty
                      ? MangoPalette.green500
                      : MangoPalette.grey500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Movie Video',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_controller.selectedVideoFilePath.value.isNotEmpty || _controller.downloadUrl.value.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MangoPalette.green500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, color: MangoPalette.green500, size: 10),
                        SizedBox(width: 4),
                        Text(
                          'Ready',
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
            if (_controller.selectedVideoFilePath.value.isNotEmpty || _controller.downloadUrl.value.isNotEmpty)
              _buildVideoFilePreview(isDark, textColor)
            else
              _buildVideoEmptyState(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFilePreview(bool isDark, Color textColor) {
    final fileName = _controller.selectedVideoFilePath.value.isNotEmpty
        ? _controller.selectedVideoFilePath.value.split('/').last
        : 'Uploaded video';

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: MangoPalette.green500.withOpacity(0.1),
            borderRadius: BorderRadius.circular(MangoRadius.sm),
          ),
          child: const Icon(Icons.videocam, color: MangoPalette.green500, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Video file selected',
                style: TextStyle(fontSize: 12, color: MangoPalette.grey600),
              ),
            ],
          ),
        ),
        IconButton(
        tooltip: 'Delete',
          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
          onPressed: () {
            _controller.selectedVideoFilePath.value = '';
            _controller.downloadUrl.value = '';
            _controller.isVideoSelected.value = false;
          },
        ),
      ],
    );
  }

  Widget _buildVideoEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            border: Border.all(color: MangoPalette.grey500.withOpacity(0.3)),
          ),
          child: Icon(
            Icons.videocam,
            color: MangoPalette.grey500.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No video file selected',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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

  Widget _buildNavigationButtons(bool isDark) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep.value > 0)
            ElevatedButton(
              onPressed: _controller.goToPreviousStep,
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
            onPressed: _controller.isStepValid.value && !_controller.isUploading.value
                ? _controller.goToNextStep
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _controller.isStepValid.value && !_controller.isUploading.value
                  ? MangoPalette.green500
                  : MangoPalette.grey500,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
            ),
            child: Text(
              _controller.currentStep.value == 3
                  ? (_controller.isUploading.value ? 'Uploading...' : 'Upload 🚀')
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

  void _showPosterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: MangoPalette.green500),
              title: const Text('Choose from Gallery'),
              onTap: () {
                _controller.pickPoster(context);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: MangoPalette.green500),
              title: const Text('Take a Photo'),
              onTap: () async {
                try {
                  final image = await _controller.picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    _controller.selectedPoster.value = image;
                    _controller.isPosterSelected.value = true;
                  }
                } catch (e) {
                  UtilsService().showSnackbar('Error', 'Could not access camera', context: context);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    
    if (_controller.currentStep.value == 0 &&
        !_controller.isPosterSelected.value &&
        !_controller.isVideoSelected.value &&
        _controller.titleController.text.isEmpty &&
        _controller.directorController.text.isEmpty) {
      return true;
    }

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
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
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
                              color: Theme.of(context).textTheme.bodyLarge?.color,
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