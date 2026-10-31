class_name CourtLink
extends Button
## Shared visual language for clickable text: hand cursor, fine underline, slight tilt.

var _over=false
var reduced_motion=false

func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	pivot_offset=size/2
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color(0,0,0,0)
		style.content_margin_left=0
		style.content_margin_right=0
		style.content_margin_top=0
		style.content_margin_bottom=0
		add_theme_stylebox_override(state,style)
	mouse_entered.connect(func() -> void: _over=true)
	mouse_exited.connect(func() -> void: _over=false)

func _process(delta: float) -> void:
	var blend=1-exp(-delta*18)
	rotation=lerpf(rotation,-0.018 if _over and not disabled and not reduced_motion else 0.0,blend)
	scale=scale.lerp(Vector2.ONE*(1.012 if _over and not disabled and not reduced_motion else 1.0),blend)
	queue_redraw()

func _draw() -> void:
	if _over and not disabled:
		draw_line(Vector2(5,size.y-2),Vector2(size.x-5,size.y-2),Color(CourtPalette.GOLD,0.45),1)
