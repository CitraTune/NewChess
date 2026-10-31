class_name CourtCardArt
extends RefCounted
## Original 48px pixel illustrations. Each card has its own object, palette and
## small material details; chess-piece silhouettes remain a separate art system.

const IDS=["chacha","grass","greed","frog","rat","union","vest","collector","traffic","gale","blackhole","warp","lasso","skyhook","scissors","dnd","blanket","ticket","scavenge","radio","eject"]
const INK=Color("292536")
const GOLD=Color("e9b85c")
const CREAM=Color("fff0c2")
const STEEL=Color("a8c4d0")
static var cache: Dictionary={}

static func texture(id: String) -> Texture2D:
	if cache.has(id): return cache[id]
	var im=Image.create(48,48,false,Image.FORMAT_RGBA8)
	# Low, broken shadow grounds each illustration without boxing it in.
	oval(im,8,39,33,5,Color(Color("443646"),0.2))
	match id:
		"chacha":
			pawn(im,23,8,Color("f5dcad"))
			poly(im,[Vector2(22,33),Vector2(29,34),Vector2(25,41),Vector2(14,41),Vector2(14,38)],Color("a85650"))
			poly(im,[Vector2(31,31),Vector2(36,33),Vector2(40,40),Vector2(29,40),Vector2(29,37)],Color("744d63"))
			line(im,7,25,18,25,GOLD,2); line(im,7,25,12,20,GOLD,2); line(im,7,25,12,30,GOLD,2)
			line(im,8,11,8,18,Color("74bdb3"),2); box(im,5,17,4,3,Color("74bdb3"))
		"grass":
			poly(im,[Vector2(10,37),Vector2(8,26),Vector2(12,20),Vector2(14,13),Vector2(18,14),Vector2(20,10),Vector2(24,12),Vector2(27,10),Vector2(31,14),Vector2(35,14),Vector2(38,24),Vector2(32,35)],Color("63965c"))
			box(im,12,21,25,9,Color("99bd70")); box(im,17,16,5,7,Color("c0d487")); box(im,24,15,5,8,Color("c0d487")); box(im,31,18,4,7,Color("c0d487"))
			for x in [10,18,29,36]: line(im,x,36,x-3,27,Color("40734f"),2); line(im,x-1,30,x+3,24,Color("82b57c"),2)
			box(im,17,33,14,9,Color("9b794f")); line(im,20,35,28,35,GOLD)
		"greed":
			oval(im,7,17,11,17,GOLD); oval(im,30,17,11,17,GOLD); oval(im,10,20,6,10,INK); oval(im,32,20,6,10,INK)
			poly(im,[Vector2(16,11),Vector2(32,11),Vector2(30,19),Vector2(36,27),Vector2(34,36),Vector2(28,42),Vector2(19,42),Vector2(12,35),Vector2(12,26),Vector2(18,18)],Color("725083"))
			box(im,15,9,19,5,GOLD); oval(im,17,9,15,3,Color("352f48"))
			line(im,17,26,21,24,Color("a9d28b"),2); line(im,27,24,31,26,Color("a9d28b"),2)
			poly(im,[Vector2(17,30),Vector2(31,30),Vector2(28,36),Vector2(21,36)],CREAM)
			for x in [21,26]: line(im,x,30,x,35,Color("7c6080"))
			box(im,19,39,11,2,GOLD); oval(im,21,5,5,4,GOLD); oval(im,29,3,5,4,GOLD)
		"frog":
			oval(im,7,12,12,12,Color("517d4b")); oval(im,29,12,12,12,Color("517d4b"))
			oval(im,8,16,32,20,Color("78ad62")); oval(im,11,12,7,8,CREAM); oval(im,30,12,7,8,CREAM)
			box(im,14,14,3,5,INK); box(im,31,14,3,5,INK); box(im,12,21,3,2,Color("b6d984"))
			line(im,15,27,33,27,Color("36533c")); line(im,18,28,30,28,Color("36533c"))
			poly(im,[Vector2(14,32),Vector2(24,36),Vector2(34,32),Vector2(38,42),Vector2(10,42)],Color("514458"))
			poly(im,[Vector2(19,32),Vector2(24,35),Vector2(29,32),Vector2(27,42),Vector2(22,42)],CREAM)
			box(im,20,33,4,3,Color("bc6662")); box(im,25,33,4,3,Color("bc6662")); box(im,25,39,2,2,GOLD)
			oval(im,5,37,9,5,Color("78ad62")); oval(im,35,37,9,5,Color("78ad62"))
		"rat":
			line(im,29,38,40,39,Color("c99591"),2); line(im,40,39,43,33,Color("c99591"),2)
			oval(im,12,23,22,19,Color("8b8e9b")); oval(im,10,18,10,12,Color("8b8e9b")); oval(im,12,20,6,7,Color("c99591"))
			poly(im,[Vector2(15,25),Vector2(30,24),Vector2(37,31),Vector2(28,36),Vector2(13,34)],Color("b6b6b9"))
			box(im,29,27,2,2,INK); box(im,35,31,3,2,Color("b86f7b")); line(im,31,33,40,35,CREAM); line(im,31,32,41,30,CREAM)
			box(im,13,11,20,13,Color("874658")); box(im,10,22,26,4,Color("b76964")); line(im,15,19,31,19,GOLD,2); box(im,21,14,5,4,GOLD)
		"union":
			box(im,7,8,34,13,Color("a75553")); line(im,10,11,36,11,Color("e1a07a")); line(im,12,15,34,15,CREAM,2)
			for x in [8,21,34]:
				box(im,x,31,7,12,Color("516e70")); box(im,x-2,23,10,11,Color("d8ab7e")); box(im,x-1,20,3,6,Color("efd0a1")); box(im,x+3,20,3,6,Color("efd0a1")); line(im,x+1,28,x+5,28,Color("a77a64"))
			line(im,9,18,9,23,GOLD); line(im,38,18,38,23,GOLD)
		"vest":
			poly(im,[Vector2(11,9),Vector2(19,8),Vector2(24,14),Vector2(29,8),Vector2(37,9),Vector2(35,24),Vector2(40,39),Vector2(9,39),Vector2(13,24)],Color("6d8061"))
			poly(im,[Vector2(19,8),Vector2(24,14),Vector2(29,8),Vector2(27,23),Vector2(21,23)],Color("3d5148"))
			box(im,15,23,19,13,Color("8a9990")); line(im,17,25,31,25,Color("c9d4c3")); line(im,24,24,24,34,Color("5b6e69"))
			for x in [12,35]:
				for y in [12,17,32,36]: box(im,x,y,2,2,GOLD)
			box(im,20,15,8,4,Color("a89b70")); box(im,14,37,21,3,Color("45564b"))
		"collector":
			box(im,9,3,30,41,Color("9dbdc8")); box(im,12,6,24,6,Color("e7d9b7")); line(im,15,8,31,8,Color("8b6e54")); line(im,15,10,24,10,Color("8b6e54"))
			box(im,13,14,22,26,Color("605a8a")); box(im,15,16,18,22,GOLD); box(im,17,18,14,18,Color("85af9c")); pawn(im,24,17,CREAM,0.65)
			line(im,11,15,11,36,Color("dce9de")); line(im,15,41,30,41,Color("dce9de")); star(im,35,35,5,Color("c27b61")); box(im,34,34,2,2,GOLD)
		"traffic":
			box(im,9,5,5,36,Color("657575")); box(im,6,5,12,22,Color("3f454c"))
			for y in [9,15,21]: oval(im,9,y,6,4,Color("e5836b") if y==9 else Color("79664d"))
			box(im,23,16,15,11,Color("c57363")); box(im,20,24,22,8,Color("a75553")); box(im,26,18,9,6,Color("bdd3d3")); box(im,23,31,4,5,INK); box(im,36,31,4,5,INK)
			box(im,14,33,16,8,Color("d2b36e")); box(im,17,30,10,5,Color("d2b36e")); box(im,18,31,7,4,Color("9ebcc2")); box(im,17,40,4,3,INK); box(im,25,40,4,3,INK)
			line(im,32,7,34,11,Color("9ebcc2")); line(im,39,11,41,7,Color("9ebcc2"))
		"gale":
			for offset in [0,8,16]:
				line(im,6,17+offset,31,17+offset,Color("82b7bc"),2); line(im,31,17+offset,37,13+offset,Color("82b7bc"),2); line(im,37,13+offset,36,9+offset,Color("82b7bc"),2); line(im,36,9+offset,31,8+offset,Color("82b7bc"),2)
			poly(im,[Vector2(12,30),Vector2(22,25),Vector2(26,34),Vector2(19,39)],Color("9dbb72")); line(im,15,34,23,29,Color("4d8366"))
			line(im,9,11,19,11,CREAM); star(im,40,35,3,CREAM)
		"blackhole":
			oval(im,6,8,35,33,Color("716485")); oval(im,11,11,27,28,Color("a488b2")); oval(im,14,14,21,23,Color("332d49")); oval(im,18,17,15,17,Color("151b2b"))
			line(im,5,30,39,19,Color("d7ad84"),3); line(im,10,33,43,22,Color("f6d79b"),2); oval(im,18,20,14,11,Color("151b2b")); line(im,11,17,15,12,Color("d2c0d8"),2)
			star(im,8,8,3,CREAM); star(im,39,38,3,CREAM); box(im,40,8,2,2,Color("bdc2d7"))
		"warp":
			oval(im,7,6,34,36,Color("78678f")); oval(im,10,9,28,30,GOLD); oval(im,13,12,22,24,CREAM)
			for pos in [Vector2(24,14),Vector2(32,23),Vector2(24,32),Vector2(15,23)]: box(im,int(pos.x),int(pos.y),2,2,Color("8c7b7d"))
			line(im,24,24,24,16,INK,2); line(im,24,24,18,28,INK,2); box(im,22,23,4,3,Color("a56a69"))
			line(im,8,36,15,42,Color("83bcb6"),3); line(im,15,42,27,42,Color("83bcb6"),3); poly(im,[Vector2(26,37),Vector2(35,42),Vector2(26,46)],Color("83bcb6"))
		"lasso":
			pawn(im,14,15,Color("b6a3c4"),0.85); pawn(im,34,15,Color("b6a3c4"),0.85)
			for width in [3,1]:
				var c=Color("78523e") if width==3 else Color("e5ba7f")
				line(im,5,18,13,10,c,width); line(im,13,10,32,9,c,width); line(im,32,9,42,17,c,width); line(im,42,17,40,30,c,width); line(im,40,30,27,35,c,width); line(im,27,35,9,31,c,width); line(im,9,31,5,18,c,width); line(im,27,35,36,43,c,width); line(im,36,43,43,39,c,width)
			box(im,26,32,5,5,GOLD)
		"skyhook":
			line(im,25,2,25,18,Color("b7c8cc"),2); box(im,21,17,8,6,GOLD)
			line(im,25,23,25,29,STEEL,3); line(im,25,29,19,32,STEEL,3); line(im,19,32,14,28,STEEL,3); line(im,14,28,16,25,STEEL,3)
			pawn(im,33,27,Color("9fa9d1"),0.8); line(im,28,29,34,23,GOLD,2)
			oval(im,4,7,13,6,Color("d3e4e0")); oval(im,10,4,9,10,Color("d3e4e0")); line(im,38,10,38,17,Color("82b7bc"),2); line(im,35,13,38,10,Color("82b7bc"),2)
		"scissors":
			box(im,24,7,17,28,Color("d4c9ad")); box(im,27,10,11,20,Color("b6c1bc")); line(im,29,16,34,16,Color("847d93"),2)
			poly(im,[Vector2(16,27),Vector2(10,6),Vector2(16,9),Vector2(24,28)],STEEL); poly(im,[Vector2(20,27),Vector2(36,9),Vector2(36,16),Vector2(24,31)],Color("e0e5d8"))
			oval(im,5,28,14,14,Color("b85d60")); oval(im,9,32,6,6,Color("4d4454")); oval(im,22,31,14,14,Color("b85d60")); oval(im,26,35,6,6,Color("4d4454")); oval(im,17,26,7,7,GOLD)
		"dnd":
			box(im,15,4,19,38,Color("ae5968")); oval(im,19,7,11,12,INK); box(im,25,11,11,5,INK)
			line(im,18,23,30,23,CREAM,2); line(im,18,28,29,28,CREAM,2); line(im,19,33,27,33,CREAM,2)
			box(im,12,39,25,3,Color("713e56")); oval(im,6,16,8,8,GOLD); oval(im,9,14,7,7,Color("e0b8c2")); star(im,39,11,3,CREAM)
		"blanket":
			pawn(im,24,5,Color("decdad"),0.7)
			poly(im,[Vector2(13,17),Vector2(30,15),Vector2(37,24),Vector2(40,41),Vector2(8,41),Vector2(11,26)],Color("8b759d"))
			for x in [15,25,35]: line(im,x,20,x-3,39,Color("c2a4b5"),2)
			for y in [24,32,39]: line(im,12,y,36,y,Color("5a607e"),2)
			line(im,12,18,10,37,Color("d2b7c4"),2); box(im,15,29,7,5,Color("d0ab8c")); line(im,18,30,18,33,Color("957a78"))
		"ticket":
			box(im,4,12,40,26,Color("e8d4ae")); box(im,7,15,34,20,Color("c0cecd")); box(im,8,17,22,15,Color("f3dfb7"))
			for y in [15,20,25,30,35]: box(im,33,y,1,2,Color("9b8a7f"))
			box(im,12,19,12,8,Color("687982")); box(im,15,16,7,3,Color("687982")); line(im,10,29,26,29,Color("687982"),2); oval(im,12,27,4,4,INK); oval(im,21,27,4,4,INK)
			line(im,37,20,37,29,Color("aa6058"),2); line(im,37,20,40,24,Color("aa6058"),2); box(im,5,24,2,4,Color("e8d4ae")); box(im,41,24,2,4,Color("e8d4ae"))
		"scavenge":
			box(im,10,15,28,25,Color("b99160")); box(im,12,17,24,20,Color("d7b57b")); box(im,22,16,5,23,Color("ede0b2")); line(im,12,26,35,26,Color("947451"))
			box(im,29,28,6,6,Color("a56859")); line(im,30,29,33,29,CREAM); line(im,14,21,19,21,Color("795b4b"))
			line(im,7,11,18,5,Color("6e9b83"),2); line(im,18,5,27,10,Color("6e9b83"),2); line(im,27,10,32,5,Color("6e9b83"),2); line(im,32,5,32,12,Color("6e9b83"),2)
			box(im,5,38,4,5,Color("81975f")); box(im,39,37,3,5,Color("81975f"))
		"radio":
			line(im,32,14,38,3,STEEL,2); box(im,8,15,33,26,Color("755644")); box(im,10,17,29,21,Color("b88a64"))
			box(im,13,19,15,4,Color("b8d1b7")); box(im,23,19,1,4,Color("d1695b")); box(im,12,26,17,10,Color("514b4c"))
			for y in [28,31,34]: line(im,14,y,27,y,Color("9b8d78"))
			oval(im,32,26,5,5,GOLD); oval(im,32,33,5,4,Color("d6c7a1")); line(im,4,9,8,6,Color("74aeb6"),2); line(im,8,6,12,10,Color("74aeb6"),2); line(im,15,10,18,7,Color("d88d7f"),2)
		"eject":
			box(im,13,19,12,18,Color("b35c5c")); box(im,14,34,23,6,Color("b35c5c")); box(im,11,18,4,22,Color("59616e")); box(im,11,39,28,3,Color("59616e"))
			line(im,18,21,21,34,Color("e4ce9d"),2); line(im,24,37,32,37,Color("e4ce9d"),2); box(im,23,32,5,5,GOLD)
			poly(im,[Vector2(23,14),Vector2(29,4),Vector2(35,14),Vector2(31,14),Vector2(31,23),Vector2(27,23),Vector2(27,14)],Color("8cbdc1"))
			for x in [15,21,28,35]: line(im,x,44,x+2,42,Color("dfa66d"),2)
	var result=ImageTexture.create_from_image(im)
	cache[id]=result
	return result

