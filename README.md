# ♞ Chess Move

A tiny macOS menu-bar app that serves you chess puzzles a few times a day.

- Lives in the menu bar (no Dock icon). **Click** the knight for a puzzle, **right-click** for the menu.
- Pops up automatically N times a day within your active hours (configurable, or off).
- Make a move by dragging or clicking → instant **✓ OK / ✗ Not OK** feedback.
- Drag the panel by its header (or the grab bar) to put it anywhere; drag the bottom-right corner to resize the board. Double-click the grab bar or right-click the icon → *Move Back Under Icon* to reset.
- **Hint** (1st press: highlights the piece + theme, 2nd press: shows an arrow), **Answer** (plays out the solution), **Skip**, **Close** (Esc).
- **Stockfish 19** checks your moves: if you find a different move that also wins, it's accepted and the engine takes over as your opponent. Wrong moves get an explanation ("Rd1 loses, engine −5.8").
- 6 levels (Beginner 600 → Master 2300+), 60,000 curated puzzles (10,000 per level) from the Lichess open database (CC0).
- Adjustable engine analysis strength, board themes, sounds, coordinates, launch at login, stats & streaks.

## Build & run

Requires macOS 14+, Xcode / Swift 6 and Stockfish (`brew install stockfish`; it gets bundled into the app).

```bash
scripts/build_app.sh            # -> build/Chess Move.app
scripts/build_app.sh --install  # also copies to /Applications and launches it
```

Run tests (perft move-generation, SAN, puzzle data validity):

```bash
swift test
```

## Layout

| Path | What |
| --- | --- |
| `Sources/ChessCore` | Chess rules: FEN, legal move generation, SAN (perft-verified) |
| `Sources/ChessMove/Engine` | UCI driver for Stockfish |
| `Sources/ChessMove/Model` | Puzzle session logic, puzzle store, scheduler, settings |
| `Sources/ChessMove/UI` | SwiftUI board, puzzle popover, settings |
| `Resources/puzzles.csv` | Puzzle set (`id,fen,moves,rating,themes`) |
| `Resources/make_puzzles.py` | Regenerates the puzzle set from the Lichess CSV |

Debug helper: `ChessMove --snapshot out.png [--play e2e4,hint,answer]` renders the UI offscreen (`PUZZLE_ID=…` picks a puzzle).

## Credits

Puzzles: [Lichess puzzle database](https://database.lichess.org/#puzzles) (CC0). Engine: [Stockfish](https://stockfishchess.org) (GPLv3).
