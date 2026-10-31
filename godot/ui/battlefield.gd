class_name CourtBattlefield
extends Control

signal square_clicked(pos: Vector2i)
signal piece_hovered(piece: Dictionary)
signal square_hovered(pos: Vector2i)
var game: ChessMatch
var selected_id = -1
var highlighted: Array = []
var target_mode = false
var preview_kind = ""
var flipped = false
var coordinates = false
var reduced_motion = false
var busy = false
var replay = false
var economy_visible = false
var inspecting_enemy = false
var replay_marks: Dictionary = {}
var _hover = Vector2i(-1,-1)
var _time = 0.0
var _moves: Dictionary = {}
var _bursts: Array = []

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(func() -> void:
		_hover = Vector2i(-1,-1)
		square_hovered.emit(_hover)
	)

func cell_size() -> float:
	return (size.x-48)/game.board_size if game != null else 70.0

func _offset() -> Vector2:
	return Vector2.ONE*24

func square_center(pos: Vector2i) -> Vector2:
	var visual = Vector2i(game.board_size-1,game.board_size-1)-pos if flipped else pos
	return _offset()+(Vector2(visual)+Vector2.ONE*0.5)*cell_size()

func square_at(local_pos: Vector2) -> Vector2i:
	var value = (local_pos-_offset())/cell_size()
	if value.x<0 or value.y<0 or value.x>=game.board_size or value.y>=game.board_size:
		return Vector2i(-1,-1)
	var pos = Vector2i(value)
	return Vector2i(game.board_size-1,game.board_size-1)-pos if flipped else pos

func fit() -> void:
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseMotion:
		var previous = _hover
		_hover = square_at(event.position)
		if _hover != previous:
			piece_hovered.emit(game.at(_hover))
			square_hovered.emit(_hover)
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var pos = square_at(event.position)
				if game.inside(pos):
					square_clicked.emit(pos)

func play(messages: Array) -> void:
	for event in messages:
		if event.kind in ["move","warp"] and event.has("id") and event.has("from"):
			_moves[int(event.id)] = {"from":event.from,"to":event.pos,"t":0.0}
		if event.kind in ["capture","shield","mystery","card_draw","shot","strike"] and event.has("pos"):
			_bursts.append({"pos":event.pos,"t":-0.14 if event.kind=="mystery" else 0.0,"kind":event.kind,"value":event.get("value",0),"positive":event.get("positive",true),"neutral":event.get("event","") in ["morph","companion"],"seed":absi(ChessMatch.key(event.pos).hash())%997})
		if event.kind=="expansion":
			fit()

