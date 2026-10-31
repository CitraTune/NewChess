class_name ChessMatch
extends RefCounted
## Authoritative native rules. Commands are transactional; presentation consumes events.

const Catalog = preload("res://game/catalog.gd")
const JUMPS = [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]
const ORTHO = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
const DIAG = [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]

var board_size = 8
var turn = 0
var ply = 0
var revision = 0
var next_id = 1
var winner = -1
var pieces: Array = []
var players: Array = []
var tiles: Dictionary = {}
var hazards: Dictionary = {}
var graves: Array = []
var pending: Array = []
var stock: Array = []
var log_lines: Array = []
var events: Array = []
var market_unlocked = false
var cards_unlocked = false
var reveals = 0
var fog = false
var shop_open = false
var shop_free = false
var free_visits = [-1,-1]
var shots = 0
var shots_id = -1
var bonus_id = -1
var bonus_moves = 0
var last_from = Vector2i(-1,-1)
var last_to = Vector2i(-1,-1)
var campaign_battle = false
var rng = RandomNumberGenerator.new()
var match_seed = 1
var history: Array = []
var record_history = true
var discard_due = -1
const TILE_RULES_VERSION = 2


func _init(seed_value: int = 1, setup: bool = true) -> void:
	match_seed = seed_value
	rng.seed = seed_value
	for side in range(2):
		players.append({"money":200,"hand":[],"items":[],"traits":[],"limit":4,"spent":0,"disabled":-1,"agent":-1,"union":-1,"wendigo":false,"chessnuts":0,"nut_ply":-1,"forced":-1,"bounty":0})
	if setup:
		var order = ["rook","knight","bishop","queen","king","bishop","knight","rook"]
		for x in range(8):
			add_piece(order[x],1,Vector2i(x,0))
			add_piece("pawn",1,Vector2i(x,1))
			add_piece("pawn",0,Vector2i(x,6))
			add_piece(order[x],0,Vector2i(x,7))
		seed_mysteries(7)
		restock()
		note("Capture armies. Collect relics. Break chess.")


static func key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x,pos.y]

static func pos_key(value: String) -> Vector2i:
	var values = value.split(",")
	return Vector2i(int(values[0]),int(values[1]))

static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x-b.x),absi(a.y-b.y))

func _free_tile_positions(excluded: Vector2i = Vector2i(-1,-1)) -> Array:
	var out: Array=[]
	for y in range(board_size):
		for x in range(board_size):
			var pos=Vector2i(x,y)
			if pos!=excluded and empty(pos) and not tiles.has(key(pos)) and not hazards.has(key(pos)): out.append(pos)
	return out

func seed_mysteries(count: int) -> void:
	var candidates=_free_tile_positions()
	for i in range(mini(count,candidates.size())):
		var pos=candidates.pop_at(rng.randi_range(0,candidates.size()-1))
		tiles[key(pos)]={"type":"mystery"}

func ensure_card_tiles(excluded: Vector2i = Vector2i(-1,-1)) -> void:
	if not cards_unlocked: return
	for tile_key in tiles.keys():
		if tiles[tile_key].type=="card_draw" and not empty(pos_key(tile_key)): tiles.erase(tile_key)
	var count=tiles.values().filter(func(tile: Dictionary) -> bool: return tile.type=="card_draw").size()
	var candidates=_free_tile_positions(excluded)
	for i in range(mini(maxi(0,3-count),candidates.size())):
		var pos=candidates.pop_at(rng.randi_range(0,candidates.size()-1))
		tiles[key(pos)]={"type":"card_draw"}

func round_number() -> int:
	return ply / 2 + 1

func inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < board_size and pos.y < board_size

func at(pos: Vector2i) -> Dictionary:
	for p in pieces:
		if p.pos == pos:
			return p
	return {}

func piece(id: int) -> Dictionary:
	for p in pieces:
		if p.id == id:
			return p
	return {}

func empty(pos: Vector2i) -> bool:
	return inside(pos) and at(pos).is_empty()

func add_piece(type: String, side: int, pos: Vector2i) -> Dictionary:
	var p = {"id":next_id,"type":type,"side":side,"pos":pos,"home":pos,"moved":false,"upgrade":"","fusion":"","status":{},"gear":[],"hp":4,"born":ply,"stack":[],"fog":0,"link":-1,"lasso":-1}
	next_id += 1
	pieces.append(p)
	return p

func active(p: Dictionary, status: String) -> bool:
	return not p.is_empty() and int(p.status.get(status,-1)) > ply

func note(text: String, kind: String = "log", details: Dictionary = {}) -> void:
	log_lines.push_front(text)
	if log_lines.size() > 80:
		log_lines.resize(80)
	var event = details.duplicate(true)
	event.kind = kind
	event.text = text
	events.append(event)

func effective_upgrade(p: Dictionary) -> String:
	return str(p.status.get("contractor_path",p.upgrade)) if active(p,"contractor") else str(p.upgrade)

func _put(out: Array, p: Dictionary, target: Vector2i, capture: bool = true) -> void:
	if not inside(target) or target == p.pos:
		return
	var victim = at(target)
	if victim.is_empty() or (capture and (victim.side != p.side or players[p.side].agent == ply)):
		if target not in out:
			out.append(target)

func _ray(out: Array, p: Dictionary, direction: Vector2i, limit: int) -> void:
	var pierced = false
	for step in range(1,limit+1):
		var pos = p.pos + direction*step
		if not inside(pos):
			break
		var q = at(pos)
		_put(out,p,pos,effective_upgrade(p) != "Divine Cleric")
		if not q.is_empty():
			if "bulldoze" in p.gear and q.side != p.side and not pierced:
				pierced = true
			else:
				break

func _pattern(out: Array, p: Dictionary, type: String) -> void:
	var direction = -1 if p.side == 0 else 1
	if type in ["pawn","frog"]:
		var steps = (2 if type == "frog" or not p.moved else 1) + (1 if players[p.side].union == ply else 0) + (1 if "combatboots" in p.gear else 0)
		if "barrett" in p.gear: steps=1
		for i in range(1,steps+1):
			var pos = p.pos + Vector2i(0,direction*i)
			if not empty(pos):
				break
			_put(out,p,pos,false)
		for dx in [-1,1]:
			var pos = p.pos + Vector2i(dx,direction)
			var q = at(pos)
			if not q.is_empty():
				_put(out,p,pos)
	elif type == "knight":
		for jump in JUMPS:
			_put(out,p,p.pos+jump)
	elif type in ["rook","bishop","queen","decoy"]:
		var directions = ORTHO if type in ["rook","decoy"] else DIAG
		if type == "queen":
			directions = ORTHO+DIAG
		for d in directions:
			_ray(out,p,d,3 if effective_upgrade(p) == "Golem" or type == "decoy" else board_size)
	else:
		var radius = {"king":1,"octopus":1,"commando":2,"goat":2,"automaton":3,"dropship":4,"canadian":5,"goose":1}.get(type,0)
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				_put(out,p,p.pos+Vector2i(dx,dy),type not in ["goose","automaton","dropship"])

