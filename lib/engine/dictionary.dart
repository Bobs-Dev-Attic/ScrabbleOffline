import 'package:flutter/services.dart' show rootBundle;

import 'trie.dart';

/// Loads the bundled dictionary asset into an in-memory [Trie] during
/// application bootstrapping. Validation thereafter is fully offline.
class Dictionary {
  final Trie _trie = Trie();
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get wordCount => _trie.wordCount;

  /// The underlying prefix tree, used by the AI move generator.
  Trie get trie => _trie;

  /// Streams the raw dictionary text from the asset bundle and compiles it into
  /// the prefix tree.
  Future<void> load({String assetPath = 'assets/dictionary.txt'}) async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(assetPath);
    _trie.loadFromRaw(raw);
    _loaded = true;
  }

  /// Test/seed hook to load words without an asset bundle.
  void loadWords(Iterable<String> words) {
    for (final w in words) {
      _trie.insert(w);
    }
    _loaded = true;
  }

  bool isValidWord(String word) => _trie.contains(word);

  bool hasPrefix(String prefix) => _trie.hasPrefix(prefix);
}
