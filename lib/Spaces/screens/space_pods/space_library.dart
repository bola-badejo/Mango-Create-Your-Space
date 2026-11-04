import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Models/cloud/post_services.dart';
import 'package:mango/Spaces/controllers/space_item.dart';
import 'package:mango/utils.dart';

import '../../../Home/controllers/dashboard_controller.dart';
import '../../../Home/pages/post_shimmer.dart';
import 'package:mango/Utils/optimized_lists.dart';

class SpaceLibrary extends StatelessWidget {
  SpaceLibrary({super.key});

  final MangoDashboardController controller = Get.put(
    MangoDashboardController(),
  );
  final SpaceItemsService itemController = Get.put(SpaceItemsService());
  final PostService postController = PostService();
  final String? spaceId = Get.arguments?['spaceId'];

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    if (spaceId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Space ID not provided',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    
    final spaceDoc = FirebaseFirestore.instance.collection('spaces').doc(spaceId!);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: spaceDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Text(
                'Space not found',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        
        final spaceData = snapshot.data!.data() as Map<String, dynamic>?;
        final isCreator = spaceData?['postCreator'] == currentUserId;
        final collaborators = List<String>.from(spaceData?['collaborators'] ?? []);
        final isCollaborator = collaborators.contains(currentUserId);
        final isAdmin = isCreator || isCollaborator;
        
        return _buildMainContent(context, isAdmin);
      },
    );
  }
  
  Widget _buildLoadingScaffold() {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  Widget _buildMainContent(BuildContext context, bool isAdmin) {
    Widget _buildSectionWithSeeAll(
      String title, {
      required VoidCallback onSeeAll,
      required Widget content,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColorLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Icon(Icons.arrow_forward_ios, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          content,
        ],
      );
    }

    Widget _buildEmptyBookSection(String message) {
      return Container(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book, size: 32, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildCardSkeleton() {
      return Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              color: Colors.grey[300],
              margin: EdgeInsets.only(bottom: 4),
            ),
            Container(width: 80, height: 10, color: Colors.grey[300]),
          ],
        ),
      );
    }

    Widget _buildBookCard(Map<String, dynamic> bookData, int index) {
      return Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(
                        bookData['thumbnail'] ?? bookData['coverImage'] ?? '',
                      ),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        print('Error loading book image: $exception');
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 10, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          bookData['rating']?.toString() ?? '0.0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              bookData['title'] ?? 'Unknown Title',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              bookData['author'] ?? 'Unknown Author',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    Widget _buildLibraryCollectionSection() {
      return _buildSectionWithSeeAll(
        'Library Collection',
        onSeeAll: () => Get.toNamed('/library-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('spaces')
              .doc(spaceId!)
              .collection('space-books')
              .orderBy('savedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 240,
                width: 160,
                color: Colors.grey[300]!,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyBookSection(
                isAdmin 
                    ? 'No books added yet. Tap the + button to add books!'
                    : 'No books have been spaced yet'
              );
            }
            
            final spaceItems = snapshot.data!.docs;
            
            return Container(
              height: 240,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: spaceItems.length,
                itemBuilder: (context, index) {
                  final item = spaceItems[index];
                  final data = item.data() as Map<String, dynamic>;
                  final originalItemId = data['originalItemId'] ?? '';
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('books')
                        .doc(originalItemId)
                        .get(),
                    builder: (context, bookSnapshot) {
                      if (bookSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildCardSkeleton();
                      }

                      if (bookSnapshot.hasError || !bookSnapshot.hasData || !bookSnapshot.data!.exists) {
                        return Container(
                          width: 140,
                          margin: EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 190,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.book,
                                          color: Colors.grey[600],
                                          size: 24,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Book not found',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Book not available',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Unknown',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }

                      final bookData = bookSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildBookCard(bookData, index);
                    },
                  );
                },
              ),
            );
          },
        ),
      );
    }

    Widget _buildBestsellersSection() {
      return _buildSectionWithSeeAll(
        'Bestsellers',
        onSeeAll: () => Get.toNamed('/library-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('books')
              .where('isBestseller', isEqualTo: true)
              .orderBy('sales', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 240,
                width: 160,
                color: Colors.grey[300]!,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyBookSection('No bestsellers available');
            }
            
            final books = snapshot.data!.docs;
            
            return Container(
              height: 240,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final bookData = books[index].data() as Map<String, dynamic>;
                  return _buildBookCard(bookData, index);
                },
              ),
            );
          },
        ),
      );
    }

    var size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: size.height * .1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleMedium,
                        children: const [
                          TextSpan(
                            text: "This is how we catch a vibe.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: "\nNo Sweat.",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SpaceBooksActions(
                    spaceId: spaceId!, 
                    podType: 'books',
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 10),
                  _buildLibraryCollectionSection(),
                  const SizedBox(height: 10),
                  _buildBestsellersSection(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Text(
                      'Book Club',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColorLight,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: BookClubCard(
                      spaceId: spaceId!, 
                      podType: 'books',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleSmall,
                        children: const [
                          TextSpan(text: "Live "),
                          TextSpan(
                            text: "Reading Sessions...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LiveReadingSessionsCard(
                      spaceId: spaceId!, 
                      podType: 'books',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "Author Corner",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AuthorCornerList(spaceId: spaceId!, isAdmin: isAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Book-specific Actions Widget
class SpaceBooksActions extends StatelessWidget {
  final String podType;
  final String spaceId;
  final bool isAdmin;
  
  const SpaceBooksActions({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildButton(
            context,
            color: Colors.deepPurple,
            icon: Icons.chat,
            text: "Book Club",
            onTap: isAdmin 
                ? () => _openBookClubSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "start book club discussions"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.teal,
            icon: Icons.mic,
            text: "Reading",
            onTap: isAdmin 
                ? () => _openReadingSessionSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create reading sessions"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.orange,
            icon: Icons.record_voice_over,
            text: "Author",
            onTap: isAdmin 
                ? () => _openAuthorCornerSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create author events"),
            isDisabled: !isAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        width: 90,
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[700] : color,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPermissionDenied(BuildContext context, String action) {
    UtilsService().showSnackbar(
      "Permission Denied",
      "Only space creators and collaborators can $action",
      backgroundColor: Colors.red,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openBookClubSheet(BuildContext context, String spaceId, String podType) {
    // Implementation for book club discussion creation
    UtilsService().showSnackbar(
      "Coming Soon",
      "Book club discussion feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openReadingSessionSheet(BuildContext context, String spaceId, String podType) {
    // Implementation for reading session creation
    UtilsService().showSnackbar(
      "Coming Soon",
      "Reading session feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openAuthorCornerSheet(BuildContext context, String spaceId, String podType) {
    // Implementation for author corner event creation
    UtilsService().showSnackbar(
      "Coming Soon",
      "Author corner feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }
}

// Book Club Card (Book-specific)
class BookClubCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const BookClubCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<BookClubCard> createState() => _BookClubCardState();
}

class _BookClubCardState extends State<BookClubCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=400",
    "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400",
    "https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=400",
    "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400",
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('bookClub')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoBookClubCarousel();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        return Container(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: _isExpanded ? 200 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              data['status'] ?? "Active",
                              style: const TextStyle(
                                fontSize: 7,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            data['title'] ?? "Book Club",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${data['members'] ?? 0} members reading",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'tap for more',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.black.withOpacity(0.8),
                                  size: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data['description'] ?? 'Join our book club discussions!',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.black.withOpacity(0.6),
                                ),
                                maxLines: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        width: _isExpanded ? 140 : 100,
                        height: _isExpanded ? 140 : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: data['image'] != null
                              ? Image.network(
                                  data['image'],
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "asset/images/book_club.jpg",
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoBookClubCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "BOOK CLUB",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Start a Book Club" : "Join the Book Club",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Create a book club discussion and share your love for reading!"
                      : "No active book club discussions. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.deepPurple
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Live Reading Sessions Card (Book-specific)
class LiveReadingSessionsCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const LiveReadingSessionsCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<LiveReadingSessionsCard> createState() => _LiveReadingSessionsCardState();
}

class _LiveReadingSessionsCardState extends State<LiveReadingSessionsCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=400",
    "https://images.unsplash.com/photo-1519682577862-22b62b24e493?w=400",
    "https://images.unsplash.com/photo-1515378960530-7c0da6231fb1?w=400",
    "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=400",
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('readingSessions')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('scheduledTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoReadingSessionsCarousel();
        }

        final sessions = snapshot.data!.docs;
        final currentSession = sessions.first.data() as Map<String, dynamic>;

        return Container(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: _isExpanded ? 200 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _getReadingTimeText(currentSession),
                              style: const TextStyle(
                                fontSize: 7,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            currentSession['title'] ?? "Reading Session",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "${currentSession['readers'] ?? 0} readers.",
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentSession),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(currentSession),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        width: _isExpanded ? 140 : 100,
                        height: _isExpanded ? 140 : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: currentSession['image'] != null
                              ? Image.network(
                                  currentSession['image'],
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "asset/images/reading_session.jpg",
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getReadingTimeText(Map<String, dynamic> session) {
    if (session['isLive'] == true) {
      return "READING NOW";
    } else if (session['scheduledTime'] != null) {
      final scheduledTime = session['scheduledTime'].toDate();
      final now = DateTime.now();
      final difference = scheduledTime.difference(now);

      if (difference.inDays > 0) {
        return 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else {
        return 'Starting soon';
      }
    }
    return "Coming soon";
  }

  String _getStatusText(Map<String, dynamic> session) {
    if (session['isLive'] == true) return "LIVE";
    if (session['isScheduled'] == true) return "SCHEDULED";
    return "UPCOMING";
  }

  Color _getStatusColor(Map<String, dynamic> session) {
    if (session['isLive'] == true) return Colors.red;
    if (session['isScheduled'] == true) return Colors.orange;
    return Colors.teal;
  }

  Widget _buildNoReadingSessionsCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.mic, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "READING",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Host a Reading Session" : "Live Reading Sessions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Start a live reading session and share stories with your space members!"
                      : "No reading sessions scheduled. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.teal
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Author Corner List (Book-specific)
class AuthorCornerList extends StatelessWidget {
  final String spaceId;
  final bool isAdmin;
  
  const AuthorCornerList({
    super.key,
    required this.spaceId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('authorCorner')
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildNoAuthorCornerCarousel();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildNoAuthorCornerCarousel();
        }

        return Column(
          children: docs.map((data) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 25.0,
                vertical: 10,
              ),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(38.5),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 10),
                      blurRadius: 33,
                      color: Theme.of(context).splashColor.withOpacity(.24),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30, right: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data["title"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                data["author"],
                                style: TextStyle(
                                  color: Theme.of(context).primaryColorLight,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  data["genre"] ?? "Author Event",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).primaryColorLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Image.network(
                        data["image"],
                        width: 55,
                        fit: BoxFit.cover,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNoAuthorCornerCarousel() {
    return _AuthorCornerCarousel(isAdmin: isAdmin);
  }
}

class _AuthorCornerCarousel extends StatefulWidget {
  final bool isAdmin;
  
  const _AuthorCornerCarousel({required this.isAdmin});
  
  @override
  State<_AuthorCornerCarousel> createState() => _AuthorCornerCarouselState();
}

class _AuthorCornerCarouselState extends State<_AuthorCornerCarousel> {
  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=400",
    "https://images.unsplash.com/photo-1519682577862-22b62b24e493?w=400",
    "https://images.unsplash.com/photo-1515378960530-7c0da6231fb1?w=400",
    "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=400",
  ];
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "AUTHOR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Meet the Author" : "Author Corner",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Invite authors for Q&A sessions, book readings, and discussions!"
                      : "No author events scheduled. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.orange
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}