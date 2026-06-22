// lib/ui/animated_background.dart —
//
// A slowly-drifting gradient backdrop (rendered static for the battery-saver theme).
//
// See docs/DESIGN.md for how this fits the overall architecture.

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
    duration: const Duration(seconds: 22),
  );

  @override
  void initState() {
    super.initState();
    // Continuous loop (no reverse) so the drift never visibly stalls or bounces.
    if (widget.theme.animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(AnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme.animated && !_controller.isAnimating) {
      _controller.repeat();
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

    final base = theme.scaffold;
    final tint = Color.lerp(base, theme.appBar, 0.85)!;
    // A glow tinted by the accent — bright enough to read motion even on the
    // very dark themes (battery saver / high contrast are static and skip this).
    final glow =
        Color.lerp(base, theme.accent, theme.flashy ? 0.40 : 0.26)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final a = _controller.value * 2 * pi;
        // Rotating linear base gradient.
        final begin = Alignment(cos(a), sin(a));
        // A soft radial glow drifting along a Lissajous path, so the background
        // is visibly "alive" rather than a near-static gradient.
        final gx = 0.75 * cos(a * 1.3);
        final gy = 0.65 * sin(a * 0.9);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: -begin,
              colors: [base, tint, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(gx, gy),
                radius: 1.2,
                colors: [glow, glow.withValues(alpha: 0.0)],
                stops: const [0.0, 0.65],
              ),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