func _process(delta: float) -> void:
	_time += delta
	for id in _moves.keys():
		_moves[id].t += delta*(12 if reduced_motion else 4.8)
		if _moves[id].t>=1:
			_moves.erase(id)
	for burst in _bursts:
		burst.t += delta/(1.45 if burst.kind=="mystery" else 0.7)
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return b.t<1)
	busy = not _moves.is_empty()
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	draw_style_box(CourtPalette.style(Color("211e2a"),Color("b59258"),8,3),Rect2(Vector2(3,3),size-Vector2(6,6)))
	var cell = cell_size()
	var parcel_side=-1
	for carrier in game.pieces:
		if carrier.get("parcel_deadline",-1)>game.ply and carrier.side==game.turn:
			parcel_side=carrier.side
			break
	for y in range(game.board_size):
		for x in range(game.board_size):
			var pos = Vector2i(x,y)
			var center = square_center(pos)
			var rect = Rect2(center-Vector2.ONE*cell*0.5,Vector2.ONE*cell)
			var color = Color("666251") if (x+y)%2==0 else Color("3e4544")
			if game.fog and y in [game.board_size/2,game.board_size/2-1]:
				color = color.lerp(Color("776d89"),0.5)
			if pos in [game.last_from,game.last_to]:
				color = color.lerp(CourtPalette.GOLD,0.18)
			if game.hazards.has(ChessMatch.key(pos)):
				color = color.lerp(CourtPalette.RED if game.hazards[ChessMatch.key(pos)].type=="fire" else CourtPalette.TEAL,0.25)
			for delayed in game.pending:
				if delayed.kind=="strike" and pos in delayed.area:
					color = color.lerp(CourtPalette.RED,0.25+sin(_time*3)*0.035)
			if pos == _hover:
				color = color.lightened(0.08)
			if parcel_side>=0 and (y>=game.board_size-2 if parcel_side==0 else y<=1):
				color=color.lerp(CourtPalette.GOLD,0.12)
			if game.inside(_hover):
				var preview=false
				if preview_kind in ["gas","blackhole","helicopter"]: preview=ChessMatch.distance(pos,_hover)<=1
				elif preview_kind=="flare": preview=ChessMatch.distance(pos,_hover)<=2
				elif preview_kind=="lager": preview=pos==_hover or pos in ChessMatch.ORTHO.map(func(d: Vector2i) -> Vector2i: return _hover+d)
				elif preview_kind=="jet": preview=pos.y==_hover.y
				elif preview_kind=="wasps": preview=pos.x==_hover.x
				if preview: color=color.lerp(CourtPalette.RED,0.3)
			draw_rect(rect,color)
			if replay_marks.has(pos):
				var mark: Color=replay_marks[pos]
				draw_rect(rect,Color(mark,0.20))
				draw_rect(rect.grow(-3),Color(mark,0.9),false,2)
			draw_line(rect.position,rect.position+Vector2(cell,0),Color(1,1,1,0.045),1)
			var tile = game.tiles.get(ChessMatch.key(pos),{})
			if tile.get("type","")=="card_draw":
				var card_rect=Rect2(center-Vector2(cell*0.12,cell*0.18),Vector2(cell*0.24,cell*0.36))
				draw_style_box(CourtPalette.style(Color("67868a"),Color("b6cecb"),2,1),card_rect)
				draw_line(center-Vector2(cell*0.06,0),center+Vector2(cell*0.06,0),CourtPalette.PAPER,1)
			elif tile.get("type","")=="banana":
				draw_texture_rect(CourtPixels.texture("coin"),Rect2(center-Vector2.ONE*cell*0.2,Vector2.ONE*cell*0.4),false)
			elif tile.get("type","")=="portal":
				draw_arc(center,cell*0.33,0,TAU,32,CourtPalette.TEAL,3,true)
			elif tile.get("type","")=="sanctuary":
				draw_rect(rect.grow(-3),CourtPalette.PAPER,false,2)
			elif tile.get("type","")=="bees":
				draw_texture_rect(CourtPixels.texture("spider"),Rect2(center-Vector2.ONE*cell*0.2,Vector2.ONE*cell*0.4),false)
			elif tile.get("type","")=="treasure" and tile.get("visible",false):
				draw_line(center-Vector2.ONE*8,center+Vector2.ONE*8,CourtPalette.RED,3)
				draw_line(center+Vector2(-8,8),center+Vector2(8,-8),CourtPalette.RED,3)
			if pos in highlighted:
				if not game.at(pos).is_empty():
					draw_rect(rect.grow(-3),CourtPalette.RED if not target_mode else CourtPalette.TEAL,false,3)
				else:
					draw_circle(center,maxf(4,cell*0.09),CourtPalette.TEAL if target_mode or inspecting_enemy else CourtPalette.GOLD)
	# Discovery particles sit beneath the pieces and stay within half a square.
	for burst in _bursts:
		if burst.kind in ["mystery","card_draw"] and burst.t>=0: _draw_discovery(burst,cell)
	for p in game.pieces:
		var center = square_center(p.pos)
		if _moves.has(int(p.id)):
			var motion = _moves[int(p.id)]
			var t = smoothstep(0,1,motion.t)
			center = square_center(motion.from).lerp(square_center(motion.to),t)-Vector2(0,sin(t*PI)*cell*0.12)
		var sprite_size = floorf(cell*0.88)
		draw_ellipse_shadow(center+Vector2(0,cell*0.24),Vector2(cell*0.31,cell*0.1))
		if p.id==selected_id:
			draw_arc(center,cell*0.43,0,TAU,40,CourtPalette.GOLD,2,true)
		draw_texture_rect(CourtPixels.texture(p.type,p.side),Rect2((center-Vector2.ONE*sprite_size/2).round(),Vector2.ONE*sprite_size),false,Color("a5bcdd") if game.active(p,"frozen") else Color.WHITE)
		if p.upgrade!="" or p.fusion!="":
			draw_texture_rect(CourtPixels.texture("star"),Rect2(center+Vector2(cell*0.16,-cell*0.45),Vector2.ONE*cell*0.28),false)
		if "shield" in p.gear or "magic" in p.gear:
			draw_texture_rect(CourtPixels.texture("shield"),Rect2(center+Vector2(-cell*0.44,cell*0.1),Vector2.ONE*cell*0.34),false,Color("a6dafa") if "magic" in p.gear else Color.WHITE)
		if p.link>=0:
			draw_circle(center+Vector2(cell*0.31,cell*0.28),cell*0.06,CourtPalette.RED)
		if p.get("parcel_deadline",-1)>game.ply:
			var pulse=0.85 if reduced_motion else 0.75+sin(_time*2.1)*0.12
			draw_arc(center,cell*0.40,0,TAU,32,Color(CourtPalette.GOLD,pulse),2,true)
			draw_texture_rect(CourtPixels.texture("coin"),Rect2(center+Vector2(cell*0.16,-cell*0.46),Vector2.ONE*cell*0.32),false)
	for burst in _bursts:
		if burst.kind in ["mystery","card_draw"]: continue
		var center = square_center(burst.pos)
		var t = burst.t
		if burst.value>0 and economy_visible:
			draw_string(CourtPalette.BOLD,center+Vector2(-25,-20-t*35),"+$%d"%burst.value,HORIZONTAL_ALIGNMENT_LEFT,100,22,Color(CourtPalette.GOLD,1-t))
		if not reduced_motion:
			for i in range(8):
				var offset = Vector2.from_angle(i*TAU/8.0)*(12+t*cell*0.5)
				draw_rect(Rect2(center+offset,Vector2.ONE*(4*(1-t)+1)),Color(CourtPalette.RED if burst.kind=="capture" else CourtPalette.GOLD,1-t))
	if replay:
		var font_size=int(size.x*0.19)
		var text_width=CourtPalette.BOLD.get_string_size("REPLAY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(CourtPalette.BOLD,Vector2((size.x-text_width)/2,size.y/2+font_size*0.32),"REPLAY",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(1,1,1,0.14))
	# Coordinate lettering stays in the frame; the game board itself never scrolls a widget.
	if coordinates:
		for i in range(game.board_size):
			var coord = game.board_size-1-i if flipped else i
			var x = 24+(i+0.5)*(size.x-48)/game.board_size
			if game.board_size==8 or i%2==0:
				draw_string(CourtPalette.BOLD,Vector2(x-5,size.y-7),char(97+coord),HORIZONTAL_ALIGNMENT_LEFT,25,15,CourtPalette.MUTED)
				draw_string(CourtPalette.BOLD,Vector2(5,x+5),str(int(game.board_size-coord)),HORIZONTAL_ALIGNMENT_LEFT,22,15,CourtPalette.MUTED)

func _draw_discovery(burst: Dictionary, cell: float) -> void:
	var center=square_center(burst.pos)
	var t=float(burst.t)
	var color=Color.WHITE
	if not burst.neutral: color=color.lerp(Color("75ed98") if burst.positive else Color("ff807a"),clampf((t-0.19)*9,0,1))
	var envelope=sin(minf(1,t*5)*PI/2)*(1-t)
	draw_circle(center,cell*0.44,Color(color,0.25*envelope))
	draw_circle(center,cell*0.32,Color(Color.WHITE,0.14*envelope))
	var count=9 if reduced_motion else 23
	for i in range(count):
		var scatter=fposmod(sin(i*73.17+float(burst.seed))*437.59,1.0)
		var age=clampf((t-scatter*0.12)/(1-scatter*0.12),0,1)
		if age<=0: continue
		var angle=i*2.39996+scatter*1.8
		var radius=cell*(0.30 if reduced_motion else (0.26+pow(age,0.6)*(0.10+scatter*0.05)))
		var point=center+Vector2.from_angle(angle)*radius
		var star=PackedVector2Array()
		var scale_value=cell*(0.04+scatter*0.045)*(1-age*0.65)
		for j in range(10):
			var spin=0.0 if reduced_motion else age*(3.8 if i%2==0 else -4.2)
			star.append(point+Vector2.from_angle(j*TAU/10+angle+spin)*scale_value*(1.0 if j%2==0 else 0.4))
		var opacity=minf(1,age*20)*pow(1-age,0.7)
		draw_circle(point,scale_value*1.5,Color(color,opacity*0.16))
		draw_colored_polygon(star,Color(color,opacity))

func draw_ellipse_shadow(center: Vector2, radius: Vector2) -> void:
	var points = PackedVector2Array()
	for i in range(20):
		points.append(center+Vector2(cos(i*TAU/20.0)*radius.x,sin(i*TAU/20.0)*radius.y))
	draw_colored_polygon(points,Color(0,0,0,0.28))