func legal_moves(p: Dictionary) -> Array:
	var out: Array = []
	if p.is_empty() or winner != -1 or active(p,"frozen") or "kragle" in p.gear or shots > 0:
		return out
	if bonus_id >= 0 and bonus_id != p.id:
		return out
	var forced = piece(players[p.side].forced)
	if not forced.is_empty() and forced.id != p.id:
		return out
	if p.fusion == "Sky Strider":
		for y in range(board_size):
			for x in range(board_size):
				if x == p.pos.x or y == p.pos.y or absi(x-p.pos.x) == absi(y-p.pos.y):
					_put(out,p,Vector2i(x,y))
		_pattern(out,p,"knight")
	elif p.fusion == "Iron Warden":
		for dx in range(-2,3):
			for dy in range(-2,3):
				_put(out,p,p.pos+Vector2i(dx,dy))
	elif "hilux" in p.gear:
		for d in ORTHO+DIAG:
			_ray(out,p,d,5)
	elif p.type == "pawn" and ("glock" in p.gear or "m4" in p.gear):
		for d in ORTHO+DIAG:
			for r in range(1,3):
				if not empty(p.pos+d*r):
					break
				_put(out,p,p.pos+d*r,false)
	else:
		_pattern(out,p,p.type)
	for extra in p.stack:
		_pattern(out,p,extra)
	var upgrade = effective_upgrade(p)
	if upgrade == "Dragon":
		for dx in [-1,0,1]:
			_ray(out,p,Vector2i(dx,-1 if p.side == 0 else 1),2)
	if upgrade == "Unicorn":
		for jump in JUMPS:
			if empty(p.pos+jump):
				for d in ORTHO+DIAG:
					_put(out,p,p.pos+jump+d)
	if active(p,"rat"):
		_pattern(out,p,"knight")
	var linked = piece(p.lasso)
	var filtered: Array = []
	for target in out:
		var q = at(target)
		if not linked.is_empty() and distance(target,linked.pos) > 4:
			continue
		if active(p,"pacified") and not q.is_empty():
			continue
		if active(p,"no_attack") and not q.is_empty():
			continue
		if active(p,"rabid") and q.is_empty():
			continue
		if active(p,"speed") and not q.is_empty():
			continue
		if active(p,"wrath") and q.is_empty():
			continue
		var protected = false
		for royal in pieces:
			if royal.side != p.side and "service" in royal.gear and p.type not in ["queen","king"] and distance(target,royal.pos) <= 1:
				protected = true
		if not protected:
			filtered.append(target)
	return filtered

func targets(definition: Dictionary, stage: int, prior: Array = []) -> Array:
	var out: Array = []
	if definition.is_empty() or stage >= definition.target.size():
		return out
	var kind = definition.target[stage]
	for y in range(board_size):
		for x in range(board_size):
			var pos = Vector2i(x,y)
			var p = at(pos)
			var ally = not p.is_empty() and p.side == turn
			var valid = false
			match kind:
				"tile", "any_tile": valid = true
				"empty": valid = p.is_empty()
				"any": valid = not p.is_empty()
				"ally": valid = ally
				"enemy": valid = not p.is_empty() and not ally
				"pawn","queen","knight","rook": valid = ally and p.type == kind
				"royal": valid = ally and p.type in ["king","queen"]
				"soldier": valid = ally and p.type in ["knight","bishop","rook"]
			if pos in prior:
				valid = false
			if valid:
				var direction=-1 if turn==0 else 1
				match str(definition.get("id","")):
					"frog": valid=y==(board_size-2 if turn==0 else 1)
					"chacha": valid=empty(pos+Vector2i(-1,0))
					"eject": valid=empty(pos+Vector2i(0,-direction*2))
					"ticket": valid=empty(pos+Vector2i(0,direction*5))
					"warp": valid=not p.is_empty() and empty(p.home)
					"lasso":
						if stage==1 and not prior.is_empty(): valid=distance(pos,prior[0])<=4
			if valid:
				out.append(pos)
	return out

func _spawn_near(type: String, side: int, origin: Vector2i, count: int, gear: Array = []) -> void:
	for radius in range(1,board_size):
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				var pos = origin+Vector2i(dx,dy)
				if maxi(absi(dx),absi(dy)) == radius and empty(pos):
					var p = add_piece(type,side,pos)
					p.gear = gear.duplicate()
					count -= 1
					if count <= 0:
						return

func _spawn_back(type: String, side: int) -> Dictionary:
	for rank in [board_size-1,board_size-2] if side == 0 else [0,1]:
		for x in range(board_size):
			if empty(Vector2i(x,rank)):
				return add_piece(type,side,Vector2i(x,rank))
	return {}

func _hit(victim: Dictionary, attacker: Dictionary = {}, ranged: bool = false, cascade: bool = false) -> bool:
	if victim.is_empty() or piece(victim.id).is_empty():
		return false
	if not cascade:
		var safe_tile = tiles.get(key(victim.pos),{}).get("type","") == "sanctuary" and victim.type != "king"
		if active(victim,"immune") or "kragle" in victim.gear or safe_tile:
			note("%s is protected." % Catalog.piece_name(victim),"shield",{"pos":victim.pos})
			return false
		if ranged and active(victim,"vest"):
			victim.status.erase("vest")
			note("The homemade vest absorbs the shot.","shield",{"pos":victim.pos})
			return false
		var shield = "magic" if ranged else "shield"
		if shield in victim.gear:
			victim.gear.erase(shield)
			note("%s shatters." % ("Magic shield" if ranged else "Shield"),"shield",{"pos":victim.pos})
			return false
		if victim.fusion == "Iron Warden":
			if not ranged:
				note("Iron Warden resists direct attacks.","shield",{"pos":victim.pos})
				return false
			victim.hp -= 1
			if victim.hp > 0:
				note("Iron Warden: %d armor remains." % victim.hp,"shield",{"pos":victim.pos})
				return false
		if effective_upgrade(victim) == "Golem" and not ranged and not attacker.is_empty() and distance(victim.pos,attacker.pos) > 2:
			note("The distant attack cannot break the Golem.","shield",{"pos":victim.pos})
			return false
	var pos = victim.pos
	var side = victim.side
	pieces.erase(victim)
	graves.append({"type":victim.type,"side":side})
	var bounty = Catalog.value(victim.type)
	if not attacker.is_empty() and attacker.side != side:
		bounty += players[attacker.side].bounty
		players[attacker.side].money += bounty
		note("%s captured. +$%d%s" % [Catalog.piece_name(victim),bounty,". The king falls; the battle continues!" if victim.type == "king" else ""],"capture",{"pos":pos,"value":bounty,"side":attacker.side,"type":victim.type})
	else:
		note("%s falls." % Catalog.piece_name(victim),"capture",{"pos":pos,"value":0,"side":side,"type":victim.type})
	if "insurance" in players[side].traits:
		players[side].money += 40
	if "rein" in victim.gear:
		var type = "rook" if players[side].spent >= 800 else ("knight" if players[side].spent >= 350 else "pawn")
		if empty(pos):
			add_piece(type,side,pos)
	if "spider" in victim.gear:
		_spawn_near("pawn",side,pos,2,["no_promote"])
	if "spore" in victim.gear:
		_spawn_near("fungus",side,pos,6)
	if victim.type == "decoy":
		_spawn_near("knight",side,pos,1)
	if victim.type == "automaton":
		for q in pieces.duplicate():
			if distance(pos,q.pos) <= 1:
				_hit(q,{},true,true)
	if victim.link >= 0 and not cascade:
		_hit(piece(victim.link),{},true,true)
	if "throwingknife" in victim.gear and not attacker.is_empty() and not cascade:
		_hit(attacker,{},true,true)
	if not attacker.is_empty() and effective_upgrade(attacker) == "Necromancer":
		_spawn_near("pawn",attacker.side,Vector2i(board_size/2,board_size-1 if attacker.side == 0 else 0),2)
	return true

