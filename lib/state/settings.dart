// lib/state/settings.dart —
//
// Persisted, observable user preferences: board theme (built-in or custom
// palette) and dictionary mode.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:hive_flutter/hive_flutter.dart';

import '../ui/game_theme.dart';

/// A user-defined palette: a name plus a primary seed color (ARGB), from which
/// a full [GameTheme] is generated via [GameTheme.fromSeed].
class CustomPalette {
  final String id;
  String name;
  int seed; // ARGB

  CustomPalette({required this.id, required this.name, required this.seed});

  Color get color => Color(seed);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'seed': seed};

  factory CustomPalette.fromJson(Map<dynamic, dynamic> j) => CustomPalette(
        id: j['id'] as String,
        name: j['name'] as String,
        seed: j['seed'] as int,
      );

  GameTheme toTheme() =>
      GameTheme.fromSeed(customId: id, label: name, seedArgb: seed);
}

/// Persisted, observable user preferences (theme + dictionary mode). Offline,
/// stored locally in Hive.
class SettingsController extends ChangeNotifier {
  static const String boxName = 'scrabble_settings';

  /// Maximum number of saved custom palettes.
  static const int maxCustomPalettes = 5;

  Box? _box;

  /// The active theme key: either a built-in [AppThemeId] name (e.g. "classic")
  /// or "custom:<paletteId>".
  String activeKey = AppThemeId.classic.name;
  bool permissiveDictionary = false;
  List<CustomPalette> customPalettes = [];

  bool get isCustomActive => activeKey.startsWith('custom:');
  String? get activeCustomId =>
      isCustomActive ? activeKey.substring('custom:'.length) : null;

  /// True when the given built-in theme is the active selection.
  bool isBuiltinActive(AppThemeId id) => !isCustomActive && activeKey == id.name;

  /// The currently-selected theme (built-in or generated from a custom palette).
  GameTheme get theme {
    if (isCustomActive) {
      final id = activeCustomId;
      for (final p in customPalettes) {
        if (p.id == id) return p.toTheme();
      }
    }
    final builtin = AppThemeId.values.firstWhere(
      (e) => e.name == activeKey,
      orElse: () => AppThemeId.classic,
    );
    return GameTheme.forId(builtin);
  }

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
    activeKey =
        _box!.get('theme', defaultValue: AppThemeId.classic.name) as String;
    permissiveDictionary = _box!.get('permissive', defaultValue: false) as bool;
    final raw = _box!.get('custom_palettes', defaultValue: const <dynamic>[])
        as List;
    customPalettes = raw
        .map((e) =>
            CustomPalette.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
    // If the active custom palette no longer exists, fall back to Classic.
    if (isCustomActive && !customPalettes.any((p) => p.id == activeCustomId)) {
      activeKey = AppThemeId.classic.name;
    }
  }

  void setBuiltinTheme(AppThemeId id) {
    if (activeKey == id.name) return;
    activeKey = id.name;
    _box?.put('theme', activeKey);
    notifyListeners();
  }

  void selectCustomPalette(String id) {
    final key = 'custom:$id';
    if (activeKey == key) return;
    activeKey = key;
    _box?.put('theme', activeKey);
    notifyListeners();
  }

  Future<void> _persistPalettes() async {
    await _box?.put(
        'custom_palettes', customPalettes.map((p) => p.toJson()).toList());
  }

  /// Adds a new palette or updates an existing one (matched by id), capped at
  /// [maxCustomPalettes]. Returns false if a *new* palette would exceed the cap.
  Future<bool> saveCustomPalette(CustomPalette palette) async {
    final idx = customPalettes.indexWhere((e) => e.id == palette.id);
    if (idx >= 0) {
      customPalettes[idx] = palette;
    } else {
      if (customPalettes.length >= maxCustomPalettes) return false;
      customPalettes.add(palette);
    }
    await _persistPalettes();
    notifyListeners();
    return true;
  }

  Future<void> deleteCustomPalette(String id) async {
    customPalettes.removeWhere((e) => e.id == id);
    if (activeCustomId == id) {
      activeKey = AppThemeId.classic.name;
      await _box?.put('theme', activeKey);
    }
    await _persistPalettes();
    notifyListeners();
  }

  void setPermissive(bool value) {
    if (value == permissiveDictionary) return;
    permissiveDictionary = value;
    _box?.put('permissive', value);
    notifyListeners();
  }

  /// Wipes stored preferences and returns to defaults. Used by the Settings
  /// "Reset local data" action (alongside clearing the saved game).
  Future<void> resetToDefaults() async {
    await _box?.clear();
    activeKey = AppThemeId.classic.name;
    permissiveDictionary = false;
    customPalettes = [];
    notifyListeners();
  }
}
