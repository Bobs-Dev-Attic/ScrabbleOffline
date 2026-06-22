import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/dictionary.dart';

void main() {
  group('Dictionary.looksLikeWordList', () {
    test('accepts a plausible newline word list', () {
      final raw = List.generate(1500, (i) => 'WORD').join('\n');
      expect(Dictionary.looksLikeWordList(raw), isTrue);
    });

    test('rejects an HTML error page', () {
      const raw = '<!DOCTYPE html>\n<html><body>503 Service Unavailable'
          '</body></html>';
      expect(Dictionary.looksLikeWordList(raw), isFalse);
    });

    test('rejects a too-small list', () {
      expect(Dictionary.looksLikeWordList('CAT\nDOG\nELF'), isFalse);
    });

    test('rejects empty text', () {
      expect(Dictionary.looksLikeWordList(''), isFalse);
    });

    test('rejects content with non-alphabetic entries', () {
      final raw = (['{"json": true}'] + List.generate(1500, (i) => 'WORD'))
          .join('\n');
      expect(Dictionary.looksLikeWordList(raw), isFalse);
    });
  });

  group('Dictionary.refreshFromRawValidated', () {
    test('replaces the trie for a valid list', () {
      final dict = Dictionary()..loadWords(['OLD']);
      final raw = (['CAT', 'DOG'] + List.generate(1500, (i) => 'WORD'))
          .join('\n');
      final n = dict.refreshFromRawValidated(raw);
      expect(n, greaterThan(0));
      expect(dict.isValidWord('CAT'), isTrue);
      expect(dict.isValidWord('OLD'), isFalse, reason: 'old list was replaced');
    });

    test('leaves the existing dictionary intact on invalid input', () {
      final dict = Dictionary()..loadWords(['KEEP']);
      final n = dict.refreshFromRawValidated('<html>nope</html>');
      expect(n, -1);
      expect(dict.isValidWord('KEEP'), isTrue, reason: 'unchanged on rejection');
    });
  });
}