func _land(p: Dictionary) -> void:
	if piece(p.id).is_empty():
		return
	var pos = p.pos
	var k = key(pos)
	var tile = tiles.get(k,{})
	match tile.get("type",""):
		"mystery":
			tiles.erase(k)
			_mystery(p)
		"card_draw":
			tiles.erase(k)
			var count=2 if "arm" in players[p.side].traits else 1
			draw_cards(p.side,count)
			ensure_card_tiles(pos)
			note("Card tile: draw %d card%s."%[count,"" if count==1 else "s"],"card_draw",{"pos":pos,"side":p.side,"count":count})
		"banana":
			players[p.side].money += 10
			tiles.erase(k)
			note("Bountiful Harvest: +$10.","gold",{"pos":pos,"value":10})
		"portal":
			var dest = tile.exit
			if empty(dest):
				p.pos = dest
				note("A wrinkle in space.","warp",{"from":pos,"pos":dest})
		"bees":
			players[p.side].forced = p.id
			for q in pieces.duplicate():
				if q.type == "pawn" and distance(pos,q.pos) <= 3:
					_hit(q,{},true)
	if p.type in ["pawn","frog","goose"] and "no_promote" not in p.gear and p.pos.y == (0 if p.side == 0 else board_size-1):
		p.type = "canadian" if p.type == "goose" else "queen"
		note("Promotion: %s!" % Catalog.piece_name(p),"reveal",{"pos":p.pos,"item":"promotion"})
	if hazards.has(key(p.pos)):
		var hazard = hazards[key(p.pos)]
		if hazard.type=="trap":
			p.trap_until=ply+2
			p.trap_pos=p.pos
			hazards.erase(key(p.pos))
		elif hazard.type == "fire" or hazard.owner != p.side:
			_hit(p,{},true)
	if p.get("parcel_deadline",-1) > ply and (p.pos.y >= board_size-2 if p.side == 0 else p.pos.y <= 1):
		players[p.side].money += 100
		p.erase("parcel_deadline")
		note("Scavenge parcel delivered. +$100.","gold",{"pos":p.pos,"value":100})
	for treasure_key in tiles.keys():
		var treasure = tiles[treasure_key]
		if treasure.type == "treasure" and treasure.owner == p.side and distance(p.pos,pos_key(treasure_key)) <= 1:
			treasure.visible = true
			if p.pos == pos_key(treasure_key):
				tiles.erase(treasure_key)
				players[p.side].money += 100
				_grant_item(p.side,_random_item(),true)
				note("Buried treasure: $100 and a relic.","gold",{"pos":p.pos,"value":100})

func _random_item(group: String = "") -> String:
	var pool = []
	for definition in Catalog.data().items:
		if not definition.get("tile_only",false) and definition.group != "special" and (group.is_empty() or definition.group == group):
			pool.append(definition.id)
	return pool[rng.randi_range(0,pool.size()-1)]

func _grant_item(side: int, id: String, reveal: bool = false) -> void:
	players[side].items.append({"id":id,"ready":ply,"bought":-1})
	if reveal:
		note("%s discovered!" % Catalog.entry(id).get("name",id),"reveal",{"item":id,"side":side})

func _mystery(p: Dictionary) -> void:
	reveals += 1
	var event = "shop" if reveals == 1 else ("cards" if reveals == 2 else Catalog.data().tile_events[rng.randi_range(0,Catalog.data().tile_events.size()-1)])
	var negative=event in ["election","freeze","hypnosis","bees","fog","love"]
	note("Mystery: %s." % event.capitalize(),"mystery",{"pos":p.pos,"event":event,"positive":not negative})
	match event:
		"shop":
			market_unlocked = true
			restock()
			note("The Bazaar awakens. Spend a turn to visit.")
		"cards":
			cards_unlocked = true
			ensure_card_tiles()
			note("Three marked card tiles appear. Land on one to draw a card; it relocates after use.")
		"shield","magic":
			p.gear.append(event)
			note("%s bestowed." % event.capitalize(),"reveal",{"item":event,"pos":p.pos})
		"treasure","castling","lego","trojan":
			_grant_item(p.side,event,true)
		"spider":
			for q in pieces:
				if q.side == p.side and q.type == "queen":
					q.gear.append("spider")
		"leprechaun":
			players[p.side].traits.append("leprechaun")
			_grant_item(p.side,"potgold",true)
		"election":
			for direction in ORTHO:
				if empty(p.pos+direction):
					add_piece("pawn",1-p.side,p.pos+direction)
		"freeze":
			p.status.frozen = ply+7
			note("Break a leg. Frozen for three own turns.")
		"hypnosis":
			players[p.side].money += Catalog.value(p.type)
			p.side = 1-p.side
			note("Hypnotism changes allegiance. Former owner compensated.")
		"bees":
			tiles[key(p.pos)] = {"type":"bees"}
			players[p.side].forced = p.id
			note("Bee Nest: move this piece next turn.")
		"morph":
			var options = {"pawn":["knight","bishop"],"frog":["knight","bishop"],"knight":["pawn","bishop"],"bishop":["knight","rook"],"rook":["bishop","queen"],"queen":["rook"],"king":["queen"]}.get(p.type,["pawn"])
			p.type = options[rng.randi_range(0,options.size()-1)]
			p.upgrade = ""
			p.fusion = ""
			note("Transmogrified into %s." % Catalog.piece_name(p))
		"companion":
			players[p.side].traits.append("companion")
			note("A tiny electric companion joins your court.","reveal",{"item":"companion","side":p.side})
		"fog":
			fog = true
			note("Curse of the Fog: do not linger in the middle two ranks.")
		"harvest":
			for i in range(10):
				var pos = Vector2i(rng.randi_range(0,board_size-1),rng.randi_range(0,board_size-1))
				if empty(pos) and not tiles.has(key(pos)):
					tiles[key(pos)] = {"type":"banana"}
		"love":
			var pairs = []
			for a in pieces:
				for b in pieces:
					if a.side != b.side and Catalog.value(a.type) == Catalog.value(b.type):
						pairs.append([a,b])
			if not pairs.is_empty():
				var pair = pairs[rng.randi_range(0,pairs.size()-1)]
				pair[0].link = pair[1].id
				pair[1].link = pair[0].id
				note("House's Curse binds two equal souls. One death takes both.")

