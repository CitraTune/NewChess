class_name CourtMenuBoards
extends Control
## Ambient orthodox chess positions, independent from the actual match and RNG.
var boards: Array=[]
var reduced_motion=false
var random=RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	random.seed=41291
	for i in range(10):
		boards.append({"game":_position(),"pos":Vector2((i%5)*385-200,int(i/5)*460-80),"wait":random.randf_range(1,5),"motion":{},"t":1.0})

func _position() -> ChessMatch:
	var game=ChessMatch.new(random.randi(),false)
	game.record_history=false
	for side in range(2):
		game.add_piece("king",side,Vector2i(4,7 if side==0 else 0))
		for i in range(11):
			var pos=Vector2i(random.randi_range(0,7),random.randi_range(1,6))
			if game.empty(pos): game.add_piece(["pawn","pawn","knight","bishop","rook","queen"][random.randi_range(0,5)],side,pos)
	return game

func _process(delta: float) -> void:
	if reduced_motion: return
	for board in boards:
		board.pos.x-=delta*8
		if board.pos.x < -360: board.pos.x+=1925
		board.wait-=delta
		board.t=minf(1,board.t+delta*1.8)
		if board.wait<=0:
			_move(board)
			board.wait=random.randf_range(1.8,4.8)
	queue_redraw()

func _move(board: Dictionary) -> void:
	var game: ChessMatch=board.game
	var candidates: Array=[]
	for p in game.pieces:
		if p.side!=game.turn: continue
		for target in game.legal_moves(p):
			var victim=game.at(target)
			if not victim.is_empty() and victim.type=="king": continue
			var from=p.pos
			game.pieces.erase(victim)
			p.pos=target
			var king=game.pieces.filter(func(q: Dictionary) -> bool: return q.side==game.turn and q.type=="king")[0]
			var attacked=false
			for enemy in game.pieces:
				if enemy.side!=game.turn and king.pos in game.legal_moves(enemy): attacked=true; break
			p.pos=from
			if not victim.is_empty(): game.pieces.append(victim)
			if not attacked: candidates.append({"id":p.id,"from":from,"to":target})
	if candidates.is_empty():
		board.game=_position()
		return
	var move=candidates[random.randi_range(0,candidates.size()-1)]
	var p=game.piece(move.id)
	game.pieces.erase(game.at(move.to))
	p.pos=move.to
	p.moved=true
	if p.type=="pawn" and p.pos.y in [0,7]: p.type="queen"
	game.turn=1-game.turn
	board.motion=move
	board.t=0.0

func _draw() -> void:
	var cell=39.0
	for board in boards:
		var origin: Vector2=board.pos
		for y in range(8):
			for x in range(8):
				draw_rect(Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*cell),Color(0.56,0.55,0.49,0.055 if (x+y)%2==0 else 0.022))
		for p in board.game.pieces:
			var pos=Vector2(p.pos)
			if not board.motion.is_empty() and board.motion.id==p.id: pos=Vector2(board.motion.from).lerp(Vector2(board.motion.to),smoothstep(0,1,board.t))
			draw_texture_rect(CourtPixels.texture(p.type,p.side),Rect2(origin+pos*cell+Vector2.ONE*3,Vector2.ONE*(cell-6)),false,Color(1,1,1,0.12))
