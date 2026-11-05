import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconify_flutter_plus/iconify_flutter_plus.dart';
import 'package:iconify_flutter_plus/icons/mingcute.dart'; 
import 'package:iconify_flutter_plus/icons/ph.dart'; 
import 'package:iconify_flutter_plus/icons/ri.dart'; 
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class ImageViewerDialog extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;
  final String caption;

  const ImageViewerDialog({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.caption,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), 
      end: Offset.zero, 
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward(); 
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _closeDialog() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    _dragOffset += details.primaryDelta!;
    _isDragging = true;
    setState(() {});
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset > 100) { 
      _closeDialog();
    } else {
      
      _dragOffset = 0.0;
      _isDragging = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _handleVerticalDrag,
      onVerticalDragEnd: _handleVerticalDragEnd,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: SlideTransition(
          position: _slideAnimation,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Stack(
              children: [
                
                _buildBlurredBackground(),
                
                
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: widget.images.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return MangoPressable(
                              onTap: _closeDialog,
                              child: InteractiveViewer(
                                panEnabled: true,
                                minScale: 0.5,
                                maxScale: 3.0,
                                child: Container(
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                                  ),
                                  child: Image.network(
                                    widget.images[index].toString(),
                                    fit: BoxFit.fitWidth,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.error, color: Colors.white, size: 50),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: MangoPalette.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            if (widget.images.length > 1)
                              Text(
                                '${_currentIndex + 1}/${widget.images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            
                            if (widget.caption.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  widget.caption,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    onPressed: () => _downloadImage(widget.images[_currentIndex].toString()),
                                    icon: const Iconify(Ri.download_line, color: Colors.white, size: 14),
                                  ),
                                  IconButton(
                                    onPressed: () => _shareImage(widget.images[_currentIndex].toString()),
                                    icon: const Iconify(Ri.share_line, color: Colors.white, size: 14),
                                  ),
                                  IconButton(
                                    onPressed: _likeImage,
                                    icon: const Iconify(Ri.heart_line, color: Colors.white, size: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                
                
                
                
                
                
                
                
                
                
                
                
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlurredBackground() {
  return Positioned.fill(
    child: Stack(
      children: [
        
        Image.network(
          widget.images[_currentIndex].toString(),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        
        
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: Colors.transparent,
          ),
        ),
        
        
        Container(
          color: MangoPalette.black.withOpacity(0.6),
        ),
      ],
    ),
  );
}

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        children: [
          
          if (widget.images.length > 1)
            Text(
              '${_currentIndex + 1}/${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          
          
          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [

                                  IconButton(
                                    onPressed: () => _downloadImage(widget.images[_currentIndex]),
                                    icon: const Iconify(Ri.download_line, color: Colors.white, size: 14),
                                  ),
                                  IconButton(
                                    onPressed: () => _shareImage(widget.images[_currentIndex]),
                                    icon: const Iconify(Ri.share_line, color: Colors.white, size: 14),
                                  ),
                                  IconButton(
                                    onPressed: _likeImage,
                                    icon: const Iconify(Ri.heart_line, color: Colors.white, size: 14),
                                  ),
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationArrows() {
    return Positioned(
      left: 10,
      right: 10,
      top: MediaQuery.of(context).size.height * 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          
          if (_currentIndex > 0)
            IconButton(
        tooltip: 'Back',
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
              ),
            )
          else
            const SizedBox(width: 48),
          
          
          if (_currentIndex < widget.images.length - 1)
            IconButton(
        tooltip: 'Next',
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 24),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _downloadImage(String imageUrl) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading image...')),
    );
  }

  void _shareImage(String imageUrl) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing image...')),
    );
  }

  void _likeImage() {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image liked!')),
    );
  }
}