import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Contributors/pages/upload_book_collection.dart';
import 'package:mango/Contributors/pages/upload_book.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class BookBoxPage extends StatefulWidget {
  final MangoUser user;  
  final String? contributorId;  
  
  const BookBoxPage({
    super.key, 
    required this.user,
    this.contributorId,
  });

  @override
  _BookBoxPageState createState() => _BookBoxPageState();
}

class _BookBoxPageState extends State<BookBoxPage>
    with TickerProviderStateMixin {
  bool _showUploadOptions = false;
  bool _showYourBooks = true;
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  String? _contributorId;  

  @override
  void initState() {
    super.initState();
    
    
    _determineContributorId();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
      }
    });
  }

  void _determineContributorId() {
    
    
    
    
    
    
    if (widget.contributorId != null && widget.contributorId!.isNotEmpty) {
      _contributorId = widget.contributorId;
    } else if (widget.user.creatorID != null && widget.user.creatorID!.isNotEmpty) {
      _contributorId = widget.user.creatorID;
    } else if (widget.user.distributorID != null && widget.user.distributorID!.isNotEmpty) {
      _contributorId = widget.user.distributorID;
    } else if (widget.user.vendorID != null && widget.user.vendorID!.isNotEmpty) {
      _contributorId = widget.user.vendorID;
    }
    
    debugPrint('BookBoxPage using contributor ID: $_contributorId');
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleYourBooks() {
    setState(() {
      _showYourBooks = !_showYourBooks;
      _showYourBooks ? _controller.forward() : _controller.reverse();
    });
  }

  void _toggleUploadOptions() {
    setState(() {
      _showUploadOptions = !_showUploadOptions;
    });
  }

  Future<void> _refreshData() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : MangoPalette.black;
    final backgroundColor = isDarkMode ? MangoPalette.grey900 : Colors.white;
    final cardColor = isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50;
    final secondaryTextColor = isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600;

    
    if (_contributorId == null || _contributorId!.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Book Box',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: MangoPalette.green500,
              ),
              const SizedBox(height: 16),
              Text(
                'No Contributor Profile Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please register as a creator to upload books.',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Book Box',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomScrollView(
              slivers: [
                
                _buildStatisticsSection(isDarkMode, textColor, cardColor!),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildUploadSection(isDarkMode, textColor),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildSectionTitle('Best Sellers', textColor),
                _buildHorizontalBooksList(isDarkMode),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildSectionTitle('Your Series', textColor),
                _buildHorizontalSeriesList(isDarkMode),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildYourBooksSection(
                  isDarkMode,
                  textColor,
                  secondaryTextColor!,
                ),

                
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Mango Books. © 2025',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(bool isDarkMode, Color textColor, Color cardColor) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("books")
            .where("contributorId", isEqualTo: _contributorId)  
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildModernStatCard(
              isLoading: true,
              isDarkMode: isDarkMode,
            );
          }

          if (snapshot.hasError) {
            return _buildErrorWidget('Failed to load statistics', isDarkMode);
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildModernStatCard(
              booksCount: 0,
              totalReads: 0,
              monthlyReads: 0,
              totalLikes: 0,
              isDarkMode: isDarkMode,
            );
          }

          final books = snapshot.data!.docs;
          int totalReads = 0;
          int monthlyReads = 0;
          int totalLikes = 0;
          final now = DateTime.now();
          final monthAgo = DateTime(now.year, now.month - 1, now.day);

          for (var book in books) {
            totalReads += (book['reads'] ?? 0) as int;
            totalLikes += (book['likes'] ?? 0) as int;
            final timestamp = book['timestamp'];
            if (timestamp != null) {
              final createdAt = (timestamp as Timestamp).toDate();
              if (createdAt.isAfter(monthAgo)) {
                monthlyReads += (book['reads'] ?? 0) as int;
              }
            }
          }

          return _buildModernStatCard(
            booksCount: books.length,
            totalReads: totalReads,
            monthlyReads: monthlyReads,
            totalLikes: totalLikes,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard({
    int? booksCount,
    int? totalReads,
    int? monthlyReads,
    int? totalLikes,
    bool isLoading = false,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey900 : Colors.white,
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(isDarkMode ? 0.4 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              _buildModernStatItem(
                value: booksCount ?? 0,
                label: 'Total Books',
                icon: Icons.book,
                color: Colors.purple,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalReads ?? 0,
                label: 'Total Reads',
                icon: Icons.visibility,
                color: Colors.blue,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: monthlyReads ?? 0,
                label: 'Monthly Reads',
                icon: Icons.trending_up,
                color: MangoPalette.green500,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalLikes ?? 0,
                label: 'Total Likes',
                icon: Icons.favorite,
                color: Colors.red,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem({
    required int value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey800 : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                )
              else
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1000),
                  tween: IntTween(begin: 0, end: value),
                  builder: (context, animatedValue, child) {
                    return Text(
                      _formatNumber(animatedValue),
                      style: TextStyle(
                        fontSize: 45,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : MangoPalette.black,
                        fontFamily: 'Inter',
                      ),
                    );
                  },
                ),
              
              const SizedBox(height: 4),
              
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey900 : Colors.white,
        borderRadius: BorderRadius.circular(MangoRadius.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(bool isDarkMode, Color textColor) {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upload Your Book',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
        tooltip: 'Show options',
                    icon: AnimatedRotation(
                      turns: _showUploadOptions ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(Icons.arrow_drop_down, color: textColor),
                    ),
                    onPressed: _toggleUploadOptions,
                  ),
                ],
              ),
            ),
            
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _showUploadOptions
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Divider(
                    color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                  ),
                  _buildUploadOption(
                    'Upload a Book',
                    Icons.menu_book,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadBookPage(
                          contributorId: _contributorId,  
                        ),
                      ),
                    ),
                    isDarkMode,
                  ),
                  _buildUploadOption(
                    'Upload a Collection',
                    Icons.collections_bookmark,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadBookCollectionPage(
                          contributorId: _contributorId,  
                        ),
                      ),
                    ),
                    isDarkMode,
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(
    String title,
    IconData icon,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, size: 20, color: Colors.blue, semanticLabel: title),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalBooksList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 160,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("books")
              .where("contributorId", isEqualTo: _contributorId)  
              .orderBy("reads", descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error loading books",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No books yet",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            final books = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return _buildBookCard(
                  book['coverUrl'] ?? '',
                  book['title'] ?? 'Untitled',
                  book['author'] ?? 'Unknown Author',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalSeriesList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 160,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("series")
              .where("contributorId", isEqualTo: _contributorId)  
              .orderBy("timestamp", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error loading series",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No series yet",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            final series = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: series.length,
              itemBuilder: (context, index) {
                final seriesItem = series[index];
                return _buildSeriesCard(
                  seriesItem['coverUrl'] ?? '',
                  seriesItem['title'] ?? 'Untitled Series',
                  '${seriesItem['bookCount'] ?? 0} books',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookCard(String imageUrl, String title, String author, bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => Container(
                width: 120,
                height: 120,
                color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                child: Icon(
                  Icons.book,
                  color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 120,
                height: 120,
                color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                child: Icon(
                  Icons.book,
                  color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                ),
              ),
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 400),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                Text(
                  author,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(String imageUrl, String title, String bookCount, bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => Container(
                    width: 120,
                    height: 120,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.collections_bookmark,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 120,
                    height: 120,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.collections_bookmark,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                    ),
                  ),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      bookCount,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : MangoPalette.black,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourBooksSection(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          MangoPressable(
            onTap: _toggleYourBooks,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Books',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showYourBooks ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_up, color: textColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizeTransition(
            sizeFactor: _animation,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("books")
                  .where("contributorId", isEqualTo: _contributorId)  
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading books",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No books uploaded yet",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                final books = snapshot.data!.docs;

                return Column(
                  children: List.generate(books.length, (index) {
                    final book = books[index];
                    return _buildBookItem(
                      id: book.id,
                      imageUrl: book['coverUrl'] ?? '',
                      title: book['title'] ?? 'Untitled',
                      author: book['author'] ?? 'Unknown Author',
                      reads: (book['reads'] ?? 0) as int,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookItem({
    required String id,
    required String imageUrl,
    required String title,
    required String author,
    required int reads,
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            
          },
          borderRadius: BorderRadius.circular(MangoRadius.md),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (context, url) => Container(
                      width: 50,
                      height: 50,
                      color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                      child: Icon(
                        Icons.book,
                        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                      child: Icon(
                        Icons.book,
                        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                      ),
                    ),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
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
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Text(
                    '$reads reads',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}