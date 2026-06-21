import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/dictionary.dart';

void main() {
  group('Dictionary permissive mode', () {
    test('standard mode only accepts the Scrabble list', () {
      final dict = Dictionary()..loadWords(['CAT', 'DOG']);
      dict.loadExtendedWords(['ZZZAP', 'GROK']);

      expect(dict.isValidWord('CAT'), isTrue);
      expect(dict.isValidWord('GROK'), isFalse, reason: 'permissive is off');
    });

    test('permissive mode also accepts the expanded supplement', () {
      final dict = Dictionary()..loadWords(['CAT', 'DOG']);
      dict.loadExtendedWords(['GROK', 'ZZZAP']);
      dict.permissive = true;

      expect(dict.isValidWord('CAT'), isTrue, reason: 'still accepts Scrabble');
      expect(dict.isValidWord('GROK'), isTrue);
      expect(dict.isValidWord('NOTAWORD'), isFalse);
    });

    test('permissive without a loaded supplement falls back to Scrabble only',
        () {
      final dict = Dictionary()..loadWords(['CAT']);
      dict.permissive = true; // no extended words loaded
      expect(dict.isValidWord('CAT'), isTrue);
      expect(dict.isValidWord('GROK'), isFalse);
    });
  });
}
