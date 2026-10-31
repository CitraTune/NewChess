# Schedule 1 Chess

A local Godot prototype where ordinary-looking chess reveals a royal court of
absurd items, hidden surprises and limited cards. Read the current
[game outline](docs/Schedule1ChessUpdatedOutline.docx) and
[agent handoff](docs/AGENT_HANDOFF.txt).

Run **Schedule 1 Chess (Godot prototype)** with **F5 in VS Code** or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Run
```

**Ctrl+Shift+B runs the local prototype.** The game is GDScript, with a small Godot
shader; Python authors the catalogs/documents and PowerShell runs development tools.
The unused Java implementations, dependency JAR, old builds and export tasks have
been removed from the project. Earlier implementations remain in Git history.

Play solo at four bot difficulties, local two-player, native ENet multiplayer, or
the six-battle Shattered Crown campaign. Seven mystery tiles start hidden. The
first discovery unlocks the Bazaar and reveals money earned so far; the second
reveals three card-draw markers. End Turn Early appears on player turn ten.
Reach one to draw and relocate it. There are no automatic turn-start draws.
Hold extra cards during your turn, then choose discards down to four at turn end.

Double-click cards, drag them to PLAY at the board center, or pick them up with
number keys. New cards slide and fade into the hand from its right edge. Click an
opponent's piece to pin its details and preview its potential moves. The large
Chronicle title opens replay; its left arrow steps straight into the previous move.
The right arrow returns to live play upon reaching the latest move. Hover previews,
click pins, W/S select actions and A/D change turns. Escape opens pause. Coordinates,
Bazaar warnings and
two-click entry are configurable.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Test
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 NetworkTest
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Verify
```

The interface suite uses separate test saves and preferences. See the
[development guide](godot/README.md) and [verification record](godot/VERIFICATION.md).
The Godot project is `godot/`. Only active game assets, tools, tests and design
documentation remain. Development tests also run in the Godot GitHub workflow.
Git branch: `AI-version-with-younger-mes-dreams` on `CitraTune/NewChess`.
