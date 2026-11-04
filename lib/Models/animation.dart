import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

enum AnimationType { opacity, translateX }

class FadeAnimation extends StatelessWidget {
  final double delay;
  final Widget child;

  const FadeAnimation(this.delay, this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    
    
    
    
    
    
    
    

    final x = MovieTweenProperty<double>();
    final y = MovieTweenProperty<double>();
    final opacity = MovieTweenProperty<double>();

    final MovieTween tweenM = MovieTween()
      ..scene(
          begin: const Duration(milliseconds: 0),
          end: const Duration(milliseconds: 500))
          .tween(opacity, Tween(begin: 0.0, end: 1.0))
          .tween(x, Tween(begin: -30.0, end: 1.0));

    return PlayAnimationBuilder<Movie>(
      delay: Duration(milliseconds: (500 * delay).round()),
      duration: tweenM.duration,
      tween: tweenM,
      child: child,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(value.get(x), 0),
          child: Opacity(opacity: value.get(opacity),
          child: child)

        );
      },
      
      
      
      
      
      
    );
  }
}

class ReverseFadeAnimation extends StatelessWidget {
  final double delay;
  final Widget child;

  const ReverseFadeAnimation(this.delay, this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    
    
    
    
    
    
    
    

    final x = MovieTweenProperty<double>();
    final y = MovieTweenProperty<double>();
    final opacity = MovieTweenProperty<double>();

    final MovieTween tweenM = MovieTween()
      ..scene(
          begin: const Duration(milliseconds: 0),
          end: const Duration(milliseconds: 500))
          .tween(opacity, Tween(begin: 0.0, end: 1.0))
          .tween(x, Tween(begin: 30.0, end: 1.0));

    return PlayAnimationBuilder<Movie>(
      delay: Duration(milliseconds: (500 * delay).round()),
      duration: tweenM.duration,
      tween: tweenM,
      child: child,
      builder: (context, value, child) {
        return Transform.translate(
            offset: Offset(value.get(x), 0),
            child: Opacity(opacity: value.get(opacity),
                child: child)

        );
      },
      
      
      
      
      
      
    );
  }
}