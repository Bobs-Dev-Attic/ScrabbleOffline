/// A node in the prefix tree. Children are keyed by uppercase letter.
class TrieNode {
  final Map<String, TrieNode> children = {};
  bool isWord = false;
}

/// In-memory prefix tree for O(L) word and prefix lookups, where L is the
/// length of the query string. All matching is case-insensitive.
class Trie {
  TrieNode _root = TrieNode();
  int _wordCount = 0;

  /// Root node, exposed for move-generation traversal.
  TrieNode get root => _root;

  int get wordCount => _wordCount;

  /// Empties the trie so it can be rebuilt in place (keeps the same Trie
  /// instance, so holders like the move generator stay valid).
  void clear() {
    _root = TrieNode();
    _wordCount = 0;
  }

  /// Inserts a single word into the trie.
  void insert(String word) {
    final normalized = word.trim().toUpperCase();
    if (normalized.isEmpty) return;
    var node = _root;
    for (var i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      node = node.children.putIfAbsent(ch, () => TrieNode());
    }
    if (!node.isWord) {
      node.isWord = true;
      _wordCount++;
    }
  }

  /// Bulk-load words from raw newline-delimited dictionary text.
  void loadFromRaw(String raw) {
    for (final line in raw.split('\n')) {
      insert(line);
    }
  }

  /// Returns true if [word] is a complete word in the dictionary.
  bool contains(String word) {
    final node = _descend(word);
    return node != null && node.isWord;
  }

  /// Returns true if any word in the dictionary starts with [prefix].
  bool hasPrefix(String prefix) => _descend(prefix) != null;

  TrieNode? _descend(String s) {
    final normalized = s.trim().toUpperCase();
    var node = _root;
    for (var i = 0; i < normalized.length; i++) {
      final next = node.children[normalized[i]];
      if (next == null) return null;
      node = next;
    }
    return node;
  }
}
