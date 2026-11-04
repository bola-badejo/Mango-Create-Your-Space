import 'dart:io';
import 'package:carousel_slider/carousel_options.dart';
import 'package:carousel_slider/carousel_slider.dart' as slider;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/space_model.dart';
import '../controllers/space_controller.dart';

class SpaceLanding extends StatefulWidget {
  const SpaceLanding(this.space, this.spaceStations, {super.key});
  final SpaceModel space;
  final List spaceStations;

  @override
  State<SpaceLanding> createState() => _SpaceLandingState();
}

class _SpaceLandingState extends State<SpaceLanding>
    with SingleTickerProviderStateMixin {
  late int currentIndex;
  late String spaceId;
  late SpaceController _spaceController;
  late String currentUserId;
  bool _isOwnerOrCollaborator = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Map<int, String> _customImages = {};
  Map<int, bool> _isUploading = {};
  Map<int, bool> _isImageLoading = {};

  @override
  void initState() {
    super.initState();
    currentIndex = 0;
    _spaceController = Get.find<SpaceController>();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    spaceId = Get.arguments?['spaceId'] ?? widget.space.id;

    _checkUserPermissions();
    _loadCustomImages();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();
  }

  Future<void> _checkUserPermissions() async {
    final isOwner = widget.space.postCreator == currentUserId;
    final isCollaborator = widget.space.collaborators.contains(currentUserId);

    setState(() {
      _isOwnerOrCollaborator = isOwner || isCollaborator;
    });
  }

  Future<void> _loadCustomImages() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final stationImages = data['stationImages'] as Map<String, dynamic>?;

        if (stationImages != null) {
          setState(() {
            for (int i = 0; i < widget.spaceStations.length; i++) {
              final stationTitle = widget.spaceStations[i]['Title'];
              if (stationImages[stationTitle] != null) {
                _customImages[i] = stationImages[stationTitle];
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading custom images: $e');
    }
  }

  Future<String?> _uploadImageToFirebase(XFile image, int index) async {
    try {
      final stationTitle = widget.spaceStations[index]['Title'];
      final fileName = '${spaceId}_${stationTitle}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('space_stations/$spaceId/$fileName');

      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _updateStationImage(int index, XFile? image) async {
    if (image == null) return;

    setState(() {
      _isUploading[index] = true;
    });

    try {
      final stationTitle = widget.spaceStations[index]['Title'];
      
      final imageUrl = await _uploadImageToFirebase(image, index);
      
      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .update({
            'stationImages.$stationTitle': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _customImages[index] = imageUrl;
      });

      if (mounted) {
        UtilsService().showSnackbar(
          'Success',
          '${stationTitle} image updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        UtilsService().showSnackbar(
          'Error',
          'Failed to update image: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          context: context,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading[index] = false;
        });
      }
    }
  }

  Future<void> _pickImage(int index) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Update Station Image',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.spaceStations[index]['Title'],
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    await _updateStationImage(index, image);
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    await _updateStationImage(index, image);
                  },
                ),
                if (_customImages.containsKey(index))
                  _buildImageSourceOption(
                    icon: Icons.refresh_rounded,
                    label: 'Reset',
                    color: Colors.orange,
                    onTap: () async {
                      Navigator.pop(context);
                      await _resetStationImage(index);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetStationImage(int index) async {
    setState(() {
      _isUploading[index] = true;
    });

    try {
      final stationTitle = widget.spaceStations[index]['Title'];
      
      final oldImageUrl = _customImages[index];
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(oldImageUrl);
          await ref.delete();
        } catch (_) {}
      }

      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .update({
            'stationImages.$stationTitle': FieldValue.delete(),
          });

      setState(() {
        _customImages.remove(index);
      });

      if (mounted) {
        UtilsService().showSnackbar(
          'Success',
          '${stationTitle} image reset to default',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        UtilsService().showSnackbar(
          'Error',
          'Failed to reset image: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          context: context,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading[index] = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            // Background Image with smooth transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: _buildBackgroundImage(),
            ),
            
            // Enhanced Gradient Overlay
            _buildGradientOverlay(),
            
            // Header
            _buildHeader(),
            
            // Stations Carousel
            _buildStationsCarousel(),
            
            // Edit Button
            if (_isOwnerOrCollaborator) _buildEditButton(),
            
            // Page Indicators
            _buildPageIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    final currentStation = widget.spaceStations[currentIndex];
    final customImage = _customImages[currentIndex];
    final defaultImage = currentStation['Image'];
    final imagePath = customImage ?? defaultImage;

    return Container(
      key: ValueKey(imagePath),
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: _buildImageWithLoading(imagePath),
    );
  }

  Widget _buildImageWithLoading(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white.withOpacity(0.5),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey[600],
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load image',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (path.startsWith('/')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey[600],
                size: 48,
              ),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey[600],
                size: 48,
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.5),
              Colors.black.withOpacity(0.2),
              Colors.black.withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.15, 0.35, 0.55, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              
              // Space Title
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.orange[300],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.space.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Menu Button (placeholder)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.38,
      right: 24,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: () => _pickImage(currentIndex),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade400,
                  Colors.orange.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isUploading[currentIndex] == true
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.33,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              widget.spaceStations.length,
              (index) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentIndex == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationsCarousel() {
    if (widget.spaceStations.isEmpty) {
      return Positioned.fill(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rocket_launch_outlined,
                color: Colors.white.withOpacity(0.5),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No stations available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.55,
      child: slider.CarouselSlider(
        options: slider.CarouselOptions(
          height: MediaQuery.of(context).size.height * 0.5,
          viewportFraction: 0.72,
          enlargeCenterPage: true,
          enlargeStrategy: CenterPageEnlargeStrategy.scale,
          onPageChanged: (index, reason) {
            setState(() {
              currentIndex = index;
              _animationController.reset();
              _animationController.forward();
            });
          },
          autoPlay: false,
          enableInfiniteScroll: true,
          pauseAutoPlayOnTouch: true,
          padEnds: false,
        ),
        items: widget.spaceStations.asMap().entries.map((entry) {
          final index = entry.key;
          final station = entry.value;
          final isActive = currentIndex == index;
          final imagePath = _customImages[index] ?? station['Image'];

          return Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () => _navigateToStation(station),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  transform: Matrix4.identity()
                    ..scale(isActive ? 1.0 : 0.92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Card Container
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: isActive ? 2 : 0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Image
                              _buildImageWithLoading(imagePath),
                              
                              // Gradient Overlay on Card
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.black.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                              
                              // Border for active card
                              if (isActive)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              
                              // Active Badge
                              if (isActive)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange.shade400,
                                          Colors.orange.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              // Station Title on Card
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      station['Title'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isActive ? 22 : 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _buildCardStatChip(
                                          icon: Icons.star_rounded,
                                          label: station['rating'] ?? '4.8',
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 10),
                                        _buildCardStatChip(
                                          icon: Icons.favorite_rounded,
                                          label: station['Likes'] ?? '2.4k',
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Description below card
                      if (isActive) ...[
                        const SizedBox(height: 16),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isActive ? 1.0 : 0.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              station['Description'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[300],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToStation(Map<String, dynamic> station) {
    final stationTitle = station['Title'];
    final spaceId = widget.space.id;

    switch (stationTitle) {
      case 'Music':
        Get.toNamed('/space-music', arguments: {'spaceId': spaceId});
        break;
      case 'Books':
        Get.toNamed('/space-library', arguments: {'spaceId': spaceId});
        break;
      case 'Podcasts':
        Get.toNamed('/space-podcasts', arguments: {'spaceId': spaceId});
        break;
      case 'Vines':
        Get.toNamed('/space-vines', arguments: {'spaceId': spaceId});
        break;
      case 'Shop':
        Get.toNamed('/space-shop', arguments: {'spaceId': spaceId});
        break;
      case 'Lounge':
        Get.toNamed('/space-lounge', arguments: {'spaceId': spaceId});
        break;
      default:
        UtilsService().showSnackbar(
          'Coming Soon',
          '$stationTitle feature is coming soon!',
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          context: context,
        );
    }
  }
}