static func box(im: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	im.fill_rect(Rect2i(x-1,y-1,w+2,h+2).intersection(Rect2i(0,0,48,48)),INK)
	im.fill_rect(Rect2i(x,y,w,h).intersection(Rect2i(0,0,48,48)),color)

static func line(im: Image, x1: int, y1: int, x2: int, y2: int, color: Color, width: int = 1) -> void:
	var start=Vector2(x1,y1)
	var finish=Vector2(x2,y2)
	var steps=maxi(1,int(start.distance_to(finish)*2))
	for i in range(steps+1):
		var point=Vector2i(start.lerp(finish,float(i)/steps).round())
		im.fill_rect(Rect2i(point-Vector2i(width/2,width/2),Vector2i.ONE*width).intersection(Rect2i(0,0,48,48)),color)

static func oval(im: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(maxi(0,y-1),mini(48,y+h+1)):
		for px in range(maxi(0,x-1),mini(48,x+w+1)):
			var at=(Vector2(px+0.5,py+0.5)-Vector2(x+w/2.0,y+h/2.0))/Vector2(w/2.0,h/2.0)
			if at.length_squared()<=1: im.set_pixel(px,py,color)
			elif at.length_squared()<1.25: im.set_pixel(px,py,INK)

static func poly(im: Image, points: Array, color: Color) -> void:
	var vertices=PackedVector2Array(points)
	for y in range(48):
		for x in range(48):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),vertices): im.set_pixel(x,y,color)
	for i in range(vertices.size()):
		var a=vertices[i]
		var b=vertices[(i+1)%vertices.size()]
		line(im,int(a.x),int(a.y),int(b.x),int(b.y),INK)

static func pawn(im: Image, x: int, y: int, color: Color, scale_value: float = 1.0) -> void:
	oval(im,x-int(5*scale_value),y,int(10*scale_value),int(10*scale_value),color)
	box(im,x-int(3*scale_value),y+int(9*scale_value),int(6*scale_value),int(9*scale_value),color)
	box(im,x-int(7*scale_value),y+int(18*scale_value),int(14*scale_value),int(4*scale_value),color)

static func star(im: Image, x: int, y: int, radius: int, color: Color) -> void:
	line(im,x-radius,y,x+radius,y,color)
	line(im,x,y-radius,x,y+radius,color)
	box(im,x-1,y-1,3,3,color)
