import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../../../Models/customModel/library.dart';
import '../../controllers/dashboard_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';

class BookHomePage extends StatefulWidget {
  const BookHomePage({super.key});

  @override
  State<BookHomePage> createState() => _BookHomePageState();
}

class _BookHomePageState extends State<BookHomePage> {
  final MangoDashboardController _controller = Get.find<MangoDashboardController>();

  final List<String> _genreFilters = [
    'All',
    'Fiction',
    'Non-Fiction',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Fantasy',
    'Biography',
  ];
  String _selectedGenre = 'All';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cache for books per genre
  final Map<String, List<MangoBooks>> _booksCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBooksForGenre(_selectedGenre);
  }

  Future<void> _loadBooksForGenre(String genre) async {
    if (_isLoading) return;
    if (_booksCache.containsKey(genre) && _booksCache[genre] != null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final stream = genre == 'All'
          ? _controller.getBooks()
          : _controller.getBooksByGenre(genre);
      final books = await stream.first;
      setState(() {
        _booksCache[genre] = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with back button
            SliverToBoxAdapter(
              child: _buildHeader(context, isDark),
            ),
            
            // Search Bar
            SliverToBoxAdapter(
              child: _buildSearchBar(isDark),
            ),
            
            // Genre Filter
            SliverToBoxAdapter(
              child: _buildGenreFilter(isDark),
            ),
            
            // Books Grid
            _buildBooksGrid(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'explore books',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search books, authors...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 22,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreFilter(bool isDark) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 15),
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _genreFilters.length,
        itemBuilder: (context, index) {
          final genre = _genreFilters[index];
          final isSelected = _selectedGenre == genre;

          return GestureDetector(
            onTap: () {
              if (_selectedGenre == genre) return;
              setState(() {
                _selectedGenre = genre;
              });
              _loadBooksForGenre(genre);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF667eea)
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF667eea)
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Center(
                child: Text(
                  genre,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBooksGrid(bool isDark) {
    final cachedBooks = _booksCache[_selectedGenre];
    final hasData = cachedBooks != null && cachedBooks.isNotEmpty;

    // Filter by search query
    List<MangoBooks> displayedBooks = [];
    if (hasData) {
      displayedBooks = [...cachedBooks];
      if (_searchQuery.isNotEmpty) {
        displayedBooks = displayedBooks.where((book) {
          return book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              book.author.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }
    }

    // Loading state
    if (_isLoading && cachedBooks == null) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildShimmerBookCard(isDark),
            childCount: 6,
          ),
        ),
      );
    }

    // Empty state
    if (displayedBooks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off : Icons.book,
                size: 60,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No books match your search' : 'No books found',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Try searching with different keywords',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF667eea),
                    side: const BorderSide(color: Color(0xFF667eea)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Books grid
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = displayedBooks[index];
            return _buildBookCard(book, isDark);
          },
          childCount: displayedBooks.length,
        ),
      ),
    );
  }

  Widget _buildBookCard(MangoBooks book, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Navigate to book detail
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.grey).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: book.coverUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 160,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 160,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    Icons.book,
                    size: 40,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ),
            // Book Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          book.genre,
                          style: const TextStyle(
                            fontSize: 8,
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 10, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            (book.likes / 100).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBookCard(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.grey[800] : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.white,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 13, width: 100, child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 8),
                  SizedBox(height: 11, width: 80, child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 8),
                  SizedBox(height: 10, width: 60, child: ColoredBox(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}