func draw_cards(side: int, count: int, _overflow: bool = false) -> void:
	if not cards_unlocked:
		return
	var ids = Catalog.card_ids()
	for i in range(count):
		players[side].hand.append({"id":ids[rng.randi_range(0,ids.size()-1)],"born":ply})

func restock() -> void:
	var pool = []
	for definition in Catalog.data().items:
		if definition.get("tile_only",false):
			continue
		if definition.id in ["arm","pack"] and not cards_unlocked:
			continue
		if definition.group == "gun" and "membership" not in players[turn].traits:
			continue
		if definition.group == "special" and "leprechaun" not in players[turn].traits:
			continue
		pool.append(definition.id)
	stock.clear()
	for i in range(mini(6,pool.size())):
		var index = rng.randi_range(0,pool.size()-1)
		stock.append(pool.pop_at(index))

func price(id: String) -> int:
	var d = Catalog.entry(id)
	return int(d.get("cost",0)* (0.75 if "wizard" in players[turn].traits and d.get("group","") == "mystic" else 1.0))

func _end_turn() -> void:
	if winner==-1 and players[turn].hand.size()>4:
		discard_due=turn
		note("Choose %d cards to discard. Keep four before your turn ends."%(players[turn].hand.size()-4),"discard_due")
		return
	discard_due=-1
	if fog:
		for p in pieces.duplicate():
			if p.side == turn:
				p.fog = p.fog+1 if p.pos.y in [board_size/2,board_size/2-1] else 0
				if p.fog >= 2:
					_hit(p,{},true)
	for p in pieces.duplicate():
		if p.side == turn and p.get("trap_until",-1) <= ply and p.has("trap_until") and p.get("trap_pos",Vector2i(-1,-1))==p.pos:
			_hit(p,{},true)
	ply += 1
	turn = 1-turn
	shop_open = false
	shots = 0
	shots_id = -1
	bonus_id = -1
	bonus_moves = 0
	for h in hazards.keys():
		if hazards[h].until <= ply:
			hazards.erase(h)
	if ply >= 38 and board_size == 8 and not campaign_battle:
		_expand()
	for p in pieces.duplicate():
		if p.get("doom",2147483647) <= ply:
			_hit(p,{},true)
		if p.has("tree_mature") and p.side == turn and p.tree_mature <= ply:
			if p.get("tree_kind","") == "sapling":
				players[turn].money += 15
			elif (ply-p.tree_mature)%10 == 0:
				_grant_item(turn,_random_item("mystic" if p.tree_kind == "celestial" else "passive"),true)
	for delivery in pending.duplicate():
		if delivery.due > ply:
			continue
		pending.erase(delivery)
		match delivery.kind:
			"skyhook":
				var restored = delivery.piece
				var rank = board_size-2 if restored.side == 0 else 1
				for x in range(board_size):
					if empty(Vector2i(x,rank)):
						restored.pos = Vector2i(x,rank)
						pieces.append(restored)
						break
			"shipping":
				_spawn_back("knight",delivery.side)
				_spawn_back("knight",delivery.side)
			"strike":
				for q in pieces.duplicate():
					if q.pos in delivery.area:
						_hit(q,{},true)
				note("Incoming! The marked area is struck.","strike",{"area":delivery.area})
			"egg":
				if empty(delivery.pos):
					add_piece("goose",delivery.side,delivery.pos)
					note("An egg hatches. Honk!","reveal",{"item":"egg","pos":delivery.pos})
	for held in players[turn].items:
		if held.id == "chaos":
			held.id = _random_item()
	_victory()
	ensure_card_tiles()
	note("%s to move." % ("Ivory" if turn == 0 else "Onyx"),"turn",{"side":turn})

func _expand_pos(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x+6,pos.y+2 if pos.y<4 else pos.y+10)

func _expand() -> void:
	for p in pieces:
		p.pos = _expand_pos(p.pos)
		p.home = _expand_pos(p.home)
	var new_tiles = {}
	for k in tiles:
		var tile = tiles[k]
		if tile.has("exit"):
			tile.exit = _expand_pos(tile.exit)
		new_tiles[key(_expand_pos(pos_key(k)))] = tile
	tiles = new_tiles
	var new_hazards = {}
	for k in hazards:
		new_hazards[key(_expand_pos(pos_key(k)))] = hazards[k]
	hazards = new_hazards
	for delayed in pending:
		if delayed.has("pos"):
			delayed.pos = _expand_pos(delayed.pos)
		if delayed.has("area"):
			delayed.area = delayed.area.map(_expand_pos)
	board_size = 20
	last_from = Vector2i(-1,-1)
	last_to = Vector2i(-1,-1)
	ensure_card_tiles()
	note("EXPANSION! The battlefield becomes 20 x 20.","expansion")

func _victory() -> void:
	var armies = [false,false]
	for p in pieces:
		if p.type not in ["fungus","tree"]:
			armies[p.side] = true
	for delayed in pending:
		if delayed.kind in ["skyhook","shipping"]:
			armies[delayed.get("side",delayed.get("piece",{}).get("side",0))] = true
	if not armies[0] or not armies[1]:
		winner = 0 if armies[0] else (1 if armies[1] else 2)
		shop_open = false
		note("Draw." if winner == 2 else ("Ivory" if winner == 0 else "Onyx")+" wins by army elimination!","victory",{"winner":winner})

func move_unit(id: int, target: Vector2i) -> Dictionary:
	var p = piece(id)
	if shop_open or p.is_empty() or p.side != turn or target not in legal_moves(p):
		return _error("That move is unavailable.")
	var from = p.pos
	var victim = at(target)
	var captured = not victim.is_empty()
	if captured and not _hit(victim,p):
		_end_turn()
		return _ok()
	if captured and not at(target).is_empty():
		# Reincarnation occupies the captured square: the attack is spent in place.
		_end_turn()
		return _ok()
	if piece(p.id).is_empty():
		_end_turn()
		return _ok()
	if captured and players[turn].wendigo:
		players[turn].wendigo = false
		pieces.erase(p)
		victim.side = turn
		victim.pos = target
		pieces.append(victim)
		note("Wendigo claims a new vessel.","warp",{"from":from,"pos":target})
		_end_turn()
		return _ok()
	if "boots" in p.gear:
		hazards[key(from)] = {"type":"fire","owner":turn,"until":ply+2}
	if "bulldoze" in p.gear or "conch" in p.gear:
		var route = from
		var travel: Array = []
		if "conch" in p.gear:
			while route.x!=target.x:
				route.x+=signi(target.x-route.x)
				if route!=target: travel.append(route)
			while route.y!=target.y:
				route.y+=signi(target.y-route.y)
				if route!=target: travel.append(route)
		else:
			var step=Vector2i(signi(target.x-from.x),signi(target.y-from.y))
			route+=step
			while route!=target and inside(route):
				travel.append(route)
				route+=step
		for crossed in travel:
			var q = at(crossed)
			if not q.is_empty() and q.side != turn:
				if not _hit(q,p):
					_end_turn()
					return _ok()
	p.pos = target
	p.erase("trap_until")
	p.erase("trap_pos")
	p.moved = true
	players[turn].forced = -1
	last_from = from
	last_to = target
	note("%s moves." % Catalog.piece_name(p),"move",{"id":p.id,"from":from,"pos":target,"capture":captured})
	_land(p)
	if "popup" in p.gear and not piece(p.id).is_empty():
		p.gear.erase("popup")
		var front = p.pos+Vector2i(0,-1 if turn==0 else 1)
		if empty(front) and front.y > 1 and front.y < board_size-2:
			add_piece("pawn",turn,front).status.no_attack = ply+2
	if "assassinknife" in p.gear and captured:
		var front = p.pos+Vector2i(0,-1 if turn==0 else 1)
		if empty(front):
			p.pos = front
			_land(p)
	_victory()
	if winner != -1:
		return _ok()
	if active(p,"speed"):
		bonus_id = p.id
		return _ok()
	if (active(p,"wrath") and captured) or active(p,"dolphin"):
		bonus_id = p.id
		bonus_moves = (2 if active(p,"dolphin") else 1) if bonus_moves == 0 else bonus_moves-1
		if bonus_moves > 0:
			return _ok()
	_end_turn()
	return _ok()

