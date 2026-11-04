import 'dart:async';
import 'dart:io' show File; 
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/ImageSetup/image_editor_screen.dart';
import 'package:mango/ImageSetup/link_dialog.dart';
import 'package:mango/ImageSetup/music_dialog.dart';
import 'package:mango/Models/cloud/new_post_service.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/utils/media_picker.dart';

class PostCreationBox extends StatefulWidget {
  final String? replyTo;
  final String? repliedPostID;
  final VoidCallback? onPostCreated;
  final VoidCallback? onCancel;

  const PostCreationBox({
    super.key,
    this.replyTo,
    this.repliedPostID,
    this.onPostCreated,
    this.onCancel,
  });

  @override
  State<PostCreationBox> createState() => _PostCreationBoxState();
}

class _PostCreationBoxState extends State<PostCreationBox> {
  final TextEditingController _controller = TextEditingController();
  final PostService _postService = PostService();
  final FocusNode _focusNode = FocusNode();
  final ThemeController themeController = Get.find<ThemeController>();

  
  List<XFile> _selectedFiles = [];
  List<Uint8List> _webImageBytes = []; 
  List<ImageEdit> _imageEdits = [];

  XFile? _selectedVideo; 
  Uint8List? _webVideoBytes; 

  String? _selectedMusicUrl;
  String? _linkUrl;
  String? _linkType;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _hasContent = false;

