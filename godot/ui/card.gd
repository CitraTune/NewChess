class_name CourtCard
extends Button
## Reusable card surface for a hand, Bazaar offer, or expedition reward.

signal inspected(definition: Dictionary)
signal uninspected
var definition: Dictionary = {}
var large = false
var is_hidden = false
var index = -1
var _hover = 0.0
var _time = 0.0
var reduced_motion = false

func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size/2
	add_theme_stylebox_override("normal",CourtPalette.style(Color("e8dcbb"),Color("aa8552"),8,2))
	add_theme_stylebox_override("hover",CourtPalette.style(Color("f6ebca"),CourtPalette.GOLD,8,3))
	add_theme_stylebox_override("pressed",CourtPalette.style(Color("d1bf9b"),CourtPalette.TEAL,8,3))
	add_theme_stylebox_override("focus",CourtPalette.style(Color(0,0,0,0),CourtPalette.GOLD,8,3))
	add_theme_stylebox_override("disabled",CourtPalette.style(Color("a39e95"),Color("797682"),8,2))
	mouse_entered.connect(func() -> void:
		_hover = 1.0
		inspected.emit(definition)
		z_index = 20
	)
	mouse_exited.connect(func() -> void:
		_hover = 0.0
		uninspected.emit()
		z_index = 0
	)
	var title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = true
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title.name = "Title"
	title.text = definition.get("name","Unknown")
	title.position = Vector2(16,82 if large else 61)
	title.size = Vector2(size.x-32,50 if large else 45)
	title.add_theme_font_override("font",CourtPalette.BOLD)
	title.add_theme_font_size_override("font_size",22 if large else 18)
	title.add_theme_color_override("font_color",Color("282536"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size = Vector2(size.x-32,50 if large else 45)
	title.max_lines_visible = 2
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	if large:
		var description = Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.clip_text = true
		description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		description.text = definition.get("description","")
		description.position = Vector2(16,140)
		description.size = Vector2(size.x-32,size.y-150)
		description.add_theme_font_override("font",CourtPalette.BODY)
		description.add_theme_font_size_override("font_size",20)
		description.add_theme_color_override("font_color",Color("393545"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size = Vector2(size.x-32,size.y-150)
		description.max_lines_visible = 4 if size.y>=300 else 3
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description.set_meta("max_width",size.x-32)
		add_child(description)
		description.set_deferred("size",Vector2(size.x-32,size.y-150))
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	var desired = Vector2.ONE*(1.035 if _hover>0 and not disabled and not reduced_motion else 1.0)
	scale = scale.lerp(desired,1-exp(-delta*18))
	rotation = lerpf(rotation,sin(_time*1.1+index)*0.006 if not reduced_motion and not large else 0.0,1-exp(-delta*5))
	queue_redraw()

func _draw() -> void:
	if is_hidden:
		return
	var id = str(definition.get("icon",definition.get("id","card")))
	draw_texture_rect(CourtPixels.texture(id),Rect2(11,5,76 if large else 54,76 if large else 54),false)
	var group = str(definition.get("group","reward")).to_upper()
	draw_string(CourtPalette.BOLD,Vector2(94 if large else 70,27),group,HORIZONTAL_ALIGNMENT_LEFT,size.x-106 if large else size.x-80,14,Color("655744"))
	var cost = int(definition.get("cost",0))
	if cost>0:
		draw_string(CourtPalette.BOLD,Vector2(size.x-90,57 if large else 49),"$%d" % cost,HORIZONTAL_ALIGNMENT_RIGHT,73,24 if large else 20,Color("684529"))
	else:
		draw_line(Vector2(94 if large else 70,42),Vector2(size.x-17,42),Color("bba779"),1)
