import 'dart:math';

import 'package:flutter/material.dart';

import 'game_theme.dart';

/// A subtle, slowly-drifting gradient backdrop that gives the game some life.
/// Static (no animation) for the battery-saver theme.
class AnimatedBackground extends StatefulWidget {
  final GameTheme theme;
  final Widget child;

  const AnimatedBackground({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.theme.animated) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme.animated && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.theme.animated && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (!theme.animated) {
      return Container(color: theme.scaffold, child: widget.child);
    }

    final c1 = theme.scaffold;
    final c2 = Color.lerp(theme.scaffold, theme.appBar, 0.7)!;
    final c3 = Color.lerp(theme.scaffold, theme.accent, theme.flashy ? 0.22 : 0.12)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * pi;
        final begin = Alignment(cos(angle), sin(angle));
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: -begin,
              colors: [c1, c2, c3],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