  static const int _maxChars = 280;
  static const int _maxImages = 10;

  
  Color get _cardColor =>
      themeController.isDarkMode.value ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor =>
      themeController.isDarkMode.value ? Colors.white : Colors.black;
  Color get _secondaryTextColor =>
      themeController.isDarkMode.value ? const Color(0xFFB0B0B0) : const Color(0xFF666666);
  Color get _surfaceColor =>
      themeController.isDarkMode.value ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
  Color get _dividerColor =>
      themeController.isDarkMode.value ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
  Color get _primaryColor => themeController.primaryColorValue;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateContentState);
    _focusNode.requestFocus();
  }

  void _updateContentState() {
    setState(() {
      _hasContent = _controller.text.trim().isNotEmpty ||
          _selectedFiles.isNotEmpty ||
          _selectedVideo != null ||
          _linkUrl != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: _cardColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              _buildHeader(),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: widget.replyTo != null ? "Post your reply..." : "How far na?",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 16),
                ),
                maxLines: null,
                maxLength: _maxChars,
                style: TextStyle(color: _textColor, fontSize: 16),
              ),
              _buildCharCounter(),
              const SizedBox(height: 16),
              if (_selectedFiles.isNotEmpty) _buildImageGrid(),
              if (_selectedVideo != null) _buildVideoPreview(),
              if (_linkUrl != null) _buildLinkPreview(),
              if (_selectedMusicUrl != null) _buildMusicIndicator(),
              if (_isUploading) _buildProgressIndicator(),
              Divider(height: 32, color: _dividerColor),
              _buildActionBar(),
            ],
          ),
        ),
      );
    });
  }

  
  Widget _buildHeader() => Row(
        children: [
          if (widget.onCancel != null)
            IconButton(
              icon: Icon(Icons.close, color: _textColor),
              onPressed: widget.onCancel,
              tooltip: 'Cancel',
            ),
          Expanded(
            child: Text(
              widget.replyTo != null ? 'Reply to ${widget.replyTo}' : 'Create Post',
              style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_isUploading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      );

  Widget _buildCharCounter() {
    final textLength = _controller.text.length;
    final nearLimit = textLength > _maxChars * 0.8;
    final overLimit = textLength > _maxChars;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (nearLimit)
          Text(
            '${_maxChars - textLength}',
            style: TextStyle(
              color: overLimit ? Colors.red : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  
  Widget _buildImageGrid() {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) => _buildImageThumbnail(index),
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _surfaceColor,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? (index < _webImageBytes.length)
                    ? Image.memory(
                        _webImageBytes[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildErrorIcon(),
                      )
                    : _buildLoadingPlaceholder()
                : FutureBuilder<Uint8List?>(
                    future: _selectedFiles[index].readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildErrorIcon(),
                        );
                      }
                      return _buildLoadingPlaceholder();
                    },
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _buildSmallIconButton(
            icon: Icons.close,
            onPressed: () => _removeImage(index),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: _buildSmallIconButton(
            icon: Icons.edit,
            onPressed: () => _editImage(index),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, size: 16, color: Colors.white),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      color: _surfaceColor,
      child: Icon(Icons.photo, color: _secondaryTextColor, size: 40),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: _surfaceColor,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
      ),
    );
  }

  
  Widget _buildVideoPreview() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _surfaceColor,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, size: 48, color: _secondaryTextColor),
                const SizedBox(height: 8),
                if (_selectedVideo != null) ...[
                  Text(
                    _selectedVideo!.name,
                    style: TextStyle(color: _textColor, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: _selectedVideo!.length(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data! > 0) {
                        final sizeMB = snapshot.data! / (1024 * 1024);
                        return Text(
                          '${sizeMB.toStringAsFixed(1)} MB',
                          style: TextStyle(color: _secondaryTextColor, fontSize: 11),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _buildSmallIconButton(
              icon: Icons.close,
              onPressed: () {
                setState(() {
                  _selectedVideo = null;
                  _webVideoBytes = null;
                  _updateContentState();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLinkPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: _surfaceColor,
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: _primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _linkType ?? 'Link',
                  style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                ),
                Text(
                  _linkUrl!,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: _secondaryTextColor),
            onPressed: () => setState(() {
              _linkUrl = null;
              _linkType = null;
              _updateContentState();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 16, color: _primaryColor),
          const SizedBox(width: 8),
          Text(
            'Music added',
            style: TextStyle(color: _textColor, fontSize: 14),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: _secondaryTextColor),
            onPressed: () => setState(() {
              _selectedMusicUrl = null;
              _updateContentState();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: _surfaceColor,
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: _secondaryTextColor, fontSize: 12),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!_isUploading)
          Row(
            children: [
              _buildMediaButton(
                icon: Icons.photo_library,
                tooltip: 'Add photos',
                onPressed: _pickImages,
              ),
              _buildMediaButton(
                icon: Icons.videocam,
                tooltip: 'Add video',
                onPressed: _pickVideo,
              ),
              _buildMediaButton(
                icon: Icons.music_note,
                tooltip: 'Add music',
                onPressed: _pickMusic,
              ),
              _buildMediaButton(
                icon: Icons.link,
                tooltip: 'Add link',
                onPressed: _addLink,
              ),
            ],
          )
        else
          const Expanded(child: SizedBox()),
        ElevatedButton(
          onPressed: _hasContent && !_isUploading ? _createPost : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _primaryColor.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(widget.replyTo != null ? 'Reply' : 'Post'),
        ),
      ],
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
      color: _secondaryTextColor,
    );
  }

  
  Future<void> _pickImages() async {
    if (_selectedVideo != null) {
      _showError('Cannot add images when video is selected');
      return;
    }
    final remainingSlots = _maxImages - _selectedFiles.length;
    if (remainingSlots <= 0) {
      _showError('Maximum $_maxImages images allowed');
      return;
    }

    try {
      final images = await MediaPicker.pickImages(
        context,
        maxImages: remainingSlots,
      ) as List<dynamic>?;

      if (images != null && images.isNotEmpty) {
        final xImages = images.map((f) => XFile(f.path)).toList();
        for (final image in xImages) {
          await _addImage(image);
        }
      }
    } catch (e) {
      _showError('Failed to pick images: ${e.toString()}');
    }
  }

  Future<void> _addImage(XFile image) async {
    try {
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await image.readAsBytes();
        
      }

      setState(() {
        _selectedFiles.add(image);
        if (kIsWeb) {
          _webImageBytes.add(bytes ?? Uint8List(0));
        }
        _imageEdits.add(ImageEdit(imageIndex: _selectedFiles.length - 1));
        _updateContentState();
      });
    } catch (e) {
      _showError('Failed to read image: $e');
    }
  }

  Future<void> _pickVideo() async {
    if (_selectedFiles.isNotEmpty) {
      _showError('Cannot add video when images are selected');
      return;
    }

    try {
      final video = await MediaPicker.pickVideo(context) as dynamic;
      if (video != null) {
        final xVideo = XFile(video.path);
        if (kIsWeb) {
          final bytes = await xVideo.readAsBytes();
          _webVideoBytes = bytes;
        }
        setState(() {
          _selectedVideo = xVideo;
          _updateContentState();
        });
      }
    } catch (e) {
      _showError('Failed to pick video: ${e.toString()}');
    }
  }

  Future<void> _pickMusic() async {
    final musicUrl = await showDialog<String>(
      context: context,
      builder: (context) => const MusicPickerDialog(),
    );
    if (musicUrl != null) {
      setState(() {
        _selectedMusicUrl = musicUrl;
        _updateContentState();
      });
    }
  }

  Future<void> _addLink() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const LinkDialog(),
    );
    if (result != null) {
      setState(() {
        _linkUrl = result['url'];
        _linkType = result['type'];
        _updateContentState();
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (kIsWeb && index < _webImageBytes.length) {
        _webImageBytes.removeAt(index);
      }
      _imageEdits.clear();
      for (int i = 0; i < _selectedFiles.length; i++) {
        _imageEdits.add(ImageEdit(imageIndex: i));
      }
      _updateContentState();
    });
  }

  Future<void> _editImage(int index) async {
    if (index >= _selectedFiles.length) return;

    dynamic imageForEditor;
    if (kIsWeb) {
      if (index < _webImageBytes.length) {
        imageForEditor = _webImageBytes[index];
      } else {
        _showError('Image data not available');
        return;
      }
    } else {
      imageForEditor = _selectedFiles[index];
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(
          image: imageForEditor,
          initialEdit: _imageEdits.firstWhere(
            (edit) => edit.imageIndex == index,
            orElse: () => ImageEdit(imageIndex: index),
          ),
        ),
      ),
    );

    if (result != null && result is ImageEdit) {
      setState(() {
        final existingIndex = _imageEdits.indexWhere((edit) => edit.imageIndex == index);
        if (existingIndex != -1) {
          _imageEdits[existingIndex] = result;
        }
      });
    }
  }

  
  Future<void> _createPost() async {
    if (!_hasContent) return;
    if (_controller.text.length > _maxChars) {
      _showError('Post cannot exceed $_maxChars characters');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final text = _controller.text.trim();

      
      List<File>? fileImages;
      if (!kIsWeb && _selectedFiles.isNotEmpty) {
        fileImages = _selectedFiles.map((x) => File(x.path)).toList();
      }

      File? fileVideo;
      if (!kIsWeb && _selectedVideo != null) {
        fileVideo = File(_selectedVideo!.path);
      }

      final webImageBytesMap = kIsWeb && _webImageBytes.isNotEmpty
          ? {for (int i = 0; i < _webImageBytes.length; i++) 'image_$i': _webImageBytes[i]}
          : null;

      final post = await _postService.createPost(
        text: text,
        images: fileImages,          
        video: fileVideo,           
        link: _linkUrl,
        linkType: _linkType,
        isLinked: _linkUrl != null,
        musicUrl: _selectedMusicUrl,
        imageEdits: _imageEdits.isNotEmpty ? _imageEdits : null,
        replyTo: widget.replyTo,
        repliedPostID: widget.repliedPostID,
        onUploadProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
        webImageBytesMap: webImageBytesMap, 
        webVideoBytes: kIsWeb ? _webVideoBytes : null, 
      );

      _resetForm();
      widget.onPostCreated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.replyTo != null ? 'Reply posted!' : 'Post created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PostCreationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _resetForm() {
    _controller.clear();
    setState(() {
      _selectedFiles.clear();
      _webImageBytes.clear();
      _selectedVideo = null;
      _webVideoBytes = null;
      _selectedMusicUrl = null;
      _linkUrl = null;
      _linkType = null;
      _imageEdits.clear();
      _hasContent = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _webImageBytes.clear();
    _webVideoBytes = null;
    super.dispose();
  }
}