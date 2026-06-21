import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ui/game_theme.dart';

/// Persisted, observable user preferences (theme + dictionary mode). Offline,
/// stored locally in Hive.
class SettingsController extends ChangeNotifier {
  static const String boxName = 'scrabble_settings';
  Box? _box;

  AppThemeId themeId = AppThemeId.classic;
  bool permissiveDictionary = false;

  GameTheme get theme => GameTheme.forId(themeId);

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
    final t = _box!.get('theme', defaultValue: AppThemeId.classic.name) as String;
    themeId = AppThemeId.values.firstWhere(
      (e) => e.name == t,
      orElse: () => AppThemeId.classic,
    );
    permissiveDictionary =
        _box!.get('permissive', defaultValue: false) as bool;
  }

  void setTheme(AppThemeId id) {
    if (id == themeId) return;
    themeId = id;
    _box?.put('theme', id.name);
    notifyListeners();
  }

  void setPermissive(bool value) {
    if (value == permissiveDictionary) return;
    permissiveDictionary = value;
    _box?.put('permissive', value);
    notifyListeners();
  }
}
