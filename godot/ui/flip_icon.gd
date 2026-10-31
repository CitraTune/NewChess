extends Control
## Pixel chessboard and a clockwise turn arrow.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for y in range(4):
		for x in range(4):
			draw_rect(Rect2(7+x*7,7+y*7,7,7),CourtPalette.PAPER if (x+y)%2==0 else Color("59635d"))
	draw_arc(Vector2(23,23),21,-0.8,3.5,16,CourtPalette.GOLD,2,false)
	draw_colored_polygon(PackedVector2Array([Vector2(41,5),Vector2(43,16),Vector2(33,11)]),CourtPalette.GOLD)
