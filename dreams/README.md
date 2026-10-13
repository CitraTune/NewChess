# Chess II — AI version with younger me's dreams

A fresh **single-file Java game** based on the Chess 2 brainstorming. The original Java project and `master` are unchanged.

## Run in VS Code

Install a free **JDK 17 or newer** (such as Eclipse Temurin). Open this folder in VS Code and run in its terminal:

```sh
java Chess2.java
```

A native Java menu opens: **Solo vs bot**, **The Shattered Crown**, or **Local two-player**. Solo modes then offer a difficulty choice. No Maven, Gradle, npm, paid service, API key, or external library is needed. VS Code's Java extension is optional. From the repository root, run `java dreams/Chess2.java`.

## Solo and roguelike

```sh
java Chess2.java --bot normal
java Chess2.java --roguelike --bot hard
java Chess2.java --server --roguelike --bot normal
```

The last command prints a private browser link. You play Ivory; the bot controls Onyx. It thinks in the background, so the window stays responsive.

| Difficulty | Behavior |
| --- | --- |
| Easy | Random legal moves; useful for learning the variant |
| Normal | Evaluates captures, exposed pieces, cards and equipment with some randomness |
| Hard | Searches replies with a two-ply, limited-width search |
| Expert | Searches up to three plies with a larger thinking budget |

These are custom Chess II opponents, not Stockfish or rated chess engines. Search is bounded; Hard and Expert can still make mistakes. Normal and above can use cards, relics, upgrades and special abilities. Future opponent card draws and mystery outcomes are not predicted.

**The Shattered Crown** is an original six-battle roguelike inspired by the army-building loop of The Ouroboros King:

- Start with a king, knight, rook, two pawns and $150.
- Surviving units, permanent equipment, money and unused items carry forward. Fallen units stay lost unless revived.
- After each of the first five wins, choose one of three rewards: recruitment, money, supplies, a forge upgrade, revival or a permanent run relic.
- Choose a supply route or a harder elite battle. Battles three and six are bosses.
- Four permanent run relics grant starting shields, extra income, a larger opening hand or capture bonuses.
- Battles use an 8×8 board with mystery tiles, cards and the Bazaar available immediately. Temporary statuses and damage reset between battles; spent shields remain spent unless a relic restores them.

Lose your army and the run ends. Complete six battles to win. Relaunch for a new run; use `--seed 123` to repeat starting generation and rewards (your choices still affect the run). Runs currently live in memory, with no save/resume or between-run progression.

## Play with a friend in their browser

Your own computer hosts the match; keep Java running and the computer awake.

1. Install Tailscale on both computers. Share your host computer with your friend using Tailscale device sharing; have them accept it.
2. Find your host PC's Tailscale IPv4 address in the app (normally `100.x.y.z`).
3. Replace `YOUR_TAILSCALE_IP` with that address:

```sh
java Chess2.java --host --bind YOUR_TAILSCALE_IP
```

You play Ivory in the Java window. The terminal prints an **Onyx invite**. Send that complete link, including its `#...` suffix, to your friend. Your friend needs a browser and Tailscale, **not Java**.

Each invite is a private seat key. Share only the Onyx invite. Reopening the same invite rejoins that seat while the host remains running. Each player receives only their own hand; Java validates moves, turns, costs, and stale requests.

For **both players in browsers**:

```sh
java Chess2.java --server --bind YOUR_TAILSCALE_IP
```

Open the Ivory invite yourself; send the Onyx invite to your friend.

For **two browsers on your own PC**, run `java Chess2.java --server`. The default binding, `127.0.0.1`, accepts only this computer. On a home LAN, bind to your PC's LAN IP instead. The port is 8080; change it with `--port 8081`.

Tailscale avoids router port forwarding. If a firewall prompt appears, allow Java for the network you intend to use; do not disable the firewall globally. Tailscale sharing/access rules and the host firewall must allow the selected port. This program does not change Tailscale or firewall configuration.

Tailscale currently has a free Personal plan for personal use. No rented server, paid game service, or AI API is required.
[Free plans](https://tailscale.com/docs/account/manage-plans/free-plans-discounts) · [Private game-server sharing](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server).

## Options

```sh
java Chess2.java --seconds 60
java Chess2.java --server --bind YOUR_TAILSCALE_IP --port 8080 --seconds 90
java Chess2.java --seed 42
java Chess2.java --test
```

Turns are untimed by default. An enabled timer keeps running through help, shopping, disconnects, and desktop dialogs. Restart to begin a new match. **There is no save/load after the host exits in this alpha.** Restarting also creates new invite keys.

## What's playable

- Native Java local two-player play and optional browser multiplayer, sharing one Java rules engine.
- Six chess pieces, frogs, captures, promotion, money, army elimination.
- Kings can die for a $500 bounty without ending the match.
- 12 mystery outcomes: shop, cards, shield, magic shield, harvest, freeze, hypnosis, transmogrification, spider sac, enemy-pawn surround, treasure, fog.
- **15 cards and 14 relics**, targeting, fire/gas, armor, temporary movement, insurance, death summons.
- Bazaar inventory and refreshes, six upgrade paths and three fusions.
- Cleric revival; Archmage summon/spell/warp; Iron Warden durability and two cannon shots.
- **20×20 expansion on round 20**, board rotation, browser zoom, desktop scrolling, move highlights, event log, keyboard browser navigation.

## Explicit alpha rules

This is a first playable implementation, not every idea in the brainstorming.

- Victory is army elimination, an assumption because the notes do not define a replacement for checkmate.
- Both players start with $200. Capture values: pawn/frog $50, knight/bishop $150, rook $250, queen $450, king $500.
- One round is two player turns. Pawns auto-promote to queens. No check, checkmate, ordinary castling, or en passant.
- Shop visits consume a turn, including leaving without buying. Every fifth round gives one free browsing visit per player; purchases still end the turn.
- The Bazaar is a menu, not a walkable room. Some tile-only effects are purchasable here. Prices are provisional.
- Range includes diagonals except the Archmage's orthogonal spell. Dragon's extra rays stop at two squares; Unicorn's optional step needs an empty intermediate landing.
- M1 Abrams fires instead of moving. Iron Warden may fire twice or end after one shot; it cannot move or play cards between shots.
- Cleric revives base pieces within two squares at half capture value. Archmage summons on surrounding empty squares.
- Rein Carnation makes a nearby pawn. Treasure pays immediately. Egg can stun but cannot hatch yet.
- Fog covers two middle ranks; ending two owner turns there causes damage. Leaving resets exposure. Relevant armor can block damage.
- Expansion adds space behind, beside and between armies, remapping original squares.
- Temporary chess glyphs, no custom pixel art/audio yet. No matchmaking, persistent lobby or saved matches.
- Desktop hotseat is shared-screen. Browser hands are private.

See [ROADMAP.md](ROADMAP.md) for remaining dreams.

## Development checks

```sh
javac -encoding UTF-8 Chess2.java SoloTest.java
java Chess2 --test
java SoloTest
```

The branch's GitHub workflow compiles Java 17, tests rules and an actual two-client HTTP session, exercises desktop rendering under a virtual display, and checks two browser player sessions. Test tooling is not required to run the game.

