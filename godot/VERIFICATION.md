# Prototype verification

Verified October 31 2026 on this Windows PC with Godot 4.7.2 and the official
Godot Tools extension. This iteration is a LOCAL PROTOTYPE; no release EXE/ZIP
was rebuilt. Obsolete Java code/dependencies/CI/IDE settings and unused release
tooling/assets were removed. The workspace runs solely from the Godot source.

- Rules: **1,333 checks, zero failures**. Every card/item is exercised. Includes
  authoritative rollback, RNG/state roundtrips, seeded seven-square mysteries,
  empty placement, three draw markers, relocation/replenishment, no turn-start
  draws, Robotic Arm, chosen end-turn discards, signed Heist outcomes, Lasso,
  save migration and exact historical frames, bounded bots, campaign and expansion.
  Enemy move previews preserve all live state/RNG and respect frozen/Lasso rules
  without inheriting the acting court's shot or bonus-movement restrictions.
- ENet transport: independent host/client processes passed connection, role,
  movement and private-hand checks. Actual app controllers also synchronized
  guest movement, mandatory owner-selected discards, turn completion and timer.
- Source graphical interface suite passed at 1920x1080 using OpenGL Compatibility
  on the Intel Arc 140V and WASAPI. It checks innocent opening, concealed mystery
  hover, discovery effects, draw-tile explanation, card layouts, mouse/number play,
  pending discards, small warning, opt-out, two-click entry and disabling it,
  independent tips with hover pause, turn-grouped replay, W/S and A/D navigation,
  hidden controls, overflow scrolling, coordinates, pause, save/resume and bot.
  Added actual enemy selection, safe previews, secret pre-unlock bounties and their
  retroactive Chronicle display, turn-ten End Turn Early, fixed-position replay
  arrows entering prior moves/returning live, real card-tile draw/fade/slide and
  preservation of existing cards. All 21 unique 48px card illustrations were
  rendered together for review. Three menu rows and longer separate white/green
  and white/red discovery effects were captured at 1080p.
- The suite uses virtual viewport clicks/keys. Windows can clear board hover
  while its window is not focused, so the board's local motion handler is also
  exercised to verify the draw-tile tooltip. Fresh button layout is allowed to
  settle before virtual input. Real-window behavior should still be reviewed
  during visual iterations.
- Tests use separate normal/test save AND settings filenames. Renamed live saves
  copy from the previous application directory without changing originals.
- Screenshots and logs are under ignored godot/test-output/. No caches, renderer
  downloads or test artifacts belong in commits.
- After the desktop was unlocked, the running main menu, settings, migrated save,
  replay watermark/hidden controls and compact pause menu were reviewed directly.
  This caught and corrected decimal rank labels from JSON-restored board sizes.
- The final revised source was also opened normally. Clicking an opponent's
  bishop kept its description visible with diagonal move previews. Clicking the
  fixed left arrow displayed the actual preceding saved move; the right arrow
  returned to the live board. No move was played during this review.

An older Windows audio shutdown can warn about AudioStreamWAV playback references;
this is the previously documented engine cleanup issue, not a failed gameplay
assertion. Current verification completed without script errors. Actual play
across a second machine or Internet/Tailscale connection remains unverified.
