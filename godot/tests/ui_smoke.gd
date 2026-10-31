extends RefCounted

var failed=false

func expect(value: bool, message: String) -> bool:
	if not value:
		printerr("SELF_TEST_FAILED: "+message)
		failed=true
	return value

func click(app: Control, control: Control, pos: Vector2, double: bool = false) -> void:
	var global_pos=control.get_global_transform()*pos
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.double_click=double and pressed
		event.position=global_pos
		app.get_viewport().push_input(event,true)
		await app.get_tree().process_frame

func hover(app: Control, global_pos: Vector2) -> void:
	var event=InputEventMouseMotion.new()
	event.position=global_pos
	app.get_viewport().push_input(event,true)
	await app.get_tree().process_frame

func hold_hover(app: Control, global_pos: Vector2, seconds: float) -> void:
	var until=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await hover(app,global_pos)

func key(app: Control, code: int) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	app.get_viewport().push_input(event,true)
	await app.get_tree().process_frame

func capture(app: Control, path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await app.get_tree().process_frame
	check_layout(app)
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png(path)

func check_layout(node: Node) -> void:
	if node is Label and node.has_meta("max_width"):
		expect(node.size.x<=float(node.get_meta("max_width"))+1,"text exceeded its reserved width")
	for child in node.get_children(): check_layout(child)

func run(app: Control) -> void:
	var output="res://test-output"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-output="): output=arg.trim_prefix("--test-output=")
	DirAccess.make_dir_recursive_absolute(output)
	await app.get_tree().create_timer(0.2).timeout
	var conveyor=app.screen.get_node("MenuChessConveyor")
	var before_x=conveyor.boards[0].pos.x
	await app.get_tree().create_timer(0.25).timeout
	expect(conveyor.boards.size()==10 and conveyor.boards[0].pos.x<before_x,"menu chess boards drift along a conveyor")
	expect(app.screen.find_child("OpenArchive",true,false)==null and app.screen.find_child("OpenRules",true,false)==null,"main menu has no Archive or How to Play")
	await capture(app,output.path_join("menu.png"))
	app.start_game("hotseat",42)
	await app.get_tree().process_frame
	var visit=app.screen.get_node("OpenShop")
	expect(not visit.visible and not app.board.coordinates,"Bazaar and coordinates are hidden at the innocent opening")
	expect(app.game.tiles.size()==7 and app.hand.cards.is_empty() and not app.enemy_count.visible,"opening contains seven hidden surprises and no card counter")
	await hover(app,app.board.global_position+app.board.square_center(ChessMatch.pos_key(app.game.tiles.keys()[0])))
	expect(not app.tooltip.visible and app._inspected.get("name","")!="MYSTERY SPACE","unrevealed mysteries do not leak through hover")
	await capture(app,output.path_join("innocent-opening-1080p.png"))
	# Fix two discovery positions for reproducible interaction tests.
	app.game.tiles.clear()
	app.game.tiles["1,5"]={"type":"mystery"}
	app.game.tiles["1,2"]={"type":"mystery"}
	await click(app,app.board,app.board.square_center(Vector2i(1,6)))
	await click(app,app.board,app.board.square_center(Vector2i(1,5)))
	expect(app.game.market_unlocked and visit.visible,"first hidden discovery reveals the Bazaar button")
	expect(app.board._bursts.any(func(b: Dictionary) -> bool: return b.kind=="mystery"),"discovery starts a star burst")
	await app.get_tree().create_timer(0.16).timeout
	await capture(app,output.path_join("mystery-burst-1080p.png"))
	await app.get_tree().create_timer(0.3).timeout
	await click(app,app.board,app.board.square_center(Vector2i(1,1)))
	await click(app,app.board,app.board.square_center(Vector2i(1,2)))
	await app.get_tree().create_timer(0.4).timeout
	expect(app.game.cards_unlocked and app.hand.cards.is_empty(),"card unlock creates marked tiles, not free cards")
	var draw_tiles=app.game.tiles.keys().filter(func(k: String) -> bool: return app.game.tiles[k].type=="card_draw")
	expect(draw_tiles.size()==3,"three visible draw markers appear")
	await hover(app,Vector2(900,30))
	await hold_hover(app,app.board.global_position+app.board.square_center(ChessMatch.pos_key(draw_tiles[0])),0.25)
	# Native Windows hover can be cleared when the virtual-pointer window is not
	# focused. Also exercise the board's local motion handler for this tooltip.
	var local_hover=InputEventMouseMotion.new()
	local_hover.position=app.board.square_center(ChessMatch.pos_key(draw_tiles[0]))
	app.board._gui_input(local_hover)
	expect(app.tooltip.visible and app._inspected.name=="CARD TILE","draw tile explains its draw and relocation")
	await capture(app,output.path_join("draw-tiles-1080p.png"))
	await hover(app,Vector2(900,30))
	# The carousel runs independently of contextual actions; only hover pauses it.
	var elapsed=app.hints.elapsed
	app._set_hint("Test action prompt",0.1)
	await app.get_tree().create_timer(0.15).timeout
	expect(app.hints.elapsed>elapsed and not app.feedback_label.text.contains("Test action"),"context cannot hold or replace rotating tips")
	app.toast.text=""
	await hold_hover(app,app.hints.global_position+Vector2(30,20),0.15)
	elapsed=app.hints.elapsed
	await hold_hover(app,app.hints.global_position+Vector2(30,20),0.15)
	expect(absf(app.hints.elapsed-elapsed)<0.03 and app.hints.duration>=18,"hover pauses the slower hint fuse")
	await click(app,app.hints.get_node("NextHint"),Vector2(12,12))
	expect(app.hints.index==1 and app.hints.counter.text=="2 / 6","inline next arrow changes tip and current count")
	await click(app,app.hints.get_node("PreviousHint"),Vector2(12,12))
	expect(app.hints.index==0 and app.hints.elapsed<0.1,"previous arrow resets fuse")
	await hover(app,Vector2(900,30))
	app.game.players[0].hand=[{"id":"greed","born":0},{"id":"radio","born":0},{"id":"lasso","born":0},{"id":"frog","born":0}]
	app.game.players[1].hand=[{"id":"rat","born":0},{"id":"scavenge","born":0},{"id":"blanket","born":0}]
	app._refresh()
	await hold_hover(app,Vector2(600,865),0.6)
	expect(app.hand.expanded>0.95 and app.hand.cards[0].position.y>550,"hand lifts only enough to read its cards")
	expect(app.enemy_hand.cards[0].size.distance_to(app.hand.cards[0].size)<0.1 and app.enemy_count.text=="3","opponent has full-sized backs and a plain numeric counter")
	var radio=app.hand.cards[1]
	await hold_hover(app,radio.get_global_transform()*Vector2(40,70),0.2)
	expect(radio.get_child(0).text=="Radio Interference" and radio.get_child(0).get_line_count()<=2,"Radio Interference fits a two-line title")
	expect(radio.get_child(1).get_theme_font_size("font_size")>radio.get_child(2).get_theme_font_size("font_size"),"card flavor is larger than mechanics")
	expect(not app._inspected.description.begins_with("("),"Particulars mechanics are plain text")
	await capture(app,output.path_join("cards-1080p.png"))
	await key(app,KEY_3)
	expect(app.card_drag.active and app.card_drag.latched,"number key picks up its matching card")
	await click(app,app,Vector2(650,830))
	await app.get_tree().create_timer(0.3).timeout
	expect(not app.card_drag.active and app.game.revision==2,"clicking the hand cancels pickup")
	await key(app,KEY_3)
	await click(app,app,app.board.global_position+app.board.size/2)
	await app.get_tree().create_timer(0.3).timeout
	expect(app._target.get("definition",{}).get("id","")=="lasso" and app.board.highlighted.all(func(pos: Vector2i) -> bool: return app.game.at(pos).side==1),"number pickup and PLAY targets opposing pieces with Lasso")
	await key(app,KEY_ESCAPE)
	await hold_hover(app,Vector2(600,865),0.5)
	var card=app.hand.cards[0]
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=card.get_global_transform()*Vector2(35,80)
	app.get_viewport().push_input(press,true)
	await app.get_tree().process_frame
	await hold_hover(app,app.board.global_position+app.board.size/2,0.2)
	expect(app.card_drag.active and not app.card_drag.latched,"mouse drag picks up a card")
	await capture(app,output.path_join("drag-play-1080p.png"))
	var release=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_LEFT
	release.pressed=false
	release.position=app.board.global_position+app.board.size/2
	app.get_viewport().push_input(release,true)
	await app.get_tree().create_timer(0.65).timeout
	expect(app.game.players[0].hand.size()==5,"Greed can overflow during the turn")
	var played=app.get_node_or_null("PlayedCard")
	expect(played!=null and (played.position+played.size/2).distance_to(app.board.global_position+app.board.size/2)<2,"played card arrives at the board center")
	await app.get_tree().create_timer(0.8).timeout
	app.command({"op":"pass"})
	expect(app._overlay_kind=="discard" and app.game.turn==0,"end-turn overflow requests discards")
	var choice=app.overlay.get_children().filter(func(c: Node) -> bool: return c is Button and c.get_child_count()>0 and c.get_child(0) is CourtPlayingCard)[0]
	await click(app,choice,Vector2(75,80))
	var confirm=app.overlay.get_node("ConfirmDiscards")
	await click(app,confirm,confirm.size/2)
	expect(app.game.turn==1 and app.game.players[0].hand.size()==4,"chosen discard completes the turn")
	# Small visit warning, persisted opt-out, two-click entry and its setting.
	await click(app,visit,visit.size/2)
	expect(app._overlay_kind=="shop-warning" and not app.game.shop_open and app.overlay.get_child(1).size.x<600,"small Bazaar warning opens on the first click")
	await capture(app,output.path_join("bazaar-warning-1080p.png"))
	var checkbox=app.overlay.get_node("DontWarnAgain")
	await click(app,checkbox,Vector2(20,20))
	confirm=app.overlay.get_node("ConfirmShopVisit")
	await click(app,confirm,confirm.size/2)
	expect(app.game.shop_open and not app.options.shop_warning,"warning opt-out applies after confirming a visit")
	app.command({"op":"leave"})
	await click(app,visit,visit.size/2)
	expect(not app.game.shop_open and visit.text=="CLICK AGAIN TO OPEN","opted-out Bazaar first click arms two-click entry")
	await click(app,visit,visit.size/2)
	expect(app.game.shop_open,"second Bazaar click opens the shop")
	app.command({"op":"leave"})
	app.options.shop_double_click=false
	await click(app,visit,visit.size/2)
	expect(app.game.shop_open,"two-click option can be disabled")
	app.command({"op":"leave"})
	# Replay pages are turns, not fixed groups of six actions.
	var chronicle=app.sidebar.get_node("OpenChronicle")
	await click(app,chronicle,Vector2(180,30))
	expect(app._history_open and not visit.visible and not app.screen.get_node("EndTurn").visible,"replay completely hides Bazaar and End Turn")
	var live=JSON.stringify(app.game.snapshot())
	var card_index=app.game.history.find(app.game.history.filter(func(e: Dictionary) -> bool: return e.label=="Play Pot of Greed")[0])
	app._history_panel.seek(card_index)
	var panel=app._history_panel
	var pinned_page=panel.page
	expect(panel.groups[panel.page].indices.size()==3,"one turn page contains card play, ending turn and discards")
	var row=panel._row_buttons[card_index]
	await hold_hover(app,row.global_position+Vector2(170,20),0.1)
	expect(app.tooltip.visible and app.board.replay and app._history_preview_index==card_index,"hovering card action shows its full replay tooltip")
	await capture(app,output.path_join("chronicle-1080p.png"))
	await hover(app,Vector2(885,250))
	await key(app,KEY_S)
	expect(app._history_index==card_index+1,"S selects the next action within this turn")
	await key(app,KEY_W)
	expect(app._history_index==card_index,"W selects the previous action")
	await key(app,KEY_D)
	expect(panel.page==pinned_page+1,"D advances one turn page")
	await key(app,KEY_A)
	expect(panel.page==pinned_page,"A goes back one turn page")
	expect(JSON.stringify(app.game.snapshot())==live,"replay navigation leaves live state intact")
	app._close_history()
	expect(visit.visible and app.screen.get_node("EndTurn").visible,"leaving replay restores available controls")
	await key(app,KEY_ESCAPE)
	expect(app._overlay_kind=="pause" and app.overlay.get_child(1).size.x<800,"Escape opens compact pause")
	await capture(app,output.path_join("pause-1080p.png"))
	app._settings()
	await click(app,app.overlay.get_node("Setting_coordinates"),Vector2(50,20))
	expect(app.options.coordinates and app.board.coordinates,"coordinate setting enables files and ranks")
	await capture(app,output.path_join("settings-1080p.png"))
	app._close_overlay()
	app._pause_parent=false
	app._save_game()
	var revision=app.game.revision
	app.load_game()
	expect(app.game.valid() and app.game.revision==revision,"prototype saves and resumes the current rules")
	# Overflowing turn pages scroll; short ones do not.
	app.game.players[app.game.turn].hand=[{"id":"vest","born":0}]
	for i in range(8): app.game.apply({"op":"pass"})
	var synthetic=app.game.history.duplicate(true)
	var base=synthetic[-1].duplicate(true)
	var start=synthetic.size()
	for i in range(8):
		var entry=base.duplicate(true)
		entry.ply=100
		entry.actor=0
		entry.label="Action %d"%(i+1)
		synthetic.append(entry)
	app._open_history()
	panel=app._history_panel
	panel.show_entries(synthetic,start)
	expect(panel.groups[panel.page].indices.size()==8 and panel._scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"more than six actions in one turn enables scrolling")
	panel.turn_page(-1)
	expect(panel._scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"short turn pages have no visible scrollbar")
	app._close_history()
	# Run the actual background bot after a local move.
	app.start_game("solo",42)
	app.command({"op":"pass"})
	var deadline=Time.get_ticks_msec()+12000
	while app.game.turn==1 and Time.get_ticks_msec()<deadline: await app.get_tree().process_frame
	expect(app.game.turn==0,"background bot completes its turn")
	app._finish_bot()
	app._settings()
	await capture(app,output.path_join("final-settings-1080p.png"))
	var report=FileAccess.open(output.path_join("self-test.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":not failed,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"checks":"innocent opening, discovery particles, limited draw tiles, card drag and number controls, full-sized opposing backs, shorter cards, Bazaar warning and opt-out and two-click entry, independent hover-paused hints, replay turn pages and WASD, scroll overflow, hidden controls, coordinates, save and bot"},"  "))
	report.close()
	if not failed: print("SELF_TEST_PASS: Schedule 1 Chess local prototype interactions")
	app.audio.configure(false,false)
	await app.get_tree().create_timer(0.3).timeout
	app.get_tree().quit(1 if failed else 0)
