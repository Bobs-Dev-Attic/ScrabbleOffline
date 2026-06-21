/// Immutable representation of a single Scrabble tile.
///
/// A tile holds a [letter] and its point [value]. Blank tiles are created with
/// the [Tile.blank] constructor; once a blank is placed on the board it is
/// assigned a letter via [assignBlank] while retaining a value of zero.
class Tile {
  /// The uppercase letter displayed on the tile. For an unassigned blank this
  /// is an empty string.
  final String letter;

  /// Point value of the tile. Blanks are always worth zero.
  final int value;

  /// Whether this tile originated from the bag as a blank.
  final bool isBlank;

  const Tile({
    required this.letter,
    required this.value,
    this.isBlank = false,
  });

  /// Creates an unassigned blank tile.
  const Tile.blank()
      : letter = '',
        value = 0,
        isBlank = true;

  /// Returns true when this is a blank that has not yet been assigned a letter.
  bool get isUnassignedBlank => isBlank && letter.isEmpty;

  /// Returns a copy of a blank tile with [chosenLetter] assigned. The value
  /// remains zero, preserving standard blank-tile scoring rules.
  Tile assignBlank(String chosenLetter) {
    assert(isBlank, 'assignBlank may only be called on blank tiles');
    return Tile(
      letter: chosenLetter.toUpperCase(),
      value: 0,
      isBlank: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'letter': letter,
        'value': value,
        'isBlank': isBlank,
      };

  factory Tile.fromJson(Map<dynamic, dynamic> json) => Tile(
        letter: json['letter'] as String,
        value: json['value'] as int,
        isBlank: json['isBlank'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is Tile &&
      other.letter == letter &&
      other.value == value &&
      other.isBlank == isBlank;

  @override
  int get hashCode => Object.hash(letter, value, isBlank);

  @override
  String toString() => isUnassignedBlank ? '[blank]' : '$letter($value)';
}
