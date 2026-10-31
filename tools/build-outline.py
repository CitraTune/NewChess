"""Rebuild the current design outline using the Codex document runtime's Python."""
import json
from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml.ns import qn

ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / 'godot/game/content.json').read_text(encoding='utf-8'))
doc = Document()
section = doc.sections[0]
section.top_margin = section.bottom_margin = Inches(.72)
section.left_margin = section.right_margin = Inches(.8)
for name in ['Normal', 'Title', 'Subtitle', 'Heading 1', 'Heading 2', 'Heading 3']:
    style = doc.styles[name]
    style.font.name = 'Calibri'
    style.font.color.rgb = RGBColor(0, 0, 0)
    style.paragraph_format.widow_control = True
doc.styles['Normal'].font.size = Pt(11)
doc.styles['Normal'].paragraph_format.line_spacing = 1.08
doc.styles['Normal'].paragraph_format.space_after = Pt(6)
# The bundled Word template can carry a blue Title border. Remove all inherited
# paragraph borders rather than letting that decoration survive in Word or PDF.
for border in list(doc.styles.element.iter(qn('w:pBdr'))):
    border.getparent().remove(border)
for name, size in [('Title', 26), ('Subtitle', 12), ('Heading 1', 17), ('Heading 2', 13), ('Heading 3', 11.5)]:
    doc.styles[name].font.size = Pt(size)
    doc.styles[name].paragraph_format.space_before = Pt(12 if name.startswith('Heading') else 0)
    doc.styles[name].paragraph_format.space_after = Pt(6)
    doc.styles[name].paragraph_format.keep_with_next = True
doc.core_properties.title = 'Schedule 1 Chess Game Outline'
doc.core_properties.author = 'Schedule 1 Chess'
doc.add_paragraph('Schedule 1 Chess Game Outline', 'Title')
doc.add_paragraph('Current rules and presentation as of October 31 2026', 'Subtitle')
doc.add_paragraph('Schedule 1 Chess begins as an innocent-looking chess game, then reveals a royal court full of absurd objects, hidden surprises and limited-use cards. This outline updates the original Chess 2 brainstorming document to match the playable Godot prototype and the agreed interface changes. The current rules below supersede conflicting ideas in that earlier outline.')

