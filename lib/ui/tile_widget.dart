import 'package:flutter/material.dart';

import '../models/tile.dart';
import 'game_theme.dart';

/// Visual representation of a single Scrabble tile, colored by the active theme.
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
    final display = tile.isUnassignedBlank ? '' : tile.letter;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: theme.richDecoration
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.tileGradient,
              )
            : null,
        color: theme.richDecoration ? null : theme.tileGradient.first,
        borderRadius: BorderRadius.circular(size * 0.12),
        border: Border.all(
          color: highlighted ? theme.accent : theme.tileBorder,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: theme.richDecoration
            ? const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
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
}
