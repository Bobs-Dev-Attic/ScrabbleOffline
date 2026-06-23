// lib/ui/help_screen.dart —
//
// A scrollable "How to play" guide covering the rules and this app's features.
// Reachable from the home screen and the in-game menu.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:flutter/material.dart';

import 'game_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: const Text('How to play'),
        backgroundColor: theme.appBar,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section('The goal', [
            'Build words on the 15×15 board to score points. The player with '
                'the most points when the tiles run out wins.',
          ]),
          _Section('Your rack', [
            'You hold up to 7 letter tiles. Drag a tile from your rack onto a '
                'board square to place it.',
            'The very first word must cross the centre ★ square.',
            'After that, every new word must connect to tiles already on the '
                'board, and each turn\'s tiles must sit in a single row or '
                'column with no gaps.',
          ]),
          _Section('Placing & fixing tiles', [
            'Drag tiles from your rack to the board. Drag a just-placed tile to '
                'another square to nudge it, or tap it to send it back.',
            '“Recall” returns all of this turn\'s tiles to your rack.',
            '“Mix” (shown before you place anything) shuffles your rack order.',
            'If you press Play on a word that isn\'t valid, the tiles shake — '
                'fix them and try again.',
          ]),
          _Section('Blank tiles', [
            'A blank tile can stand in for any letter — you choose the letter '
                'when you place it. Blanks are worth 0 points.',
          ]),
          _Section('Premium squares', [
            'DL / TL — double or triple that letter\'s value.',
            'DW / TW — double or triple the whole word\'s value.',
            'The centre ★ acts as a double-word square on the first move.',
          ]),
          _Section('Scoring', [
            'Add up each letter\'s value (applying any letter multipliers), '
                'then apply word multipliers.',
            'Use all 7 of your tiles in one turn for a 50-point “Bingo” bonus.',
          ]),
          _Section('Turn buttons', [
            'Pass — skip your turn.',
            'Swap — trade some tiles for new ones (counts as a turn; not '
                'available in two-device games).',
            'Suggest — rearranges your rack to spell a strong word and shows '
                'faint “ghost” tiles where it could go. Press again for other '
                'ideas.',
            'Play — submit your word.',
          ]),
          _Section('Coaching & celebrations', [
            'When you play the best possible word, confetti falls and your '
                'tiles sparkle. Otherwise the board briefly shows the best word '
                'you could have played and its points.',
            'You can turn this off in Settings → Gameplay.',
          ]),
          _Section('Words & dictionary', [
            'Words are checked instantly on-device. Turn on “Expanded / Casual” '
                'in Settings to also accept many everyday and slang words.',
          ]),
          _Section('Opponents', [
            'Play pass-and-play with a friend on one device, or “vs Computer” '
                'and choose the difficulty and how many opponents.',
          ]),
          _Section('Play on two devices', [
            'Tap “Two devices”. One player creates a game and shares the short '
                'code (copy it or show the QR); the other joins by pasting or '
                'scanning it.',
            'After each turn, share your move code / QR and your opponent '
                'enters it. No internet needed.',
          ]),
          _Section('Make it yours', [
            'Change the board theme — or create your own colour palette — in '
                'Settings. The app works fully offline and can be installed to '
                'your home screen.',
          ]),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Have fun!',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> points;
  const _Section(this.title, this.points);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