sections = [
('The identity of the game', [
 'Keep the original contrast between elegant royal typography, crisp pixel pieces and ridiculous real-world items. Ink, parchment, muted purple and gold frame the table. Cards use individual colors, such as green for Big Frog. Body text remains thick enough to read at 1080p.',
 'Schedule 1 Chess is the current name. The main menu contains the name, play modes, difficulty, Continue and Settings. Remove the former slogans, flavor paragraphs, Archive and How to Play links from that menu. Faint chessboards drift behind it and make ordinary chess moves at staggered slow intervals. These decorative positions may be implausible; they do not affect a match.',
 'Development is a local prototype workflow in Godot and VS Code. Do not produce release executables or ZIP exports for routine iterations. Keep changes in Git on AI-version-with-younger-mes-dreams and run checks appropriate to the changed rules and interactions.'
]),
('The board and the objective', [
 'Standard matches start on an 8 by 8 board with the usual chess army. Eliminate the opposing army to win. Kings can be captured for $500; losing a king does not end the game. The actual game has no check, checkmate, en passant or ordinary castling. Pawns promote automatically. The Castling item supplies its own swap effect.',
 'A turn means one player acting; a round contains one Ivory turn and one Onyx turn. Adjacent means orthogonally next to a square. Surrounding includes diagonals. Descriptions that specify a radius use square distance unless their pattern says otherwise.',
 'Standard duels expand to 20 by 20 at round 20. Existing pieces, tiles and delayed effects are remapped. Campaign battles remain 8 by 8. The whole board always fits its frame: there is no wheel zoom, drag pan or Reset View control. A pixel chessboard with a rotate arrow flips the board.',
 'Chess board coordinates are optional and off by default. Enabling the setting shows both files and ranks, and flipping the view changes their orientation consistently.'
]),
('Turns and actions', [
 'Play cards and activate items before moving a piece. Moving, shooting, purchasing or leaving a paid Bazaar visit ends the turn, except when an effect explicitly grants additional actions. LA Traffic ends the turn immediately. Train Ticket and Retreat Flag also spend the movement turn.',
 'Card play uses a single authoritative rules model. Invalid targets, stale commands and wrong-player actions are rejected without spending a card, consuming money or changing the random generator. Solo bots use detached snapshots. Network hosts validate submitted actions and keep opponents’ hands private.',
 'The timer can be off or set to 30, 60 or 90 seconds. Offline pause and replay stop the clock and bot; online play continues while menus or replay are open. If an enabled timer expires during a discard choice, the game resolves the required extra discards so the turn cannot stall.'
]),
('Hidden mysteries', [
 'Choose exactly seven distinct, random empty squares at the start of a battle. They are hidden mystery tiles: do not draw idle stars, highlight their locations or disclose them through hover. Different seeds choose different squares. Mysteries disappear when triggered.',
 'Landing on a mystery activates it. The first discovery unlocks the Bazaar. The second unlocks the card system. Later discoveries use the original pool of rewards, transformations, summons and curses. The remaining mysteries stay hidden. Expansion does not add another visible field of stars.',
 'A discovery emits a brief white glow and spinning stars beneath the landing piece. Stars spray in varied directions and sizes, fade before traveling half a square, and rapidly turn green for a positive result or red for a negative result. Neutral transformations and companions keep a white effect. Reduced Motion limits the decorative movement.',
 'Rewards include treasure maps, Shield, Magic Shield, Castling, Spider Sac, Lego Block, Trojan Horse, Leprechaun access and Harvest. Curses include Election Rigging, Freeze, Hypnotism, Bee Nest, Fog and linked deaths. Transmogrify changes a unit near its existing rank. The companion remains a small court-side discovery.'
]),
('Limited cards and draw tiles', [
 'Cards are a limited board resource. There are no automatic turn-start draws and no free opening hand when the card system unlocks. Once unlocked, maintain three marked card-draw tiles on distinct empty squares. These markers are visible card symbols, separate from hidden mystery tiles.',
 'Landing on a marked tile draws one random card for the landing piece’s owner. Immediately relocate that marker to another available empty square. Do not overlap a piece, another tile or a hazard when choosing a location. Replenish removed or overwritten markers to keep three available whenever the board has space.',
 'Robotic Arm draws two cards instead of one from a claimed draw tile. It does not create turn-start draws or increase hand capacity. Pot of Greed and Card Pack still draw the quantities printed on them. Scholar’s Charm can grant three cards at an unlocked campaign battle start.',
 'Players can hold more than four cards while taking their turn. When the turn ends, the owner chooses which extras to discard until exactly four remain. Resolve the triggering move or purchase first, then wait for those choices before the opponent begins. A pending choice survives save and resume. Bots choose legal discards for their own hands.',
 'Lasso targets two opposing pieces within four squares of each other. Neither linked piece may move more than four squares from the other. Scavenge selects the friendly piece farthest toward the opponent; that same marked carrier must return to either home rank within five rounds for $100. A pawn normally needs a movement card to retreat.'
]),
('Cards on the table', [
 'The player’s hand is a spread fan of portrait playing cards tucked along the bottom. Hovering raises it only enough to read the cards. Each hovered card lifts slightly. Single-click inspection does not spend it. Double-click plays it or begins its target selection.',
 'Cards can also be dragged onto a generous blue, glowing PLAY zone at the board center. A red return zone appears in the hand. Number keys 1 through 9 pick up the corresponding card without holding the mouse; click PLAY to use it, the hand to return it, or another menu control to cancel pickup while interacting with that control. Escape cancels a pickup or target selection.',
 'A held card follows the mouse from a top-center pivot with light inertia and a small wiggle. Returning or playing starts from its current pose and eases to the exact hand slot or board center. Both players’ played-card presentations resolve at the board center, not the screen center.',
 'Opponent cards use the same large portrait proportions, show only upside-down backs and cannot be inspected or played. Hover gives a small forward nudge. A small bordered number beside the fan shows its count; hide both the number and border when empty.',
 'Card position numbers are small translucent marks on the cards, without large circle badges. Long titles wrap to two readable lines. Flavor text is larger than the short mechanics text. Particulars and Chronicle tooltips show the full description, including complex targeting, duration and outcome details. Mechanics in Particulars are not enclosed in parentheses. There is no permanent Your Hand or activation-instruction label.'
]),
('The Bazaar and equipment', [
 'Hide the Bazaar button until the first discovery unlocks it. A paid visit spends the turn even without a purchase. Every fifth round grants one free browsing visit; purchases still end the turn. The store has six randomized offers, a $25 refresh, and departments for the Bazaar, Royal Forge, Gun Costco and the Chessnut Room.',
 'The visit warning is a small nearby panel. It explains the cost without taking over the screen and includes Don’t warn me again. Confirming a visit with that checked saves the opt-out. The warning can be restored in Settings.',
 'Require two clicks for Bazaar is on by default. While the warning is enabled, one click opens that warning. After opting out, the first click changes the button to Click again to open; a second click within the short confirmation window enters the store. The confirmation resets when the turn changes or the window expires. With both protections disabled, one click enters.',
 'Most items are manually activated or become persistent equipment and traits. One-use effects are consumed on successful activation. Reusable items show cooldowns. Guns equip pawns after Gun Costco Membership; Wizard reduces mystical prices by 25 percent and opens the Chessnut Room. Tile-only rewards are excluded from ordinary stock.',
 'The Royal Forge provides two paths each for knights, rooks and bishops. Combining two differently upgraded units of one base type creates the corresponding Alignation on an available back-rank square. The item and unit catalogs below describe the implemented effects.'
]),
('Chronicle and replay', [
 'Click Chronicle to open it over the Particulars panel. Each page represents one player’s turn: Ivory turn 1, Onyx turn 1, and so on, with a separate starting-position page. All actions in that turn remain together. More than six actions enable the action-list scrollbar; shorter turns have no scrollbar.',
 'Each action row includes its result details in the row text: for example a move followed by Mystery Cards, a capture bounty, an affected unit, or The Great Heist followed by a signed cash amount. Heist gains and losses are signed from the viewing player’s perspective. There are no separate Detail 1 of 3 controls or detail-navigation panel.',
 'Hover temporarily previews the historical board and highlights movement origins, destinations, captures and changed effects. Hovering a played-card row also shows its full card tooltip and recorded outcome. Leaving the row restores the pinned position. Clicking pins that state until another action is selected or replay is closed.',
 'W and S move up and down within the current action list. A and D move between turns. Left and Right still step through actions; Home and End reach the first and latest recorded states. Return to Live restores the live match.',
 'Replay never branches or mutates the actual game. A large bold translucent REPLAY watermark covers the board. Completely hide Bazaar and End Turn during replay. Save and resume retain history; older saves can only replay actions that were recorded. Historical network frames retain hand privacy.'
]),
('Menus tips and motion', [
 'Escape opens a compact centered pause menu with larger text and smaller vertically stacked buttons. Keep the table visible around it. Include the title, mode, Resume, Settings, How to Play, Archive, Save and Main Menu. Settings include sound, music, reduced motion, local auto-flip, coordinates, Bazaar warning, two-click Bazaar entry, turn timer and fullscreen.',
 'The lower-left tips cycle independently of selection, targeting, bot thinking and replay. Relevant actions do not hold or replace them. Hovering the tip panel alone pauses the fuse. The grey fuse is subtle and takes eighteen seconds to complete. Previous and next arrows sit together at its end; a current and total count remains visible. Clicking either arrow resets the timer.',
 'Clickable text that lacks a button outline uses a hand cursor, a small hover tilt and a fine underline. Keep decorative animations restrained: soft background drift, card sway and lifts, eased movement, short discovery effects and brief captures. The queen shares the king’s body silhouette with a distinct crown, avoiding a rook-like or cactus-like shape.'
]),
('Campaign modes and persistence', [
 'Modes are solo duels at Easy, Normal, Hard or Expert; local two-player; a six-battle Shattered Crown campaign; and native ENet two-player matches. The campaign carries the player’s surviving army, equipment, treasury and run relics between encounters, provides rewards and routes, and has bosses on battles three and six.',
 'The first campaign battle also begins with locked Bazaar and cards. Later encounters retain systems already unlocked, seed seven fresh hidden mysteries, and add the three draw markers if cards are unlocked. Hands reset between encounters; Scholar’s Charm grants its documented starting cards when the card system is active.',
 'Solo, local and campaign actions autosave. Settings are saved separately. The renamed prototype copies existing Dream Chess II saves and preferences into Schedule 1 Chess only when no current file exists, preserving the original files. Automated interface checks use separate test saves and preferences. Network games remain live host sessions and do not produce resumable offline saves.'
])]
sections[0][1].append('The live game is GDScript with a Godot shader. Python and PowerShell support content authoring and local development. Unused Java source, JAR dependencies, old IDE profiles, Java CI, the Gatsby font experiment and release export tasks have been removed. The main menu now uses three closely spaced rows of five decorative chessboards.')
sections[2][1].append('End Turn Early appears from the tenth player turn onward. Before that, players finish a turn by moving or taking another turn-ending action. Clicking any opposing piece pins its identity and details in Particulars and shows its potential movement. This preview respects that piece\'s restrictions, cannot command it and does not change the game state.')
sections[3][1].append('The sparkle lasts about one and a half seconds after arrival. Stars begin around the piece silhouette, spread asymmetrically and remain within half a tile. Each event chooses one color only: white to green for a positive result, or white to red for a negative result, then fades. It never cycles between red and green for one discovery.')
sections[5][1].append('Every card has its own detailed original 48 pixel illustration. Drawing a card slides it into the fan from the hand\'s right edge while fading from transparent to opaque. Multiple draws are slightly staggered and existing cards remain in place.')
sections[6][1].append('The economy is concealed until the Bazaar unlocks. Captures still earn their full bounties, but treasury labels, floating money amounts, king bounty copy and Chronicle financial hints are hidden. Once the Bazaar opens, the recorded earlier bounties become visible retroactively in Chronicle. Label the discovery only The Bazaar awakens rather than repeating it as Mystery Shop.')
sections[7][1].append('On the live screen, a large yellow Chronicle title is the entire hover-tilt target. Remove the live bullet history and Click to Explore caption. Fixed left and right move arrows sit at the bottom of the right column in both live and replay views. Left immediately opens the preceding move. Right is muted and disabled while live; advancing to the latest move returns to the main game automatically.')
for heading, paras in sections:
    doc.add_paragraph(heading, 'Heading 1')
    for text in paras: doc.add_paragraph(text)

