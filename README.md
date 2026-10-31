# Schedule 1 Chess

A local Godot prototype where ordinary-looking chess reveals a royal court of
absurd items, hidden surprises and limited cards. Read the current
[game outline](docs/Schedule1ChessUpdatedOutline.docx) and
[agent handoff](docs/AGENT_HANDOFF.txt).

Run **Schedule 1 Chess (Godot prototype)** with **F5 in VS Code** or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Run
```

**Ctrl+Shift+B runs the local prototype.** Routine work does not export an EXE or
ZIP. Existing `dist/` files are older snapshots, not the current game.

Play solo at four bot difficulties, local two-player, native ENet multiplayer, or
the six-battle Shattered Crown campaign. Seven mystery tiles start hidden. The
first discovery unlocks the Bazaar; the second reveals three card-draw markers.
Reach one to draw and relocate it. There are no automatic turn-start draws.
Hold extra cards during your turn, then choose discards down to four at turn end.

Double-click cards, drag them to PLAY at the board center, or pick them up with
number keys. Click Chronicle to replay: hover previews, click pins, W/S select
actions, A/D change turns. Escape opens pause. Coordinates, Bazaar warnings and
two-click entry are configurable.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Test
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 NetworkTest
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Verify
```

The interface suite uses separate test saves and preferences. See the
[development guide](godot/README.md) and [verification record](godot/VERIFICATION.md).
The Godot project is `godot/`; Java folders `dreams/` and `src/` are historical.
Git branch: `AI-version-with-younger-mes-dreams` on `CitraTune/NewChess`.
