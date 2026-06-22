// lib/engine/dictionary.dart —
//
// Offline word validation. Compiles the bundled Scrabble word list into the Trie
// and, in permissive mode, also consults an expanded supplement.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:flutter/services.dart' show rootBundle;

import 'trie.dart';

/// Loads the bundled dictionaries into memory during application bootstrapping.
/// Validation thereafter is fully offline.
///
/// The official Scrabble word list is compiled into a [Trie] (also used by the
/// AI move generator). An optional "expanded" supplement — common English words
/// that the Scrabble list excludes, including slang/edgy words — is lazily
/// loaded into a membership [Set] and consulted only when [permissive] is on.
class Dictionary {
  final Trie _trie = Trie();
  Set<String>? _extended;
  bool _loaded = false;

  /// When true, [isValidWord] also accepts words from the expanded supplement.
  bool permissive = false;

  bool get isLoaded => _loaded;
  int get wordCount => _trie.wordCount;
  bool get extendedLoaded => _extended != null;
  int get extendedCount => _extended?.length ?? 0;

  /// The underlying prefix tree, used by the AI move generator.
  Trie get trie => _trie;

  /// Streams the raw Scrabble dictionary text from the asset bundle and compiles
  /// it into the prefix tree.
  Future<void> load({String assetPath = 'assets/dictionary.txt'}) async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(assetPath);
    _trie.loadFromRaw(raw);
    _loaded = true;
  }

  /// Lazily loads the expanded supplement (only needed for permissive mode).
  Future<void> loadExtended(
      {String assetPath = 'assets/dictionary_extended.txt'}) async {
    if (_extended != null) return;
    final raw = await rootBundle.loadString(assetPath);
    final set = <String>{};
    for (final line in raw.split('\n')) {
      final w = line.trim().toUpperCase();
      if (w.isNotEmpty) set.add(w);
    }
    _extended = set;
  }

  /// Test/seed hook to load words without an asset bundle.
  void loadWords(Iterable<String> words) {
    for (final w in words) {
      _trie.insert(w);
    }
    _loaded = true;
  }

  /// Test/seed hook to load the expanded supplement without an asset bundle.
  void loadExtendedWords(Iterable<String> words) {
    _extended = {for (final w in words) w.trim().toUpperCase()};
  }

  /// Rebuilds the Scrabble word list in place from fresh raw text. Returns the
  /// new word count. Used by the "Update dictionary" action.
  int refreshFromRaw(String raw) {
    _trie.clear();
    _trie.loadFromRaw(raw);
    return _trie.wordCount;
  }

  /// Rebuilds the expanded supplement in place from fresh raw text.
  void refreshExtendedFromRaw(String raw) {
    final set = <String>{};
    for (final line in raw.split('\n')) {
      final w = line.trim().toUpperCase();
      if (w.isNotEmpty) set.add(w);
    }
    _extended = set;
  }

  bool isValidWord(String word) {
    if (_trie.contains(word)) return true;
    if (permissive && _extended != null) {
      return _extended!.contains(word.trim().toUpperCase());
    }
    return false;
  }

  bool hasPrefix(String prefix) => _trie.hasPrefix(prefix);
}