doc.add_page_break()
doc.add_paragraph('Card catalog', 'Heading 1')
doc.add_paragraph('Each entry gives the full current rule and its flavor. Card faces use shorter mechanics; Particulars and Chronicle tooltips show the full details. Cards have no purchase price and are normally consumed when successfully played.')
for card in catalog['cards']:
    doc.add_paragraph(card['name'].replace('!', ''), 'Heading 3')
    p = doc.add_paragraph()
    p.add_run(card['description'])
    if card['flavor']:
        p.add_run(' ' + card['flavor']).italic = True

doc.add_page_break()
doc.add_paragraph('Item catalog', 'Heading 1')
doc.add_paragraph('Costs below are base Bazaar prices. Tile-only entries are discoveries rather than ordinary offers. A trait or equipment item becomes persistent after activation; its catalog rule describes the effect. Shielding, cooldowns, deployment limits and target restrictions still apply.')
for item in catalog['items']:
    label = item['name'].replace('!', '')
    price = 'Tile discovery' if item.get('tile_only') else f"${item['cost']}"
    doc.add_paragraph(label, 'Heading 3')
    p = doc.add_paragraph()
    p.add_run(f'{price}. ').bold = True
    p.add_run(item['description'])
    if item.get('reusable') and not any(word in item['description'].lower() for word in ['reusable','cooldown']): p.add_run(f" Reusable after {item['reusable']} rounds.")
    if item['flavor']: p.add_run(' ' + item['flavor']).italic = True