func _error(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _ok() -> Dictionary:
	return {"ok":true,"error":""}

func apply(command: Dictionary, actor: int = -1) -> Dictionary:
	if actor >= 0 and actor != turn:
		return _error("Wait for your turn.")
	if command.has("revision") and int(command.revision) != revision:
		return _error("The board changed. Try again.")
	if winner != -1:
		return _error("This battle has ended.")
	var before = snapshot(false)
	var acting_side = turn
	var title = action_title(command)
	events = []
	var result = _execute(command)
	if not result.ok:
		restore(before)
		events = []
		return result
	revision += 1
	_victory()
	ensure_card_tiles()
	if record_history:
		if history.is_empty():
			history.append({"label":"Starting position" if int(before.ply)==0 else "Recording starts here","actor":acting_side,"ply":int(before.ply),"state":before,"notes":[] if int(before.ply)==0 else ["This older save begins recording from this position."],"events":[]})
		history.append({"label":title,"actor":acting_side,"ply":int(before.ply),"state":snapshot(false),"notes":events.map(func(e: Dictionary) -> String: return str(e.text)),"events":encode(events)})
	result.events = events.duplicate(true)
	return result

func square_name(pos: Vector2i) -> String:
	return char(97+pos.x)+str(board_size-pos.y)

func action_title(command: Dictionary) -> String:
	var op=str(command.get("op",""))
	if op=="move":
		var p=piece(int(command.get("id",-1)))
		if not p.is_empty():
			var destination=command.get("pos",p.pos)
			return "%s %s %s %s"%[Catalog.piece_name(p),square_name(p.pos),"×" if not at(destination).is_empty() else "→",square_name(destination)]
	if op in ["card","item"]:
		var held=players[turn].hand if op=="card" else players[turn].items
		var index=int(command.get("index",-1))
		if index>=0 and index<held.size(): return "Play "+str(Catalog.entry(held[index].id).get("name",held[index].id))
	if op=="buy": return "Buy "+str(Catalog.entry(command.get("item","")).get("name","item"))
	if op=="upgrade": return "Forge: "+str(command.get("path","upgrade"))
	if op=="ability": return str(command.get("ability","ability")).capitalize()
	return {"pass":"End turn","shop":"Visit the Bazaar","leave":"Leave the Bazaar","refresh":"Refresh offers","fuse":"Alignation"}.get(op,op.capitalize())

func _execute(a: Dictionary) -> Dictionary:
	if discard_due>=0 and a.get("op","")!="discard":
		return _error("Choose your discards first; your turn is ending.")
	var target = a.get("pos",Vector2i(-1,-1))
	match str(a.get("op","")):
		"discard":
			var indices=a.get("indices",[])
			var needed=players[turn].hand.size()-4
			if discard_due!=turn or not indices is Array or indices.size()!=needed:
				return _error("Choose exactly %d cards to discard."%maxi(0,needed))
			var chosen: Array=[]
			for index in indices:
				if not (index is int or index is float) or int(index)<0 or int(index)>=players[turn].hand.size() or int(index) in chosen:
					return _error("Choose distinct cards from your hand.")
				chosen.append(int(index))
			chosen.sort()
			chosen.reverse()
			for index in chosen:
				players[turn].hand.pop_at(index)
				note("A card was discarded.","discard",{"side":turn})
			discard_due=-1
			_end_turn()
			return _ok()
		"move": return move_unit(int(a.get("id",-1)),target)
		"pass":
			if shop_open:
				return _error("Leave the Bazaar first.")
			_end_turn()
		"shop":
			if not market_unlocked or shop_open or shots > 0 or bonus_id >= 0:
				return _error("The Bazaar is unavailable. Reveal a mystery tile to discover it.")
			shop_open = true
			shop_free = round_number()%5 == 0 and free_visits[turn] != round_number()
			restock()
		"leave":
			if not shop_open:
				return _error("You are not visiting the Bazaar.")
			shop_open = false
			if shop_free:
				free_visits[turn] = round_number()
			else:
				_end_turn()
		"buy":
			var id = str(a.get("item",""))
			if not shop_open or id not in stock or players[turn].money < price(id):
				return _error("That purchase is unavailable or too expensive.")
			var cost = price(id)
			players[turn].money -= cost
			players[turn].spent += cost
			_grant_item(turn,id)
			players[turn].items[-1].bought = ply
			stock.erase(id)
			note("%s purchased." % Catalog.entry(id).name,"purchase",{"item":id})
			_end_turn()
		"reroll":
			if not shop_open or players[turn].money < 25:
				return _error("Refreshing the Bazaar costs $25.")
			players[turn].money -= 25
			restock()
		"upgrade": return upgrade(int(a.get("id",-1)),str(a.get("path","")))
		"fuse": return fuse(str(a.get("type","")),target)
		"card","item": return use(str(a.op) == "card",int(a.get("index",-1)),a.get("positions",[target]))
		"ability": return ability(int(a.get("id",-1)),str(a.get("ability","")),target,int(a.get("grave",-1)))
		"chessnut":
			if not shop_open or "wizard" not in players[turn].traits or players[turn].money < 50 or players[turn].nut_ply == ply:
				return _error("One Chessnut costs $50. You may buy one per turn after meeting the Wizard.")
			players[turn].money -= 50
			players[turn].chessnuts += 1
			players[turn].nut_ply = ply
		"spell":
			if not shop_open or "wizard" not in players[turn].traits or players[turn].chessnuts < 3:
				return _error("A mystical relic costs three Chessnuts.")
			players[turn].chessnuts -= 3
			_grant_item(turn,_random_item("mystic"),true)
			_end_turn()
		_: return _error("Unknown command.")
	return _ok()

func upgrade(id: int, path: String) -> Dictionary:
	var p = piece(id)
	if not shop_open or p.is_empty() or p.side != turn or p.upgrade != "" or p.fusion != "" or path not in Catalog.paths(p.type) or players[turn].money < 250:
		return _error("An eligible soldier and $250 are required.")
	p.upgrade = path
	players[turn].money -= 250
	players[turn].spent += 250
	note("%s joins your court." % path,"reveal",{"pos":p.pos,"item":"upgrade"})
	_end_turn()
	return _ok()

func fuse(type: String, pos: Vector2i) -> Dictionary:
	if not shop_open or Catalog.paths(type).size() != 2 or not empty(pos) or pos.y != (board_size-1 if turn == 0 else 0) or players[turn].money < 500:
		return _error("Alignation requires both upgrade paths, $500 and an empty back-rank square.")
	var pair = []
	for path in Catalog.paths(type):
		for p in pieces:
			if p.side == turn and p.type == type and p.upgrade == path and p.fusion == "":
				pair.append(p)
				break
	if pair.size() != 2:
		return _error("You must own both distinct upgrade paths.")
	for p in pair:
		pieces.erase(p)
	var result = add_piece(type,turn,pos)
	result.fusion = Catalog.data().fusions[type]
	players[turn].money -= 500
	players[turn].spent += 500
	note("ALIGNATION: %s rises!" % result.fusion,"reveal",{"pos":pos,"item":"fusion"})
	_end_turn()
	return _ok()

func ability_names(p: Dictionary) -> Array:
	var result = []
	if p.is_empty():
		return result
	if p.fusion == "Archmage":
		result = ["cast","summon","warp"]
	if p.fusion == "Iron Warden" or effective_upgrade(p) == "M1 Abrams" or p.type == "goat" or p.type == "commando":
		result.append("shoot")
	if effective_upgrade(p) == "Divine Cleric":
		result.append("revive")
	if p.type == "automaton":
		result.append("detonate")
	if p.type == "dropship":
		result.append("deploy")
	for gun in ["barrett","lewis","grenade","glock","m4"]:
		if gun in p.gear and "shoot" not in result:
			result.append("shoot")
	return result

func ability(id: int, action: String, pos: Vector2i, grave: int = -1) -> Dictionary:
	var p = piece(id)
	if shop_open or p.is_empty() or p.side != turn or active(p,"frozen") or active(p,"no_attack") or "kragle" in p.gear or action not in ability_names(p):
		return _error("Select an active piece with that ability.")
	var q = at(pos)
	var dist = distance(p.pos,pos)
	if action in ["shoot","cast"]:
		var radius = 3 if p.fusion == "Archmage" or p.type == "goat" else (2 if p.fusion == "Iron Warden" or p.type == "commando" or "m4" in p.gear or "barrett" in p.gear else 1)
		if q.is_empty() or q.side == turn or dist > radius or ("barrett" in p.gear and dist != 2) or (action == "cast" and p.pos.x != pos.x and p.pos.y != pos.y) or (shots > 0 and shots_id != id):
			return _error("Choose an enemy in this weapon's range.")
		_hit(q,p,true)
		note("%s fires." % Catalog.piece_name(p),"shot",{"from":p.pos,"pos":pos})
		_victory()
		if winner == -1:
			if (p.fusion == "Iron Warden" or "lewis" in p.gear) and shots == 0:
				shots = 1
				shots_id = id
			else:
				_end_turn()
		return _ok()
	if shots > 0:
		return _error("Finish firing or end the turn first.")
	match action:
		"summon","deploy":
			if not empty(pos) or dist > 1:
				return _error("Choose an empty surrounding square.")
			add_piece("pawn" if action == "summon" else "octopus",turn,pos)
		"warp":
			if not empty(pos) or dist <= 5:
				return _error("Choose an empty square more than five tiles away.")
			p.pos = pos
			_land(p)
		"revive":
			if grave < 0 or grave >= graves.size() or graves[grave].side != turn or not empty(pos) or dist > 2 or players[turn].money < Catalog.value(graves[grave].type)/2:
				return _error("Revive a fallen ally within two tiles for half its base cost.")
			var dead = graves.pop_at(grave)
			players[turn].money -= int(Catalog.value(dead.type)/2)
			add_piece(dead.type,turn,pos).moved = true
		"detonate":
			_hit(p,{},true,true)
	note("%s: %s." % [Catalog.piece_name(p),action],"ability",{"pos":pos})
	_end_turn()
	return _ok()

func _relocate(p: Dictionary, pos: Vector2i) -> Dictionary:
	if not empty(pos) or active(p,"frozen") or "kragle" in p.gear:
		return _error("The destination must be empty and the piece able to move.")
	var from = p.pos
	p.pos = pos
	p.moved = true
	note("A change of scenery.","warp",{"id":p.id,"from":from,"pos":pos})
	_land(p)
	return _ok()

func use(card: bool, index: int, positions: Array) -> Dictionary:
	var player = players[turn]
	var held = player.hand if card else player.items
	if shop_open or shots > 0 or index < 0 or index >= held.size() or (not card and player.disabled > ply):
		return _error("That card or item is unavailable.")
	var owned = held[index]
	var d = Catalog.entry(owned.id)
	if d.is_empty() or (not card and owned.ready > ply):
		return _error("That item is cooling down.")
	var prior = []
	if d.target != ["none"]:
		if positions.size() != d.target.size():
			return _error("Choose every highlighted target.")
		for stage in range(d.target.size()):
			if positions[stage] not in targets(d,stage,prior):
				return _error("Choose a valid %s target." % d.target[stage])
			prior.append(positions[stage])
	var result = _effect(d,owned,positions)
	if not result.ok:
		return result
	if d.has("reusable"):
		owned.ready = ply+int(d.reusable)*2
	else:
		held.erase(owned)
	note("%s played." % d.name,"card" if card else "item",{"item":d.id,"side":turn})
	_victory()
	if result.get("end",false) and winner == -1:
		_end_turn()
	return _ok()

func _effect(d: Dictionary, held: Dictionary, positions: Array) -> Dictionary:
	var pos = positions[0] if not positions.is_empty() else Vector2i(-1,-1)
	var p = at(pos)
	var q = at(positions[1]) if positions.size() > 1 else {}
	var player = players[turn]
	var direction = -1 if turn == 0 else 1
	var ends = false
	match d.id:
		"chacha","eject","ticket","warp","retreat":
			var dest = p.pos+Vector2i(-1,0) if d.id == "chacha" else (p.pos+Vector2i(0,-direction*2) if d.id == "eject" else (p.pos+Vector2i(0,direction*5) if d.id == "ticket" else p.home))
			if d.id == "retreat":
				var edges = [Vector2i(0,p.pos.y),Vector2i(board_size-1,p.pos.y),Vector2i(p.pos.x,0),Vector2i(p.pos.x,board_size-1)]
				edges.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return distance(a,p.pos)<distance(b,p.pos))
				for edge in edges:
					if empty(edge):
						dest = edge
						break
			var relocated = _relocate(p,dest)
			if not relocated.ok:
				return relocated
			ends = d.id in ["ticket","retreat"]
		"grass":
			if not p.is_empty():
				p.trap_until = ply+(2 if p.side==turn else 1)
				p.trap_pos = p.pos
			else:
				hazards[key(pos)] = {"type":"trap","owner":turn,"until":ply+3}
		"greed": draw_cards(turn,2)
		"pack": draw_cards(turn,5,true)
		"frog":
			if pos.y != (board_size-2 if turn==0 else 1):
				return _error("Choose your pawn starting rank.")
			add_piece("frog",turn,pos)
		"rat": p.status.rat = ply+1
		"union": player.union = ply
		"vest": p.status.vest = ply+2
		"collector": player.money += 10*int((ply-held.born)/2)
		"traffic": ends = true
		"gale":
			var column = pieces.filter(func(unit: Dictionary) -> bool: return unit.pos.x == pos.x)
			column.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.y > b.pos.y)
			for unit in column:
				var dest = unit.pos+Vector2i(0,1 if unit.side==0 else -1)
				if empty(dest):
					unit.pos = dest
		"radio","egg":
			if d.id == "egg" and p.is_empty():
				pending.append({"kind":"egg","due":ply+2,"side":turn,"pos":pos})
			elif not p.is_empty() and p.side != turn:
				p.status.frozen = ply+2
			else:
				return _error("Choose an enemy to stun or an empty square for an egg.")
		"blackhole":
			for unit in pieces:
				if distance(pos,unit.pos)<=1:
					unit.status.frozen = ply+2
		"lasso":
			if distance(p.pos,q.pos)>4:
				return _error("Bind pieces within four squares.")
			p.lasso = q.id
			q.lasso = p.id
		"skyhook":
			pieces.erase(p)
			pending.append({"kind":"skyhook","due":ply+4,"side":turn,"piece":p})
		"scissors":
			if not players[1-turn].hand.is_empty():
				players[1-turn].hand.pop_front()
		"dnd","sabotage": players[1-turn].disabled = ply+2
		"blanket": p.status.blanket = ply+2
		"scavenge":
			var allies = pieces.filter(func(unit: Dictionary) -> bool: return unit.side == turn)
			allies.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.y < b.pos.y if turn==0 else a.pos.y>b.pos.y)
			allies[0].parcel_deadline = ply+10
			note("Parcel: %s on %s. Move it onto either of your two home ranks within five rounds for $100."%[Catalog.piece_name(allies[0]),square_name(allies[0].pos)],"parcel",{"id":allies[0].id,"pos":allies[0].pos})
		"shield","magic","spider","boots","hilux","kragle","conch","rein","spore","service","bulldoze","popup","throwingknife","assassinknife","combatboots","barrett","lewis","grenade","glock","m4":
			if d.id not in p.gear:
				p.gear.append(d.id)
		"treasure":
			for i in range(board_size*board_size):
				var location = Vector2i(rng.randi_range(0,board_size-1),rng.randi_range(0,board_size-1))
				if not tiles.has(key(location)):
					tiles[key(location)] = {"type":"treasure","owner":turn,"visible":false}
					break
		"castling":
			var from = p.pos
			p.pos = q.pos
			q.pos = from
			ends = true
		"lego":
			if p.moved or q.moved:
				return _error("Both pieces must not have moved yet.")
			p.stack.append(q.type)
			p.pos = q.pos
			pieces.erase(q)
		"trojan":
			if p.type not in ["pawn","rook","bishop"]:
				return _error("Choose an enemy pawn, rook or bishop.")
			p.type = "knight"
			p.upgrade = ""
		"ufo":
			var victim = pieces[rng.randi_range(0,pieces.size()-1)]
			var origin = victim.pos
			var side = victim.side
			pieces.erase(victim)
			_spawn_near("pawn",side,origin,4)
		"gas":
			for unit in pieces:
				if unit.side != turn and distance(pos,unit.pos)<=1:
					return _error("Gas cannot deploy over enemy pieces.")
			for dx in range(-1,2):
				for dy in range(-1,2):
					if inside(pos+Vector2i(dx,dy)):
						hazards[key(pos+Vector2i(dx,dy))] = {"type":"gas","owner":turn,"until":ply+6}
		"bleach":
			tiles.erase(key(pos))
			hazards.erase(key(pos))
		"contractor":
			p.status.contractor = ply+1
			p.status.contractor_path = Catalog.paths(p.type)[rng.randi_range(0,1)]
		"speed","wrath","dolphin": p.status[d.id] = ply+1
		"doom":
			if p.type in ["king","queen"]:
				return _error("Doomed Fate cannot target royalty.")
			p.doom = ply+10
		"chaos": _grant_item(turn,_random_item(),true)
		"glass": p.status.immune = ply+2
		"royalguard": p.status.immune = ply+6
		"lager":
			var victims = pieces.filter(func(unit: Dictionary) -> bool: return unit.pos == pos or unit.pos in ORTHO.map(func(v: Vector2i) -> Vector2i: return pos+v))
			if victims.is_empty():
				return _error("The plus-shaped preview must contain a piece.")
			_hit(victims[rng.randi_range(0,victims.size()-1)],{},true)
		"pacify": p.status.pacified = ply+2
		"rabid": p.status.rabid = ply+2
		"wendigo": player.wendigo = true
		"agent": player.agent = ply
		"tidal":
			for pawn in pieces:
				if pawn.side == turn and pawn.type == "pawn":
					for unit in pieces:
						if unit.side == turn and unit.id != pawn.id and unit.home.x == pawn.home.x and unit.home.y == (board_size-1 if turn==0 else 0):
							var old = pawn.pos
							pawn.pos = unit.pos
							unit.pos = old
							break
		"missile":
			var queens = pieces.filter(func(unit: Dictionary) -> bool: return unit.side == turn and unit.type == "queen" and distance(unit.pos,pos)<=5)
			if queens.is_empty() or p.type in ["pawn","frog"]:
				return _error("Choose a non-pawn enemy within five squares of your queen.")
			_hit(p,queens[0],true)
		"flare","jet","helicopter":
			var cost = 100 if d.id == "jet" else (70 if d.id == "helicopter" else 0)
			if player.money < cost:
				return _error("This strike needs $%d in operating costs." % cost)
			player.money -= cost
			var area = []
			for y in range(board_size):
				for x in range(board_size):
					var location = Vector2i(x,y)
					if (y == pos.y if d.id == "jet" else distance(location,pos) <= (2 if d.id == "flare" else 1)):
						area.append(location)
			pending.append({"kind":"strike","due":ply+2,"side":turn,"area":area})
		"portals":
			tiles[key(pos)] = {"type":"portal","exit":positions[1]}
			tiles[key(positions[1])] = {"type":"portal","exit":pos}
		"sanctuary": tiles[key(pos)] = {"type":"sanctuary"}
		"counterspawn":
			if held.bought == ply:
				return _error("Counterspawn cannot be used on its purchase turn.")
			for unit in pieces.duplicate():
				if unit.side != turn and unit.born >= ply-2:
					_hit(unit,{},true)
		"counterspell":
			pending = pending.filter(func(e: Dictionary) -> bool: return e.get("side",turn)==turn)
			for unit in pieces:
				if unit.side == turn:
					unit.status.clear()
		"automaton","goat","mothership","decoy":
			if pos.y != (board_size-1 if turn==0 else 0):
				return _error("Deploy on your back rank.")
			add_piece({"automaton":"automaton","goat":"goat","mothership":"dropship","decoy":"decoy"}[d.id],turn,pos)
		"lotto":
			var roll = rng.randi_range(0,99)
			var payout = 60 if roll<50 else (25 if roll<70 else (0 if roll<90 else (150 if roll<95 else 300)))
			player.money += payout
			note("Lotto pays $%d." % payout,"gold",{"value":payout,"pos":Vector2i(-1,-1)})
		"cia":
			if p.type in ["king","queen"]:
				return _error("The CIA Agent only targets soldiers.")
			player.money += Catalog.value(p.type)
			_hit(p,{},true,true)
		"sapling","celestial","robotic":
			var tree = add_piece("tree",turn,pos)
			tree.tree_mature = ply+10
			tree.tree_kind = d.id
		"arm","insurance","wizard","membership":
			if d.id not in player.traits:
				player.traits.append(d.id)
			if d.id == "arm":
				player.limit = 4
		"grave": player.money += graves.size()*30
		"heist":
			if rng.randf()<0.5:
				var stolen = mini(200,players[1-turn].money)
				players[1-turn].money -= stolen
				player.money += stolen
				note("The Great Heist: +$%d for %s; -$%d for %s."%[stolen,"Ivory" if turn==0 else "Onyx",stolen,"Onyx" if turn==0 else "Ivory"],"heist",{"side":turn,"value":stolen,"money_delta":{"0":stolen if turn==0 else -stolen,"1":stolen if turn==1 else -stolen}})
				if stolen == 0:
					for i in range(mini(2,players[1-turn].items.size())):
						player.items.append(players[1-turn].items.pop_front())
					note("The Great Heist stole equipment instead of cash.")
			else:
				note("The Great Heist failed: +$0.")
		"wasps":
			for unit in pieces.duplicate():
				if unit.pos.x == pos.x and unit.type == "pawn":
					_hit(unit,{},true)
		"shipping": pending.append({"kind":"shipping","due":ply+16,"side":turn})
		"pawn","halo":
			if d.id == "pawn" and (pos.y < board_size/2 if turn==0 else pos.y>=board_size/2):
				return _error("Launch the pawn into your own half.")
			if d.id == "halo" and (pos.y<3 if turn==0 else pos.y>=board_size-3):
				return _error("HALO cannot deploy in the enemy back three ranks.")
			var unit = add_piece("pawn" if d.id=="pawn" else "commando",turn,pos)
			unit.status.no_attack = ply+2
			if d.id == "halo":
				unit.status.immune = ply+2
		"amendment":
			var guns = ["barrett","lewis","grenade","glock","m4"]
			for unit in pieces:
				if unit.side == turn and unit.type == "pawn":
					unit.gear.append(guns[rng.randi_range(0,guns.size()-1)])
		"potgold": player.money += 300
		_: return _error("This effect has no implementation: "+d.id)
	return {"ok":true,"end":ends}

