class_name CourtChronicle
extends Panel

signal selected(index: int)
signal closed
signal previewed(index: int)
signal preview_ended
var entries: Array=[]
var groups: Array=[]
var cursor=0
var page=0
var viewer_side=0
var money_visible=false
var _title: Label
var _page_label: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _row_buttons: Dictionary={}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	size=Vector2(637,647)
	add_theme_stylebox_override("panel",CourtPalette.style(Color("201e2c"),CourtPalette.GOLD,9,2))
	_label("THE CHRONICLE",Rect2(24,16,490,42),31,CourtPalette.PAPER,true)
	_button("×",Rect2(568,18,45,36),func() -> void: closed.emit())
	_label("Hover previews · click pins · W S actions · A D turns",Rect2(24,62,585,28),18,CourtPalette.MUTED)
	_title=_label("",Rect2(24,102,585,32),22,CourtPalette.GOLD)
	_button("←",Rect2(24,145,46,32),func() -> void: turn_page(-1))
	_page_label=_label("",Rect2(84,148,465,28),17,CourtPalette.MUTED)
	_button("→",Rect2(566,145,46,32),func() -> void: turn_page(1))
	_scroll=ScrollContainer.new()
	_scroll.position=Vector2(24,195)
	_scroll.size=Vector2(589,366)
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_rows=VBoxContainer.new()
	_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation",9)
	_scroll.add_child(_rows)
	_button("BACK TO LIVE",Rect2(208,589,405,40),func() -> void: closed.emit())

func show_entries(value: Array, index: int = -1) -> void:
	entries=value
	groups=[]
	for i in range(entries.size()):
		var entry=entries[i]
		var group_key="start" if i==0 else "%d:%d"%[int(entry.ply),int(entry.actor)]
		if groups.is_empty() or groups[-1].key!=group_key:
			groups.append({"key":group_key,"indices":[],"ply":entry.ply,"actor":entry.actor})
		groups[-1].indices.append(i)
	cursor=entries.size()-1 if index<0 else clampi(index,0,entries.size()-1)
	page=_page_of(cursor)
	_render()

func _page_of(index: int) -> int:
	for i in range(groups.size()):
		if index in groups[i].indices: return i
	return 0

func seek(index: int) -> void:
	cursor=clampi(index,0,entries.size()-1)
	var next_page=_page_of(cursor)
	if next_page!=page:
		page=next_page
		_render()
	else: _highlight()
	show_details(cursor)
	selected.emit(cursor)
	if _row_buttons.has(cursor): _scroll.ensure_control_visible(_row_buttons[cursor])

func turn_page(direction: int) -> void:
	if groups.is_empty(): return
	page=clampi(page+direction,0,groups.size()-1)
	cursor=groups[page].indices[0]
	_render()
	selected.emit(cursor)

func action_step(direction: int) -> void:
	if groups.is_empty(): return
	var indices=groups[page].indices
	var at=indices.find(cursor)
	seek(indices[clampi(at+direction,0,indices.size()-1)])

func action_text(index: int) -> String:
	var entry=entries[index]
	var parts: Array[String]=[visible_note(str(entry.label))]
	var events=ChessMatch.decode(entry.get("events",[]))
	for event in events:
		var text=visible_note(str(event.get("text","")))
		if not money_visible and event.get("kind","")=="capture":
			text=str(event.get("text","")).split(". +$")[0]+("." if str(event.get("text","")).contains(". +$") else "")
		if event.get("kind","")=="turn" or text.ends_with("played.") or event.get("kind","")=="move": continue
		if event.get("kind","")=="mystery":
			parts.append("The Bazaar awakens" if event.get("event","")=="shop" else "Mystery " + str(event.get("event","surprise")).capitalize())
		elif event.get("kind","")=="heist":
			if not money_visible: continue
			var delta=int(event.get("value",0))*(1 if int(event.get("side",0))==viewer_side else -1)
			parts.append("%s$%d"%["+" if delta>=0 else "-",absi(delta)])
		elif text!="" and text not in parts: parts.append(text)
	if events.is_empty():
		for note in entry.get("notes",[]):
			var text=visible_note(str(note))
			if text!="" and not text.ends_with("to move.") and text not in parts: parts.append(text)
	return " · ".join(parts)

func visible_note(text: String) -> String:
	if money_visible: return text
	for word in ["$","money","treasury","bounty","compensated","purse"]:
		if text.to_lower().contains(word): return ""
	return text

func _render() -> void:
	if not is_instance_valid(_rows) or groups.is_empty(): return
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_row_buttons.clear()
	var group=groups[page]
	_page_label.text="%s  ·  %d / %d"%["START" if group.key=="start" else "%s TURN %d"%["IVORY" if group.actor==0 else "ONYX",int(group.ply)/2+1],page+1,groups.size()]
	_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO if group.indices.size()>6 else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	for index in group.indices:
		var button=Button.new()
		button.text=action_text(index)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size=Vector2(565,51)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",17 if button.text.length()>140 else 19)
		_compact(button)
		button.pressed.connect(func() -> void: seek(index))
		button.mouse_entered.connect(func() -> void: previewed.emit(index))
		button.mouse_exited.connect(func() -> void: preview_ended.emit())
		_rows.add_child(button)
		_row_buttons[index]=button
	_highlight()
	show_details(cursor)
	_scroll.set_deferred("scroll_vertical",0)

func _highlight() -> void:
	for index in _row_buttons:
		var button=_row_buttons[index]
		var style=CourtPalette.style(CourtPalette.LIGHT_PANEL if index==cursor else CourtPalette.PANEL,CourtPalette.TEAL if index==cursor else Color("665a59"),5,1)
		style.content_margin_top=7
		style.content_margin_bottom=7
		style.content_margin_left=10
		style.content_margin_right=10
		button.add_theme_stylebox_override("normal",style)

func show_details(index: int, preview: bool = false) -> void:
	if entries.is_empty(): return
	var entry=entries[index]
	_title.text="%s%s · %s"%["PREVIEW / " if preview else "", "START" if index==0 else "TURN %d"%(int(entry.ply)/2+1),"IVORY" if entry.actor==0 else "ONYX"]

func _label(text: String, rect: Rect2, font_size: int, color: Color, display: bool = false) -> Label:
	var label=Label.new()
	label.text=text
	label.position=rect.position
	label.size=rect.size
	label.clip_text=true
	label.add_theme_font_override("font",CourtPalette.DISPLAY if display else CourtPalette.BODY)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text: String, rect: Rect2, callback: Callable) -> void:
	var button=Button.new()
	button.text=text
	button.position=rect.position
	button.size=rect.size
	button.add_theme_font_size_override("font_size",17)
	_compact(button)
	button.pressed.connect(callback)
	add_child(button)

func _compact(button: Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		var box=CourtPalette.style(CourtPalette.LIGHT_PANEL if state=="hover" else CourtPalette.PANEL,CourtPalette.GOLD if state in ["hover","focus"] else Color("665a59"),5,1)
		box.content_margin_top=5
		box.content_margin_bottom=5
		box.content_margin_left=10
		box.content_margin_right=10
		box.shadow_size=0
		button.add_theme_stylebox_override(state,box)