doc.add_page_break()
doc.add_paragraph('Units upgrades and Alignations', 'Heading 1')
doc.add_paragraph('Capture bounties use the base unit values below; special effects can alter the award. A unit’s equipment, upgrade, fusion and active statuses modify its base movement and survival rules.')
for ident, unit in catalog['pieces'].items():
    if ident in ['pawn', 'knight', 'bishop', 'rook', 'queen', 'king']:
        desc={'pawn':'Advance straight and capture diagonally. An unmoved pawn can advance two squares; reaching the far rank promotes it.', 'knight':'Leap in an L shape over intervening pieces.', 'bishop':'Slide diagonally until blocked.', 'rook':'Slide along a rank or file until blocked.', 'queen':'Slide along ranks, files or diagonals.', 'king':'Move one square in any direction. Capturable without ending the battle.'}[ident]
    else:
        desc={'frog':'Advance one or two squares, capture diagonally and promote.', 'goose':'One-square movement, no attack. Promotes into Canadian Goose.', 'canadian':'Five-square flying movement and attack.', 'automaton':'Three-square movement, no direct attack. Explodes on death or by its detonate action.', 'goat':'Two-square movement and three-square ranged attack.', 'dropship':'Four-square flight. Deploy an octopus instead of moving.', 'octopus':'One-square movement and attack.', 'decoy':'Rook movement up to three squares. Releases a knight on death.', 'commando':'Two-square movement and ranged attack.', 'fungus':'Destructible obstacle.', 'tree':'An investment that matures after five rounds.'}[ident]
    doc.add_paragraph(f"{unit['name']} ${unit['value']}. {desc}")
