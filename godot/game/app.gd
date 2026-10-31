extends Control
## Application flow and view composition. No gameplay rules live in the widgets.

var save_path = "user://court-save.json"
var settings_path = "user://court-settings.cfg"
const SAVE_VERSION = 2

var game: ChessMatch
var campaign: ChessCampaign
var mode = "solo"
var difficulty = "normal"
var options = {"sound":true,"music":true,"reduced_motion":false,"auto_flip":false,"seconds":0,"coordinates":false,"shop_warning":true,"shop_double_click":true}
var network = ChessNetwork.new()
var audio = CourtAudio.new()
var screen = Control.new()
var overlay = Control.new()
var tooltip = Panel.new()
var toast = Label.new()
var board: CourtBattlefield
var sidebar: Control
var hand: CourtHand
var enemy_hand: CourtHand
var enemy_count: Label
var shelf: Control
var turn_label: Label
var money_label: Label
var timer_label: Label
var feedback_label: Label
var enemy_label: Label
var _selected = -1
var _target: Dictionary = {}
var _positions: Array = []
var _inspected: Dictionary = {}
var _overlay_kind = ""
var _menu_open = true
var _deadline = 0.0
var _last_clock = ""
var _toast_time = 0.0
var _shelf_page = 0
var _archive_page = 0
var _forge_page = 0
var _forge_selected = -1
var _bot_thread: Thread
var _bot_revision = -1
var _bot_ready_at = 0.0
var _status = ""
var _host_address = "127.0.0.1"
var _port = 8799
var _seed = 1
var _startup_args: PackedStringArray
var _history_open=false
var _history_index=-1
var _history_panel: CourtChronicle
var _history_view: ChessMatch
var _history_preview_index=-1
var hints: CourtHints
var card_drag: CourtCardDrag
var _pending_card_origin: Dictionary={}
var _discard_selected: Array=[]
var _discard_page=0
var _pause_parent=false
var _shop_click_until=0
var _shop_click_revision=-1
var _board_hover=Vector2i(-1,-1)
var _card_presentations: Array = []
var _presenting_card=false
var _presentation_generation=0
var _drag_game: ChessMatch
var _pointer=Vector2(-1000,-1000)

func _ready() -> void:
	theme = CourtPalette.theme()
	_startup_args = OS.get_cmdline_user_args()
	if "--self-test" in _startup_args: settings_path="user://court-self-test-settings.cfg"
	_migrate_user_data()
	_load_settings()
	if DisplayServer.get_name()=="headless":
		options.sound=false
		options.music=false
	_startup_args = OS.get_cmdline_user_args()
	get_tree().auto_accept_quit=false
	if "--self-test" in _startup_args:
		save_path="user://court-self-test-save.json"
		options.seconds=0
		options.shop_warning=true
		options.shop_double_click=true
		options.coordinates=false
	_seed = int(Time.get_unix_time_from_system())
	for arg in _startup_args:
		if arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = load("res://ui/table.gdshader")
	material.set_shader_parameter("reduced_motion",options.reduced_motion)
	backdrop.material = material
	add_child(backdrop)
	for layer in [screen,overlay]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	overlay.z_index = 50
	tooltip.z_index = 100
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	add_child(tooltip)
	toast.position = Vector2(400,24)
	toast.size = Vector2(800,55)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font",CourtPalette.BOLD)
	toast.add_theme_font_size_override("font_size",22)
	toast.add_theme_color_override("font_color",CourtPalette.GOLD)
	toast.z_index = 110
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	network.name = "Network"
	add_child(network)
	audio.name = "CourtAudio"
	audio.music_enabled = options.music
	add_child(audio)
	audio.configure(options.sound,options.music)
	network.command_received.connect(_remote_command)
	network.state_received.connect(_receive_state)
	network.status_changed.connect(func(message: String) -> void:
		_status = message
		_notify(message)

	)
	card_drag=CourtCardDrag.new()
	add_child(card_drag)
	card_drag.play_requested.connect(_drop_card)
	card_drag.pointer_updated.connect(func(point: Vector2) -> void: _pointer=point)
	card_drag.returned.connect(func() -> void:
		if is_instance_valid(hand):
			hand.drag_index=-1
			hand.interaction_blocked=_overlay_kind!="" or _history_open
			hand._pointer=hand.get_global_transform().affine_inverse()*_pointer
	)
	_show_menu()
	print("DREAM_CHESS_READY native Godot %s / %s / %s" % [Engine.get_version_info().string,RenderingServer.get_current_rendering_method(),AudioServer.get_driver_name()])
	if "--self-test" in _startup_args:
		_run_smoke.call_deferred()
	elif "--network-app-host" in _startup_args or "--network-app-client" in _startup_args:
		_run_network_test.call_deferred()

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _label(parent: Node, value: String, rect: Rect2, font_size: int = 22, color: Color = CourtPalette.PAPER, display: bool = false, bold: bool = false) -> Label:
	var label = Label.new()
	label.clip_text = true
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = value.to_upper() if display else value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font",CourtPalette.DISPLAY if display else (CourtPalette.ACCENT if bold and value==value.to_upper() and value.length()>3 and font_size>=20 and font_size<30 else (CourtPalette.BOLD if bold else CourtPalette.BODY)))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _paragraph(parent: Node, value: String, rect: Rect2, font_size: int = 22, color: Color = CourtPalette.MUTED) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text = value
	label.position = rect.position
	label.add_theme_font_override("font",CourtPalette.BODY)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = rect.size
	label.set_meta("max_width",rect.size.x)
	parent.add_child(label)
	label.set_deferred("size",rect.size)
	return label

func _panel(parent: Node, rect: Rect2, fill: Color = CourtPalette.PANEL, border: Color = Color("665a59")) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",CourtPalette.style(fill,border))
	parent.add_child(p)
	return p

