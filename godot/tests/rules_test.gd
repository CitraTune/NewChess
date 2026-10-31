extends SceneTree

var failures: Array = []
var checks = 0

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: "+label)

func fixture() -> ChessMatch:
	var g = ChessMatch.new(42,false)
	g.add_piece("king",0,Vector2i(7,7))
	g.add_piece("king",1,Vector2i(7,0))
	var pawn = g.add_piece("pawn",0,Vector2i(0,6))
	pawn.home = Vector2i(0,7)
	g.add_piece("pawn",1,Vector2i(1,5))
	g.add_piece("rook",0,Vector2i(3,5))
	g.add_piece("bishop",0,Vector2i(2,6))
	g.add_piece("knight",0,Vector2i(4,5))
	g.add_piece("queen",0,Vector2i(3,7))
	g.add_piece("pawn",0,Vector2i(5,6))
	g.add_piece("rook",1,Vector2i(3,2))
	g.add_piece("knight",1,Vector2i(5,2))
	g.add_piece("bishop",1,Vector2i(6,1))
	g.players[0].money = 2000
	g.graves = [{"type":"knight","side":0}]
	g.market_unlocked = true
	g.cards_unlocked = true
	g.restock()
	return g

func _test_hand_rules() -> void:
	var g=fixture()
	g.players[0].hand=[{"id":"greed","born":0},{"id":"frog","born":0},{"id":"lasso","born":0},{"id":"rat","born":0}]
	expect(g.apply({"op":"card","index":0,"positions":[]}).ok and g.players[0].hand.size()==5 and g.discard_due==-1,"Greed can overflow four during the turn without losing cards")
	var pawn=g.at(Vector2i(0,6))
	expect(g.apply({"op":"move","id":pawn.id,"pos":Vector2i(0,5)}).ok and g.turn==0 and g.ply==0 and g.discard_due==0,"move resolves before a mandatory end-turn discard")
	var pending=g.snapshot()
	expect(not g.apply({"op":"pass"}).ok and g.snapshot()==pending,"pending discards block additional actions transactionally")
	expect(not g.apply({"op":"discard","indices":[0,0]}).ok and g.snapshot()==pending,"wrong discard count does not change state")
	expect(not g.apply({"op":"discard","indices":[99]}).ok and g.snapshot()==pending,"out-of-range discards do not change state")
	var saved=ChessMatch.new(1,false)
	saved.restore(JSON.parse_string(JSON.stringify(pending)))
	expect(saved.discard_due==0 and saved.players[0].hand.size()==5,"unfinished discard selection survives save and resume")
	var kept=g.players[0].hand.slice(1).duplicate(true)
	expect(g.apply({"op":"discard","indices":[0]}).ok and g.players[0].hand==kept and g.turn==1 and g.ply==1,"chosen card is discarded and the turn advances exactly once")
	g=fixture()
	g.players[0].hand=[{"id":"traffic","born":0},{"id":"rat","born":0},{"id":"greed","born":0},{"id":"frog","born":0},{"id":"lasso","born":0},{"id":"radio","born":0}]
	g.apply({"op":"pass"})
	pending=g.snapshot()
	expect(not g.apply({"op":"discard","indices":[0,0]}).ok and g.snapshot()==pending,"duplicate discard indices are rejected")
	var action=ChessBot.choose(g.snapshot(false))
	expect(action.op=="discard" and action.indices.size()==2 and g.apply(action).ok and g.players[0].hand.size()==4,"AI resolves overflow with an exact legal discard choice")
	g=fixture()
	g.players[0].traits=["arm"]
	g.players[0].hand=[]
	g.apply({"op":"pass"})
	g.apply({"op":"pass"})
	expect(g.players[0].hand.is_empty() and g.players[0].limit==4,"Robotic Arm does not restore automatic turn-start draws")
	g.tiles.clear()
	g.tiles[ChessMatch.key(Vector2i(0,5))]={"type":"card_draw"}
	g.apply({"op":"move","id":g.at(Vector2i(0,6)).id,"pos":Vector2i(0,5)})
	expect(g.players[0].hand.size()==2,"Robotic Arm doubles a claimed card tile")
	g=fixture()
	g.players[0].hand=[{"id":"lasso","born":0}]
	var definition=ChessCatalog.entry("lasso")
	expect(g.targets(definition,0).all(func(pos: Vector2i) -> bool: return g.at(pos).side==1),"Lasso first target must be an opposing piece")
	var first=Vector2i(3,2)
	expect(g.targets(definition,1,[first]).all(func(pos: Vector2i) -> bool: return g.at(pos).side==1 and pos!=first and ChessMatch.distance(pos,first)<=4),"Lasso second target is another nearby opposing piece")
	expect(not g.apply({"op":"card","index":0,"positions":[Vector2i(3,5),first]}).ok,"Lasso rejects an allied target")
	expect(g.apply({"op":"card","index":0,"positions":[first,Vector2i(5,2)]}).ok and g.at(first).lasso==g.at(Vector2i(5,2)).id,"Lasso links two opposing pieces")

