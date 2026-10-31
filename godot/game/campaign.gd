class_name ChessCampaign
extends RefCounted
## Six connected battles. Survivors, equipment, currency and run relics persist.

var run_seed = 1
var floor_number = 1
var phase = "battle"
var route = "skirmish"
var relics: Array = []
var rewards: Array = []
var rng = RandomNumberGenerator.new()

func start(seed_value: int) -> ChessMatch:
	run_seed = seed_value
	rng.seed = seed_value
	floor_number = 1
	phase = "battle"
	relics = []
	var game = ChessMatch.new(seed_value,false)
	game.players[0].money = 150
	for type in ["king","knight","rook","pawn","pawn"]:
		game.add_piece(type,0,Vector2i.ZERO)
	return encounter(game,"skirmish")

func encounter(old: ChessMatch, path: String) -> ChessMatch:
	route = path
	var game = ChessMatch.new(rng.randi(),false)
	game.campaign_battle = true
	game.market_unlocked = old.market_unlocked
	game.cards_unlocked = old.cards_unlocked
	game.players[0] = old.players[0].duplicate(true)
	game.players[0].hand = []
	game.players[0].forced = -1
	game.players[0].disabled = -1
	game.players[0].agent = -1
	game.players[0].bounty = 25 if "hunter" in relics else 0
	for held in game.players[0].items:
		held.ready=maxi(0,int(held.ready)-old.ply)
		held.bought=-1
	game.graves = old.graves.duplicate(true)
	var slot = 0
	for p in old.pieces:
		if p.side != 0 or p.type in ["tree","fungus"] or slot >= 32:
			continue
		var pos = Vector2i(slot%8,7-int(slot/8))
		var unit = game.add_piece(p.type,0,pos)
		unit.gear = p.gear.duplicate()
		unit.stack = p.stack.duplicate()
		unit.upgrade = p.upgrade
		unit.fusion = p.fusion
		if "aegis" in relics and slot < 2 and "shield" not in unit.gear:
			unit.gear.append("shield")
		slot += 1
	if "purse" in relics:
		game.players[0].money += 60
	if path == "supply":
		game.players[0].money += 40
		game._grant_item(0,"glass")
	var elite = path == "elite" or floor_number%3 == 0
	var count = 3+floor_number+(2 if elite else 0)
	var files = [0,1,2,3,4,5,6,7]
	for i in range(7,0,-1):
		var j = rng.randi_range(0,i)
		var swap = files[i]
		files[i] = files[j]
		files[j] = swap
	for i in range(count):
		var types = ["pawn","knight","bishop","rook"]
		var type = "king" if i==0 else ("queen" if i==1 and floor_number%3==0 else types[rng.randi_range(0,mini(3,1+floor_number/2))])
		var unit = game.add_piece(type,1,Vector2i(files[i%8],int(i/8)))
		if elite and i==0:
			unit.gear = ["shield","magic"]
		if floor_number>=4 and i==2:
			unit.type = "rook"
			unit.upgrade = "Golem"
	game.seed_mysteries(7)
	game.reveals = old.reveals
	game.ensure_card_tiles()
	game.restock()
	if "charm" in relics: game.draw_cards(0,3)
	phase = "battle"
	game.note("THE SHATTERED CROWN: battle %d/6. %s." % [floor_number,"BOSS" if floor_number%3==0 else path.to_upper()])
	return game

func observe(game: ChessMatch) -> void:
	if phase != "battle" or game.winner == -1:
		return
	if game.winner != 0:
		phase = "defeat"
		return
	game.players[0].money += 180 if route == "elite" or floor_number%3==0 else 100
	if floor_number == 6:
		phase = "victory"
		return
	phase = "reward"
	var pool = [
		{"id":"gold","name":"War Chest","description":"Gain $180 for the road ahead.","icon":"potgold"},
		{"id":"knight","name":"Fresh Cavalry","description":"Recruit a knight into your surviving army.","icon":"knight"},
		{"id":"bishop","name":"A New Believer","description":"Recruit a bishop into your surviving army.","icon":"bishop"},
		{"id":"rook","name":"Heavy Reinforcements","description":"Recruit a rook into your surviving army.","icon":"rook"},
		{"id":"supplies","name":"Care Package","description":"Gain a Shield and a Magic Shield.","icon":"shield"}
	]
	var options = {
		"aegis":["Aegis Banner","Two survivors start each battle shielded.","shield"],
		"purse":["Bottomless Purse","Gain $60 at each battle start.","potgold"],
		"charm":["Scholar's Charm","Start each battle with three cards.","greed"],
		"hunter":["Hunter's Seal","Every friendly capture pays $25 extra.","missile"]
	}
	for id in options:
		if id not in relics:
			pool.append({"id":id,"name":options[id][0],"description":options[id][1],"icon":options[id][2]})
	for p in game.pieces:
		if p.side == 0 and not ChessCatalog.paths(p.type).is_empty() and p.upgrade == "" and p.fusion == "":
			var path = ChessCatalog.paths(p.type)[rng.randi_range(0,1)]
			pool.append({"id":"forge:%d:%s" % [p.id,path],"name":"Royal Forge","description":"Upgrade a survivor to %s for free." % path,"icon":"upgrade"})
			break
	if not game.graves.filter(func(g: Dictionary) -> bool: return g.side == 0).is_empty():
		pool.append({"id":"revive","name":"Second Chance","description":"Restore your most recently fallen ally.","icon":"rein"})
	rewards = []
	for i in range(3):
		rewards.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))

func choose_reward(game: ChessMatch, id: String) -> bool:
	if phase != "reward" or rewards.filter(func(r: Dictionary) -> bool: return r.id == id).is_empty():
		return false
	match id:
		"gold": game.players[0].money += 180
		"knight","rook","bishop": game._spawn_back(id,0)
		"supplies":
			game._grant_item(0,"shield")
			game._grant_item(0,"magic")
		"aegis","purse","charm","hunter": relics.append(id)
		"revive":
			for index in range(game.graves.size()-1,-1,-1):
				if game.graves[index].side == 0:
					game._spawn_back(game.graves.pop_at(index).type,0)
					break
		_:
			if id.begins_with("forge:"):
				var parts = id.split(":")
				var p = game.piece(int(parts[1]))
				if not p.is_empty():
					p.upgrade = parts[2]
	phase = "route"
	game.revision += 1
	return true

func next_battle(game: ChessMatch, path: String) -> ChessMatch:
	if phase != "route" or path not in ["supply","elite","boss"]:
		return game
	floor_number += 1
	return encounter(game,"boss" if floor_number%3==0 else path)

func snapshot() -> Dictionary:
	return {"run_seed":str(run_seed),"floor_number":floor_number,"phase":phase,"route":route,"relics":relics.duplicate(),"rewards":rewards.duplicate(true),"rng_state":str(rng.state)}

func restore(state: Dictionary) -> void:
	run_seed = int(state.run_seed)
	floor_number = int(state.floor_number)
	phase = state.phase
	route = state.route
	relics = state.relics.duplicate()
	rewards = state.rewards.duplicate(true)
	rng.seed = run_seed
	rng.state = int(state.rng_state)