static func encode(value: Variant) -> Variant:
	if value is Vector2i:
		return {"@pos":[value.x,value.y]}
	if value is Array:
		return value.map(encode)
	if value is Dictionary:
		var result = {}
		for k in value:
			result[str(k)] = encode(value[k])
		return result
	return value

static func decode(value: Variant) -> Variant:
	if value is Array:
		return value.map(decode)
	if value is Dictionary:
		if value.has("@pos"):
			return Vector2i(int(value["@pos"][0]),int(value["@pos"][1]))
		var result = {}
		for k in value:
			result[k] = decode(value[k])
		return result
	return value

func snapshot(include_history: bool = true) -> Dictionary:
	var state = {}
	state.tile_rules_version=TILE_RULES_VERSION
	state.discard_due=discard_due
	for name in ["board_size","turn","ply","revision","next_id","winner","pieces","players","tiles","hazards","graves","pending","stock","log_lines","market_unlocked","cards_unlocked","reveals","fog","shop_open","shop_free","free_visits","shots","shots_id","bonus_id","bonus_moves","last_from","last_to","campaign_battle"]:
		state[name] = get(name)
	state.match_seed = str(match_seed)
	state.rng_state = str(rng.state)
	if include_history: state.history=history
	return encode(state)

func restore(state: Dictionary, migrate_tiles: bool = true) -> void:
	var decoded = decode(state)
	discard_due=int(decoded.get("discard_due",-1))
	for name in decoded:
		if name not in ["rng_state","match_seed","tile_rules_version"]:
			set(name,decoded[name])
	match_seed = int(decoded.match_seed)
	rng.seed = match_seed
	rng.state = int(decoded.rng_state)
	for player in players: player.limit=4
	if migrate_tiles and int(state.get("tile_rules_version",0))<TILE_RULES_VERSION:
		# Migrate old saves without changing their already recorded replay frames.
		ensure_card_tiles()

