import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/state/settings.dart';

void main() {
  group('sound settings', () {
    test('all sounds on at a default volume', () {
      final s = SettingsController();
      expect(s.soundVolume, closeTo(0.7, 0.001));
      for (final k in SettingsController.soundKeys) {
        expect(s.soundEnabled(k), isTrue, reason: '$k on by default');
      }
    });

    test('disabling and re-enabling a single sound', () {
      final s = SettingsController();
      s.setSoundEnabled('invalid', false);
      expect(s.soundEnabled('invalid'), isFalse);
      expect(s.soundEnabled('place'), isTrue, reason: 'others unaffected');
      s.setSoundEnabled('invalid', true);
      expect(s.soundEnabled('invalid'), isTrue);
    });

    test('volume is clamped to 0..1', () {
      final s = SettingsController();
      s.setSoundVolume(1.8);
      expect(s.soundVolume, 1.0);
      s.setSoundVolume(-0.5);
      expect(s.soundVolume, 0.0);
      s.setSoundVolume(0.5);
      expect(s.soundVolume, 0.5);
    });
  });
}
