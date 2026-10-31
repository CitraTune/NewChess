"""Author the native game's catalog from the user's Chess 2 outline."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
cards, items = [], []

def card(id, name, target, description, flavor=""):
    cards.append(dict(id=id, name=name, target=target.split(','), description=description, flavor=flavor, cost=0, group='card'))

def item(id, name, target, cost, description, flavor="", group='manual', **extra):
    items.append(dict(id=id, name=name, target=target.split(','), cost=cost, description=description, flavor=flavor, group=group, **extra))

card('chacha','Cha-Cha','pawn','Move a pawn one square left. The destination must be empty.','Everybody slide to the left.')
card('grass','Grass Knuckles','tile','Place a trap. A piece still there after its next turn is destroyed.','Touch grass. Carefully.')
card('greed','Pot of Greed','none','Draw two cards. You may hold more than four until your turn ends; then choose discards to keep four.','What does it do again?')
card('frog','Big Frog','empty','Summon a frog on your pawn starting rank. It advances one or two squares.','A distinguished gentleman.')
card('rat','Rat Hat','ally','Give a piece knight movement for this turn.','A very small cavalry officer.')
card('union','Unionize!','none','Your pawns can advance one extra square this turn.','Collective bargaining. Individual violence.')
card('vest','Homemade Vest','ally','Block the next ranged attack before your next turn.','Made with love. And scrap metal.')
card('collector',"Collector's Edition",'none','Gain $10 for every own turn this card has waited in your hand.','Mint condition.')
card('traffic','LA Traffic','none','End your turn immediately.','You are not going anywhere.')
card('gale','Gale Forces','tile','Push every piece in this file one square toward its own back rank, if open.','Please mind the gap.')
card('blackhole','Black Hole','tile','Freeze all pieces in a 3x3 area through their next turn. Friendly fire.','Personal space is cancelled.')
card('warp','Time Warp','ally','Return a piece to its starting square, if empty.','We have been here before.')
card('lasso','Lasso','enemy,enemy','Bind two opposing pieces within four squares of each other. Neither can move more than four squares away from the other.','An extremely awkward friendship.')
card('skyhook','Skyhook','ally','Extract a piece. After two rounds it returns on your pawn rank.','Your ride is here.')
card('scissors','Scissors','none',"Discard the opponent's oldest card.",'Paper had it coming.')
card('dnd','Do Not Disturb','none','Disable opposing items through their next turn.','Please leave the apocalypse outside.')
card('blanket','Blanket','ally','Hide the identity of your piece from your opponent until your next turn.','Probably just a pawn.')
card('ticket','Train Ticket','ally','Move a piece five squares forward into an empty square. Ends your turn.','One way. First class.')
card('scavenge','Scavenge','none','Your piece farthest toward the enemy gets a parcel (a glow marks it). Move that same piece onto either of your two home ranks within five rounds to earn $100.','Expenses reimbursed on return.')
card('radio','Radio Interference','enemy','Freeze an enemy through its next turn.','Can you hear me now?')
card('eject','Ejector Seat','ally','Move a piece two squares backward into an empty square.','A tactical change of scenery.')

item('shield','Shield','ally',100,'Absorb one direct capture. The attack still spends the enemy turn.','One very firm no.',group='tile', tile_only=True)
item('magic','Magic Shield','ally',100,'Absorb one spell or ranged hit. Direct captures still work.','Not rated for horse impact.',group='tile', tile_only=True)
item('treasure','Victoria\'s Secret','none',0,'Receive a treasure map. Approach the buried square to reveal its X.','There is something in the drawer.',group='tile',tile_only=True)
item('castling','Castling','ally,any',0,'Swap a friendly piece with any other piece. Ends your turn.','A change in management.',group='tile',tile_only=True)
item('spider','Spider Sac','queen',170,'On death, your queen releases two pawns that cannot promote.','Family business.',group='tile',tile_only=True)
item('lego','Lego Block','ally,ally',0,'Stack two unmoved allies. The survivor inherits both movement patterns.','Some assembly required.',group='tile',tile_only=True)
item('trojan','Trojan Horse','enemy',0,'Replace an enemy pawn, bishop or rook with an enemy knight.','Absolutely nothing suspicious.',group='tile',tile_only=True)
item('boots','Flame Boots','ally',180,'Moving leaves a one-round trail of fire. Any piece landing there burns.','Excessive snow boots.',group='passive')
item('ufo','UFO','none',170,'A random piece is abducted and replaced by up to four allied pawns.','We need to study you.')
item('gas','Gas Bomb','tile',160,'Cover a 3x3 empty-of-enemies area in gas for three rounds. Enemies die on entry.','The Geneva Convention does not apply to chess.')
item('bleach','Bleach','tile',40,'Remove a mystery, hazard or special tile.','Fry your hair.')
item('contractor','Contractor','soldier',110,'Temporarily grant a random upgrade path through this turn.','You only get what you paid for.')
item('speed','Heart of Speed','ally',160,'Move the selected piece repeatedly this turn, without capturing. End when ready.','A questionable supplement.')
item('doom','Doomed Fate','enemy',190,'Mark a non-royal enemy for death in five rounds.','Mate in twelve.',group='mystic')
item('wrath','Spirit of Wrath','ally',190,'This piece may make two consecutive captures in one turn.','Exactly what I wanted.')
item('chaos','Bottled Chaos','none',70,'Transform into another one-use item at each turn start.','On sale for a reason.',group='manual')
item('glass','Glass Armor','ally',130,'Make a piece invulnerable until your next turn.','An unconventional choice of material.')
item('lager',"Thor's Lager",'tile',210,'Lightning hits an occupied square in the chosen plus-shaped area. Friendly fire.','Drink responsibly.',group='mystic')
item('pacify','Pacify','enemy',120,'For one round an enemy can move but cannot capture.','Let us all calm down.',group='mystic')
item('rabid','Rabid Bite','enemy',120,'For one round an enemy may move only if it captures.','Anger management.',group='mystic')
item('conch','Giant Horse Conch','knight',230,'A knight also tramples enemies along its L-shaped path.','What did you think it said?',group='passive')
item('rein','Rein Carnation','ally',220,'On death, reincarnate as a pawn, knight or rook based on shop spending.','A fresh arrangement.',group='passive')
item('wendigo','Wendigo Skull','none',260,'Your next capture converts its victim and sacrifices the attacker.','Questionable ethics.',group='mystic')
item('agent','Double Agent','none',140,'Enable friendly captures this turn. Reusable after five rounds.','A red spy is in the base?',reusable=5)
item('tidal','Tidal Shift','none',180,'Swap each surviving pawn with the unit that started behind its file.','Adult swim.')
item('missile','Heatseeker Missile','enemy',350,'Hit a non-pawn enemy within five squares of your queen.','Raytheon loves you.')
item('flare','War Flare','tile',380,'Mark a radius-two area. Artillery hits after the opponent has had a turn.','Please vacate the premises.')
item('portals','Scroll of Distortion','empty,empty',240,'Create two linked portals. Enter either to emerge at the other if empty.','Quantum something.',group='mystic')
item('sanctuary','No Killing Sign','tile',170,'Protect a square from deaths. Kings remain vulnerable.','Terms and conditions apply.',group='mystic')
item('hilux','Toyota Hilux','pawn',280,'Give a pawn queen movement up to five squares. It can still use guns.','Insurrection truck.',group='passive')
item('kragle','Kragle','ally',130,'Glue a piece in place permanently. It cannot move or die.','Some assembly irreversible.',group='mystic')
item('retreat','Retreat Flag','ally',80,'Move a piece to its closest empty edge square. Ends your turn.','A strategic disagreement.')
item('jet','FA-18','tile',420,'Pay $100 to mark a row for an airstrike after one enemy turn. Eight-round cooldown.','Highway to the danger zone.',reusable=8)
item('helicopter','Helicopter','tile',320,'Pay $70 for a delayed 3x3 airstrike. Eight-round cooldown.','Fortunate son.',reusable=8)
item('counterspawn','Counterspawn','none',150,'Destroy enemy units summoned during the last round. Cannot use on purchase turn.','Back to life. Briefly.')
item('counterspell','Counterspell','none',150,'Cancel all pending delayed attacks and enemy timed effects.','Interception.',group='mystic')
item('automaton','C4 Automaton','empty',200,'Deploy a non-attacking automaton on your back rank. It explodes on death or by ability.','Not originally meant to blow up.')
item('goat','Rocket Goat','empty',300,'Deploy a goat on your back rank: two-square movement, three-square rocket attack.','An unfortunate combination of infantry and tanks.')
item('lotto','Lotto Ticket','none',50,'A gamble: 50% $60, 20% $25, 20% nothing, 5% $150, 5% $300.','Just one more.')
item('cia','CIA Agent','ally',0,'Sacrifice one friendly soldier and gain its capture value.','An unfortunate accounting error.')
item('sapling','Sapling','empty',150,'Plant a tree. In five rounds it matures and earns $15 each own turn.','Money does not grow on...',group='passive')
item('celestial','Celestial Sapling','empty',280,'Matures after five rounds. Grants a mystical item every five own turns.','The blue glow is actually hidden LEDs.',group='mystic')
item('robotic','Robotic Sapling','empty',280,'Matures after five rounds. Grants a mechanical item every five own turns.','We do not know how it gets bigger.',group='passive')
item('mothership','Mothership Distress Beacon','empty',650,'Deploy a four-square flying dropship. Its ability releases an octopus each turn.','The cavalry has tentacles.')
item('arm','Robotic Arm','none',160,'Draw two cards instead of one when you claim a marked card tile. Still discard down to four at turn end.','Is this all we could use it for?',group='passive')
item('insurance','Insurance Contract','none',180,'Receive $40 whenever one of your pieces dies.','Investing in put options.',group='passive')
item('decoy','Obvious Decoy','empty',180,'Deploy a rook-like decoy. On death it releases a knight.','Surely someone could be fooled.')
item('grave','Grave Robber','none',90,'Gain $30 for every piece that has died in this battle.','The dead do not need it. Right?')
item('heist','The Great Heist','none',100,'A 50% chance to steal up to $200, or two items if the enemy has no money.','Bellbottoms!')
item('dolphin','Bottled Space Dolphin Spirit','ally',260,'Move or capture with a piece three times this turn.','Did you bring an infinite bag?',group='mystic')
item('royalguard','Counter-Counter-Offensive Sabotage','royal',250,'Your king or queen cannot die for three rounds.','Includes counter-counter-counter measures.')
item('wizard','Wizard','none',200,'Mystical offers cost 25% less. Unlock the Chessnut Room.','Why do you barter with money?',group='passive')
item('egg','Egg','any_tile',70,'Throw at an enemy to stun it, or place on an empty square to hatch a baby goose.','Honk!')
item('wasps','Horde of Wasps','tile',170,'Sweep a file with wasps, destroying every pawn in it.','Not the bees.',group='mystic')
item('pack','Card Pack','none',100,'Draw five cards. Keep them during your turn, then choose discards down to four at turn end.','Gambling for kids.')
item('membership','Gun Costco Membership','none',120,'Unlock the Gun Costco department. Guns equip pawns.','Live and die by the second amendment.',group='passive')
item('spore','Curse of Spore','ally',170,'On death, leave destructible fungus on nearby empty squares.','At least the ending was colorful.',group='mystic')
item('shipping','AliExpress Shipping','none',75,'Two knights arrive on your back rank after eight rounds.','A patent or two may be breached.')
item('service','Secret Service','royal',220,'Non-royal enemies cannot move next to this king or queen.','Get down, Mr. President!',group='passive')
item('bulldoze','Bulldoze','rook',230,'Your rook may smash through one enemy and keep moving along its ray.','A minor traffic violation.',group='passive')
item('sabotage','Logistics Sabotage','none',130,'The enemy cannot use items during its next turn.','Where is your airstrike now?')
item('popup','Pop-Up Pawn','ally',90,'After this piece next moves, a new pawn appears in front if space allows.','Surprise reinforcements.')
item('pawn','Pawn Cannon','empty',100,'Launch a pawn into your own half. It cannot attack until your next turn.','Express delivery.')
item('halo','HALO Drop Commando','empty',240,'Deploy a protected commando outside the enemy back three ranks.','Feet first into trouble.')
item('throwingknife','Throwing Knife','pawn',100,'On death, kill the attacker as well.','The last laugh.',group='passive')
item('assassinknife','Assassin Knife','pawn',120,'After a capture, take one extra step forward if empty.','Keep walking.',group='passive')
item('amendment','Second Amendment','none',350,'Give every friendly pawn a random gun.','A well-regulated chessboard.')
item('combatboots','Combat Boots','pawn',110,'Increase pawn advance range by one.','These boots were made for marching.',group='gun')
item('barrett','Barrett','pawn',200,'Shoot enemies exactly two squares away. One-square movement.','Long-distance correspondence.',group='gun')
item('lewis','Lewis Gun','pawn',190,'Shoot adjacent enemies twice per turn.','A second opinion.',group='gun')
item('grenade','Slingshot and Grenade','pawn',140,'Shoot an adjacent enemy without moving.','Simple engineering.',group='gun')
item('glock','Glock 17','pawn',150,'Two-square movement and an adjacent ranged attack.','Pocket diplomacy.',group='gun')
item('m4','M4','pawn',220,'Two-square movement and a ranged attack within two surrounding squares.','A persuasive argument.',group='gun')
item('potgold','Pot of Gold','none',50,'Claim $300. Appears after meeting the Leprechaun.','Excellent financial advice.',group='special')

short_cards = {
 'chacha':'Slide a pawn one square left.', 'grass':'Place a trap. Staying there is fatal.',
 'greed':'Draw two cards.', 'frog':'Summon a frog on your pawn rank.', 'rat':'Give an ally knight movement this turn.',
 'union':'Pawns advance one extra square this turn.', 'vest':'Block one ranged hit until your next turn.',
 'collector':'Gain $10 per own turn held.', 'traffic':'End your turn.', 'gale':'Push this file toward each piece\'s home.',
 'blackhole':'Freeze a 3 x 3 area. Friendly fire.', 'warp':'Return an ally to its starting square.',
 'lasso':'Tether two enemies within four squares.', 'skyhook':'Extract an ally. Return in two rounds.',
 'scissors':'Discard the enemy\'s oldest card.', 'dnd':'Disable enemy items for one turn.',
 'blanket':'Hide an ally until your next turn.', 'ticket':'Move five squares forward. Ends turn.',
 'scavenge':'Deliver your marked piece home for $100.', 'radio':'Freeze an enemy for one turn.',
 'eject':'Move an ally two squares backward.'}
for definition in cards:
    definition['short'] = short_cards[definition['id']]

pieces = {k: dict(name=n, value=v) for k,n,v in [
 ('pawn','Pawn',50),('knight','Knight',150),('bishop','Bishop',150),('rook','Rook',250),('queen','Queen',450),('king','King',500),('frog','Big Frog',50),('goose','Baby Goose',50),('canadian','Canadian Goose',250),('automaton','C4 Automaton',100),('goat','Rocket Goat',200),('dropship','Mothership',450),('octopus','Space Octopus',50),('decoy','Obvious Decoy',100),('commando','HALO Commando',150),('fungus','Fungus',0),('tree','Money Tree',100)]}
data = dict(cards=cards, items=items, pieces=pieces,
 upgrades={'knight':['Dragon','Unicorn'],'rook':['M1 Abrams','Golem'],'bishop':['Necromancer','Divine Cleric']},
 fusions={'knight':'Sky Strider','rook':'Iron Warden','bishop':'Archmage'},
 tile_events=['shield','magic','treasure','castling','spider','lego','trojan','leprechaun','election','freeze','hypnosis','bees','morph','companion','fog','harvest','love'])
(ROOT / 'godot/game/content.json').write_text(json.dumps(data,indent=2,ensure_ascii=False), encoding='utf-8')
print(f'Catalog: {len(cards)} cards, {len(items)} items, {len(pieces)} piece types')
