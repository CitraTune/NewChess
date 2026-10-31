# Current prototype direction

As of October 31 2026 the game is Schedule 1 Chess. Routine iterations run locally
from Godot and VS Code rather than rebuilding release exports. The current design
is in Schedule1ChessUpdatedOutline.docx and the development handoff is
AGENT_HANDOFF.txt. Those supersede conflicting earlier notes below.

The latest changes use seven hidden mysteries, three relocating visible draw
tiles, no automatic draws, a four-card end-turn choice, two-opponent Lasso,
turn-grouped hover/pinned replay with WASD, a larger watermark and hidden actions,
small optional Bazaar warnings and two-click entry, an independent hover-paused
hint carousel, large opponent backs and subtle card numbers. Coordinates default
off; zoom/pan/reset controls are removed. A faint chessboard conveyor replaces
main-menu flavor text. The first campaign battle begins locked, later encounters
keep unlocked systems. Robotic Arm doubles draw-tile claims. Historical snapshots
restore without live-save migration. Tests isolate both saves and preferences.

## Earlier migration record

# Godot migration and design decisions

The source of truth for theme is the
[Chess 2 brainstorming document](https://docs.google.com/document/d/1GDvx3URa9pSkLYy1ozMG2TiZqrG-7ws89sX3C_67x8s/edit).
`design-source.txt` records the text and revision used for this implementation.
This migration interprets a brainstorming outline as a playable ruleset, using the
permission to improve mechanics rather than reproducing every Java behavior.

## Preserved direction

The game is a royal pixel-art court interrupted by ridiculous real-world objects.
Kings can be captured for $500 without ending the game. Hidden tiles unlock the
Bazaar and card play; later discoveries grant shields, summons, treasure, curses,
linked deaths, transformations and a tiny companion. The board expands to 20x20.
There are 21 cards and 74 purchasable or discoverable items, six piece upgrade
paths and three Alignation fusions. The Archive describes their implemented rules.

Railway 1901 supplies the royal display character; Krefeld Condensed accents the
larger labels. Atkinson Hyperlegible supplies
heavier, legible body text at 1080p. Purple, ink, parchment and gold unify every
screen. Item icons and pieces use crisp pixel silhouettes. Motion is limited to
soft backdrop drift, slight hand-card sway, eased piece travel, short capture
particles, hover feedback and brief discovery reveals. Reduced Motion disables
decorative motion. Audio is generated locally and can be muted independently.

The follow-up table pass adds portrait cards in a tucked fan. The shared hover
zone raises the hand, individual cards lift for inspection, and double-clicking
activates a card. Cards have distinct colors and a wider spread. Mouse dragging
and number-key pickup offer alternate activation through a blue PLAY zone;
cancelled pickups return smoothly to the hand. Opposing cards expose only backs
and a count. Played cards travel to the board center from their current pose or
their owner's side. Escape opens a compact title/mode/settings menu.
Clicking Chronicle opens every recorded action over the Particulars. Hovering
temporarily previews a frame and its highlights; clicking pins it. A REPLAY
watermark identifies history, and played-card rows show full card tooltips.
Its historical board is read-only and independent of the
live model. New saves retain history; older saves start recording from their
current position. Contextual hints, star hover explanations, explicit mechanics
under flavor text, parcel markers and a small shop confirmation teach as you play.
Tips have a visible fuse, manual arrows and a current/total count. Lasso targets
two opposing pieces. Hands can overflow mid-turn; the owner chooses extras to
discard down to four at the end of a turn, including after a Bazaar purchase.

## Deliberate adaptations

- Army elimination is the win condition. There is no check/checkmate, en passant
  or standard castling; the Castling item performs a swap. Pawns auto-promote.
- The shop is a set of departments in an overlay rather than a walkable room.
  Purchases and paid browsing cost a turn; browsing is free every fifth round.
  Guns, the Forge and Chessnuts are actual separate shop functions.
- First and second discoveries guarantee the shop and cards, putting the shop
  within the outline's first four revealed tiles. Standard duels expand at round
  20; campaign encounters keep their compact board. A round means one turn from
  each side. Explicit descriptions resolve the outline's
  ambiguous durations, costs, targeting and effect boundaries.
- A royal menu, battle HUD, inventory, targeting previews and paged Archive replace
  the Java desktop widgets and long scrolling panels. The 20x20 board has its own
  zoom/pan camera; this is useful camera movement rather than page scrolling.
- Native ENet multiplayer replaces browser clients. Both players run the exported
  game. There is no public lobby or automatically configured internet hosting.
- The six-battle Shattered Crown mode has persistent survivors/equipment, rewards,
  route choices and bosses. Bots run in a background thread with bounded thinking.
- Local saves contain the entire match and campaign state, including deterministic
  RNG state. Online hands are filtered separately for each player.
- The companion is an original electric star icon and court flavor, avoiding a
  dependency on third-party character artwork. Related item icons share motifs;
  this is a coherent original pixel set, not 74 separately illustrated objects.

## Architecture

The native rules own all state changes. Commands are checked against the player
and revision, applied transactionally, and rolled back on failure. Widgets dispatch
commands and render snapshots; they do not implement a second rules engine. The
same model serves hotseat, bots, campaign and the authoritative network host.
Content definitions live in JSON; all effect implementations live in GDScript.
The exported executable embeds its resources, including the JSON catalog.

The old Java sources remain for historical reference. They are not linked into
the Godot game. Godot is now the default VS Code launch/build/test workflow.

## Further polish

The complete playable refactor is the new base. Long play sessions can now guide
balance and pacing: all catalog effects have regression coverage, but automated
reachability/invariant checks cannot establish that every combination is balanced.
Future art work can replace shared item motifs with individual illustrations
without changing the rules. Real remote-network sessions remain a separate
environment check beyond the verified loopback host/client flow.
