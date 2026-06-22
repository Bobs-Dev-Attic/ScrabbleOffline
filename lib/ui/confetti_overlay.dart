// lib/ui/confetti_overlay.dart —
//
// A lightweight, dependency-free confetti celebration. When [trigger] increases
// it rains colored confetti from the top of the screen that drifts down and
// fades out near the bottom over ~3.5 seconds.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:math';

import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  /// Increase this to fire a new confetti burst.
  final int trigger;
  const ConfettiOverlay({super.key, required this.trigger});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _pieces = const []);
      }
    });

  final _rng = Random();
  List<_Piece> _pieces = const [];

  static const _colors = [
    Color(0xFFFFD54F), Color(0xFFFF8A65), Color(0xFFE57373), Color(0xFFBA68C8),
    Color(0xFF64B5F6), Color(0xFF4DD0E1), Color(0xFF81C784), Color(0xFFFFF176),
  ];

  @override
  void didUpdateWidget(ConfettiOverlay old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) {
      _spawn();
      _c.forward(from: 0);
    }
  }

  void _spawn() {
    _pieces = List.generate(90, (_) {
      return _Piece(
        x: _rng.nextDouble(),
        color: _colors[_rng.nextInt(_colors.length)],
        w: 6 + _rng.nextDouble() * 7,
        h: 9 + _rng.nextDouble() * 9,
        delay: _rng.nextDouble() * 0.25,
        swayAmp: 12 + _rng.nextDouble() * 34,
        swayFreq: 1 + _rng.nextDouble() * 2,
        phase: _rng.nextDouble() * pi * 2,
        spin: (_rng.nextDouble() * 2 - 1) * 6,
        fall: 0.85 + _rng.nextDouble() * 0.3,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pieces.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(_pieces, _c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _Piece {
  final double x; // 0..1 fraction of width
  final Color color;
  final double w, h;
  final double delay; // 0..1 start offset
  final double swayAmp, swayFreq, phase, spin, fall;
  const _Piece({
    required this.x,
    required this.color,
    required this.w,
    required this.h,
    required this.delay,
    required this.swayAmp,
    required this.swayFreq,
    required this.phase,
    required this.spin,
    required this.fall,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double progress; // 0..1
  _ConfettiPainter(this.pieces, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      // Per-piece normalized time after its start delay.
      final span = (1 - p.delay);
      var t = span <= 0 ? progress : (progress - p.delay) / span;
      if (t <= 0) continue;
      t = (t * p.fall).clamp(0.0, 1.0);

      final y = -p.h + t * (size.height + p.h * 2);
      final x = p.x * size.width +
          sin(t * p.swayFreq * 2 * pi + p.phase) * p.swayAmp;

      // Fade in quickly, hold, then fade out over the last 25% of the fall.
      final fadeIn = (t / 0.06).clamp(0.0, 1.0);
      final fadeOut = t > 0.75 ? (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;
      final opacity = fadeIn * fadeOut;
      if (opacity <= 0) continue;

      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + t * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
