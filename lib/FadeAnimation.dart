import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

enum AniProps { opacity, translateY }

class FadeAnimation extends StatelessWidget {
  final double delay;
  final Widget child;

  FadeAnimation(@required this.delay, this.child);

  @override
  Widget build(BuildContext context) {
    final tween = MovieTween()
      ..tween('opacity', Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
          .thenTween('translateY', Tween(begin: 120.0, end: 0.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut);

    return PlayAnimationBuilder<Movie>(
      tween: tween,
      child: child,
      duration: tween.duration,
      builder: (context, value, _) {
        return Container(
          color: Colors.pink, // use animated value
          width: 100,
          height: 100,
        );
      },
    );
  }
}
