class_name CourtPalette
extends RefCounted

const INK = Color("141622")
const DEEP = Color("10111a")
const PANEL = Color("212332")
const LIGHT_PANEL = Color("2d3042")
const GOLD = Color("f2c86c")
const PAPER = Color("f8edcc")
const MUTED = Color("c0bdac")
const RED = Color("ed8f81")
const TEAL = Color("80d4bf")
const DISPLAY = preload("res://assets/fonts/Railway1901.otf")
const ACCENT = preload("res://assets/fonts/KrefeldCondensed.otf")
const BODY = preload("res://assets/fonts/Atkinson-Regular.ttf")
const BOLD = preload("res://assets/fonts/Atkinson-Bold.ttf")

static func style(fill: Color = PANEL, edge: Color = Color("5c5360"), radius: int = 9, width: int = 2) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0,0,0,0.24)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0,5)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func theme() -> Theme:
	var result = Theme.new()
	result.default_font = BODY
	result.default_font_size = 22
	result.set_color("font_color","Label",PAPER)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var edge = GOLD if state in ["hover","focus"] else Color("665a59")
		var fill = LIGHT_PANEL if state=="hover" else (Color("38334a") if state=="pressed" else PANEL)
		result.set_stylebox(state,"Button",style(fill,edge,7))
	result.set_font("font","Button",BOLD)
	result.set_font_size("font_size","Button",20)
	result.set_color("font_color","Button",PAPER)
	result.set_color("font_hover_color","Button",GOLD)
	result.set_color("font_pressed_color","Button",GOLD)
	result.set_color("font_disabled_color","Button",Color("827f86"))
	result.set_stylebox("normal","LineEdit",style(DEEP,Color("665a59")))
	result.set_stylebox("focus","LineEdit",style(DEEP,GOLD))
	result.set_color("font_color","LineEdit",PAPER)
	result.set_stylebox("panel","Panel",style())
	return result
