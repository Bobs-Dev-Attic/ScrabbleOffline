import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/state/settings.dart';
import 'package:scrabble_offline/ui/game_theme.dart';

CustomPalette _p(String id, int seed) =>
    CustomPalette(id: id, name: 'P$id', seed: seed);

void main() {
  group('GameTheme.fromSeed', () {
    test('produces a custom theme with a seed-dependent key', () {
      final a = GameTheme.fromSeed(customId: 'x', label: 'X', seedArgb: 0xFF1565C0);
      final b = GameTheme.fromSeed(customId: 'x', label: 'X', seedArgb: 0xFFC62828);
      final aAgain =
          GameTheme.fromSeed(customId: 'x', label: 'X', seedArgb: 0xFF1565C0);
      expect(a.id, AppThemeId.custom);
      expect(a.key, isNot(b.key), reason: 'different seed -> different key');
      expect(a.key, aAgain.key, reason: 'same id+seed -> same key');
    });

    test('built-in themes key on their id name', () {
      expect(GameTheme.classic.key, 'classic');
      expect(GameTheme.monochrome.key, 'monochrome');
    });
  });

  group('SettingsController custom palettes', () {
    test('saves up to 5 palettes then refuses more', () async {
      final s = SettingsController();
      for (var i = 0; i < SettingsController.maxCustomPalettes; i++) {
        expect(await s.saveCustomPalette(_p('$i', 0xFF1565C0 + i)), isTrue);
      }
      expect(s.customPalettes.length, 5);
      expect(await s.saveCustomPalette(_p('overflow', 0xFF000000)), isFalse);
      expect(s.customPalettes.length, 5);
    });

    test('editing an existing palette updates in place (no new entry)', () async {
      final s = SettingsController();
      await s.saveCustomPalette(_p('a', 0xFF1565C0));
      await s.saveCustomPalette(CustomPalette(id: 'a', name: 'renamed', seed: 0xFFC62828));
      expect(s.customPalettes.length, 1);
      expect(s.customPalettes.first.name, 'renamed');
      expect(s.customPalettes.first.seed, 0xFFC62828);
    });

    test('selecting and resolving a custom palette as the active theme', () async {
      final s = SettingsController();
      await s.saveCustomPalette(_p('a', 0xFF6A1B9A));
      s.selectCustomPalette('a');
      expect(s.isCustomActive, isTrue);
      expect(s.activeCustomId, 'a');
      expect(s.theme.id, AppThemeId.custom);
      expect(s.theme.key, contains('custom:a:'));
    });

    test('deleting the active palette falls back to a built-in theme', () async {
      final s = SettingsController();
      await s.saveCustomPalette(_p('a', 0xFF6A1B9A));
      s.selectCustomPalette('a');
      await s.deleteCustomPalette('a');
      expect(s.customPalettes, isEmpty);
      expect(s.isCustomActive, isFalse);
      expect(s.theme.id, AppThemeId.classic);
    });

    test('CustomPalette JSON round-trips', () {
      final p = _p('z', 0xFF00838F);
      final back = CustomPalette.fromJson(p.toJson());
      expect(back.id, 'z');
      expect(back.seed, 0xFF00838F);
      expect(back.name, p.name);
    });
  });
}
