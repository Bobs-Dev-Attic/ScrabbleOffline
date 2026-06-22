// lib/ui/game_theme.dart —
//
// Board theme palettes and behavior flags, plus an InheritedWidget scope so widgets
// rebuild reactively when the theme changes.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:flutter/material.dart';

/// Identifiers for the selectable board themes / modes.
enum AppThemeId { classic, dark, battery, arcade, highContrast }

/// A complete visual palette + behavior flags for the game, selected in
/// Settings. All themes work fully offline.
class GameTheme {
  final AppThemeId id;
  final String label;
  final String description;
  final IconData icon;

  final Brightness brightness;
  final Color seed;

  final Color scaffold;
  final Color appBar;
  final Color panel;
  final Color boardFrame;

  final Color cellStandard;
  final Color cellDL;
  final Color cellTL;
  final Color cellDW;
  final Color cellTW;
  final Color cellCenter;
  final Color premiumText;
  final Color hover;

  final List<Color> tileGradient;
  final Color tileBorder;
  final Color tileText;
  final Color tileValueText;

  final Color rack;
  final Color accent;

  /// Whether decorative animations play (tile pop-in, etc.).
  final bool animated;

  /// Extra flair reserved for the arcade theme (pulsing center, bigger pops).
  final bool flashy;

  /// Whether gradients/shadows are used (off in battery saver for flat, cheaper
  /// rendering).
  final bool richDecoration;

  const GameTheme({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.brightness,
    required this.seed,
    required this.scaffold,
    required this.appBar,
    required this.panel,
    required this.boardFrame,
    required this.cellStandard,
    required this.cellDL,
    required this.cellTL,
    required this.cellDW,
    required this.cellTW,
    required this.cellCenter,
    required this.premiumText,
    required this.hover,
    required this.tileGradient,
    required this.tileBorder,
    required this.tileText,
    required this.tileValueText,
    required this.rack,
    required this.accent,
    required this.animated,
    required this.flashy,
    required this.richDecoration,
  });

