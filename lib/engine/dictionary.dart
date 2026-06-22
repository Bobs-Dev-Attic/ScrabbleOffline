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

  // ---- Defensive validation for downloaded word lists ----
  // Fetched dictionary text is same-origin but still untrusted: a proxy error
  // page, truncated download, or tampered response must not silently replace
  // the in-memory dictionary. Callers gate refreshFromRaw on this.

  /// Hard ceiling on a downloaded list (bytes). The bundled list is ~2 MB; this
  /// leaves generous headroom while rejecting absurd payloads.
  static const int maxRawBytes = 16 * 1024 * 1024;

  /// Hard ceiling on line count.
  static const int maxRawLines = 600000;

  /// Minimum number of words for a response to be considered a real word list.
  static const int minWords = 1000;

  /// Returns true if [raw] plausibly looks like a newline-delimited word list:
  /// within size/line bounds, enough entries, and a sample of entries are
  /// purely alphabetic (rejecting HTML error pages, JSON, truncated junk, etc.).
  static bool looksLikeWordList(String raw) {
    if (raw.isEmpty || raw.length > maxRawBytes) return false;
    final lines = raw.split('\n');
    if (lines.length > maxRawLines) return false;
    final alpha = RegExp(r'^[A-Za-z]+$');
    var words = 0;
    var sampled = 0;
    for (final line in lines) {
      final w = line.trim();
      if (w.isEmpty) continue;
      words++;
      // Validate the shape of the first 500 non-empty entries; if any of those
      // isn't a plain alphabetic word, this isn't our dictionary.
      if (sampled < 500) {
        if (!alpha.hasMatch(w)) return false;
        sampled++;
      }
    }
    return words >= minWords;
  }

  /// Validates [raw] and, if it looks like a real word list, rebuilds the trie.
  /// Returns the new word count, or -1 if [raw] failed validation (leaving the
  /// existing dictionary untouched).
  int refreshFromRawValidated(String raw) {
    if (!looksLikeWordList(raw)) return -1;
    return refreshFromRaw(raw);
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
