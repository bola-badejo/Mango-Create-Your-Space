import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Contributors/controllers/movies_upload_controller.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Home/pages/post_shimmer.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Models/customModel/mango_movies.dart';
import 'package:mango/Spaces/common/space_it.dart';

class MangoMovieCard extends StatefulWidget {
  final MangoMovie movie;

  const MangoMovieCard({super.key, required this.movie});

  @override
  _MangoMovieCardState createState() => _MangoMovieCardState();
}

class _MangoMovieCardState extends State<MangoMovieCard> {
  bool _isExpanded = false;
  final GlobalKey _imageKey = GlobalKey();

  void _openFullScreen(BuildContext context, MangoMovie movie) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenMoviePage(movie: movie),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 130,
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Hero(
                tag: 'image_${widget.movie.id}',
                child: Image.network(widget.movie.posterUrl, fit: BoxFit.cover),
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
                        ? [Colors.black, Colors.black]
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
                      widget.movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.movie.releaseYear,
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
                            widget.movie.description,
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
                                
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.0,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Read',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _isExpanded ? Icons.expand_more : Icons.expand_less,
                            color: Colors.white,
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
  }
}

class FullScreenMoviePage extends StatefulWidget {
  final MangoMovie movie;
  const FullScreenMoviePage({super.key, required this.movie});

  @override
  State<FullScreenMoviePage> createState() => _FullScreenMoviePageState();
}

class _FullScreenMoviePageState extends State<FullScreenMoviePage> {
  final MangoDashboardController controller = Get.put(
    MangoDashboardController(),
  );
  final ScrollController _scrollController = ScrollController();
  double _blurIntensity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(() {
        setState(
          () =>
              _blurIntensity = (_scrollController.offset / 100).clamp(0.0, 1.0),
        );
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight / 1.5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: imageHeight,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title:
                  _scrollController.hasClients &&
                      _scrollController.offset > imageHeight - kToolbarHeight
                  ? Text(
                      '${widget.movie.title} - ${widget.movie.genre}',
                      style: const TextStyle(fontSize: 12),
                    )
                  : const SizedBox.shrink(),
              background: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.8),
                      Colors.black,
                    ],
                    stops: const [0.7, 0.8, 0.9, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.multiply,
                child: Image.network(
                  widget.movie.language,
                  fit: BoxFit.cover,
                  height: imageHeight,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.movie.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.movie.productionCompany!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),

                        SpaceItButton(
                          itemId: widget.movie.id,
                          itemType: 'movie',
                          itemData: {
                            'title': widget.movie.title,
                            'author': widget.movie.genre,
                            'description': widget.movie.description,
                            'coverUrl': widget.movie.posterUrl,
                            'pages': widget.movie.language,
                            'genre': widget.movie.tags,
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.movie.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.only(top: 3, left: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                          bottom: BorderSide(color: Colors.white),
                          top: BorderSide(color: Colors.white),
                          left: BorderSide(color: Colors.white),
                          right: BorderSide(color: Colors.white),
                        ),
                      ),
                      child: MaterialButton(
                        minWidth: double.infinity,
                        height: 60,
                        onPressed: () {
                          
                          
                          
                          
                          
                          
                        },
                        color: Colors.orangeAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Read this Movie",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Related movies',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Comment',
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
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