for heading, text in [
 ('Knight upgrades','Dragon adds forward and diagonal options to knight movement. Unicorn adds adjacent landing choices around a knight leap. Sky Strider combines knight and queen-style travel and can cross pieces.'),
 ('Rook upgrades','M1 Abrams adds a nearby cannon attack. Golem limits rook travel to three squares and resists attackers farther than two squares away. Iron Warden has short movement, survives ordinary direct captures, takes four ranged hits to destroy and can fire twice in a turn.'),
 ('Bishop upgrades','Necromancer summons two pawns near its own back rank after a kill. Divine Cleric cannot capture and revives a fallen ally at half base cost onto an empty nearby square. Archmage keeps bishop movement and gains Summon, a three-square rank or file Cast, and Warp to a square more than five tiles away.')]:
    doc.add_paragraph(heading, 'Heading 2'); doc.add_paragraph(text)

doc.add_paragraph('Source and change authority', 'Heading 1')
doc.add_paragraph('Original theme and content: Chess 2 brainstorming, saved locally in docs/design-source.txt. Original source https://docs.google.com/document/d/1GDvx3URa9pSkLYy1ozMG2TiZqrG-7ws89sX3C_67x8s/edit. The current prototype catalog, authoritative match rules and the user’s subsequent design instructions govern the updated behavior in this document. Balance and timing can continue to change during local playtesting.')
for paragraph in doc.paragraphs:
    if paragraph.style.name.startswith('Heading'):
        paragraph.text=' '.join(''.join(c if c.isalnum() or c.isspace() else ' ' for c in paragraph.text).split())
    if paragraph._p.pPr is not None:
        for border in list(paragraph._p.pPr.iter(qn('w:pBdr'))): border.getparent().remove(border)
out=ROOT/'docs/Schedule1ChessUpdatedOutline.docx'
doc.save(out)
print(out)
