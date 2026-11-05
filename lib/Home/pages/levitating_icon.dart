import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class LevitatingIcon extends StatefulWidget {
  const LevitatingIcon({super.key});

  @override
  State<LevitatingIcon> createState() => _LevitatingIconState();
}

class _LevitatingIconState extends State<LevitatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: const Icon(
            Icons.post_add,
            size: 100,
            color: MangoPalette.grey500,
          ),
        );
      },
    );
  }
}