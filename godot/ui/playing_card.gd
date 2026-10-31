class_name CourtPlayingCard
extends Control
## A portrait card used in the hand and in the played-card presentation.

var definition: Dictionary = {}
var face_down = false
var hover_amount = 0.0
var press_amount = 0.0
var armed = false
var slot_number = -1

static func tint(id: String) -> Color:
	var palettes={"frog":"c8dfa9","grass":"b9d3ab","rat":"dfc29c","lasso":"e7ba9e","greed":"efda9f","collector":"e5ce9a","scavenge":"ead3b0","radio":"bed8e2","blackhole":"cac1df","blanket":"cfbee0","skyhook":"c3dbe1","gale":"bbd5ce","warp":"c3c9e1","ticket":"e1c1b3","vest":"c2d0b5","scissors":"d8d4c3","dnd":"d8bec3","traffic":"e0b8a7","union":"c2d4b0","eject":"b9d2da"}
	return Color(palettes.get(id,"eee1bf"))

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	pivot_offset=size/2
	if face_down: return
	var title_size=22
	_text(definition.get("name","Unknown"),Rect2(15,17,size.x-30,60),title_size,CourtPalette.BOLD,Color("292633"),2)
	_text(definition.get("flavor",""),Rect2(16,161,size.x-32,55),18,CourtPalette.BODY,Color("70583f"),3)
	_text(definition.get("short",definition.get("description","")),Rect2(17,225,size.x-34,size.y-242),15,CourtPalette.BODY,Color("4c4750"),4)

func _text(value: String, rect: Rect2, font_size: int, font: Font, color: Color, lines: int) -> void:
	var label=Label.new()
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.clip_text=true
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible=lines
	label.text=value
	label.position=rect.position
	label.size=rect.size
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.set_meta("max_width",rect.size.x)
	add_child(label)
	label.set_deferred("size",rect.size)

func _draw() -> void:
	var rect=Rect2(Vector2.ZERO,size)
	var edge=CourtPalette.TEAL if armed else CourtPalette.GOLD.lerp(Color("a58a62"),1-hover_amount)
	draw_style_box(CourtPalette.style(tint(str(definition.get("id",""))) if not face_down else Color("423b50"),edge,12,3),rect)
	var inset=CourtPalette.style(Color(0,0,0,0),Color("ba9d6a"),8,1)
	inset.shadow_size=0
	draw_style_box(inset,rect.grow(-9))
	if face_down:
		var center=size/2
		for y in range(5):
			for x in range(3):
				var p=Vector2(32+x*(size.x-64)/2,38+y*(size.y-76)/4)
				var diamond=PackedVector2Array([p+Vector2(0,-9),p+Vector2(7,0),p+Vector2(0,9),p+Vector2(-7,0)])
				draw_colored_polygon(diamond,Color("66576b"))
		draw_circle(center,47,Color("302c3f"))
		draw_arc(center,45,0,TAU,48,Color("b49663"),2,true)
		draw_texture_rect(CourtPixels.texture("queen",0),Rect2(center-Vector2(35,35),Vector2(70,70)),false)
		return
	var id=str(definition.get("id","card"))
	draw_line(Vector2(25,82),Vector2(size.x-25,82),Color("c2aa79"),1)
	draw_texture_rect(CourtPixels.texture(id),Rect2(Vector2(size.x/2-44,83),Vector2(88,80)),false)
	draw_line(Vector2(25,218),Vector2(size.x-25,218),Color("c2aa79"),1)
	draw_circle(Vector2(16,size.y-17),3,Color("9e8056"))
	draw_circle(Vector2(size.x-16,size.y-17),3,Color("9e8056"))
	if slot_number>0:
		draw_string(CourtPalette.BODY,Vector2(13,15),str(slot_number),HORIZONTAL_ALIGNMENT_LEFT,22,12,Color(0.18,0.15,0.18,0.28))
