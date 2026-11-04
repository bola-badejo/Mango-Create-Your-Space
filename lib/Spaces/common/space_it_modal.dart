import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Spaces/controllers/space_controller.dart';
import 'package:mango/utils.dart';
import 'package:mango/Utils/optimized_lists.dart';

class SpaceItModal extends StatefulWidget {
  final String itemId;
  final String itemType;
  final Map<String, dynamic> itemData;
  final VoidCallback? onSuccess;
  final VoidCallback? onError;

  const SpaceItModal({
    Key? key,
    required this.itemId,
    required this.itemType,
    required this.itemData,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  @override
  State<SpaceItModal> createState() => _SpaceItModalState();
}

class _SpaceItModalState extends State<SpaceItModal> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpaceController _spaceController = Get.find<SpaceController>();
  
  List<String> _selectedSpaces = [];
  int _selectedSegment = 0; // 0 = Private, 1 = Featured
  List<Map<String, dynamic>> _privateSpaces = [];
  List<Map<String, dynamic>> _featuredSpaces = [];
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Load private spaces (user is creator)
      final privateSnapshot = await _firestore
          .collection('spaces')
          .where('postCreator', isEqualTo: currentUserId)
          .orderBy('timeStamp', descending: true)
          .get();

      // Load featured spaces (user is collaborator)
      final featuredSnapshot = await _firestore
          .collection('spaces')
          .where('collaborators', arrayContains: currentUserId)
          .orderBy('timeStamp', descending: true)
          .get();

      setState(() {
        _privateSpaces = privateSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Untitled Space',
            'category': data['category'] ?? 'General',
            'members': data['members'] ?? 0,
            'isPrivate': data['isPrivate'] ?? false,
            'image': data['image'] ?? '',
            'iconUrl': data['iconUrl'] ?? '',
          };
        }).toList();

        _featuredSpaces = featuredSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Untitled Space',
            'category': data['category'] ?? 'General',
            'members': data['members'] ?? 0,
            'isPrivate': data['isPrivate'] ?? false,
            'image': data['image'] ?? '',
            'iconUrl': data['iconUrl'] ?? '',
          };
        }).toList();

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading spaces: $e');
      setState(() {
        _isLoading = false;
      });
      if (widget.onError != null) widget.onError!();
    }
  }

  void _toggleSpaceSelection(String spaceId) {
    setState(() {
      if (_selectedSpaces.contains(spaceId)) {
        _selectedSpaces.remove(spaceId);
      } else {
        _selectedSpaces.add(spaceId);
      }
    });
  }

  Future<void> _saveToSpaces() async {
    if (_selectedSpaces.isEmpty) {
      UtilsService().showSnackbar(
        'No Spaces Selected',
        'Please select at least one space',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      int successCount = 0;
      int failCount = 0;

      for (final spaceId in _selectedSpaces) {
        try {
          await _saveItemToSpace(spaceId);
          successCount++;
        } catch (e) {
          print('Error saving to space $spaceId: $e');
          failCount++;
        }
      }

      if (mounted) {
        Get.back(); // Close modal
        
        if (failCount == 0) {
          UtilsService().showSnackbar(
            'Success! ✨',
            '${StringExtension(widget.itemType).capitalizeFirst()} added to $successCount space(s)',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            context: context,
          );
          if (widget.onSuccess != null) widget.onSuccess!();
        } else if (successCount > 0) {
          UtilsService().showSnackbar(
            'Partial Success',
            'Added to $successCount space(s), failed for $failCount',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            context: context,
          );
        } else {
          throw Exception('Failed to add to any spaces');
        }
      }
    } catch (e) {
      if (mounted) {
        UtilsService().showSnackbar(
          'Error',
          'Failed to save item: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          context: context,
        );
        if (widget.onError != null) widget.onError!();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveItemToSpace(String spaceId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    final collectionName = _getCollectionName(widget.itemType);
    
    // Check if item already exists in space
    final existingItem = await _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection(collectionName)
        .where('originalItemId', isEqualTo: widget.itemId)
        .limit(1)
        .get();

    if (existingItem.docs.isNotEmpty) {
      throw Exception('Item already exists in this space');
    }
    
    final itemData = {
      ...widget.itemData,
      'spaceId': spaceId,
      'savedBy': currentUserId,
      'savedAt': FieldValue.serverTimestamp(),
      'itemType': widget.itemType,
      'originalItemId': widget.itemId,
    };

    await _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection(collectionName)
        .add(itemData);
    
    // Also update the space's total items count if needed
    await _updateSpaceItemCount(spaceId, collectionName);
  }

  Future<void> _updateSpaceItemCount(String spaceId, String collectionName) async {
    final snapshot = await _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection(collectionName)
        .count()
        .get();
    
    await _firestore.collection('spaces').doc(spaceId).update({
      '${collectionName}Count': snapshot.count,
    });
  }

  String _getCollectionName(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'music':
        return 'space-music';
      case 'book':
        return 'space-books';
      case 'podcast':
        return 'space-podcasts';
      case 'product':
        return 'space-products';
      case 'vine':
      case 'video':
        return 'space-vines';
      default:
        return 'space-items';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Item Preview
            _buildItemPreview(),
            
            // Space Type Tabs
            _buildSpaceTabs(),
            
            // Spaces List
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _buildSpacesList(),
            ),
            
            // Action Button
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Add to Space",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          // Item thumbnail
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getItemIcon(),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemData['title'] ?? widget.itemData['name'] ?? 'Untitled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.itemType.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedSpaces.length} selected',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabButton(
              title: "My Spaces",
              index: 0,
              count: _privateSpaces.length,
            ),
            _buildTabButton(
              title: "Collaborations",
              index: 1,
              count: _featuredSpaces.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index, required int count}) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          Text(
            "Loading your spaces...",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacesList() {
    final spaces = _selectedSegment == 0 ? _privateSpaces : _featuredSpaces;
    
    if (spaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.space_dashboard,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedSegment == 0 
                  ? "No spaces yet"
                  : "No collaborations yet",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedSegment == 0
                  ? "Create a space to get started"
                  : "Join spaces to collaborate",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return OptimizedListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: spaces.length,
      itemBuilder: (context, index) {
        final space = spaces[index];
        final isSelected = _selectedSpaces.contains(space['id']);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleSpaceSelection(space['id']!),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Space icon/avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: space['iconUrl'] != null && space['iconUrl'].isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  space['iconUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.space_dashboard,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.space_dashboard,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Space info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              space['title'] ?? 'Untitled Space',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${space['category']} • ${space['members']} members',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Selection indicator
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[600]!,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isSaving ? 0.7 : 1.0,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSaving ? null : _saveToSpaces,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rocket_launch,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Space It",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getItemIcon() {
    switch (widget.itemType.toLowerCase()) {
      case 'music':
        return Icons.music_note;
      case 'book':
        return Icons.book;
      case 'podcast':
        return Icons.podcasts;
      case 'product':
        return Icons.shopping_cart;
      case 'vine':
      case 'video':
        return Icons.video_library;
      default:
        return Icons.folder;
    }
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}