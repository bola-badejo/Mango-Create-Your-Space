import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mango/Books/pdf_viewer.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Home/pages/post_shimmer.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Spaces/common/space_it.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Utils/optimized_lists.dart';

class MangoLibraryList extends StatefulWidget {
  final MangoBooks book;

  const MangoLibraryList({super.key, required this.book});

  @override
  _MangoLibraryListState createState() => _MangoLibraryListState();
}

class _MangoLibraryListState extends State<MangoLibraryList> {
  bool _isExpanded = false;
  final GlobalKey _imageKey = GlobalKey();

  void _openFullScreen(BuildContext context, MangoBooks book) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenBookPage(book: book),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeInOut;
          var scaleTween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var scaleAnimation = animation.drive(scaleTween);
          return ScaleTransition(scale: scaleAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(() {
      final primaryColor = themeController.primaryColorValue;
      final isDarkMode = themeController.isDarkMode.value;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 130,
        margin: const EdgeInsets.all(8),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          clipBehavior: Clip.antiAlias,
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildImageWithShimmer(
                  imageUrl: widget.book.coverUrl,
                  width: 130,
                  height: 200,
                  borderRadius: 0,
                  icon: Icons.book,
                ),
              ),
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _isExpanded
                          ? [
                              Colors.black.withOpacity(0.8),
                              Colors.black.withOpacity(0.9),
                            ]
                          : [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.6),
                              Colors.black.withOpacity(1.0),
                              Colors.black.withOpacity(1.0),
                            ],
                      stops: _isExpanded
                          ? [0.0, 1.0]
                          : [0.35, 0.45, 0.55, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.book.author,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ExpandedSection(
                        expand: _isExpanded,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              widget.book.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 8,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: GestureDetector(
                                onTap: () {
                                  print("pressed");
                                  _openFullScreen(context, widget.book);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: primaryColor,
                                      width: 1.0,
                                    ),
                                    color: primaryColor.withOpacity(0.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Read',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isExpanded
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                              color: primaryColor,
                              key: ValueKey<bool>(_isExpanded),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildImageWithShimmer({
    required String imageUrl,
    required double width,
    required double height,
    required double borderRadius,
    required IconData icon,
    bool isNetworkImage = true,
    Map<String, String>? headers,
  }) {
    final themeController = ThemeController.to;

    if (imageUrl.isEmpty) {
      return _buildPlaceholder(
        themeController,
        width,
        height,
        borderRadius,
        icon,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        httpHeaders: headers,

        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: themeController.isDarkMode.value
              ? Colors.grey[800]
              : Colors.grey[300],
          child: Center(
            child: SizedBox(
              width: width * 0.3,
              height: height * 0.3,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  themeController.primaryColorValue,
                ),
              ),
            ),
          ),
        ),

        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: themeController.isDarkMode.value
                ? Colors.grey[800]
                : Colors.grey[300],
          ),
          child: Icon(
            icon,
            size: width * 0.4,
            color: themeController.isDarkMode.value
                ? Colors.grey
                : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    ThemeController themeController,
    double width,
    double height,
    double borderRadius,
    IconData icon,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: themeController.isDarkMode.value
            ? Colors.grey[800]
            : Colors.grey[300],
      ),
      child: Icon(
        icon,
        size: width * 0.4,
        color: themeController.isDarkMode.value
            ? Colors.grey
            : Colors.grey[600],
      ),
    );
  }

  Future<bool> _checkImageUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class FullScreenBookPage extends StatefulWidget {
  final MangoBooks book;
  const FullScreenBookPage({super.key, required this.book});

  @override
  State<FullScreenBookPage> createState() => _FullScreenBookPageState();
}

class _FullScreenBookPageState extends State<FullScreenBookPage> {
  final MangoDashboardController controller =
      Get.find<MangoDashboardController>();
  final ThemeController themeController = Get.find<ThemeController>();
  final ScrollController _scrollController = ScrollController();
  double _blurIntensity = 0.0;

  List<MangoBooks>? _cachedRelatedBooks;
  String? _cachedBooksKey;
  bool _isLoadingBooks = false;

  bool _isImageLoading = true;
  bool _hasImageError = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _blurIntensity = (_scrollController.offset / 100).clamp(0.0, 1.0);
        });
      }
    });

    _loadRelatedBooks();
    _preloadImage();
  }

  Future<void> _preloadImage() async {
    if (widget.book.coverUrl.isEmpty) {
      setState(() {
        _hasImageError = true;
        _isImageLoading = false;
      });
      return;
    }

    setState(() {
      _isImageLoading = true;
      _hasImageError = false;
      _currentImageUrl = widget.book.coverUrl;
    });
  }

  Future<void> _loadRelatedBooks() async {
    if (_isLoadingBooks) return;

    _isLoadingBooks = true;

    try {
      final books = await controller.getBooks().first;

      if (mounted) {
        setState(() {
          _cachedRelatedBooks = books;
          _cachedBooksKey = DateTime.now().millisecondsSinceEpoch.toString();
          _isLoadingBooks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBooks = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildFullScreenImage({required String imageUrl}) {
    final themeController = ThemeController.to;

    if (imageUrl.isEmpty) {
      return _buildErrorPlaceholder(themeController);
    }

    if (kIsWeb) {
      return _buildWebImageWithMultipleAttempts(imageUrl, themeController);
    } else {
      return _buildCachedImage(imageUrl, themeController);
    }
  }

  Widget _buildWebImageWithMultipleAttempts(
    String imageUrl,
    ThemeController themeController,
  ) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/webp,image/apng,image*;q=0.9',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildWebImageWithProxy(imageUrl, themeController);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildLoadingState(themeController);
      },
    );
  }

  Widget _buildWebImageWithProxy(
    String imageUrl,
    ThemeController themeController,
  ) {
    final proxiedUrl = _getProxiedImageUrl(imageUrl);

    return Image.network(
      proxiedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      headers: {'User-Agent': 'Mozilla/5.0'},
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorPlaceholder(themeController);
      },
      loadingBuilder: (context, child, loadingProgress) {
        return _buildLoadingState(themeController);
      },
    );
  }

  String _getProxiedImageUrl(String originalUrl) {
    final encodedUrl = Uri.encodeComponent(originalUrl);

    final proxyServices = [
      'https://corsproxy.io/?$encodedUrl',
      'https://api.allorigins.win/raw?url=$encodedUrl',
      'https://cors-anywhere.herokuapp.com/$originalUrl',
    ];

    return proxyServices[0];
  }

  Widget _buildCachedImage(String imageUrl, ThemeController themeController) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => _buildLoadingState(themeController),
      errorWidget: (context, url, error) =>
          _buildErrorPlaceholder(themeController),
    );
  }

  Widget _buildLoadingState(ThemeController themeController) {
    return Container(
      color: themeController.isDarkMode.value
          ? Colors.grey[900]
          : Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            themeController.primaryColorValue,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(ThemeController themeController) {
    return Container(
      color: themeController.isDarkMode.value
          ? Colors.grey[900]
          : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_rounded,
              size: 60,
              color: themeController.isDarkMode.value
                  ? Colors.grey[700]
                  : Colors.grey[400],
            ),
            const SizedBox(height: 10),
            Text(
              'Cover image',
              style: TextStyle(
                color: themeController.isDarkMode.value
                    ? Colors.grey[500]
                    : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight / 1.5;

    return WillPopScope(
      onWillPop: () async {
        Get.back();
        return false;
      },
      child: Obx(() {
        final primaryColor = themeController.primaryColorValue;
        final isDarkMode = themeController.isDarkMode.value;
        final scaffoldBackground = isDarkMode ? Colors.black : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[100];

        return Scaffold(
          backgroundColor: scaffoldBackground,
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: imageHeight,
                pinned: true,
                backgroundColor: isDarkMode ? Colors.black : primaryColor,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Get.back();
                  },
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  title:
                      _scrollController.hasClients &&
                          _scrollController.offset >
                              imageHeight - kToolbarHeight
                      ? Text(
                          widget.book.title,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildFullScreenImage(imageUrl: widget.book.coverUrl),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              scaffoldBackground.withOpacity(0.3),
                              scaffoldBackground.withOpacity(0.6),
                              scaffoldBackground,
                            ],
                            stops: const [0.4, 0.6, 0.8, 0.9, 1.0],
                          ),
                        ),
                      ),

                      if (kDebugMode && widget.book.coverUrl.isNotEmpty)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'URL: ${widget.book.coverUrl.length > 40 ? '${widget.book.coverUrl.substring(0, 40)}...' : widget.book.coverUrl}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.book.title,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.book.author,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SpaceItButton(
                            key: ValueKey('bookmark_${widget.book.id}'),
                            itemId: widget.book.id,
                            itemType: 'book',
                            itemData: {
                              'title': widget.book.title,
                              'author': widget.book.author,
                              'description': widget.book.description,
                              'coverUrl': widget.book.coverUrl,
                              'pages': widget.book.reads,
                              'genre': widget.book.genre,
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        widget.book.description,
                        style: TextStyle(
                          color: textColor.withOpacity(0.9),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 30),

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.5),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Get.to(
                                () => PdfViewerScreen(
                                  fileUrl: widget.book.fileUrl,
                                  book: widget.book,
                                ),
                                transition: Transition.rightToLeft,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Read this Book",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      _buildRelatedBooksSection(cardColor!, textColor),
                      const SizedBox(height: 40),

                      Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts about this book...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2.0,
                            ),
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.grey[900]
                              : Colors.grey[50],
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.send_rounded, color: primaryColor),
                            onPressed: () {},
                          ),
                        ),
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRelatedBooksSection(Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Books',
          style: TextStyle(
            fontSize: 18,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        if (_cachedRelatedBooks == null && _isLoadingBooks)
          HorizontalShimmerList(height: 200, width: 130, color: cardColor)
        else if (_cachedRelatedBooks?.isEmpty ?? true)
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cardColor.withOpacity(0.5),
            ),
            child: Center(
              child: Text(
                "No related books found",
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 210,
            child: OptimizedListView(
              key: ValueKey(_cachedBooksKey),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _cachedRelatedBooks!.length,
              itemBuilder: (context, index) {
                final book = _cachedRelatedBooks![index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _cachedRelatedBooks!.length - 1 ? 16 : 0,
                  ),
                  child: MangoLibraryList(
                    key: ValueKey('related_${book.id}'),
                    book: book,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class ExpandedSection extends StatelessWidget {
  final bool expand;
  final Widget child;

  const ExpandedSection({super.key, required this.expand, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: child,
      crossFadeState: expand
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }
}
