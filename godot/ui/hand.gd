class_name CourtHand
extends Control
## One shared hover zone keeps the fan steady as individual cards lift.

signal card_inspected(definition: Dictionary)
signal inspection_ended
signal activate_card(index: int)
signal single_clicked
signal drag_requested(index: int)

var cards: Array[CourtPlayingCard] = []
var opponent = false
var reduced_motion = false
var enabled = true
var armed_index = -1
var expanded = 0.0
var hovered_index = -1
var _signature = ""
var _last_click = -1000
var _last_index = -1
var _time = 0.0
var _pointer=Vector2(-1000,-1000)
var interaction_blocked=false
var drag_index=-1
var _press_index=-1
var _press_global=Vector2.ZERO
var _press_held=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS
	set_process_input(true)

func set_cards(definitions: Array, backs: bool = false, animate_draws: bool = false) -> void:
	opponent=backs
	var signature=JSON.stringify(definitions)+str(backs)
	if signature==_signature: return
	_signature=signature
	var previous=cards.duplicate()
	cards.clear()
	hovered_index=-1
	var arrivals=0
	for d in definitions:
		var key=str(d.get("_hand_key",d.get("id","hidden")))
		var card: CourtPlayingCard
		for old in previous:
			if str(old.get_meta("hand_key",""))==key:
				card=old
				previous.erase(old)
				break
		var is_new=card==null
		if is_new: card=CourtPlayingCard.new()
		card.definition=d
		card.face_down=backs
		card.size=Vector2(200,310)
		card.name="HandCard%d"%cards.size()
		card.slot_number=-1 if backs else cards.size()+1
		card.set_meta("hand_key",key)
		if is_new:
			add_child(card)
			if animate_draws:
				card.arrival=-minf(arrivals*0.08,0.4)
				arrivals+=1
		elif not backs and card.get_child_count()>=3:
			card.get_child(0).text=d.get("name","")
			card.get_child(1).text=d.get("flavor","")
			card.get_child(2).text=d.get("short",d.get("description",""))
		cards.append(card)
		if is_new: _layout_card(cards.size()-1,true)
	for old in previous:
		remove_child(old)
		old.queue_free()
	for i in range(cards.size()): move_child(cards[i],i)

func _has_point(point: Vector2) -> bool:
	return card_at(point)>=0 or (not opponent and not cards.is_empty() and Rect2(0,810,size.x,90).has_point(point))

func card_at(point: Vector2) -> int:
	if hovered_index>=0 and hovered_index<cards.size():
		var hovered=cards[hovered_index]
		if hovered.visible and Rect2(Vector2.ZERO,hovered.size).has_point(hovered.get_transform().affine_inverse()*point): return hovered_index
	for i in range(cards.size()-1,-1,-1):
		if cards[i].visible and Rect2(Vector2.ZERO,cards[i].size).has_point(cards[i].get_transform().affine_inverse()*point): return i
	return -1

func _process(delta: float) -> void:
	_time+=delta
	var point=_pointer
	var hovered=card_at(point) if is_visible_in_tree() and not interaction_blocked else -1
	if hovered!=hovered_index:
		hovered_index=hovered
		if hovered>=0 and not opponent: card_inspected.emit(cards[hovered].definition)
		elif not opponent: inspection_ended.emit()
	var observing=drag_index>=0 or (not interaction_blocked and (hovered>=0 or (not opponent and Rect2(0,810,size.x,90).has_point(point))))
	expanded=move_toward(expanded,1.0 if observing else 0.0,delta*(5.5 if observing else 3.4))
	for i in range(cards.size()):
		cards[i].press_amount=move_toward(cards[i].press_amount,0,delta*5)
		if cards[i].arrival>-1:
			cards[i].arrival+=delta/(0.12 if reduced_motion else 0.65)
			if cards[i].arrival>=1: cards[i].arrival=-1
		_layout_card(i,false,delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer=get_global_transform().affine_inverse()*event.position
	if event is InputEventMouseMotion and _press_held and enabled and not interaction_blocked:
		if event.position.distance_to(_press_global)>11 and _press_index>=0:
			_press_held=false
			_last_index=-1
			drag_requested.emit(_press_index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_press_held=false

func _layout_card(index: int, instant: bool, delta: float = 0.0) -> void:
	var card=cards[index]
	var middle=(cards.size()-1)*0.5
	var offset=index-middle
	var spread=minf(146+expanded*24,880.0/maxf(1,cards.size()-1)) if not opponent else 110.0
	var is_hovered=index==hovered_index
	var angle=offset*0.095
	var target=Vector2(size.x/2-card.size.x/2+offset*spread,835+offset*offset*5)
	if opponent:
		target.y=-249+offset*offset*3+(10 if is_hovered else 0)
		angle=PI-offset*0.09
	else:
		target.y-=expanded*260+(10 if is_hovered else 0)
		if is_hovered: angle*=1-expanded
		if not reduced_motion: angle+=sin(_time*0.85+index)*0.004
		card.armed=index==armed_index
	card.z_index=30 if is_hovered else index
	card.hover_amount=1 if is_hovered else 0
	var target_scale=Vector2.ONE*((1.035 if is_hovered and not opponent else 1.0)-card.press_amount*0.045)
	if card.arrival>-1:
		var progress=clampf(card.arrival,0,1)
		var remaining=pow(1-progress,3)
		target+=Vector2(190,-18)*remaining
		angle+=0.12*remaining
		card.modulate.a=smoothstep(0,0.85,progress)
	else: card.modulate.a=1
	var blend=1.0 if instant or reduced_motion else 1-exp(-delta*15)
	card.position=card.position.lerp(target,blend)
	card.rotation=lerp_angle(card.rotation,angle,blend)
	card.scale=card.scale.lerp(target_scale,blend)
	card.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if interaction_blocked: return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed: return
	var index=card_at(event.position)
	if index<0 or opponent: return
	cards[index].press_amount=1
	card_inspected.emit(cards[index].definition)
	var now=Time.get_ticks_msec()
	if enabled and (event.double_click or (index==_last_index and now-_last_click<350)):
		_last_index=-1
		_last_click=-1000
		activate_card.emit(index)
	else:
		_last_click=now
		_last_index=index
		_press_index=index
		_press_global=get_global_transform()*event.position
		_press_held=enabled and not interaction_blocked
		single_clicked.emit()
	accept_event()
