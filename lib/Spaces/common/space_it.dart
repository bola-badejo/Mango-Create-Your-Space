import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Spaces/common/space_it_modal.dart';
import 'package:mango/Spaces/controllers/space_controller.dart';

class SpaceItButton extends StatefulWidget {
  final String itemId;
  final String itemType; // music, book, podcast, product, vine
  final Map<String, dynamic> itemData;
  final VoidCallback? onSuccess; // Optional callback for success
  final VoidCallback? onError; // Optional callback for error

  const SpaceItButton({
    Key? key,
    required this.itemId,
    required this.itemType,
    required this.itemData,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  @override
  State<SpaceItButton> createState() => _SpaceItButtonState();
}

class _SpaceItButtonState extends State<SpaceItButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _waveAnimation;
  final SpaceController _spaceController = Get.find<SpaceController>();
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)], 
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () => _showSpaceItModal(),
            borderRadius: BorderRadius.circular(25),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + _waveAnimation.value * 0.1,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.rocket_launch,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Space It",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpaceItModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpaceItModal(
        itemId: widget.itemId,
        itemType: widget.itemType,
        itemData: widget.itemData,
        onSuccess: widget.onSuccess,
        onError: widget.onError,
      ),
    );
  }
}