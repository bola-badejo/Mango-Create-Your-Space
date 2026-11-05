import 'package:flutter/material.dart';
import 'dart:math';
import 'package:mango/Core/theme/mango_palette.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isRecording;
  final double amplitude;

  const AudioVisualizer({
    Key? key,
    required this.isRecording,
    required this.amplitude,
  }) : super(key: key);

  @override
  _AudioVisualizerState createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _bars = List.generate(25, (index) => 0.0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateBars();
  }

  void _updateBars() {
    for (int i = 0; i < _bars.length; i++) {
      
      double baseHeight = sin((i * 0.25) + _animationController.value * 2 * pi) * 0.5 + 0.5;
      double amplitudeFactor = widget.amplitude;
      
      
      _bars[i] = baseHeight * amplitudeFactor;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateBars();
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _bars.asMap().entries.map((entry) {
          final height = entry.value;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 3,
            height: height * 40 + 2, 
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.red.shade400.withOpacity(0.8 + height * 0.2),
                  Colors.red.shade600.withOpacity(0.8 + height * 0.2),
                  Colors.red.shade800.withOpacity(0.8 + height * 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(MangoRadius.xs),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(height * 0.3),
                  blurRadius: 2,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CircleAudioVisualizer extends StatefulWidget {
  final bool isRecording;
  final double amplitude;

  const CircleAudioVisualizer({
    Key? key,
    required this.isRecording,
    required this.amplitude,
  }) : super(key: key);

  @override
  _CircleAudioVisualizerState createState() => _CircleAudioVisualizerState();
}

class _CircleAudioVisualizerState extends State<CircleAudioVisualizer> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> _particleHeights = List.generate(24, (index) => 0.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat();
  }

  @override
  void didUpdateWidget(CircleAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateParticles();
        return Container(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: CircleVisualizerPainter(
              particleHeights: _particleHeights,
              amplitude: widget.amplitude,
              time: _controller.value,
            ),
          ),
        );
      },
    );
  }

  void _updateParticles() {
    for (int i = 0; i < _particleHeights.length; i++) {
      double base = sin(i * 0.25 + _controller.value * 2 * pi) * 0.5 + 0.5;
      _particleHeights[i] = base * widget.amplitude;
    }
  }
}

class CircleVisualizerPainter extends CustomPainter {
  final List<double> particleHeights;
  final double amplitude;
  final double time;

  CircleVisualizerPainter({
    required this.particleHeights,
    required this.amplitude,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.red.shade300.withOpacity(0.3)
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, outerPaint);

    
    for (int i = 0; i < particleHeights.length; i++) {
      final angle = 2 * pi * i / particleHeights.length;
      final particleHeight = particleHeights[i];
      
      final particleRadius = 2 + particleHeight * 6;
      final distance = radius - 8 + particleHeight * 20;
      
      final x = center.dx + distance * cos(angle);
      final y = center.dy + distance * sin(angle);
      
      
      final pulse = 1.0 + sin(time * 2 * pi) * 0.3 * amplitude;
      
      final particlePaint = Paint()
        ..color = Colors.red.withOpacity(0.6 + amplitude * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particleRadius * pulse,
        particlePaint,
      );
    }

    
    final centerGradient = RadialGradient(
      colors: [
        Colors.red.shade400,
        Colors.red.shade600,
        Colors.red.shade800,
      ],
    );

    final centerPaint = Paint()
      ..shader = centerGradient.createShader(Rect.fromCircle(center: center, radius: 20))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 20, centerPaint);

    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = const TextSpan(
      text: '🎤',
      style: TextStyle(fontSize: 24),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(CircleVisualizerPainter oldDelegate) {
    return true;
  }
}