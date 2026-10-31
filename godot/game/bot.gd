class_name ChessBot
extends RefCounted
## Bounded search on detached rules snapshots. Never touches the scene tree.

static func evaluate(game: ChessMatch, side: int) -> float:
	if game.winner != -1:
		return 100000 if game.winner==side else (-100000 if game.winner!=2 else 0)
	var score = (game.players[side].money-game.players[1-side].money)*0.16
	score+=(game.players[side].hand.size()-game.players[1-side].hand.size())*20
	for p in game.pieces:
		var value = ChessCatalog.value(p.type)+p.gear.size()*22+(90 if p.upgrade!="" else 0)+(350 if p.fusion!="" else 0)
		var center = float(game.board_size-absf(p.pos.x-(game.board_size-1)*0.5)-absf(p.pos.y-(game.board_size-1)*0.5))*2
		score += (value+center) * (1 if p.side==side else -1)
	return score

static func choose(snapshot: Dictionary, level: String = "normal") -> Dictionary:
	var game = ChessMatch.new(1,false)
	game.restore(snapshot)
	game.record_history=false
	var random = RandomNumberGenerator.new()
	random.seed = game.match_seed+game.ply*97+game.revision*11
	var side = game.turn
	if game.discard_due==side:
		var ranked: Array=[]
		for i in range(game.players[side].hand.size()):
			var id=game.players[side].hand[i].id
			var value={"traffic":0,"collector":10,"scavenge":12,"greed":90,"blackhole":85,"radio":80,"rat":70}.get(id,40)
			ranked.append({"index":i,"value":value})
		ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.value<b.value)
		return {"op":"discard","indices":ranked.slice(0,ranked.size()-4).map(func(entry: Dictionary) -> int: return entry.index)}
	if game.shop_open:
		for id in game.stock:
			if game.price(id)<=game.players[side].money:
				return {"op":"buy","item":id}
		return {"op":"leave"}
	var candidates: Array = []
	for p in game.pieces:
		if p.side != side:
			continue
		for pos in game.legal_moves(p):
			var victim = game.at(pos)
			var tactical = ChessCatalog.value(victim.type) if not victim.is_empty() else 0
			candidates.append({"action":{"op":"move","id":p.id,"pos":pos},"tactical":tactical+random.randf()*8})
		for ability in game.ability_names(p):
			if ability in ["shoot","cast"]:
				for q in game.pieces:
					if q.side != side:
						candidates.append({"action":{"op":"ability","id":p.id,"ability":ability,"pos":q.pos},"tactical":ChessCatalog.value(q.type)+20})
	if level != "easy":
		for is_card in [true,false]:
			var held = game.players[side].hand if is_card else game.players[side].items
			for index in range(held.size()):
				var d = ChessCatalog.entry(held[index].id)
				if d.is_empty():
					continue
				if d.target == ["none"]:
					candidates.append({"action":{"op":"card" if is_card else "item","index":index,"positions":[]},"tactical":40})
				elif d.target.size() == 1:
					var targets = game.targets(d,0)
					for i in range(mini(targets.size(),12)):
						var pos = targets[(i*7+game.ply)%targets.size()]
						candidates.append({"action":{"op":"card" if is_card else "item","index":index,"positions":[pos]},"tactical":35})
	if candidates.is_empty():
		return {"op":"pass"}
	if level == "easy":
		return candidates[random.randi_range(0,candidates.size()-1)].action
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.tactical>b.tactical)
	var limit = 12 if level=="normal" else (20 if level=="hard" else 28)
	var deadline = Time.get_ticks_msec() + (140 if level=="normal" else (450 if level=="hard" else 950))
	var best: Dictionary = {"op":"pass"}
	var best_score = -INF
	for entry in candidates.slice(0,limit):
		if Time.get_ticks_msec()>deadline:
			break
		var child = ChessMatch.new(1,false)
		child.restore(snapshot)
		child.record_history=false
		if not child.apply(entry.action).ok:
			continue
		var score = evaluate(child,side)+random.randf()*(18 if level=="normal" else 3)
		if child.turn==side:
			score += 14
		if level in ["hard","expert"] and child.turn!=side and child.winner==-1:
			var worst = score
			var replies = []
			for p in child.pieces:
				if p.side == child.turn:
					for pos in child.legal_moves(p):
						var victim = child.at(pos)
						replies.append({"id":p.id,"pos":pos,"value":0 if victim.is_empty() else ChessCatalog.value(victim.type)})
			replies.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.value>b.value)
			for reply in replies.slice(0,8 if level=="hard" else 14):
				if Time.get_ticks_msec()>deadline:
					break
				var response = ChessMatch.new(1,false)
				response.restore(child.snapshot(false))
				response.record_history=false
				response.apply({"op":"move","id":reply.id,"pos":reply.pos})
				worst = minf(worst,evaluate(response,side))
			score = worst
		if score>best_score:
			best_score = score
			best = entry.action
	if best.get("op","") == "move" and game.market_unlocked and game.players[side].money>=400 and game.ply%12==7:
		return {"op":"shop"}
	return best
