extends Control
## Pixel chessboard inside a nearly closed, pixel-stepped turn arrow.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for y in range(4):
		for x in range(4):
			draw_rect(Rect2(12+x*6,12+y*6,6,6),CourtPalette.PAPER if (x+y)%2==0 else Color("59635d"))
	var center=Vector2(24,24)
	for i in range(31):
		var angle=-0.8+float(i)/30.0*(TAU-0.45)
		var point=(center+Vector2.from_angle(angle)*22).round()
		draw_rect(Rect2(point-Vector2.ONE,Vector2(3,3)),CourtPalette.GOLD)
	# The head follows the circular tangent and points back toward its own tail.
	draw_colored_polygon(PackedVector2Array([Vector2(31,1),Vector2(45,4),Vector2(37,15),Vector2(37,8),Vector2(31,8)]),CourtPalette.GOLD)