func _test_tile_rules() -> void:
	var g=ChessMatch.new(42)
	expect(g.tiles.size()==7 and g.tiles.values().all(func(t: Dictionary) -> bool: return t.type=="mystery"),"seven hidden mysteries are seeded at the start")
	expect(g.tiles.keys().all(func(k: String) -> bool: return g.empty(ChessMatch.pos_key(k))),"starting mysteries use empty squares")
	expect(g.tiles==ChessMatch.new(42).tiles and g.tiles!=ChessMatch.new(43).tiles,"mysteries are deterministic per seed and vary between games")
	g.cards_unlocked=true
	g.ensure_card_tiles()
	var marked=g.tiles.keys().filter(func(k: String) -> bool: return g.tiles[k].type=="card_draw")
	expect(marked.size()==3 and marked.all(func(k: String) -> bool: return g.empty(ChessMatch.pos_key(k))),"unlocked cards maintain exactly three empty marked draw tiles")
	for i in range(6): g.apply({"op":"pass"})
	expect(g.players[0].hand.is_empty() and g.players[1].hand.is_empty(),"six turns do not generate any cards")
	g=fixture()
	g.tiles.clear()
	g.tiles[ChessMatch.key(Vector2i(0,5))]={"type":"card_draw"}
	g.ensure_card_tiles()
	var result=g.apply({"op":"move","id":g.at(Vector2i(0,6)).id,"pos":Vector2i(0,5)})
	expect(result.ok and g.players[0].hand.size()==1 and g.players[1].hand.is_empty(),"landing on a card tile draws exactly one for its owner")
	expect(not g.tiles.has(ChessMatch.key(Vector2i(0,5))) and g.tiles.values().filter(func(t: Dictionary) -> bool: return t.type=="card_draw").size()==3,"claimed card marker relocates and keeps the active count at three")
	expect(result.events.any(func(e: Dictionary) -> bool: return e.kind=="card_draw"),"card draws create a specific replay event")
	var before=g.snapshot()
	var copy=ChessMatch.new(1,false)
	copy.restore(JSON.parse_string(JSON.stringify(before)))
	expect(copy.tiles==g.tiles and copy.rng.state==g.rng.state and copy.history.size()==g.history.size(),"card tile positions and RNG survive JSON roundtrips")
	var legacy=g.snapshot(false)
	legacy.erase("tile_rules_version")
	legacy.tiles={}
	copy.restore(legacy)
	expect(copy.tiles.values().filter(func(t: Dictionary) -> bool: return t.type=="card_draw").size()==3,"old saved games acquire the new draw markers")
	copy.restore(legacy,false)
	expect(copy.tiles.is_empty(),"historical frames stay exact when migration is disabled")
	g=fixture()
	g.tiles.clear()
	g.ensure_card_tiles()
	var tile_key=g.tiles.keys()[0]
	g.players[0].items=[{"id":"bleach","ready":0,"bought":-1}]
	g.apply({"op":"item","index":0,"positions":[ChessMatch.pos_key(tile_key)]})
	expect(g.tiles.values().filter(func(t: Dictionary) -> bool: return t.type=="card_draw").size()==3,"destroying a draw marker replenishes it")
	for seed_value in range(12):
		g=fixture()
		g.rng.seed=seed_value
		g.players[0].items=[{"id":"heist","ready":0,"bought":-1}]
		var enemy_before=g.players[1].money
		var own_before=g.players[0].money
		result=g.apply({"op":"item","index":0,"positions":[]})
		if g.players[0].money>own_before:
			expect(result.events.any(func(e: Dictionary) -> bool: return e.kind=="heist" and e.value==g.players[0].money-own_before),"Heist records its exact signed cash result")
			expect(enemy_before-g.players[1].money==g.players[0].money-own_before,"Heist transfer balances both treasuries")
			break