  ThemeData get materialTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
        scaffoldBackgroundColor: scaffold,
        fontFamily: 'Roboto',
        useMaterial3: true,
        // Dialogs are a clean white card with a soft border + shadow, readable
        // on every theme.
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 12,
          shadowColor: Color(0x66000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xFFB5965A), width: 1.5),
          ),
          titleTextStyle: TextStyle(
            color: Color(0xFF22311F),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(color: Color(0xFF3A463E), fontSize: 15),
        ),
      );

  static GameTheme forId(AppThemeId id) => switch (id) {
        AppThemeId.classic => classic,
        AppThemeId.dark => dark,
        AppThemeId.battery => battery,
        AppThemeId.arcade => arcade,
        AppThemeId.highContrast => highContrast,
      };

  static const classic = GameTheme(
    id: AppThemeId.classic,
    label: 'Classic',
    description: 'The traditional green board and cream tiles.',
    icon: Icons.grid_on,
    brightness: Brightness.dark,
    seed: Color(0xFF1B5E20),
    scaffold: Color(0xFF263238),
    appBar: Color(0xFF1B5E20),
    panel: Color(0xFF37474F),
    boardFrame: Color(0xFF1B5E20),
    cellStandard: Color(0xFF2E7D32),
    cellDL: Color(0xFF90CAF9),
    cellTL: Color(0xFF1976D2),
    cellDW: Color(0xFFEF9A9A),
    cellTW: Color(0xFFD32F2F),
    cellCenter: Color(0xFFEF9A9A),
    premiumText: Colors.white,
    hover: Color(0x80FFEB3B),
    tileGradient: [Color(0xFFF6E2B3), Color(0xFFE9C883)],
    tileBorder: Color(0xFFB5965A),
    tileText: Color(0xFF3A2E14),
    tileValueText: Color(0xFF5A4A22),
    rack: Color(0xFF6D4C41),
    accent: Color(0xFFB2FF59),
    animated: true,
    flashy: false,
    richDecoration: true,
  );

  static const dark = GameTheme(
    id: AppThemeId.dark,
    label: 'Dark',
    description: 'Easy on the eyes with muted, low-glare colors.',
    icon: Icons.dark_mode,
    brightness: Brightness.dark,
    seed: Color(0xFF263238),
    scaffold: Color(0xFF121212),
    appBar: Color(0xFF1F1F1F),
    panel: Color(0xFF1E1E1E),
    boardFrame: Color(0xFF1B1B1B),
    cellStandard: Color(0xFF242A2B),
    cellDL: Color(0xFF1E3A4C),
    cellTL: Color(0xFF15496E),
    cellDW: Color(0xFF5E2B2B),
    cellTW: Color(0xFF7A1F1F),
    cellCenter: Color(0xFF5E2B2B),
    premiumText: Color(0xFFB0BEC5),
    hover: Color(0x803F51B5),
    tileGradient: [Color(0xFF3A3A3A), Color(0xFF2A2A2A)],
    tileBorder: Color(0xFF555555),
    tileText: Color(0xFFE0E0E0),
    tileValueText: Color(0xFFAAAAAA),
    rack: Color(0xFF2A2320),
    accent: Color(0xFF64FFDA),
    animated: true,
    flashy: false,
    richDecoration: true,
  );

  static const battery = GameTheme(
    id: AppThemeId.battery,
    label: 'Battery Saver',
    description: 'True-black, flat, no animations — gentle on OLED batteries.',
    icon: Icons.battery_saver,
    brightness: Brightness.dark,
    seed: Color(0xFF2E7D32),
    scaffold: Color(0xFF000000),
    appBar: Color(0xFF000000),
    panel: Color(0xFF0A0A0A),
    boardFrame: Color(0xFF000000),
    cellStandard: Color(0xFF111111),
    cellDL: Color(0xFF14303D),
    cellTL: Color(0xFF103A55),
    cellDW: Color(0xFF3D1A1A),
    cellTW: Color(0xFF551515),
    cellCenter: Color(0xFF3D1A1A),
    premiumText: Color(0xFF888888),
    hover: Color(0x40FFFFFF),
    tileGradient: [Color(0xFF1A1A1A), Color(0xFF1A1A1A)],
    tileBorder: Color(0xFF333333),
    tileText: Color(0xFFDDDDDD),
    tileValueText: Color(0xFF999999),
    rack: Color(0xFF0A0A0A),
    accent: Color(0xFF4CAF50),
    animated: false,
    flashy: false,
    richDecoration: false,
  );

  static const arcade = GameTheme(
    id: AppThemeId.arcade,
    label: 'Arcade',
    description: 'Neon colors and extra animations for a playful vibe.',
    icon: Icons.videogame_asset,
    brightness: Brightness.dark,
    seed: Color(0xFF8E24AA),
    scaffold: Color(0xFF1A0033),
    appBar: Color(0xFF6A1B9A),
    panel: Color(0xFF311B92),
    boardFrame: Color(0xFF4A148C),
    cellStandard: Color(0xFF3949AB),
    cellDL: Color(0xFF00B0FF),
    cellTL: Color(0xFF2979FF),
    cellDW: Color(0xFFFF4081),
    cellTW: Color(0xFFD500F9),
    cellCenter: Color(0xFFFFD600),
    premiumText: Colors.white,
    hover: Color(0x80FFEB3B),
    tileGradient: [Color(0xFFFFF59D), Color(0xFFFFB300)],
    tileBorder: Color(0xFFFF6F00),
    tileText: Color(0xFF311B92),
    tileValueText: Color(0xFFAD1457),
    rack: Color(0xFF4A148C),
    accent: Color(0xFFFFEB3B),
    animated: true,
    flashy: true,
    richDecoration: true,
  );

  static const highContrast = GameTheme(
    id: AppThemeId.highContrast,
    label: 'High Contrast',
    description: 'Bold colors and crisp edges for maximum visibility.',
    icon: Icons.contrast,
    brightness: Brightness.dark,
    seed: Color(0xFFFFEB3B),
    scaffold: Color(0xFF000000),
    appBar: Color(0xFF000000),
    panel: Color(0xFF000000),
    boardFrame: Color(0xFFFFFFFF),
    cellStandard: Color(0xFF111111),
    cellDL: Color(0xFF00B0FF),
    cellTL: Color(0xFF2962FF),
    cellDW: Color(0xFFFF9100),
    cellTW: Color(0xFFFF1744),
    cellCenter: Color(0xFFFFD600),
    premiumText: Color(0xFF000000),
    hover: Color(0x80FFEB3B),
    tileGradient: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    tileBorder: Color(0xFF000000),
    tileText: Color(0xFF000000),
    tileValueText: Color(0xFF000000),
    rack: Color(0xFF000000),
    accent: Color(0xFFFFEB3B),
    animated: false,
    flashy: false,
    richDecoration: false,
  );

  static const all = [classic, dark, battery, arcade, highContrast];
}

/// Provides the active [GameTheme] to the widget subtree.
class GameThemeScope extends InheritedWidget {
  final GameTheme theme;

  const GameThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  static GameTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<GameThemeScope>();
    return scope?.theme ?? GameTheme.classic;
  }

  @override
  bool updateShouldNotify(GameThemeScope oldWidget) => theme.id != oldWidget.theme.id;
}
