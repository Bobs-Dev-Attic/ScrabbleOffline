// lib/engine/remote_game.dart —
//
// Encoding/decoding for the two-device "share code" game. A remote game is fully
// reproducible from a shared random seed plus the ordered list of moves, so the
// only thing players exchange each turn is a compact code (no server, fully
// offline). Each device keeps its own rack on screen.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:convert';

/// A single recorded move in a remote game, replayable from the shared seed.
class RemoteMove {
  /// 'play' or 'pass'.
  final String type;

  /// For 'play': placements as [row, col, letter, blank(0/1)].
  final List<List<dynamic>> placements;

  const RemoteMove.play(this.placements) : type = 'play';
  const RemoteMove.pass()
      : type = 'pass',
        placements = const [];

  Map<String, dynamic> toJson() =>
      type == 'pass' ? {'t': 'x'} : {'t': 'p', 'w': placements};

  factory RemoteMove.fromJson(Map<dynamic, dynamic> j) {
    if (j['t'] == 'x') return const RemoteMove.pass();
    final w = (j['w'] as List)
        .map((e) => (e as List)
            .map<dynamic>((x) => x)
            .toList())
        .toList();
    return RemoteMove.play(w);
  }
}

/// The full, self-contained description of a remote game at a point in time:
/// the seed, the two seat names, and every move so far. Encodes to a short
/// shareable code (URL-safe base64 of JSON, prefixed for recognizability).
class RemoteGameCode {
  final int seed;
  final List<String> names; // [seat0, seat1]
  final List<RemoteMove> moves;

  RemoteGameCode({
    required this.seed,
    required this.names,
    required this.moves,
  });

  static const String prefix = 'SCRB1.';

  String encode() {
    final map = {
      'v': 1,
      's': seed,
      'n': names,
      'm': moves.map((m) => m.toJson()).toList(),
    };
    return prefix + base64Url.encode(utf8.encode(jsonEncode(map)));
  }

  /// Parses a code, returning null if it isn't a valid game code.
  static RemoteGameCode? decode(String code) {
    try {
      var c = code.trim();
      if (c.startsWith(prefix)) c = c.substring(prefix.length);
      c = c.trim();
      final mod = c.length % 4;
      if (mod != 0) c = c + '=' * (4 - mod);
      final map = jsonDecode(utf8.decode(base64Url.decode(c)))
          as Map<dynamic, dynamic>;
      final names =
          (map['n'] as List).map((e) => e.toString()).toList(growable: false);
      if (names.length != 2) return null;
      final moves = (map['m'] as List)
          .map((e) => RemoteMove.fromJson(e as Map<dynamic, dynamic>))
          .toList();
      return RemoteGameCode(seed: map['s'] as int, names: names, moves: moves);
    } catch (_) {
      return null;
    }
  }
}
