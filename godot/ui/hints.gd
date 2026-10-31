class_name CourtHints
extends Control
## Uninterrupted idle tips. Only hovering this panel pauses the fuse.

var tips: Array[String]=[
	"Some surprises are hidden. An ordinary square may change the game.",
	"Double-click a card, drag to PLAY, or pick it up with a number key.",
	"Hold extra cards now. Choose discards down to four at turn end.",
	"The Bazaar costs your turn. Every fifth round: free browsing.",
	"Click Chronicle. Hover to preview; click to pin. WASD navigates.",
	"Marked card tiles draw a card when reached, then move somewhere new."
]
var label: Label
var counter: Label
var index=0
var elapsed=0.0
var duration=18.0
var _pointer=Vector2(-1000,-1000)
var hovered=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS
	label=Label.new()
	label.size=Vector2(size.x,79)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.clip_text=true
	label.max_lines_visible=4
	label.add_theme_font_override("font",CourtPalette.BODY)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",CourtPalette.MUTED)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	for direction in [-1,1]:
		var arrow=CourtLink.new()
		arrow.name="PreviousHint" if direction==-1 else "NextHint"
		arrow.text="←" if direction==-1 else "→"
		arrow.position=Vector2(size.x-52 if direction==-1 else size.x-25,size.y-25)
		arrow.size=Vector2(25,24)
		arrow.add_theme_font_size_override("font_size",18)
		arrow.pressed.connect(func() -> void: step(direction))
		add_child(arrow)
	counter=Label.new()
	counter.position=Vector2(0,77)
	counter.size=Vector2(70,22)
	counter.add_theme_font_size_override("font_size",13)
	counter.add_theme_color_override("font_color",Color("807e85"))
	counter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(counter)
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer=get_global_transform().affine_inverse()*event.position

func step(direction: int) -> void:
	index=posmod(index+direction,tips.size())
	elapsed=0
	_refresh()

func _process(delta: float) -> void:
	hovered=Rect2(Vector2.ZERO,size).has_point(_pointer)
	if not hovered:
		elapsed+=delta
		if elapsed>=duration:
			elapsed=0
			index=(index+1)%tips.size()
	_refresh()
	queue_redraw()

func _refresh() -> void:
	if not is_instance_valid(label): return
	label.text=tips[index]
	counter.text="%d / %d"%[index+1,tips.size()]

func _draw() -> void:
	var y=size.y-12
	var length=size.x-64
	draw_line(Vector2(2,y),Vector2(length,y),Color("45434a"),2)
	draw_line(Vector2(2,y),Vector2(2+(length-2)*clampf(elapsed/duration,0,1),y),Color("66636b"),2)
