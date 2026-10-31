class_name ChessCatalog
extends RefCounted
## Content is data; prices and descriptions live beside the rules they describe.

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://game/content.json"))
	return _data

static func entry(id: String) -> Dictionary:
	for kind in ["cards", "items"]:
		for definition in data()[kind]:
			if definition.id == id:
				return definition
	return {}

static func value(type: String) -> int:
	return int(data().pieces.get(type, {}).get("value", 50))

static func piece_name(piece: Dictionary) -> String:
	return str(piece.get("fusion", "")) if not str(piece.get("fusion", "")).is_empty() else (str(piece.get("upgrade", "")) if not str(piece.get("upgrade", "")).is_empty() else str(data().pieces.get(piece.get("type", "pawn"), {}).get("name", "Pawn")))

static func card_ids() -> Array:
	return data().cards.map(func(c: Dictionary) -> String: return c.id)

static func paths(type: String) -> Array:
	return data().upgrades.get(type, [])