func _run() -> void:
	_test_hand_rules()
	_test_tile_rules()
	var g = ChessMatch.new(42)
	var history_game=ChessMatch.new(42)
	var first_pawn=history_game.at(Vector2i(1,6)).id
	history_game.apply({"op":"move","id":first_pawn,"pos":Vector2i(1,5)})
	expect(history_game.history.size()==2,"history includes the initial position and first move")
	var history_before=JSON.stringify(history_game.history)
	history_game.apply({"op":"move","id":first_pawn,"pos":Vector2i(1,4)})
	expect(JSON.stringify(history_game.history)==history_before,"rejected commands never enter the Chronicle")
	history_game.apply({"op":"move","id":history_game.at(Vector2i(1,1)).id,"pos":Vector2i(1,2)})
	var history_copy=ChessMatch.new(1,false)
	history_copy.restore(JSON.parse_string(JSON.stringify(history_game.snapshot())))
	expect(history_copy.history.size()==3 and history_copy.history[1].label.contains("b2"),"history survives JSON save and resume with square notation")
	var old_frame=ChessMatch.new(1,false)
	old_frame.restore(history_copy.history[0].state)
	expect(old_frame.at(Vector2i(1,6)).id==first_pawn and old_frame.ply==0,"initial replay frame is an independent real position")
	old_frame.apply({"op":"pass"})
	expect(history_copy.ply==2 and history_copy.history.size()==3,"browsing a replay cannot change the live game")
	var redacted_history=history_game.public_snapshot(1).history
	expect(redacted_history[-1].state.players[0].hand.all(func(c: Dictionary) -> bool: return c.id=="hidden"),"historical network snapshots keep opposing hands private")
	expect(not history_game.snapshot(false).has("history"),"bot snapshots exclude replay storage")
	var silent_simulation=ChessMatch.new(1)
	silent_simulation.record_history=false
	silent_simulation.apply({"op":"pass"})
	expect(silent_simulation.history.is_empty(),"AI analysis does not record imaginary moves")
	expect(history_game.targets(ChessCatalog.entry("frog"),0).all(func(pos: Vector2i) -> bool: return pos.y==6),"frog targeting explains its actual starting-rank restriction")
	expect(Vector2i(0,6) not in ChessMatch.new(42).targets(ChessCatalog.entry("chacha"),0),"Cha-Cha never highlights a pawn that cannot slide left")
	var count = 0
	for p in g.pieces:
		if p.side==0: count += g.legal_moves(p).size()
	expect(g.pieces.size()==32 and count==20,"opening has 32 pieces and 20 legal Ivory moves")
	var pawn = g.at(Vector2i(1,6))
	g.tiles[ChessMatch.key(Vector2i(1,5))]={"type":"mystery"}
	expect(g.apply({"op":"move","id":pawn.id,"pos":Vector2i(1,5)}).ok and g.market_unlocked,"first mystery unlocks Bazaar")
	expect(not g.apply({"op":"pass","revision":0}).ok,"stale revision is rejected")
	expect(not g.apply({"op":"pass"},0).ok,"wrong player is rejected")
	g.tiles[ChessMatch.key(Vector2i(1,2))]={"type":"mystery"}
	g.apply({"op":"move","id":g.at(Vector2i(1,1)).id,"pos":Vector2i(1,2)})
	expect(g.cards_unlocked and g.players[0].hand.is_empty() and g.tiles.values().filter(func(t: Dictionary) -> bool: return t.type=="card_draw").size()==3,"second mystery unlocks three draw tiles without a free hand")
	var original = g.snapshot()
	var restored = ChessMatch.new(1,false)
	restored.restore(JSON.parse_string(JSON.stringify(original)))
	expect(restored.valid() and restored.ply==g.ply and restored.rng.state==g.rng.state,"JSON save roundtrip preserves state and RNG")
	expect(not g.apply({"op":"move","id":999,"pos":Vector2i.ZERO}).ok and g.snapshot()==original,"invalid commands roll back completely")
	g = fixture()
	g.apply({"op":"shop"})
	g.stock=["glass"]
	expect(g.apply({"op":"buy","item":"glass"}).ok and g.players[0].money==1870 and g.turn==1,"purchase charges once and ends turn")
	var k = ChessMatch.new(5,false)
	var rook = k.add_piece("rook",0,Vector2i(0,7))
	k.add_piece("king",1,Vector2i(0,0))
	k.add_piece("pawn",1,Vector2i(7,1))
	k.apply({"op":"move","id":rook.id,"pos":Vector2i(0,0)})
	expect(k.winner==-1 and k.players[0].money==700,"king capture pays $500 without ending a surviving army")
	k = ChessMatch.new(5,false)
	rook = k.add_piece("rook",0,Vector2i(0,7))
	var victim = k.add_piece("pawn",1,Vector2i(0,0))
	victim.gear=["shield"]
	k.apply({"op":"move","id":rook.id,"pos":Vector2i(0,0)})
	expect(k.at(Vector2i(0,7)).id==rook.id and k.at(Vector2i(0,0)).gear.is_empty() and k.turn==1,"shield blocks attack, consumes shield and spends turn")
	k = ChessMatch.new(5,false)
	rook = k.add_piece("rook",0,Vector2i(0,7))
	victim = k.add_piece("pawn",1,Vector2i(0,0))
	victim.gear=["magic"]
	k.apply({"op":"move","id":rook.id,"pos":Vector2i(0,0)})
	expect(k.winner==0,"magic shield does not block direct capture")
	g = fixture()
	g.players[0].items=[{"id":"gas","ready":0,"bought":-1}]
	var before=g.snapshot()
	expect(not g.apply({"op":"item","index":0,"positions":[Vector2i(3,2)]}).ok and g.snapshot()==before,"invalid item targeting does not spend inventory")
	g = ChessMatch.new(12)
	for i in range(38): g.apply({"op":"pass"})
	expect(g.board_size==20 and g.pieces.size()==32 and g.valid(),"round 20 expands and remaps the board")
	g = fixture()
	g.shop_open=true
	g.add_piece("knight",0,Vector2i(5,7)).upgrade="Dragon"
	g.add_piece("knight",0,Vector2i(6,7)).upgrade="Unicorn"
	expect(g.apply({"op":"fuse","type":"knight","pos":Vector2i(4,7)}).ok and g.at(Vector2i(4,7)).fusion=="Sky Strider","fusion consumes two distinct upgrade paths")
	g = fixture()
	var cleric=g.at(Vector2i(2,6))
	cleric.upgrade="Divine Cleric"
	expect(g.apply({"op":"ability","id":cleric.id,"ability":"revive","grave":0,"pos":Vector2i(1,6)}).ok and g.at(Vector2i(1,6)).type=="knight" and g.players[0].money==1925,"Cleric revives for half cost")
	g = fixture()
	var warden=g.at(Vector2i(3,5))
	warden.fusion="Iron Warden"
	g.add_piece("pawn",1,Vector2i(3,4))
	g.add_piece("pawn",1,Vector2i(4,4))
	expect(g.apply({"op":"ability","id":warden.id,"ability":"shoot","pos":Vector2i(3,4)}).ok and g.turn==0 and g.shots==1,"Iron Warden retains a second shot")
	expect(g.legal_moves(warden).is_empty(),"cannon sequence blocks movement")
	expect(g.apply({"op":"ability","id":warden.id,"ability":"shoot","pos":Vector2i(4,4)}).ok and g.turn==1,"second Warden shot ends turn")
	# Every catalog entry must have at least one usable, legal application.
	for is_card in [true,false]:
		for definition in ChessCatalog.data().cards if is_card else ChessCatalog.data().items:
			var base=fixture()
			var holding={"id":definition.id,"ready":0,"bought":-1,"born":0}
			if is_card: base.players[0].hand=[holding]
			else: base.players[0].items=[holding]
			var choices=[[]]
			if definition.target!=["none"]:
				choices=[]
				for first in base.targets(definition,0):
					if definition.target.size()==1: choices.append([first])
					else:
						for second in base.targets(definition,1,[first]): choices.append([first,second])
			var succeeded=false
			for positions in choices:
				var attempt=ChessMatch.new(1,false)
				attempt.restore(base.snapshot())
				var result=attempt.apply({"op":"card" if is_card else "item","index":0,"positions":positions})
				if result.ok:
					expect(attempt.valid(),"catalog invariant: "+definition.id)
					succeeded=true
					break
			expect(succeeded,"catalog effect reachable: "+definition.id)
	print("PASS catalog: every card and item exercised")
	g=ChessMatch.new(1,false)
	var attacker=g.add_piece("rook",0,Vector2i(0,7))
	var reborn=g.add_piece("pawn",1,Vector2i(0,0))
	reborn.gear=["rein"]
	g.apply({"op":"move","id":attacker.id,"pos":Vector2i(0,0)})
	expect(g.valid() and not g.at(Vector2i(0,0)).is_empty() and g.at(Vector2i(0,7)).id==attacker.id,"reincarnation never overlaps the attacker")
	g=fixture()
	var restricted=g.at(Vector2i(0,6))
	restricted.status.no_attack=2
	expect(Vector2i(1,5) not in g.legal_moves(restricted),"newly deployed pawn cannot capture early")
	var snapshot=g.snapshot()
	expect(ChessMatch.is_snapshot(snapshot) and not ChessMatch.is_snapshot({"players":[]}),"save schema rejects incomplete snapshots")
	g=ChessMatch.new(1,false)
	var borrowed=g.add_piece("rook",0,Vector2i(3,3))
	borrowed.status={"contractor":2,"contractor_path":"Golem"}
	expect(Vector2i(3,7) not in g.legal_moves(borrowed),"Contractor applies Golem movement limit")
	borrowed.status.contractor_path="M1 Abrams"
	expect("shoot" in g.ability_names(borrowed),"Contractor enables the borrowed cannon")
	borrowed.type="bishop"
	borrowed.status.contractor_path="Divine Cleric"
	g.add_piece("pawn",1,Vector2i(4,4))
	expect("revive" in g.ability_names(borrowed) and Vector2i(4,4) not in g.legal_moves(borrowed),"Contractor applies Cleric revival and nonviolence")
	g=fixture()
	borrowed=g.at(Vector2i(0,6))
	borrowed.gear=["barrett"]
	expect(Vector2i(0,4) not in g.legal_moves(borrowed),"Barrett limits first pawn move too")
	# Deterministic simulations catch interactions that isolated fixtures miss.
	for seed_value in range(1,5):
		g=ChessMatch.new(seed_value)
		for step in range(130):
			if g.winner!=-1: break
			var actions=[]
			for p in g.pieces:
				if p.side==g.turn:
					for pos in g.legal_moves(p): actions.append({"op":"move","id":p.id,"pos":pos})
			var action={"op":"pass"} if actions.is_empty() else actions[(step*37+seed_value*11)%actions.size()]
			if g.discard_due>=0: action=ChessBot.choose(g.snapshot(false))
			expect(g.apply(action).ok,"simulation action accepted %d/%d"%[seed_value,step])
			expect(g.valid(),"simulation %d/%d"%[seed_value,step])
	for level in ["easy","normal","hard","expert"]:
		g=ChessMatch.new(3,false)
		g.add_piece("rook",1,Vector2i(0,0))
		g.add_piece("king",0,Vector2i(0,3))
		g.turn=1
		var started=Time.get_ticks_msec()
		var action=ChessBot.choose(g.snapshot(),level)
		expect(g.apply(action).ok and g.valid(),"bot legal: "+level)
		expect(Time.get_ticks_msec()-started<3000,"bot bounded: "+level)
		if level!="easy": expect(g.winner==1,"bot finds winning capture: "+level)
	var run=ChessCampaign.new()
	g=run.start(123)
	g.pieces[0].gear.append("boots")
	for floor_number in range(1,7):
		expect(g.valid() and run.floor_number==floor_number,"campaign encounter %d"%floor_number)
		g.pieces=g.pieces.filter(func(p: Dictionary) -> bool: return p.side==0)
		g.winner=0
		run.observe(g)
		if floor_number==6:
			expect(run.phase=="victory","six-battle campaign victory")
			break
		expect(run.rewards.size()==3 and run.phase=="reward","three rewards")
		var reward=run.rewards[0].id
		expect(run.choose_reward(g,reward) and not run.choose_reward(g,reward),"reward replay rejected")
		g=run.next_battle(g,"supply")
		expect("boots" in g.pieces[0].gear,"campaign equipment persists")
	g=fixture()
	g.draw_cards(0,2)
	g.draw_cards(1,2)
	var public_state=g.public_snapshot(1)
	expect(public_state.players[0].hand[0].id=="hidden" and public_state.players[1].hand[0].id!="hidden","network state keeps opponent's hand private")
	print("RULES_TESTS: %d checks, %d failures"%[checks,failures.size()])
	if failures.is_empty(): print("RULES_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
