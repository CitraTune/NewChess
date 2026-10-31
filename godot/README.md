# Schedule 1 Chess development

This is the native Godot 4.7.2 local prototype. The root scene is `main.tscn`; its
controls are generated at runtime. Use Godot's Remote tree while playing to
inspect them. Use VS Code for scripts and Godot for importing and debugging.

F5 launches **Schedule 1 Chess (Godot prototype)**. Ctrl+Shift+B runs from source.
Routine changes do not require or produce release exports. The obsolete Java
implementations, JAR, Java CI/IDE settings, old exports and export tasks are removed.
The game uses GDScript and a Godot shader; Python and PowerShell support development.

## Local tools

The installed engine is `%LOCALAPPDATA%/NewChess/tools/godot-4.7.2/` and the extension
is `geequlim.godot-tools`. Workspace settings must point to the complete Godot EXE.
Run `tools/setup-godot.ps1` if reinstalling; it configures paths for the local user.
No administrator access, Java, .NET or browser server is needed for the game.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Run
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Test
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 NetworkTest
powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 Verify
```

`Test -Headless` runs interactions without the renderer. A graphical Test writes
1080p screenshots and reports under ignored `godot/test-output/`. The suite uses
separate save AND preference files. Run focused checks during development and
Verify after the meaningful work is ready. Do not rerun unchanged checks endlessly.

Use `Editor` for the Godot editor and `Import` for a headless import. Avoid duplicate
editors. LSP uses localhost:6005, editor DAP 6006 and VS Code debugging 6007.
If `project.godot` changes externally, reload from disk before quitting. Stacked
external-change and Quit dialogs caused the old exclusive-window error.

## Current rules and controls

Fresh standard matches look ordinary: no visible mystery stars, money, cards or
Bazaar button. Seven random empty squares hide surprises. Land on them to discover the
Bazaar, then cards, then rewards or curses. Discovery particles stay beneath pieces
and within half a tile. They begin white and choose ONE outcome color, green for
positive or red for negative, then fade. Neutral outcomes remain white. Money
still accrues secretly; after unlocking Bazaar, Chronicle reveals earlier bounties.
End Turn Early appears on the tenth player turn (ply 9), and stays hidden in replay.
Click enemy pieces to pin their details and preview legal potential moves without
issuing a command for that side. Three visible draw markers appear after cards unlock.
Reaching one draws a card and relocates it. Turn starts never draw cards. Robotic
Arm doubles a draw-tile claim. At turn end, choose extra discards down to four.

Cards fan out at the bottom. Single click inspects, double click plays, mouse drag
uses the generous blue PLAY zone, and number keys latch the matching card to the
mouse. Click the red hand zone or press Escape to return it. A menu click cancels
pickup and operates the menu. Full descriptions are in Particulars and replay;
card faces use shorter mechanics and larger flavor. Opponents expose only large
upside-down backs and a small numeric count. Both sides play to the BOARD center.
Drawn cards fade and slide in from the hand's right side without rebuilding or
animating existing cards. All 21 cards have dedicated original 48px pixel artwork.

Click the large Chronicle title to open turn-based pages. Its small title-only
hover tilts; the rest of Particulars stays still. The fixed bottom-left arrow opens
the previous move directly. Next is muted/disabled in live play; reaching the latest
move with it exits replay. Both arrows keep the same position in both views.
There is no live bullet history or Click to Explore caption.
Hover previews temporarily; click pins.
W/S choose actions, A/D change turns, arrows step, Home/End reach start/latest.
Replay highlights effects/captures and shows a bold translucent watermark. It
hides Bazaar and End Turn and cannot change the live match. Return to Live resumes.
A scrollbar appears on pages with more than six actions; short pages hide it.

Escape opens compact pause. Rules and Archive are there rather than the main
menu. The rotating tip panel always cycles unless hovered, with an eighteen-second
subtle fuse, inline arrows and a current/total count. Target prompts stay in
Particulars. The board has no zoom or pan; its pixel rotate icon flips it.
Coordinates include ranks and files, default off, and are optional in Settings.

Bazaar is invisible until unlocked. Paid browsing costs a turn, even without buying;
every fifth round has one free browse. Buying still ends the turn. A small warning
supports Don't warn me again. After opt-out, the default two-click entry first says
Click again to open, then enters on a second click within 3.5 seconds. Warning and
two-click entry have separate settings. Sound, music, reduced motion, local
rotation, coordinates, timer and fullscreen are also configurable.

## Saves and multiplayer

Data lives in `%APPDATA%/Godot/app_userdata/Schedule 1 Chess/`. The rename copies
legacy Dream Chess II saves/preferences only if destination files are absent,
leaving originals intact. Current settings and normal saves remain separate from
test files. Live legacy saves gain draw markers; historical frames restore without
migration so replay remains faithful. Earlier unrecorded actions cannot be rebuilt.

Host/join uses UDP 8799 by default, with LAN or Tailscale addresses. Host validation
and per-player snapshots preserve hidden hands. Loopback transport and actual app
controllers are verified, including guest discards. Second-machine Internet or
Tailscale connectivity is not yet verified. Network games are not offline saves.

## Editing content and documentation

Keep authoritative rules in `game/match.gd`, presentation in `ui/` and orchestration
in `game/app.gd`. `tools/build-content.py` generates `game/content.json`: 21 cards,
74 items and 17 units. Update both together. `short` is card-face copy; `description`
is the complete rule. `bot.gd`, `campaign.gd` and `network.gd` implement their named
systems. `ui/menu_boards.gd` owns three close rows of independent decorative
ordinary-chess positions. `ui/card_art.gd` contains the individual card illustrations.

Original theme: `docs/design-source.txt`. Current rules: the separate
`docs/Schedule1ChessUpdatedOutline.docx`. The builder is `tools/build-outline.py`;
use the bundled Codex Python/docx dependencies and visually verify rendered pages.
Read `docs/AGENT_HANDOFF.txt` before taking over. User instructions override stale
brainstorming ideas. Do not edit the original Google Doc without a new request.

Railway 1901, Krefeld Condensed and Atkinson Hyperlegible fonts have source notices
in `assets/fonts/`. Pixel silhouettes are original code drawings. Keep third-party
notices with any eventual release. Generated imports, test artifacts and release
binaries stay out of Git.