func _button(parent: Node, value: String, rect: Rect2, callback: Callable, name_value: String = "") -> Button:
	var b = Button.new()
	b.text = value
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size",clampi(int((rect.size.x-36)/maxf(1,value.length())/0.58),16,20))
	if parent==overlay and _overlay_kind in ["pause","settings","discard"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var box=theme.get_stylebox(state,"Button").duplicate()
			box.content_margin_top=4
			box.content_margin_bottom=4
			b.add_theme_stylebox_override(state,box)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if name_value != "": b.name = name_value
	b.pressed.connect(func() -> void:
		audio.play_sound("select")
		_hide_tip()
		callback.call()
	)
	parent.add_child(b)
	return b

func _sprite(parent: Node, id: String, rect: Rect2, side: int = -1) -> TextureRect:
	var icon = TextureRect.new()
	icon.texture = CourtPixels.texture(id,side)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = rect.position
	icon.size = rect.size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _card(parent: Node, d: Dictionary, rect: Rect2, callback: Callable, large: bool = false, index: int = -1) -> CourtCard:
	var c = CourtCard.new()
	c.definition = d
	c.position = rect.position
	c.size = rect.size
	c.large = large
	c.index = index
	c.reduced_motion = options.reduced_motion
	c.pressed.connect(func() -> void:
		audio.play_sound("select")
		_hide_tip()
		callback.call()
	)
	c.inspected.connect(func(definition: Dictionary) -> void:
		if not _menu_open and _overlay_kind == "":
			_inspected = definition
			_update_sidebar()
		else:
			_show_tip(definition)
	)
	c.uninspected.connect(func() -> void:
		_hide_tip()
		_inspected = {}
		if not _menu_open and _overlay_kind == "": _update_sidebar()
	)
	parent.add_child(c)
	return c

func _show_tip(d: Dictionary) -> void:
	_clear(tooltip)
	var description=str(d.get("description",""))
	var body=_paragraph(tooltip,description,Rect2(20,57,400,700),21,CourtPalette.PAPER)
	var body_height=maxf(80,body.get_line_count()*(body.get_line_height()+3)+18)
	body.size=Vector2(400,body_height)
	body.set_deferred("size",body.size)
	var height=body_height+148
	tooltip.size=Vector2(440,height)
	tooltip.position=(_pointer+Vector2(22,12)).clamp(Vector2(20,20),Vector2(1140,880-height))
	tooltip.add_theme_stylebox_override("panel",CourtPalette.style(CourtPalette.DEEP,CourtPalette.GOLD))
	_label(tooltip,d.get("name",""),Rect2(20,14,400,35),24,CourtPalette.GOLD,false,true)
	_paragraph(tooltip,d.get("flavor",""),Rect2(20,64+body_height,400,66),18,CourtPalette.MUTED)
	tooltip.show()

func _hide_tip() -> void:
	tooltip.hide()

func _show_menu() -> void:
	_cancel_card_presentations()
	if is_instance_valid(card_drag): card_drag.cancel()
	_history_open=false
	_pause_parent=false
	_menu_open=true
	_close_overlay()
	_clear(screen)
	board=null
	var conveyor=CourtMenuBoards.new()
	conveyor.name="MenuChessConveyor"
	conveyor.reduced_motion=options.reduced_motion
	conveyor.size=Vector2(1600,900)
	screen.add_child(conveyor)
	_label(screen,"SCHEDULE 1",Rect2(90,290,780,120),95,CourtPalette.PAPER,true)
	_label(screen,"CHESS",Rect2(90,410,780,130),110,CourtPalette.PAPER,true)
	_panel(screen,Rect2(950,100,560,690),Color(0.12,0.11,0.16,0.94),Color("9a7c53"))
	_button(screen,"THE SHATTERED CROWN",Rect2(990,150,480,62),func() -> void: start_game("campaign"),"StartCampaign")
	_button(screen,"DUEL THE COURT",Rect2(990,231,480,60),func() -> void: start_game("solo"),"StartSolo")
	_button(screen,"LOCAL TWO-PLAYER",Rect2(990,312,480,58),func() -> void: start_game("hotseat"),"StartLocal")
	_button(screen,"PLAY WITH A FRIEND",Rect2(990,393,480,58),_network_menu,"StartNetwork")
	var cont=_button(screen,"CONTINUE",Rect2(990,474,480,58),load_game,"ContinueGame")
	cont.disabled=not FileAccess.file_exists(save_path)
	_label(screen,"BOT DIFFICULTY",Rect2(995,570,460,28),17,CourtPalette.MUTED,false,true)
	for i in range(4):
		var level=["easy","normal","hard","expert"][i]
		var b=_button(screen,level.capitalize(),Rect2(990+i*122,611,114,45),func() -> void:
			difficulty=level
			_save_settings()
			_show_menu()
		)
		if difficulty==level: b.add_theme_stylebox_override("normal",CourtPalette.style(CourtPalette.LIGHT_PANEL,CourtPalette.GOLD))
	_button(screen,"SETTINGS",Rect2(990,702,480,48),_settings,"OpenSettings")
	if game!=null: _button(screen,"RETURN TO GAME",Rect2(990,817,480,48),_build_battle,"ReturnGame")

func start_game(kind: String, seed_value: int = -1) -> void:
	_history_open=false
	_history_index=-1
	_cancel_card_presentations()
	_finish_bot()
	network.close()
	mode = kind
	if seed_value >= 0: _seed = seed_value
	else: _seed = int(Time.get_unix_time_from_system())
	campaign = null
	if kind == "campaign":
		campaign = ChessCampaign.new()
		game = campaign.start(_seed)
	else:
		game = ChessMatch.new(_seed)
	_selected = -1
	_target = {}
	_positions = []
	_shelf_page = 0
	_reset_clock()
	_build_battle()
	_save_game()

func role() -> int:
	return game.turn if mode=="hotseat" and game != null else (1 if mode=="online-client" else 0)

func _build_battle() -> void:
	if game==null: return
	_history_open=false
	_history_index=-1
	_history_preview_index=-1
	_menu_open=false
	_shop_click_until=0
	toast.text=""
	_toast_time=0
	_close_overlay()
	_clear(screen)
	_button(screen,"Ⅱ",Rect2(48,32,56,43),_pause_menu,"PauseGame")
	_label(screen,"ESC  /  PAUSE",Rect2(118,43,135,25),17,CourtPalette.MUTED,false,true)
	shelf=Control.new()
	shelf.name="RelicShelf"
	shelf.position=Vector2(940,49)
	screen.add_child(shelf)
	_panel(screen,Rect2(32,131,224,635),Color("211f2d"),Color("655349"))
	_label(screen,"YOUR COURT",Rect2(52,154,190,28),22,CourtPalette.GOLD,false,true)
	turn_label=_label(screen,"",Rect2(52,198,190,91),30,CourtPalette.PAPER,true)
	money_label=_label(screen,"",Rect2(52,302,190,63),43,CourtPalette.GOLD,false,true)
	enemy_label=_label(screen,"",Rect2(52,375,190,54),20,CourtPalette.MUTED)
	timer_label=_label(screen,"",Rect2(52,441,190,40),23,CourtPalette.TEAL,false,true)
	var visit=_button(screen,"THE BAZAAR",Rect2(51,507,186,56),_shop_pressed,"OpenShop")
	_button(screen,"END TURN",Rect2(51,578,186,56),func() -> void: command({"op":"pass"}),"EndTurn")
	var flip=_button(screen,"",Rect2(116,681,54,54),func() -> void: board.flipped=not board.flipped,"FlipBoard")
	var flip_art=load("res://ui/flip_icon.gd").new()
	flip_art.size=Vector2(48,48)
	flip_art.position=Vector2(3,3)
	flip.add_child(flip_art)
	flip.tooltip_text="Flip board"
	board=CourtBattlefield.new()
	board.name="Battlefield"
	board.position=Vector2(275,118)
	board.size=Vector2(648,648)
	board.game=game
	board.flipped=role()==1
	board.reduced_motion=options.reduced_motion
	board.coordinates=options.coordinates
	board.square_clicked.connect(_square_clicked)
	board.square_hovered.connect(_square_hovered)
	screen.add_child(board)
	sidebar=Control.new()
	sidebar.name="Details"
	sidebar.position=Vector2(930,120)
	screen.add_child(sidebar)
	for is_enemy in [false,true]:
		var fan=CourtHand.new()
		fan.name="OpponentHand" if is_enemy else "Hand"
		fan.position=Vector2(260,0)
		fan.size=Vector2(680,900)
		fan.z_index=15 if is_enemy else 25
		fan.opponent=is_enemy
		fan.reduced_motion=options.reduced_motion
		screen.add_child(fan)
		if is_enemy:
			enemy_hand=fan
		else:
			hand=fan
			fan.card_inspected.connect(func(d: Dictionary) -> void:
				if _history_open or _overlay_kind!="": return
				_inspected=d
				_update_sidebar()
			)
			fan.inspection_ended.connect(func() -> void:
				_inspected={}
				_update_sidebar()
			)
			fan.activate_card.connect(func(index: int) -> void:
				if _overlay_kind=="":
					_remember_card(index)
					_arm_use(true,index)
			)
			fan.drag_requested.connect(func(index: int) -> void: _begin_drag(index,false))
			fan.single_clicked.connect(func() -> void: _set_hint("Double-click to play, or drag the card to PLAY. Number keys pick cards up too.",3))
	enemy_count=_label(screen,"",Rect2(830,34,36,30),17,CourtPalette.MUTED)
	enemy_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var count_box=CourtPalette.style(Color(0,0,0,0.10),Color("625b62"),4,1)
	count_box.content_margin_left=4
	count_box.content_margin_right=4
	count_box.content_margin_top=2
	count_box.content_margin_bottom=2
	count_box.shadow_size=0
	enemy_count.add_theme_stylebox_override("normal",count_box)
	hints=CourtHints.new()
	hints.position=Vector2(38,778)
	hints.size=Vector2(212,116)
	screen.add_child(hints)
	feedback_label=hints.label
	_refresh()

func _refresh(messages: Array = []) -> void:
	if _menu_open or not is_instance_valid(board):
		return
	board.game = game
	board.reduced_motion = options.reduced_motion
	board.play(messages)
	for event in messages:
		if event.kind=="card" and not _history_open: _queue_card_presentation(event)
	if options.auto_flip and mode=="hotseat": board.flipped=game.turn==1
	turn_label.text = "%s\nROUND %d" % ["IVORY" if game.turn==0 else "ONYX",game.round_number()]
	turn_label.add_theme_color_override("font_color",CourtPalette.PAPER if game.turn==0 else Color("c9b4e8"))
	money_label.text = "$%d" % game.players[role()].money
	enemy_label.text = "Enemy treasury\n$%d" % game.players[1-role()].money
	var visit = screen.find_child("OpenShop",true,false)
	if visit is Button:
		visit.visible=game.market_unlocked and not _history_open
		visit.disabled=not can_act() or game.shots>0 or game.discard_due>=0
		visit.text="CLICK AGAIN TO OPEN" if _shop_click_until>Time.get_ticks_msec() and _shop_click_revision==game.revision else "THE BAZAAR"
		visit.add_theme_font_size_override("font_size",16 if visit.text.begins_with("CLICK") else 20)
	var pass_button = screen.find_child("EndTurn",true,false)
	if pass_button is Button:
		pass_button.visible=not _history_open
		pass_button.disabled=not can_act() or game.shop_open or game.discard_due>=0
	_update_hint()
	_update_hand()
	_update_shelf()
	_update_highlights()
	_update_sidebar()
	if _history_open:
		_history_panel.show_entries(_timeline_entries(),_history_index)
		_seek_history(_history_index)
	if game.discard_due==role() and game.winner==-1 and not _history_open and _overlay_kind not in ["pause","settings","rules","archive"]:
		_show_discard()
	elif campaign != null and campaign.phase != "battle":
		_show_campaign()
	elif game.winner != -1:
		_show_victory()

func can_act() -> bool:
	return not _presenting_card and not _history_open and _overlay_kind not in ["pause","shop-warning"] and game != null and game.winner==-1 and game.turn==role() and (not mode.begins_with("online") or network.active)

func _update_hand() -> void:
	var view=board.game if _history_open else game
	var definitions: Array=[]
	for held in view.players[role()].hand:
		var d=ChessCatalog.entry(held.id).duplicate(true)
		if d.is_empty(): continue
		if d.id=="collector": d.description+=" Current value: $%d."%(10*int((view.ply-held.born)/2))
		definitions.append(d)
	hand.set_cards(definitions)
	hand.enabled=can_act() and not game.shop_open and game.shots==0 and _overlay_kind=="" and game.discard_due<0
	hand.armed_index=_target.get("index",-1) if _target.get("op","")=="card" else -1
	hand.reduced_motion=options.reduced_motion
	var backs: Array=[]
	for ignored in view.players[1-role()].hand: backs.append({"id":"hidden"})
	enemy_hand.set_cards(backs,true)
	enemy_hand.reduced_motion=options.reduced_motion
	enemy_count.text=str(backs.size())
	enemy_count.visible=not backs.is_empty()
	enemy_count.position.x=clampf(600+maxi(1,backs.size()-1)*55+120,715,895)

func _update_shelf() -> void:
	_clear(shelf)
	var items = game.players[role()].items.duplicate(true)
	for trait_id in game.players[role()].traits:
		items.append({"id":trait_id,"ready":0,"passive":true})
	var start = _shelf_page*10
	if start>=items.size():
		_shelf_page = 0
		start = 0
	for i in range(start,mini(start+10,items.size())):
		var definition = ChessCatalog.entry(items[i].id)
		if definition.is_empty():
			definition={"id":items[i].id,"name":"Electric Companion" if items[i].id=="companion" else "Leprechaun's Favor","description":"A tiny friend cheers on your court." if items[i].id=="companion" else "The leprechaun's special Bazaar offers are available.","group":"passive"}
		var passive=items[i].get("passive",false)
		var x = (i-start)*63
		var button = _button(shelf,"",Rect2(x,0,56,48),func() -> void:
			if passive:
				_inspected=definition
				_update_sidebar()
			else: _arm_use(false,i)
		)
		button.disabled = not passive and (not can_act() or game.shop_open or items[i].ready>game.ply)
		_sprite(button,definition.id,Rect2(8,3,40,40))
		button.mouse_entered.connect(func() -> void:
			_inspected = definition
			_update_sidebar()
			_show_tip(definition)
		)
		button.mouse_exited.connect(_hide_tip)
	if items.size()>10:
		_button(shelf,">",Rect2(638,0,50,48),func() -> void:
			_shelf_page = (_shelf_page+1)%int(ceil(items.size()/10.0))
			_update_shelf()
		)
	if items.is_empty(): _label(shelf,"RELICS YOU FIND WILL LIVE HERE",Rect2(0,11,700,28),17,CourtPalette.MUTED)

func _piece_description(p: Dictionary) -> String:
	var descriptions = {
		"pawn":"Advance straight. Capture diagonally. Reach the far rank to promote.","knight":"Leap in an L shape. Pieces in the way do not matter.","bishop":"Slide diagonally. Other pieces block the path.","rook":"Slide along ranks and files. Other pieces block the path.","queen":"Slide along ranks, files and diagonals.","king":"One square in any direction. Worth $500, but its death does not end the battle.","frog":"Advance one or two squares. Capture diagonally. Can promote.","goose":"One-square movement. Cannot attack. Reach the far rank for an unreasonable surprise.","canadian":"Five-square movement and attack. Flies over pieces.","automaton":"Three-square movement, no attack. Explodes on death or by ability.","goat":"Two-square movement. Three-square rocket attack.","dropship":"Four-square flight. Deploy an octopus instead of moving.","commando":"Two-square movement and ranged attack.","octopus":"One square in any direction.","tree":"An investment. Matures after five rounds.","fungus":"An obstacle left by the Curse of Spore.","decoy":"Rook movement up to three squares. Releases a knight on death.","hidden":"Blanketed by its owner. Its identity is temporarily concealed."
	}
	var value = descriptions.get(p.type,"")
	if p.upgrade!="": value += "\nUpgrade: "+p.upgrade+"."
	if p.fusion!="": value += "\nAlignation: "+p.fusion+"."
	if not p.gear.is_empty():
		value += "\nEquipment: "+", ".join(p.gear.map(func(id: String) -> String: return ChessCatalog.entry(id).get("name",id)))+"."
	var statuses = []
	for status in p.status:
		if p.status[status] is int or p.status[status] is float:
			if int(p.status[status])>game.ply: statuses.append(status.capitalize())
	if not statuses.is_empty(): value += "\n"+", ".join(statuses)+"."
	if p.get("parcel_deadline",-1)>game.ply:
		value+="\nPARCEL: Move this piece onto either home rank (%d or %d) within %d turns to earn $100. Pawns need a movement card to go backward."%[1 if p.side==0 else game.board_size-1,2 if p.side==0 else game.board_size,maxi(1,int(ceil((p.parcel_deadline-game.ply)/2.0)))]
	return value

func _update_sidebar() -> void:
	if not is_instance_valid(sidebar) or _menu_open:
		return
	if _history_open: return
	_clear(sidebar)
	_panel(sidebar,Rect2(0,0,637,647),Color("23212f"),Color("665349"))
	var p = game.piece(_selected)
	var info = _inspected
	if not p.is_empty() and info.is_empty(): info={"name":ChessCatalog.piece_name(p),"description":_piece_description(p),"icon":p.type}
	if info.is_empty(): info={"name":"A COURT OF POSSIBILITIES","description":"Select a piece to see legal moves. Eliminate the opposing army to win.","icon":"king"}
	_label(sidebar,"THE PARTICULARS",Rect2(24,18,560,28),17,CourtPalette.GOLD,false,true)
	_sprite(sidebar,info.get("icon",info.get("id","star")),Rect2(20,58,98,98),p.get("side",-1) if not p.is_empty() and _inspected.is_empty() else -1)
	var heading = _label(sidebar,info.get("name",""),Rect2(135,60,475,91),31,CourtPalette.PAPER,true)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size = Vector2(475,91)
	if info.has("flavor"):
		_paragraph(sidebar,'"'+info.flavor+'"',Rect2(27,163,580,48),23,CourtPalette.GOLD)
		_paragraph(sidebar,info.get("description",""),Rect2(27,221,581,183),20,CourtPalette.MUTED)
	else:
		_paragraph(sidebar,info.get("description",""),Rect2(27,167,581,196),22,CourtPalette.PAPER)
	if not p.is_empty() and p.side==role() and _inspected.is_empty():
		var abilities = game.ability_names(p)
		for i in range(abilities.size()):
			var ability = abilities[i]
			var button = _button(sidebar,ability.capitalize(),Rect2(26+(i%3)*195,363+int(i/3)*49,180,42),func() -> void: _arm_ability(ability))
			button.disabled = not can_act()
	if not _target.is_empty():
		_paragraph(sidebar,str(_target.get("prompt","Choose a highlighted square."))+" Esc cancels.",Rect2(27,365,581,65),20,CourtPalette.TEAL)
	var chronicle_zone=CourtLink.new()
	chronicle_zone.name="OpenChronicle"
	chronicle_zone.position=Vector2(15,445)
	chronicle_zone.size=Vector2(607,195)
	chronicle_zone.reduced_motion=options.reduced_motion
	chronicle_zone.pressed.connect(_open_history)
	sidebar.add_child(chronicle_zone)
	_label(chronicle_zone,"THE CHRONICLE  ›",Rect2(12,11,560,27),20,CourtPalette.GOLD,false,true)
	var lines=[]
	for line in game.log_lines.slice(0,4): lines.append("• "+str(line))
	_paragraph(chronicle_zone,"\n".join(lines),Rect2(12,53,581,105),18,CourtPalette.MUTED)
	_label(chronicle_zone,"CLICK TO EXPLORE THE PAST",Rect2(12,168,581,24),16,CourtPalette.MUTED,false,true)

func _update_highlights() -> void:
	if not is_instance_valid(board): return
	board.selected_id = _selected
	board.target_mode = not _target.is_empty()
	board.preview_kind = _target.get("definition",{}).get("id","")
	if _target.is_empty():
		board.highlighted = game.legal_moves(game.piece(_selected)) if _selected>=0 else []
	elif _target.op in ["card","item"]:
		board.highlighted = game.targets(_target.definition,_positions.size(),_positions)
	elif _target.op=="fuse":
		board.highlighted = []
		for x in range(game.board_size):
			var pos = Vector2i(x,game.board_size-1 if role()==0 else 0)
			if game.empty(pos): board.highlighted.append(pos)
	else:
		board.highlighted = _ability_targets()

func _square_clicked(pos: Vector2i) -> void:
	if not can_act() or board.busy or _overlay_kind!="" or card_drag.active or game.discard_due>=0:
		return
	_hide_tip()
	_inspected = {}
	if not _target.is_empty():
		if pos not in board.highlighted:
			_notify("Choose one of the highlighted targets.")
			return
		if _target.op in ["card","item"]:
			_positions.append(pos)
			if _positions.size()<_target.definition.target.size():
				_target.prompt = _target_prompt(_target.definition,_positions.size())
				_refresh()
				return
			command({"op":_target.op,"index":_target.index,"positions":_positions.duplicate()})
		elif _target.op=="fuse": command({"op":"fuse","type":_target.type,"pos":pos})
		else: command({"op":"ability","id":_selected,"ability":_target.ability,"pos":pos,"grave":_target.get("grave",-1)})
		return
	var p = game.at(pos)
	if pos in board.highlighted and _selected>=0:
		command({"op":"move","id":_selected,"pos":pos})
	elif not p.is_empty() and p.side==role():
		_selected = int(p.id)
		audio.play_sound("select")
		_refresh()
	else:
		_selected = -1
		_refresh()

func _arm_use(is_card: bool, index: int) -> void:
	if not can_act() or game.shop_open or game.discard_due>=0: return
	var held = game.players[role()].hand if is_card else game.players[role()].items
	if index<0 or index>=held.size(): return
	var d = ChessCatalog.entry(held[index].id)
	if d.target==["none"]:
		command({"op":"card" if is_card else "item","index":index,"positions":[]})
		return
	_target = {"op":"card" if is_card else "item","index":index,"definition":d,"prompt":_target_prompt(d,0)}
	_positions = []
	_inspected = d
	_refresh()

func _target_prompt(definition: Dictionary, stage: int) -> String:
	var names={"ally":"one of your pieces","enemy":"an opposing piece","pawn":"one of your pawns","knight":"your knight","rook":"your rook","queen":"your queen","royal":"your king or queen","soldier":"your knight, rook or bishop","empty":"an empty highlighted square","tile":"a highlighted square","any_tile":"a highlighted square","any":"a highlighted piece"}
	return "%s: %schoose %s."%[definition.name,"next, " if stage>0 else "",names.get(definition.target[stage],definition.target[stage])]

func _arm_ability(ability: String) -> void:
	if ability=="detonate":
		command({"op":"ability","id":_selected,"ability":ability})
		return
	_target = {"op":"ability","ability":ability,"prompt":ability+" target"}
	if ability=="revive":
		_open_overlay("THE GONE, NOT FORGOTTEN","Choose a fallen ally. Then choose an empty square within two tiles of your Cleric.","revive")
		var row = 0
		for i in range(game.graves.size()):
			if game.graves[i].side!=role(): continue
			if row>=8: break
			_button(overlay,"%s  /  $%d" % [ChessCatalog.data().pieces[game.graves[i].type].name,ChessCatalog.value(game.graves[i].type)/2],Rect2(230,220+row*57,1100,48),func() -> void:
				_target.grave = i
				_close_overlay()
				_refresh()
			)
			row+=1
		if row==0: _label(overlay,"No fallen allies yet.",Rect2(230,240,1000,60),28)
	_refresh()

func _ability_targets() -> Array:
	var out = []
	var p = game.piece(_selected)
	if p.is_empty(): return out
	for y in range(game.board_size):
		for x in range(game.board_size):
			var pos = Vector2i(x,y)
			var q = game.at(pos)
			var dist = ChessMatch.distance(p.pos,pos)
			var ability = _target.get("ability","")
			var valid = false
			if ability in ["shoot","cast"]:
				var radius = 3 if p.fusion=="Archmage" or p.type=="goat" else (2 if p.fusion=="Iron Warden" or p.type=="commando" or "barrett" in p.gear or "m4" in p.gear else 1)
				valid = not q.is_empty() and q.side!=role() and dist<=radius and (not "barrett" in p.gear or dist==2) and (ability!="cast" or x==p.pos.x or y==p.pos.y)
			elif ability in ["summon","deploy"]: valid=game.empty(pos) and dist<=1
			elif ability=="revive": valid=game.empty(pos) and dist<=2
			elif ability=="warp": valid=game.empty(pos) and dist>5
			if valid: out.append(pos)
	return out

func command(action: Dictionary) -> Dictionary:
	if game==null: return {"ok":false}
	if not can_act():
		if _history_open: _set_hint("You're viewing the past. Return to Live to make your next move.")
		elif _presenting_card: _set_hint("Let the card settle on the table, then make your next move.")
		else: _notify("Wait for your turn.")
		return {"ok":false}
	action.revision = game.revision
	if mode=="online-client":
		network.send(action)
		return {"ok":true}
	return _execute_command(action,role())

func _execute_command(action: Dictionary, actor: int) -> Dictionary:
	var previous_turn = game.turn
	var result = game.apply(action,actor)
	if not result.ok:
		_notify(result.error,true)
		return result
	_selected = -1
	_target = {}
	_positions = []
	_inspected = {}
	if game.turn!=previous_turn: _reset_clock()
	if campaign!=null: campaign.observe(game)
	if game.shop_open and game.discard_due<0: _show_shop()
	elif _overlay_kind in ["shop","forge","discard"]: _close_overlay()
	for event in result.events:
		if event.kind in ["capture","reveal","purchase"]:
			audio.play_sound(event.kind)
			if event.kind=="reveal": _reveal(event)
		elif event.kind=="move": audio.play_sound("move")
	_refresh(result.events)
	if network.active and network.role==0: network.broadcast(result.events)
	_save_game()
	_bot_ready_at = Time.get_ticks_msec()+300
	return result

func _open_overlay(title: String, subtitle: String, kind: String) -> void:
	if is_instance_valid(card_drag): card_drag.cancel()
	if is_instance_valid(hand): hand.interaction_blocked=true
	for effect in get_tree().get_nodes_in_group("discovery_effect"):
		effect.queue_free()
	_clear(overlay)
	_hide_tip()
	_overlay_kind = kind
	var dim = ColorRect.new()
	dim.color = Color(0.025,0.025,0.045,0.92)
	dim.size = Vector2(1600,900)
	overlay.add_child(dim)
	_panel(overlay,Rect2(70,48,1460,802),Color("201e2b"),Color("ad8953"))
	_label(overlay,title,Rect2(110,75,1330,68),43,CourtPalette.PAPER,true)
	_paragraph(overlay,subtitle,Rect2(113,144,1320,62),21,CourtPalette.MUTED)
	_button(overlay,"CLOSE",Rect2(1388,76,100,44),_leave_overlay,"CloseOverlay")

func _close_overlay() -> void:
	if is_instance_valid(hand): hand.interaction_blocked=false
	_clear(overlay)
	_overlay_kind = ""
	_hide_tip()

func _leave_overlay() -> void:
	if _pause_parent:
		_pause_menu()
	elif game!=null and game.shop_open and _overlay_kind in ["shop","forge"]:
		command({"op":"leave"})
	elif game!=null and game.discard_due==role():
		_show_discard()
	else:
		_close_overlay()

func _shop_pressed() -> void:
	if not game.market_unlocked or not can_act(): return
	if options.shop_warning:
		_open_shop()
		return
	if options.shop_double_click and (_shop_click_until<=Time.get_ticks_msec() or _shop_click_revision!=game.revision):
		_shop_click_until=Time.get_ticks_msec()+3500
		_shop_click_revision=game.revision
		var visit=screen.find_child("OpenShop",true,false)
		visit.text="CLICK AGAIN TO OPEN"
		visit.add_theme_font_size_override("font_size",16)
		return
	_shop_click_until=0
	command({"op":"shop"})

func _open_shop() -> void:
	if game.shop_open: _show_shop(); return
	if not can_act() or not game.market_unlocked: return
	var free=game.round_number()%5==0 and game.free_visits[role()]!=game.round_number()
	_open_overlay("","","shop-warning")
	_clear(overlay)
	var dim=ColorRect.new()
	dim.color=Color(0.025,0.025,0.045,0.18)
	dim.size=Vector2(1600,900)
	overlay.add_child(dim)
	_panel(overlay,Rect2(286,429,538,274),CourtPalette.PANEL,Color("8e795c"))
	_label(overlay,"A free browse" if free else "Visiting uses your turn",Rect2(310,448,490,38),26,CourtPalette.PAPER,false,true)
	_paragraph(overlay,"Browsing is free this round. Purchases still end your turn." if free else "Even leaving without buying ends your turn. Every fifth round offers free browsing.",Rect2(310,494,490,68),19,CourtPalette.MUTED)
	var dont_warn=CheckBox.new()
	dont_warn.name="DontWarnAgain"
	dont_warn.text="Don't warn me again"
	dont_warn.position=Vector2(306,568)
	dont_warn.size=Vector2(490,42)
	dont_warn.add_theme_font_size_override("font_size",19)
	overlay.add_child(dont_warn)
	_button(overlay,"STAY",Rect2(310,636,175,42),_close_overlay)
	_button(overlay,"VISIT BAZAAR",Rect2(504,636,295,42),func() -> void:
		if dont_warn.button_pressed:
			options.shop_warning=false
			_save_settings()
		_close_overlay()
		command({"op":"shop"})
	,"ConfirmShopVisit")

func _show_shop(department: String = "bazaar") -> void:
	var subtitle = "$%d in your purse. %s Refresh offers for $25." % [game.players[role()].money,"Browsing is free this round; purchases end your turn." if game.shop_free else "Visiting or buying ends your turn."]
	_open_overlay("THE BAZAAR",subtitle,"shop")
	for i in range(4):
		var tab = ["bazaar","forge","guns","chessnuts"][i]
		_button(overlay,["THE BAZAAR","ROYAL FORGE","GUN COSTCO","CHESSNUT ROOM"][i],Rect2(112+i*334,210,318,45),func() -> void:
			if tab=="forge": _show_forge()
			else: _show_shop(tab)
		)
	var offers = game.stock.duplicate()
	if department=="guns":
		if "membership" not in game.players[role()].traits:
			_paragraph(overlay,"A members-only establishment. Find and activate a Gun Costco Membership to unlock weapons for your pawns.",Rect2(220,360,1160,180),32,CourtPalette.PAPER)
			offers=[]
		else: offers=game.stock.filter(func(id: String) -> bool: return ChessCatalog.entry(id).group=="gun")
	elif department=="chessnuts":
		offers=[]
		if "wizard" in game.players[role()].traits:
			_label(overlay,"YOUR CHESSNUTS: %d"%game.players[role()].chessnuts,Rect2(210,330,1100,70),40,CourtPalette.GOLD,true)
			_button(overlay,"BUY A CHESSNUT  /  $50",Rect2(210,450,560,70),func() -> void: command({"op":"chessnut"}))
			_button(overlay,"MYSTICAL RELIC  /  3 CHESSNUTS",Rect2(810,450,560,70),func() -> void: command({"op":"spell"}))
		else:
			_paragraph(overlay,"The Wizard knows the way in. Find and activate the Wizard relic to receive spell discounts and access to this room.",Rect2(220,360,1160,180),32,CourtPalette.PAPER)
	for i in range(mini(6,offers.size())):
		var id = offers[i]
		var d = ChessCatalog.entry(id).duplicate(true)
		d.cost = game.price(id)
		var card = _card(overlay,d,Rect2(112+(i%3)*454,280+int(i/3)*242,430,222),func() -> void: command({"op":"buy","item":id}),true,i)
		card.disabled = d.cost>game.players[role()].money
	_button(overlay,"REFRESH  /  $25",Rect2(112,782,320,45),func() -> void: command({"op":"reroll"}),"RerollShop")
	_button(overlay,"LEAVE THE BAZAAR",Rect2(1118,782,354,45),func() -> void: command({"op":"leave"}),"LeaveShop")

func _show_forge() -> void:
	_open_overlay("THE ROYAL FORGE","A soldier's upgrade costs $250. Alignation combines two distinct paths for $500. Every purchase ends the turn.","forge")
	var eligible = game.pieces.filter(func(p: Dictionary) -> bool: return p.side==role() and not ChessCatalog.paths(p.type).is_empty())
	if not eligible.is_empty() and game.piece(_forge_selected).is_empty(): _forge_selected=eligible[0].id
	for i in range(_forge_page*8,mini(_forge_page*8+8,eligible.size())):
		var p = eligible[i]
		_button(overlay,ChessCatalog.piece_name(p),Rect2(120,232+(i%8)*58,360,49),func() -> void:
			_forge_selected = p.id
			_show_forge()
		)
	if eligible.size()>8:
		_button(overlay,"NEXT SOLDIERS",Rect2(120,730,360,48),func() -> void:
			_forge_page=(_forge_page+1)%int(ceil(eligible.size()/8.0))
			_show_forge()
		)
	var p = game.piece(_forge_selected)
	if p.is_empty(): return
	_sprite(overlay,p.type,Rect2(530,230,140,140),role())
	_label(overlay,ChessCatalog.piece_name(p),Rect2(700,250,750,70),43,CourtPalette.GOLD,true)
	var descriptions = {"Dragon":"Knight movement plus forward rays up to two squares.","Unicorn":"Leap as a knight, then take an optional extra step.","Necromancer":"Each capture summons two pawns near your back rank.","Divine Cleric":"Cannot capture. Revive fallen allies within two tiles for half cost.","M1 Abrams":"Rook movement plus an adjacent cannon attack.","Golem":"Three-square rook movement. Resists distant direct attacks."}
	for i in range(ChessCatalog.paths(p.type).size()):
		var path = ChessCatalog.paths(p.type)[i]
		_card(overlay,{"id":"upgrade","name":path,"description":descriptions[path],"cost":250,"group":"upgrade"},Rect2(535+i*460,407,430,223),func() -> void: command({"op":"upgrade","id":p.id,"path":path}),true)
	var fusion = ChessCatalog.data().fusions[p.type]
	_button(overlay,"ALIGNATION: "+fusion.to_upper()+"  /  $500",Rect2(535,680,890,65),func() -> void:
		_target={"op":"fuse","type":p.type,"prompt":"an empty back-rank square for "+fusion}
		_close_overlay()
		_refresh()
	)
	_button(overlay,"BACK TO THE BAZAAR",Rect2(1120,780,350,45),_show_shop)

func _show_campaign() -> void:
	if campaign.phase in ["defeat","victory"]:
		_show_victory()
		return
	if campaign.phase=="reward":
		_open_overlay("THE SPOILS OF A BAD IDEA","Your survivors, equipment and treasury carry onward. Choose one reward.","reward")
		for i in range(campaign.rewards.size()):
			var reward = campaign.rewards[i]
			_card(overlay,reward,Rect2(120+i*465,270,430,365),func() -> void:
				if campaign.choose_reward(game,reward.id):
					_save_game()
					_show_campaign()
			,true,i)
	elif campaign.phase=="route":
		_open_overlay("THE ROAD AHEAD","Choose the next encounter. Battles three and six are bosses.","route")
		var routes = [{"id":"supply","name":"The Supply Road","description":"An easier battle. Start with $40 and Glass Armor.","icon":"pack"},{"id":"elite","name":"The Crooked Court","description":"A stronger army, a richer victory. Take the risk.","icon":"king"}]
		if (campaign.floor_number+1)%3==0: routes=[{"id":"boss","name":"The Crown's Guard","description":"A boss stands between you and the next court.","icon":"queen"}]
		for i in range(routes.size()):
			var route = routes[i]
			_card(overlay,route,Rect2(340+i*490,280,450,330),func() -> void:
				game=campaign.next_battle(game,route.id)
				_reset_clock()
				_build_battle()
				_save_game()
			,true,i)

func _show_victory() -> void:
	var won = game.winner==role()
	var title = "THE COURT IS YOURS" if won else "A ROYAL MISFORTUNE"
	if campaign!=null and campaign.phase=="victory": title="THE SHATTERED CROWN IS YOURS"
	_open_overlay(title,"Six battles survived. A crown well earned." if campaign!=null and campaign.phase=="victory" else "Kings fall. Armies decide. There is always another terrible idea.","victory")
	_sprite(overlay,"king" if won else "skull",Rect2(650,250,300,300))
	_button(overlay,"ANOTHER ROUND",Rect2(350,650,430,66),func() -> void: start_game(mode if not mode.begins_with("online") else "solo"))
	_button(overlay,"RETURN TO MENU",Rect2(820,650,430,66),_show_menu)

func _rules() -> void:
	_open_overlay("THE RULES, SUCH AS THEY ARE","A royal strategy game with a deeply unserious attitude.","rules")
	var left = "WIN BY ARMY ELIMINATION\nKings are capturable for $500. Losing a king does not end the game. There is no check or checkmate. Pawns auto-promote.\n\nONE TURN MANY IDEAS\nPlay cards and activate relics before moving. Moving, shooting or buying ends your turn unless an effect grants extra actions.\n\nHIDDEN SURPRISES\nSeven random empty squares hide mysteries at battle start. Discover them by landing there. The first opens the Bazaar; the second unlocks cards. White stars flash green for rewards, red for curses."
	var right = "THE BAZAAR\nVisiting spends your turn, even without buying. Every fifth round has a free browse. Buying still ends your turn. The warning and two-click entry can be changed in Settings.\n\nLIMITED CARDS\nThree marked tiles appear after cards unlock. Land on one to draw a card; it moves elsewhere. There are NO turn-start draws. Robotic Arm doubles a tile draw. Hold extras during your turn, then choose discards down to four. Double-click, drag to PLAY, or pick up with a number key. Lasso binds two opposing pieces.\n\nREPLAY AND VIEW\nChronicle groups actions by turn. Hover previews; click pins. W S choose actions; A D change turns. Coordinates are optional. The board always fits; it expands at round 20 in standard duels."
	_paragraph(overlay,left,Rect2(125,235,630,545),24,CourtPalette.PAPER)
	_paragraph(overlay,right,Rect2(825,235,630,545),23,CourtPalette.PAPER)

func _show_archive() -> void:
	_open_overlay("THE ARCHIVE OF BAD IDEAS","Every card and item has a real effect. Hover an entry for its full description and flavor.","archive")
	var entries = ChessCatalog.data().cards+ChessCatalog.data().items
	var pages = int(ceil(entries.size()/8.0))
	_archive_page = clampi(_archive_page,0,pages-1)
	for i in range(_archive_page*8,mini(_archive_page*8+8,entries.size())):
		var d = entries[i]
		_card(overlay,d,Rect2(112+(i%4)*345,240+(int(i/4)%2)*251,325,230),func() -> void: _show_tip(d),true,i)
	_button(overlay,"PREVIOUS",Rect2(112,780,280,45),func() -> void:
		_archive_page=maxi(0,_archive_page-1)
		_show_archive()
	)
	_label(overlay,"PAGE %d / %d"%[_archive_page+1,pages],Rect2(650,787,350,35),20,CourtPalette.GOLD,false,true)
	_button(overlay,"NEXT",Rect2(1190,780,280,45),func() -> void:
		_archive_page=mini(pages-1,_archive_page+1)
		_show_archive()
	)

func _settings() -> void:
	_compact_overlay("SETTINGS","Preferences are saved on this computer.","settings",Rect2(380,46,840,808))
	var labels={"sound":"SOUND EFFECTS","music":"QUIET COURT MUSIC","reduced_motion":"REDUCED MOTION","auto_flip":"AUTO-FLIP LOCAL TWO-PLAYER","coordinates":"CHESS BOARD COORDINATES","shop_warning":"BAZAAR VISIT WARNING","shop_double_click":"REQUIRE TWO CLICKS FOR BAZAAR"}
	var row=0
	for id in labels:
		_label(overlay,labels[id],Rect2(426,211+row*58,565,43),23,CourtPalette.PAPER,false,true)
		var toggle=_button(overlay,"ON" if options[id] else "OFF",Rect2(1040,211+row*58,112,40),func() -> void:
			options[id]=not options[id]
			audio.configure(options.sound,options.music)
			_save_settings()
			_settings()
		)
		toggle.name="Setting_"+id
		toggle.add_theme_font_size_override("font_size",23)
		row+=1
	_label(overlay,"TURN TIMER",Rect2(426,644,260,43),23,CourtPalette.PAPER,false,true)
	for i in range(4):
		var seconds=[0,30,60,90][i]
		var b=_button(overlay,"OFF" if seconds==0 else str(seconds)+"s",Rect2(756+i*101,644,92,40),func() -> void:
			options.seconds=seconds
			_reset_clock()
			_save_settings()
			_settings()
		)
		if options.seconds==seconds: b.add_theme_stylebox_override("normal",CourtPalette.style(CourtPalette.LIGHT_PANEL,CourtPalette.GOLD))
	_button(overlay,"FULLSCREEN / WINDOWED",Rect2(480,720,640,42),_toggle_fullscreen).add_theme_font_size_override("font_size",24)
	_button(overlay,"BACK",Rect2(650,788,300,40),_leave_overlay,"CloseOverlay").add_theme_font_size_override("font_size",24)

func _network_menu() -> void:
	_open_overlay("A TABLE FOR TWO","Invite a friend to your court. Both players open Schedule 1 Chess. Enter their LAN or Tailscale address to join.","network")
	_label(overlay,"HOST ADDRESS",Rect2(220,280,1100,35),20,CourtPalette.GOLD,false,true)
	_label(overlay,"PORT",Rect2(1120,280,240,35),20,CourtPalette.GOLD,false,true)
	var address = LineEdit.new()
	address.name = "HostAddress"
	address.text = _host_address
	address.position = Vector2(220,330)
	address.size = Vector2(860,58)
	overlay.add_child(address)
	var port = LineEdit.new()
	port.text = str(_port)
	port.position = Vector2(1120,330)
	port.size = Vector2(240,58)
	overlay.add_child(port)
	_button(overlay,"HOST A MATCH",Rect2(220,460,545,74),func() -> void:
		_port = clampi(int(port.text),1024,65535)
		start_game("online-host")
		var error = network.host(game,_port)
		if error!=OK: _notify("Could not host on port %d. It may already be in use."%_port,true)
		_refresh()
	,"HostMatch")
	_button(overlay,"JOIN THE HOST",Rect2(815,460,545,74),func() -> void:
		_host_address=address.text.strip_edges()
		_port=clampi(int(port.text),1024,65535)
		_finish_bot()
		mode="online-client"
		campaign=null
		if network.join(_host_address,_port)!=OK: _notify("Could not begin the connection.",true)
		else: _notify("Connecting to "+_host_address+"...")
	,"JoinMatch")
	_paragraph(overlay,"The host plays Ivory. Your opponent's hand stays private. Rejoin the same host to reconnect.\n\nKeep the host's game open while playing. If you cannot connect, allow Schedule 1 Chess through your firewall on your private network. The default port is 8799 (UDP).",Rect2(220,600,1140,190),24,CourtPalette.MUTED)

func _remote_command(action: Dictionary, sender_role: int) -> void:
	if mode=="online-host":
		var result = _execute_command(action,sender_role)
		if not result.ok: network.broadcast([])

func _receive_state(state: Dictionary, messages: Array) -> void:
	if mode!="online-client": return
	if game==null: game=ChessMatch.new(1,false)
	game.restore(state)
	options.seconds=network.timer_seconds
	_deadline=Time.get_ticks_msec()+network.time_remaining*1000
	_selected=-1
	_target={}
	_positions=[]
	if _menu_open or not is_instance_valid(board): _build_battle()
	else:
		_close_overlay()
		_refresh(messages)

func _reset_clock() -> void:
	_deadline=Time.get_ticks_msec()+float(options.seconds)*1000
	_last_clock=""
	network.timer_seconds=int(options.seconds)
	network.time_remaining=float(options.seconds)

func _process(_delta: float) -> void:
	if _toast_time>0 and Time.get_ticks_msec()>_toast_time:
		toast.text=""
		_toast_time=0
	if _shop_click_until>0 and Time.get_ticks_msec()>_shop_click_until:
		_shop_click_until=0
		var visit=screen.find_child("OpenShop",true,false)
		if visit is Button:
			visit.text="THE BAZAAR"
			visit.add_theme_font_size_override("font_size",20)
	if game==null: return
	if _menu_open:
		if not mode.begins_with("online"): _deadline+=_delta*1000
		return
	_update_hint()
	if not mode.begins_with("online") and (_history_open or _overlay_kind in ["pause","settings","rules","archive","shop-warning"]):
		_deadline+=_delta*1000
		return
	if mode=="online-host":
		network.timer_seconds=int(options.seconds)
		network.time_remaining=maxf(0,(_deadline-Time.get_ticks_msec())/1000.0)
	if is_instance_valid(timer_label):
		var remaining=maxi(0,int(ceil((_deadline-Time.get_ticks_msec())/1000.0)))
		var text="UNTIMED" if options.seconds==0 else "%ds LEFT"%remaining
		if _bot_thread!=null: text="BOT THINKING"
		if text!=_last_clock:
			timer_label.text=text
			_last_clock=text
		if options.seconds>0 and remaining==0 and game.winner==-1 and mode!="online-client":
			var a={"op":"leave" if game.shop_open else "pass","revision":game.revision}
			if game.discard_due>=0:
				a={"op":"discard","indices":range(game.players[game.turn].hand.size()-4),"revision":game.revision}
			_execute_command(a,game.turn)
	if mode in ["solo","campaign"] and game.turn==1 and game.winner==-1 and (campaign==null or campaign.phase=="battle"):
		if _bot_thread==null and Time.get_ticks_msec()>_bot_ready_at and not _presenting_card:
			_bot_revision=game.revision
			var state=game.snapshot(false)
			_bot_thread=Thread.new()
			_bot_thread.start(func() -> Dictionary: return ChessBot.choose(state,difficulty))
		elif _bot_thread!=null and not _bot_thread.is_alive():
			var action=_bot_thread.wait_to_finish()
			_bot_thread=null
			if game.revision==_bot_revision:
				action.revision=game.revision
				var result=_execute_command(action,1)
				if not result.ok: _execute_command({"op":"pass"},1)
			_bot_ready_at=Time.get_ticks_msec()+240

func _finish_bot() -> void:
	if _bot_thread!=null:
		_bot_thread.wait_to_finish()
		_bot_thread=null

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		_finish_bot()
		network.close()
		audio.configure(false,false)
		_shutdown.call_deferred()

func _shutdown() -> void:
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _notify(message: String, error: bool = false) -> void:
	toast.text=message
	_toast_time=Time.get_ticks_msec()+3500
	if error: audio.play_sound("error")

func _reveal(event: Dictionary) -> void:
	var definition=ChessCatalog.entry(event.get("item",""))
	_notify("DISCOVERED: "+definition.get("name",event.text))
	if options.reduced_motion or _overlay_kind!="": return
	var glint=TextureRect.new()
	glint.texture=CourtPixels.texture(event.get("item","star"))
	glint.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	glint.position=Vector2(700,320)
	glint.size=Vector2(200,200)
	glint.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	glint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	glint.z_index=90
	add_child(glint)
	glint.add_to_group("discovery_effect")
	var tween=create_tween()
	tween.tween_property(glint,"position:y",285.0,0.3).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(glint,"modulate:a",0.0,0.5)
	tween.tween_callback(glint.queue_free)

func _save_game() -> void:
	if game==null or mode.begins_with("online"): return
	var data={"version":SAVE_VERSION,"mode":mode,"difficulty":difficulty,"match":game.snapshot(),"campaign":campaign.snapshot() if campaign!=null else {}}
	var file=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(save_path+".tmp",save_path)

func load_game() -> void:
	if not FileAccess.file_exists(save_path): return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version",0)!=SAVE_VERSION or not data.get("match",{}) is Dictionary or not ChessMatch.is_snapshot(data.match):
		_notify("This save could not be read. Your file has been left intact.",true)
		return
	_finish_bot()
	network.close()
	var restored=ChessMatch.new(1,false)
	restored.restore(data.match)
	if not restored.valid():
		_notify("The saved board is invalid. Your file has been left intact.",true)
		return
	game=restored
	mode=data.mode
	difficulty=data.difficulty
	campaign=null
	if not data.campaign.is_empty():
		campaign=ChessCampaign.new()
		campaign.restore(data.campaign)
	_reset_clock()
	_build_battle()

func _load_settings() -> void:
	var config=ConfigFile.new()
	if config.load(settings_path)==OK:
		for id in options: options[id]=config.get_value("court",id,options[id])
		difficulty=config.get_value("court","difficulty","normal")

func _migrate_user_data() -> void:
	var legacy=OS.get_user_data_dir().get_base_dir().path_join("Dream Chess II")
	for filename in ["court-save.json","court-settings.cfg"]:
		var destination=OS.get_user_data_dir().path_join(filename)
		var source=legacy.path_join(filename)
		if not FileAccess.file_exists(destination) and FileAccess.file_exists(source): DirAccess.copy_absolute(source,destination)

func _save_settings() -> void:
	var config=ConfigFile.new()
	for id in options: config.set_value("court",id,options[id])
	config.set_value("court","difficulty",difficulty)
	config.save(settings_path)
	if is_instance_valid(board):
		board.reduced_motion=options.reduced_motion
		board.coordinates=options.coordinates
	if is_instance_valid(hand): hand.reduced_motion=options.reduced_motion
	if is_instance_valid(enemy_hand): enemy_hand.reduced_motion=options.reduced_motion
	var conveyor=screen.find_child("MenuChessConveyor",true,false)
	if conveyor is CourtMenuBoards: conveyor.reduced_motion=options.reduced_motion
	_shop_click_until=0
	var backdrop=get_child(0)
	if backdrop is ColorRect and backdrop.material is ShaderMaterial: backdrop.material.set_shader_parameter("reduced_motion",options.reduced_motion)

func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_F11:
		_toggle_fullscreen()
		return
	if card_drag.active: return
	if event.keycode>=KEY_1 and event.keycode<=KEY_9 and not _menu_open and _overlay_kind=="" and not _history_open:
		_begin_drag(event.keycode-KEY_1,true)
		get_viewport().set_input_as_handled()
		return
	if _history_open:
		match event.keycode:
			KEY_LEFT: _history_panel.seek(_history_index-1)
			KEY_W: _history_panel.action_step(-1)
			KEY_S: _history_panel.action_step(1)
			KEY_A: _history_panel.turn_page(-1)
			KEY_D: _history_panel.turn_page(1)
			KEY_RIGHT: _history_panel.seek(_history_index+1)
			KEY_HOME: _history_panel.seek(0)
			KEY_END: _history_panel.seek(_timeline_entries().size()-1)
			KEY_ESCAPE: _close_history()
		return
	match event.keycode:
		KEY_ESCAPE:
			if _overlay_kind!="": _leave_overlay()
			elif not _target.is_empty():
				_target={}
				_positions=[]
				_refresh()
			elif not _menu_open: _pause_menu()
		KEY_SPACE:
			if not _menu_open and _overlay_kind=="" and can_act(): command({"op":"pass"})
		KEY_F5:
			_save_game()
			_notify("Game saved.")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer=event.position

func _run_smoke() -> void:
	var suite=load("res://tests/ui_smoke.gd").new()
	await suite.run(self)

func _run_network_test() -> void:
	var suite=load("res://tests/app_network_test.gd").new()
	await suite.run(self,"--network-app-host" in _startup_args)


func _mode_title() -> String:
	if campaign!=null: return "THE SHATTERED CROWN  /  BATTLE %d OF 6"%campaign.floor_number
	return {"solo":"DUEL THE COURT  /  "+difficulty.to_upper(),"hotseat":"LOCAL TWO-PLAYER","online-host":"A FRIEND'S TABLE  /  HOST","online-client":"A FRIEND'S TABLE  /  GUEST"}.get(mode,"THE ROYAL COURT")

func _compact_overlay(title: String, subtitle: String, kind: String, rect: Rect2) -> void:
	_open_overlay(title,subtitle,kind)
	_clear(overlay)
	var dim=ColorRect.new()
	dim.color=Color(0.025,0.025,0.04,0.55)
	dim.size=Vector2(1600,900)
	overlay.add_child(dim)
	_panel(overlay,rect,Color("24222c"),CourtPalette.GOLD)
	_panel(overlay,Rect2(rect.position+Vector2(18,18),Vector2(rect.size.x-36,86)),Color("302b31"),Color("806e58"))
	var title_label=_label(overlay,title,Rect2(rect.position+Vector2(35,26),Vector2(rect.size.x-70,58)),45,CourtPalette.PAPER,true)
	title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle_label=_label(overlay,subtitle,Rect2(rect.position+Vector2(30,111),Vector2(rect.size.x-60,30)),18,CourtPalette.MUTED)
	subtitle_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func _resume_game() -> void:
	_close_overlay()
	if game.discard_due==role(): _show_discard()

func _remember_card(index: int, pose: Dictionary = {}) -> void:
	if index<0 or index>=hand.cards.size(): return
	_pending_card_origin={"id":hand.cards[index].definition.id,"pose":CourtCardDrag.pose_of(hand.cards[index]) if pose.is_empty() else pose}

func _begin_drag(index: int, keyboard: bool) -> void:
	if not can_act() or _overlay_kind!="" or not hand.enabled or card_drag.active or index<0 or index>=hand.cards.size(): return
	_target={}
	_selected=-1
	_positions=[]
	_hide_tip()
	card_drag.play_center=board.global_position+board.size/2
	card_drag.reduced_motion=options.reduced_motion
	_drag_game=game
	hand.drag_index=index
	hand.interaction_blocked=true
	card_drag.begin(hand.cards[index],index,game.revision,keyboard,_pointer)
	_update_highlights()

func _drop_card(index: int, pose: Dictionary) -> void:
	if game!=_drag_game or game.revision!=card_drag.revision or not can_act() or _overlay_kind!="" or index<0 or index>=hand.cards.size(): return
	_remember_card(index,pose)
	_arm_use(true,index)

func _show_discard() -> void:
	if game.discard_due!=role(): return
	var held=game.players[role()].hand
	var needed=held.size()-4
	_discard_selected=_discard_selected.filter(func(i: int) -> bool: return i>=0 and i<held.size())
	_discard_page=clampi(_discard_page,0,int((held.size()-1)/6))
	_compact_overlay("KEEP FOUR", "Your turn is ending. Select %d card%s to discard."%[needed,"" if needed==1 else "s"],"discard",Rect2(260,143,1080,614))
	for i in range(_discard_page*6,mini(held.size(),_discard_page*6+6)):
		var button=Button.new()
		button.position=Vector2(316+(i%6)*162,312)
		button.size=Vector2(150,233)
		for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.pressed.connect(func() -> void:
			if i in _discard_selected: _discard_selected.erase(i)
			elif _discard_selected.size()<needed: _discard_selected.append(i)
			_show_discard()
		)
		overlay.add_child(button)
		var card=CourtPlayingCard.new()
		card.definition=ChessCatalog.entry(held[i].id)
		card.size=Vector2(200,310)
		card.scale=Vector2.ONE*0.75
		card.armed=i in _discard_selected
		card.slot_number=i+1
		button.add_child(card)
		card.pivot_offset=Vector2.ZERO
		button.mouse_entered.connect(func() -> void: _show_tip(ChessCatalog.entry(held[i].id)))
		button.mouse_exited.connect(_hide_tip)
	if held.size()>6:
		_button(overlay,"‹",Rect2(305,575,60,40),func() -> void: _discard_page-=1; _show_discard())
		_button(overlay,"›",Rect2(1235,575,60,40),func() -> void: _discard_page+=1; _show_discard())
	_label(overlay,"%d / %d SELECTED"%[_discard_selected.size(),needed],Rect2(620,569,360,33),22,CourtPalette.GOLD)
	var confirm=_button(overlay,"DISCARD & END TURN",Rect2(595,630,410,51),func() -> void:
		var chosen=_discard_selected.duplicate()
		_discard_selected.clear()
		command({"op":"discard","indices":chosen})
	,"ConfirmDiscards")
	confirm.add_theme_font_size_override("font_size",24)
	confirm.disabled=_discard_selected.size()!=needed

func _pause_menu() -> void:
	_pause_parent=false
	if _history_open: _close_history()
	_compact_overlay("GAME PAUSED",_mode_title(),"pause",Rect2(480,101,640,698))
	_label(overlay,"SCHEDULE 1 CHESS",Rect2(520,247,560,36),26,CourtPalette.GOLD,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var names=["RESUME","SETTINGS","HOW TO PLAY","THE ARCHIVE","SAVE GAME","MAIN MENU"]
	var actions=[_resume_game,func() -> void: _settings(); _pause_parent=true,func() -> void: _rules(); _pause_parent=true,func() -> void: _show_archive(); _pause_parent=true,func() -> void: _save_game(); _notify("Game saved."),func() -> void: _save_game(); _show_menu()]
	for i in range(names.size()):
		var b=_button(overlay,names[i],Rect2(615,297+i*62,370,45),actions[i],"ResumeGame" if i==0 else "")
		b.add_theme_font_size_override("font_size",24)
	_label(overlay,"ESC TO RETURN  ·  F11 FULLSCREEN",Rect2(535,705,530,30),18,CourtPalette.MUTED)
	_paragraph(overlay,"The table stays live online." if mode.begins_with("online") else "The clock and bot are paused.",Rect2(535,744,530,30),18,CourtPalette.MUTED)

func _set_hint(value: String, _seconds: float = 3.5) -> void:
	_notify(value)
	toast.add_theme_font_size_override("font_size",18)

func _update_hint() -> void:
	pass # The carousel never yields to context. Gameplay prompts live in Particulars.

func _square_hovered(pos: Vector2i) -> void:
	_board_hover=pos
	if _history_open or _overlay_kind!="" or not _target.is_empty(): return
	_hide_tip()
	if game.tiles.get(ChessMatch.key(pos),{}).get("type","")=="card_draw":
		_inspected={"name":"CARD TILE","icon":"card","description":"Land a piece here to draw a card. This marker immediately moves to another empty square. Robotic Arm draws two instead. No cards are drawn automatically each turn."}
		_show_tip(_inspected)
	else:
		var p=game.at(pos)
		_inspected={"name":ChessCatalog.piece_name(p),"description":_piece_description(p),"icon":p.type} if not p.is_empty() and _selected<0 else {}
	_update_sidebar()

func _timeline_entries() -> Array:
	if not game.history.is_empty(): return game.history
	return [{"label":"Position when this save was opened","actor":game.turn,"ply":game.ply,"state":game.snapshot(false),"notes":["Earlier actions were not recorded in this older save."],"events":[]}]

func _open_history() -> void:
	if _history_open or _overlay_kind!="" or _menu_open: return
	card_drag.cancel()
	_history_open=true
	_history_preview_index=-1
	_history_index=_timeline_entries().size()-1
	_target={}
	_selected=-1
	_hide_tip()
	_clear(sidebar)
	_history_panel=CourtChronicle.new()
	_history_panel.name="ChronicleReplay"
	_history_panel.viewer_side=role()
	sidebar.add_child(_history_panel)
	_history_panel.selected.connect(_seek_history)
	_history_panel.previewed.connect(_preview_history)
	_history_panel.preview_ended.connect(_end_history_preview)
	_history_panel.closed.connect(_close_history)
	_history_panel.show_entries(_timeline_entries(),_history_index)
	_seek_history(_history_index)

func _seek_history(index: int) -> void:
	_hide_tip()
	_history_index=clampi(index,0,_timeline_entries().size()-1)
	_history_preview_index=-1
	_history_panel.show_details(_history_index)
	_display_history(_history_index)

func _preview_history(index: int) -> void:
	if not _history_open: return
	_history_preview_index=index
	_history_panel.show_details(index,true)
	_display_history(index)
	for event in ChessMatch.decode(_timeline_entries()[index].get("events",[])):
		if event.get("kind","")=="card":
			var d=ChessCatalog.entry(event.item).duplicate(true)
			var outcomes: Array=_timeline_entries()[index].get("notes",[]).filter(func(note: String) -> bool: return not note.ends_with("played.") and not note.ends_with("to move."))
			d.description+="\n\nPlayed by %s."%["Ivory" if event.get("side",0)==0 else "Onyx"]
			if not outcomes.is_empty(): d.description+="\n"+str(outcomes[0])
			if outcomes.size()>1: d.description+="\n%d more outcomes in Chronicle details."%(outcomes.size()-1)
			_show_tip(d)
			break

func _end_history_preview() -> void:
	if not _history_open: return
	_history_preview_index=-1
	_hide_tip()
	_history_panel.show_details(_history_index)
	_display_history(_history_index)

func _display_history(index: int) -> void:
	var entries=_timeline_entries()
	_history_view=ChessMatch.new(1,false)
	_history_view.record_history=false
	_history_view.restore(entries[index].state,false)
	var before=ChessMatch.new(1,false)
	before.restore(entries[maxi(0,index-1)].state,false)
	var changed_size=board.game.board_size!=_history_view.board_size
	board.game=_history_view
	board.replay=true
	board.replay_marks.clear()
	for p in before.pieces:
		var after=_history_view.piece(p.id)
		if after.is_empty(): board.replay_marks[p.pos]=CourtPalette.RED
		elif after!=p:
			board.replay_marks[p.pos]=CourtPalette.GOLD
			board.replay_marks[after.pos]=CourtPalette.TEAL
	for p in _history_view.pieces:
		if before.piece(p.id).is_empty(): board.replay_marks[p.pos]=CourtPalette.TEAL
	for key in _history_view.tiles:
		if before.tiles.get(key,{})!=_history_view.tiles[key]: board.replay_marks[ChessMatch.pos_key(key)]=CourtPalette.TEAL
	for key in before.tiles:
		if not _history_view.tiles.has(key): board.replay_marks[ChessMatch.pos_key(key)]=CourtPalette.GOLD
	for key in _history_view.hazards:
		if before.hazards.get(key,{})!=_history_view.hazards[key]: board.replay_marks[ChessMatch.pos_key(key)]=CourtPalette.RED
	for event in _history_view.pending:
		if event not in before.pending:
			for pos in event.get("area",[]): board.replay_marks[pos]=CourtPalette.RED
	for event in ChessMatch.decode(entries[index].get("events",[])):
		for field in ["from","pos"]:
			if event.get(field) is Vector2i: board.replay_marks[event[field]]=CourtPalette.RED if event.get("kind","")=="capture" else CourtPalette.GOLD
	for event in ChessMatch.decode(entries[index].get("events",[])):
		if event.get("kind","")=="capture" and event.get("pos") is Vector2i: board.replay_marks[event.pos]=CourtPalette.RED
	turn_label.text="REPLAY\nROUND %d"%_history_view.round_number()
	money_label.text="$%d"%_history_view.players[role()].money
	enemy_label.text="Enemy treasury\n$%d"%_history_view.players[1-role()].money
	timer_label.text="HOVER PREVIEW" if _history_preview_index>=0 else "PINNED"
	for button_name in ["OpenShop","EndTurn"]:
		var button=screen.find_child(button_name,true,false)
		if button is Button: button.hide()
	board.selected_id=-1
	board.highlighted=[]
	board.target_mode=false
	board.preview_kind=""
	board._moves.clear()
	board._bursts.clear()
	if changed_size: board.fit()
	board.queue_redraw()
	_update_hand()
	_update_hint()

func _close_history() -> void:
	_history_open=false
	_history_index=-1
	_history_preview_index=-1
	_history_view=null
	_shop_click_until=0
	_last_clock=""
	if is_instance_valid(board):
		board.game=game
		board.replay=false
		board.replay_marks.clear()
		board._moves.clear()
		board._bursts.clear()
	_inspected={}
	_refresh()

func _queue_card_presentation(event: Dictionary) -> void:
	var queued=event.duplicate(true)
	if int(event.get("side",-1))==role() and _pending_card_origin.get("id","")==event.item:
		queued.origin_pose=_pending_card_origin.pose
	_pending_card_origin={}
	_card_presentations.append(queued)
	if not _presenting_card: _present_next_card.call_deferred()

func _present_next_card() -> void:
	if _presenting_card or _card_presentations.is_empty() or _menu_open: return
	_presenting_card=true
	var generation=_presentation_generation
	var event=_card_presentations.pop_front()
	var card=CourtPlayingCard.new()
	card.name="PlayedCard"
	card.definition=ChessCatalog.entry(event.item).duplicate(true)
	card.size=Vector2(200,310)
	var from_opponent=int(event.get("side",1-role()))!=role()
	card.position=Vector2(470,-350 if from_opponent else 1000)
	card.rotation=PI if from_opponent else -0.2
	card.z_index=85
	add_child(card)
	card.add_to_group("played_cards")
	_label(card,"%s PLAYS"%("IVORY" if int(event.get("side",0))==0 else "ONYX"),Rect2(0,-35,200,29),18,CourtPalette.GOLD,false,true)
	var destination=board.global_position+board.size/2-card.size/2
	if event.has("origin_pose"): card_drag._set_pose(card,event.origin_pose)
	var tween=create_tween().set_parallel(true)
	var duration=0.08 if options.reduced_motion else 0.34
	tween.tween_property(card,"position",destination,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card,"rotation",0.0,duration)
	tween.chain().tween_interval(0.65)
	tween.chain().tween_property(card,"modulate:a",0.0,0.18)
	await tween.finished
	if generation!=_presentation_generation: return
	card.queue_free()
	_presenting_card=false
	if is_instance_valid(hand) and not _menu_open: _update_hand()
	_present_next_card.call_deferred()

func _cancel_card_presentations() -> void:
	_presentation_generation+=1
	_card_presentations.clear()
	_presenting_card=false
	for card in get_tree().get_nodes_in_group("played_cards"): card.queue_free()
