// lib/ui/tile_widget.dart —
//
// Visual for a single tile, themed, with an optional 3D bevel/gloss in rich themes.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:flutter/material.dart';

import '../models/tile.dart';
import 'game_theme.dart';

/// Visual representation of a single Scrabble tile, colored by the active theme.
/// In rich themes it gets a subtle bevel + gloss to look three-dimensional.
class TileWidget extends StatelessWidget {
  final Tile tile;
  final double size;
  final bool highlighted;

  const TileWidget({
    super.key,
    required this.tile,
    this.size = 40,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeScope.of(context);
    final rich = theme.richDecoration;
    final display = tile.isUnassignedBlank ? '' : tile.letter;
    final radius = size * 0.14;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: rich
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _lighten(theme.tileGradient.first, 0.10),
                  theme.tileGradient.first,
                  theme.tileGradient.last,
                ],
                stops: const [0.0, 0.45, 1.0],
              )
            : null,
        color: rich ? null : theme.tileGradient.first,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted ? theme.accent : theme.tileBorder,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: rich
            ? [
                BoxShadow(
                  color: const Color(0x66000000),
                  blurRadius: size * 0.10,
                  offset: Offset(size * 0.04, size * 0.06),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Glossy highlight across the top to read as a raised, 3D surface.
          if (rich)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: size * 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          Center(
            child: Text(
              display,
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: theme.tileText,
              ),
            ),
          ),
          if (!tile.isBlank || tile.letter.isNotEmpty)
            Positioned(
              right: size * 0.08,
              bottom: size * 0.04,
              child: Text(
                '${tile.value}',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  color: theme.tileValueText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
