import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mango/Models/cloud/new_post_service.dart';
import 'package:mango/Utils/optimized_lists.dart';

class ImageEditorScreen extends StatefulWidget {
  
  
  final dynamic image;
  final ImageEdit initialEdit;

  const ImageEditorScreen({
    super.key,
    required this.image,
    required this.initialEdit,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen>
    with SingleTickerProviderStateMixin {
  late ImageEdit _currentEdit;
  late List<TextOverlay> _textOverlays;

  
  Uint8List? _webImageBytes;
  
  File? _mobileImageFile;

  
  double? _imageWidth;
  double? _imageHeight;

  String _currentTool = 'filters';
  TextOverlay? _selectedTextOverlay;
  bool _isDraggingText = false;

  final GlobalKey _imageKey = GlobalKey();
  Size? _imageSize;

  final List<String> _filters = const [
    'normal',
    'clarendon',
    'gingham',
    'moon',
    'lark',
    'reyes',
    'juno',
    'slumber',
    'crema',
    'ludwig',
    'aden',
    'perpetua',
    'brannan',
    'inkwell',
    'valencia',
    'xpro2',
    'lo-fi',
    'sierra',
    'walden',
    'hefe',
    'nashville',
    '1977',
    'kelvin',
    'toaster',
    'earlybird',
    'sutro',
    'amaro',
    'willow',
  ];

  final List<Color> _textColors = const [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _currentEdit = widget.initialEdit;
    _textOverlays = List.from(widget.initialEdit.textOverlays);

    
    if (kIsWeb) {
      
      _webImageBytes = widget.image as Uint8List?;
      
      _decodeWebImage(_webImageBytes!);
    } else {
      
      _mobileImageFile = widget.image as File;
      _decodeMobileImage(_mobileImageFile!);
    }
  }

  Future<void> _decodeWebImage(Uint8List bytes) async {
    final completer = Completer<void>();
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    setState(() {
      _imageWidth = frameInfo.image.width.toDouble();
      _imageHeight = frameInfo.image.height.toDouble();
    });
  }

  Future<void> _decodeMobileImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);

    setState(() {
      _imageWidth = image.width.toDouble();
      _imageHeight = image.height.toDouble();
    });
  }

  double get _aspectRatio {
    if (_imageWidth != null && _imageHeight != null) {
      return _imageWidth! / _imageHeight!;
    }
    return 1.0; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateImageSize(constraints);
                });
                return InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Container(
                      key: _imageKey,
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: AspectRatio(
                        aspectRatio: _aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            
                            _buildImage(),
                            
                            ..._buildTextOverlays(),
                            
                            if (_currentTool == 'text')
                              GestureDetector(
                                onTapUp: (details) =>
                                    _addTextOverlay(details.localPosition),
                                behavior: HitTestBehavior.translucent,
                                child: Container(color: Colors.transparent),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: _buildAppBar(),
          ),

          
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomTools()),

          
          if (_currentTool == 'filters')
            Positioned(
              left: 16,
              top: MediaQuery.of(context).padding.top + 80,
              bottom: 120,
              child: _buildFiltersPanel(),
            ),

          
          if (_currentTool == 'adjust')
            Positioned(
              left: 0,
              right: 0,
              bottom: 120,
              child: _buildAdjustPanel(),
            ),

          
          if (_currentTool == 'text' && _selectedTextOverlay != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: _buildTextEditingPanel(),
            ),
        ],
      ),
    );
  }

  
  
  
  Widget _buildImage() {
    if (kIsWeb) {
      return _webImageBytes != null
          ? ColorFiltered(
              colorFilter: _getFilterColorFilter(_currentEdit.filter),
              child: Image.memory(_webImageBytes!, fit: BoxFit.contain),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      return _mobileImageFile != null
          ? ColorFiltered(
              colorFilter: _getFilterColorFilter(_currentEdit.filter),
              child: Image.file(_mobileImageFile!, fit: BoxFit.contain),
            )
          : const Center(child: CircularProgressIndicator());
    }
  }

  
  
  
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Edit Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveAndReturn,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTools() {
    return Container(
      height: 80,
      color: Colors.black.withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton('filters', Icons.filter, 'Filters'),
          _buildToolButton('adjust', Icons.tune, 'Adjust'),
          _buildToolButton('text', Icons.text_fields, 'Text'),
          _buildToolButton('crop', Icons.crop, 'Crop'),
        ],
      ),
    );
  }

  Widget _buildToolButton(String tool, IconData icon, String label) {
    final isSelected = _currentTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _currentTool = tool),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  
  
  
  Widget _buildFiltersPanel() {
    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: OptimizedListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _currentEdit.filter == filter;
          return GestureDetector(
            onTap: () => setState(() {
              _currentEdit = _currentEdit.copyWith(filter: filter);
            }),
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
                image: DecorationImage(
                  image: kIsWeb
                      ? (_webImageBytes != null
                            ? MemoryImage(_webImageBytes!)
                            : const AssetImage('asset/images/placeholder.jpg')
                                  as ImageProvider)
                      : (_mobileImageFile != null
                            ? FileImage(_mobileImageFile!)
                            : const AssetImage('asset/images/placeholder.jpg')),
                  fit: BoxFit.cover,
                  colorFilter: _getFilterColorFilter(filter),
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        },
      ),
    );
  }

  
  
  
  Widget _buildAdjustPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSliderRow(
            label: 'Brightness',
            value: _currentEdit.brightness,
            min: 0.5,
            max: 1.5,
            onChanged: (val) => setState(() {
              _currentEdit = _currentEdit.copyWith(brightness: val);
            }),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: 'Contrast',
            value: _currentEdit.contrast,
            min: 0.5,
            max: 2.0,
            onChanged: (val) => setState(() {
              _currentEdit = _currentEdit.copyWith(contrast: val);
            }),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: 'Saturation',
            value: _currentEdit.saturation,
            min: 0.0,
            max: 2.0,
            onChanged: (val) => setState(() {
              _currentEdit = _currentEdit.copyWith(saturation: val);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey[800],
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  
  
  
  List<Widget> _buildTextOverlays() {
    if (_imageSize == null) return [];
    return _textOverlays.map((overlay) {
      final isSelected = _selectedTextOverlay == overlay;
      final left = overlay.x * _imageSize!.width;
      final top = overlay.y * _imageSize!.height;

      return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onTap: () => setState(() => _selectedTextOverlay = overlay),
          onPanStart: (details) {
            setState(() {
              _isDraggingText = true;
              _selectedTextOverlay = overlay;
            });
          },
          onPanUpdate: (details) {
            final newX = (overlay.x + details.delta.dx / _imageSize!.width)
                .clamp(0.0, 1.0);
            final newY = (overlay.y + details.delta.dy / _imageSize!.height)
                .clamp(0.0, 1.0);
            setState(() {
              final index = _textOverlays.indexOf(overlay);
              _textOverlays[index] = overlay.copyWith(x: newX, y: newY);
            });
          },
          onPanEnd: (_) => setState(() => _isDraggingText = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              overlay.text,
              style: TextStyle(
                color: _hexToColor(overlay.color),
                fontSize: overlay.fontSize,
                fontFamily: overlay.fontFamily,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _addTextOverlay(Offset localPosition) {
    if (_imageSize == null) return;
    final normalizedX = (localPosition.dx / _imageSize!.width).clamp(0.0, 1.0);
    final normalizedY = (localPosition.dy / _imageSize!.height).clamp(0.0, 1.0);

    final newOverlay = TextOverlay(
      text: 'Double tap to edit',
      x: normalizedX,
      y: normalizedY,
      color: '#FFFFFFFF',
      fontSize: 24,
      fontFamily: 'Arial',
    );
    setState(() {
      _textOverlays.add(newOverlay);
      _selectedTextOverlay = newOverlay;
    });
  }

  Widget _buildTextEditingPanel() {
    if (_selectedTextOverlay == null) return const SizedBox();
    final overlay = _selectedTextOverlay!;
    final index = _textOverlays.indexOf(overlay);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: TextEditingController(text: overlay.text),
            decoration: InputDecoration(
              hintText: 'Enter text',
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (text) {
              setState(() {
                _textOverlays[index] = overlay.copyWith(text: text);
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Size:', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: overlay.fontSize,
                  min: 12,
                  max: 72,
                  onChanged: (size) {
                    setState(() {
                      _textOverlays[index] = overlay.copyWith(fontSize: size);
                    });
                  },
                ),
              ),
              Text(
                '${overlay.fontSize.toInt()}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          DropdownButton<String>(
            value: overlay.fontFamily,
            dropdownColor: Colors.grey[900],
            items: const [
              DropdownMenuItem(
                value: 'Arial',
                child: Text('Arial', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Roboto',
                child: Text('Roboto', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Times New Roman',
                child: Text(
                  'Times New Roman',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem(
                value: 'Courier New',
                child: Text(
                  'Courier New',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem(
                value: 'Georgia',
                child: Text('Georgia', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Verdana',
                child: Text('Verdana', style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (font) {
              if (font != null) {
                setState(() {
                  _textOverlays[index] = overlay.copyWith(fontFamily: font);
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _textColors.map((color) {
              final isSelected = _colorToHex(color) == overlay.color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _textOverlays[index] = overlay.copyWith(
                      color: _colorToHex(color),
                    );
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _textOverlays.removeAt(index);
                _selectedTextOverlay = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  
  
  
  void _updateImageSize(BoxConstraints constraints) {
    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      if (_imageSize != size) {
        setState(() {
          _imageSize = size;
        });
      }
    }
  }

  void _saveAndReturn() {
    final updatedEdit = _currentEdit.copyWith(
      filter: _currentEdit.filter,
      brightness: _currentEdit.brightness,
      contrast: _currentEdit.contrast,
      saturation: _currentEdit.saturation,
      exposure: _currentEdit.exposure,
      textOverlays: _textOverlays,
    );
    Navigator.pop(context, updatedEdit);
  }

  ColorFilter _getFilterColorFilter(String filter) {
    switch (filter) {
      case 'clarendon':
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'gingham':
        return const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'moon':
        return const ColorFilter.matrix([
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'lark':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          20,
          0,
          1.1,
          0,
          0,
          20,
          0,
          0,
          1.1,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'reyes':
        return const ColorFilter.matrix([
          1.1,
          0.1,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'juno':
        return const ColorFilter.matrix([
          1.0,
          0.1,
          0,
          0,
          10,
          0.1,
          1.0,
          0,
          0,
          10,
          0,
          0,
          1.0,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'slumber':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          20,
          0,
          0.8,
          0,
          0,
          20,
          0,
          0,
          0.8,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'crema':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          -10,
          0,
          1.0,
          0,
          0,
          -10,
          0,
          0,
          0.9,
          0,
          -10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'ludwig':
        return const ColorFilter.matrix([
          1.05,
          0,
          0,
          0,
          5,
          0,
          1.0,
          0,
          0,
          5,
          0,
          0,
          0.95,
          0,
          5,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'aden':
        return const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          15,
          0,
          0.9,
          0,
          0,
          15,
          0,
          0,
          0.9,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'perpetua':
        return const ColorFilter.matrix([
          1.05,
          0,
          0,
          0,
          0,
          0,
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'brannan':
        return const ColorFilter.matrix([
          0.8,
          0.1,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'inkwell':
        return const ColorFilter.matrix([
          0.3,
          0.3,
          0.3,
          0,
          0,
          0.3,
          0.3,
          0.3,
          0,
          0,
          0.3,
          0.3,
          0.3,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'valencia':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'xpro2':
        return const ColorFilter.matrix([
          1.2,
          0.1,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'lo-fi':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          10,
          0,
          1.1,
          0,
          0,
          10,
          0,
          0,
          1.1,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'sierra':
        return const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          15,
          0,
          0.8,
          0,
          0,
          15,
          0,
          0,
          0.7,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'walden':
        return const ColorFilter.matrix([
          1.0,
          0.2,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'hefe':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'nashville':
        return const ColorFilter.matrix([
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case '1977':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          10,
          0,
          1.0,
          0,
          0,
          10,
          0,
          0,
          0.9,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'kelvin':
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'toaster':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          30,
          0,
          0.7,
          0,
          0,
          30,
          0,
          0,
          0.6,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'earlybird':
        return const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          20,
          0,
          0.9,
          0,
          0,
          20,
          0,
          0,
          0.8,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'sutro':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          0,
          0,
          0.7,
          0,
          0,
          0,
          0,
          0,
          0.6,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'amaro':
        return const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'willow':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.srcOver);
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
