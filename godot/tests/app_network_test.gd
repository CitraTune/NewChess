extends RefCounted

func run(app: Control, hosting: bool) -> void:
	app.options.seconds=60
	if hosting:
		app.start_game("online-host",42)
		app.game.cards_unlocked=true
		app.game.draw_cards(0,2)
		app.game.draw_cards(1,5)
		app.game.apply({"op":"move","id":app.game.at(Vector2i(0,6)).id,"pos":Vector2i(0,5)})
		app._build_battle()
		app.network.host(app.game,18800)
		print("APP_NETWORK_HOST_READY")
	else:
		# Join from a fresh main menu, before any local game has been created.
		app.mode="online-client"
		app.network.join("127.0.0.1",18800)
	var deadline=Time.get_ticks_msec()+12000
	if not hosting:
		while (app.game==null or app._menu_open) and Time.get_ticks_msec()<deadline:
			await app.get_tree().process_frame
		if app.game==null or app._menu_open:
			printerr("NETWORK_TEST_FAILED: client main menu did not become a match")
			app.get_tree().quit(1)
			return
		if not app.can_act() or app.game.players[0].hand[0].id!="hidden" or app.options.seconds!=60:
			printerr("NETWORK_TEST_FAILED: client role, hand privacy or clock sync")
			app.get_tree().quit(1)
			return
		app.command({"op":"move","id":app.game.at(Vector2i(0,1)).id,"pos":Vector2i(0,2)})
		while app.game.discard_due!=1 and Time.get_ticks_msec()<deadline:
			await app.get_tree().process_frame
		if app.game.discard_due!=1 or app._overlay_kind!="discard":
			printerr("NETWORK_TEST_FAILED: guest did not receive its end-turn discard choice")
			app.get_tree().quit(1)
			return
		app.command({"op":"discard","indices":range(app.game.players[1].hand.size()-4)})
	while (app.game==null or app.game.ply<2) and Time.get_ticks_msec()<deadline:
		await app.get_tree().process_frame
	var passed=app.game!=null and app.game.ply==2 and app.game.valid() and app.game.discard_due==-1 and app.game.players[1].hand.size()==4 and not app.game.at(Vector2i(0,2)).is_empty()
	if passed: print("APP_NETWORK_PASS: %s main menu, controller, private state, clock, movement and owner-selected discards"%("host" if hosting else "client"))
	else: printerr("NETWORK_TEST_FAILED: app controllers did not synchronize")
	if hosting: await app.get_tree().create_timer(0.5).timeout
	app.audio.configure(false,false)
	app.network.close()
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	app.get_tree().quit(0 if passed else 1)
