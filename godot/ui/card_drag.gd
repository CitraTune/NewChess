class_name CourtCardDrag
extends Control
## One input owner for mouse-held and number-key card pickup.

signal play_requested(index: int, pose: Dictionary)
signal returned
signal pointer_updated(point: Vector2)
var active=false
var snapping=false
var latched=false
var index=-1
var revision=-1
var ghost: CourtPlayingCard
var source: CourtPlayingCard
var play_center=Vector2(599,442)
var return_rect=Rect2(170,740,860,160)
var reduced_motion=false
var _pointer=Vector2.ZERO
var _time=0.0
var _last_pointer=Vector2.ZERO

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=80
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible=false

func begin(card: CourtPlayingCard, card_index: int, current_revision: int, keyboard: bool, pointer: Vector2) -> void:
	if active or snapping: return
	source=card
	index=card_index
	revision=current_revision
	latched=keyboard
	_pointer=pointer
	_last_pointer=pointer
	ghost=CourtPlayingCard.new()
	ghost.name="DraggedCard"
	ghost.definition=card.definition.duplicate(true)
	ghost.size=card.size
	ghost.slot_number=card_index+1
	add_child(ghost)
	ghost.pivot_offset=Vector2(ghost.size.x/2,18)
	var pose=pose_of(card)
	_set_pose(ghost,pose)
	card.hide()
	active=true
	show()
	queue_redraw()

static func pose_of(card: Control) -> Dictionary:
	var transform=card.get_global_transform()
	return {"origin":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"size":card.size}

func _set_pose(card: Control, pose: Dictionary) -> void:
	card.rotation=pose.rotation
	card.scale=pose.get("scale",Vector2.ONE)
	card.position=pose.origin-card.pivot_offset+(card.pivot_offset*card.scale).rotated(card.rotation)

func _input(event: InputEvent) -> void:
	if not active or snapping: return
	if event is InputEventMouseMotion or event is InputEventMouseButton: pointer_updated.emit(event.position)
	if event is InputEventMouseMotion:
		_pointer=event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_pointer=event.position
		if (latched and event.pressed) or (not latched and not event.pressed):
			var accepted=play_hit(_pointer)
			var in_hand=return_rect.has_point(_pointer)
			_finish(accepted)
			if accepted or in_hand or not latched: get_viewport().set_input_as_handled()

func play_hit(point: Vector2) -> bool:
	return Rect2(play_center-Vector2(110,160),Vector2(220,320)).grow(85).has_point(point) and point.y<return_rect.position.y

func cancel() -> void:
	if active and not snapping: _finish(false)

func _process(delta: float) -> void:
	if not active or snapping or not is_instance_valid(ghost): return
	_time+=delta
	var desired=_pointer-ghost.pivot_offset
	var lag=desired-ghost.position
	var blend=1-exp(-delta*(45 if reduced_motion else 25))
	ghost.position=ghost.position.lerp(desired,blend)
	var lean=0.0 if reduced_motion else clampf(-lag.x*0.0018,-0.17,0.17)+sin(_time*8)*minf(0.012,lag.length()*0.00015)
	ghost.rotation=lerp_angle(ghost.rotation,lean,1-exp(-delta*15))
	ghost.scale=ghost.scale.lerp(Vector2.ONE,blend)
	ghost.queue_redraw()
	_last_pointer=_pointer
	queue_redraw()

func _finish(play: bool) -> void:
	if snapping: return
	snapping=true
	var rotation=0.0
	var scale_target=Vector2.ONE
	var destination=play_center-ghost.size/2
	if not play:
		if is_instance_valid(source):
			var pose=pose_of(source)
			rotation=pose.rotation
			scale_target=pose.scale
			destination=pose.origin-ghost.pivot_offset+(ghost.pivot_offset*scale_target).rotated(rotation)
		else: destination=Vector2(play_center.x-100,850)
	var tween=create_tween().set_parallel(true)
	var duration=0.08 if reduced_motion else 0.24
	if not play and is_instance_valid(source):
		var start=pose_of(ghost)
		tween.tween_method(func(t: float) -> void:
			if not is_instance_valid(source): return
			var end=pose_of(source)
			_set_pose(ghost,{"origin":start.origin.lerp(end.origin,t),"rotation":lerp_angle(start.rotation,end.rotation,t),"scale":start.scale.lerp(end.scale,t)})
		,0.0,1.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(ghost,"position",destination,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost,"rotation",rotation,duration)
		tween.tween_property(ghost,"scale",scale_target,duration)
	await tween.finished
	var final_pose=pose_of(ghost)
	active=false
	snapping=false
	if is_instance_valid(source): source.show()
	ghost.queue_free()
	hide()
	if play: play_requested.emit(index,final_pose)
	returned.emit()

func _draw() -> void:
	if not active: return
	var play_rect=Rect2(play_center-Vector2(100,155),Vector2(200,310))
	var hovering=play_hit(_pointer)
	for i in [3,2,1]:
		var glow=CourtPalette.style(Color(0.13,0.44,0.70,0.025),Color(0.38,0.77,1.0,0.10),12+i*3,2)
		glow.shadow_size=0
		draw_style_box(glow,play_rect.grow(i*6))
	var blue=CourtPalette.style(Color(0.13,0.36,0.55,0.25 if hovering else 0.14),Color(0.48,0.80,1.0,0.85),12,2)
	blue.shadow_size=0
	draw_style_box(blue,play_rect)
	draw_string(CourtPalette.BOLD,play_rect.position+Vector2(15,145),"PLAY",HORIZONTAL_ALIGNMENT_CENTER,170,29,Color("b7e2ff"))
	var red_rect=Rect2(Vector2(play_center.x-100,780),Vector2(200,310))
	var red=CourtPalette.style(Color(0.45,0.15,0.19,0.25),Color(0.95,0.48,0.50,0.75),12,2)
	red.shadow_size=0
	draw_style_box(red,red_rect)
	draw_string(CourtPalette.BOLD,red_rect.position+Vector2(8,43),"RETURN TO HAND",HORIZONTAL_ALIGNMENT_CENTER,184,17,Color("f1b2ae"))