func public_snapshot(role: int) -> Dictionary:
	var state = snapshot()
	_redact_state(state,role)
	for entry in state.get("history",[]): _redact_state(entry.state,role)
	return state

func _redact_state(state: Dictionary, role: int) -> void:
	state.rng_state = "0"
	for side in range(2):
		if side != role:
			state.players[side].hand = state.players[side].hand.map(func(_card: Dictionary) -> Dictionary: return {"id":"hidden","born":0})
	for p in state.pieces:
		if p.side != role and int(p.status.get("blanket",-1)) > int(state.ply):
			p.type = "hidden"
			p.upgrade = ""
			p.fusion = ""
			p.gear = []

func valid() -> bool:
	var seen = {}
	var ids = {}
	for p in pieces:
		if not inside(p.pos) or seen.has(key(p.pos)) or ids.has(p.id):
			return false
		seen[key(p.pos)] = true
		ids[p.id] = true
	return players.size() == 2 and players[0].money >= 0 and players[1].money >= 0

static func is_snapshot(state: Dictionary) -> bool:
	for required in ["board_size","turn","ply","pieces","players","tiles","hazards","pending","graves","match_seed","rng_state"]:
		if not state.has(required): return false
	if not state.players is Array or state.players.size()!=2 or not state.pieces is Array: return false
	if int(state.board_size) not in [8,20] or int(state.turn) not in [0,1]: return false
	for p in state.pieces:
		if not p is Dictionary: return false
		for required in ["id","type","side","pos","home","status","gear","stack","upgrade","fusion","moved"]:
			if not p.has(required): return false
		for location in [p.pos,p.home]:
			if not location is Dictionary or not location.has("@pos") or not location["@pos"] is Array or location["@pos"].size()!=2: return false
	for player in state.players:
		if not player is Dictionary or not player.has("money") or not player.has("hand") or not player.has("items"): return false
	return true
