extends CanvasLayer
## Enlarged card with its keyword glossary, shown beside whichever card or board unit the mouse is over.

const CardWidget = preload("res://scripts/ui/card_widget.gd")
const Data = preload("res://scripts/core/data.gd")

const BIG_SIZE := Vector2(300, 450)
## Bosses have long rules text, so their card is shown larger and taller than a card's usual 2:3.
const BOSS_SIZE := Vector2(400, 720)
const GLOSSARY_W := 270
const GAP := 14

var holder: Control
var owner_control: Control


func _ready() -> void:
	layer = 90
	add_to_group("card_preview")
	holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	add_child(holder)


func show_card(card_id: String, from: Control, cost := -1) -> void:
	var face := CardWidget.card_face(card_id, BIG_SIZE, true, false, cost)
	_show(face, _keyword_entries(CardWidget.card_icons(card_id)), from.get_global_rect(), from)


## A unit on the board (a combat snapshot entry, or {} for an empty slot) plus extra glossary
## entries of the form [icon id or "", title, text, title colour].
func show_unit(u: Dictionary, rect: Rect2, from: Control, extras: Array) -> void:
	var face: Control = null
	var entries: Array = []
	var size := BIG_SIZE
	if not u.is_empty():
		if u["side"] == 0:
			face = CardWidget.card_face(u["id"], BIG_SIZE, true)
			entries = _keyword_entries(CardWidget.card_icons(u["id"]))
		else:
			if Data.ENEMIES[u["id"]]["kind"] == "boss":
				size = BOSS_SIZE
			face = CardWidget.enemy_face(u["id"], size)
			entries = _keyword_entries(CardWidget.def_icons(CardWidget.enemy_def(u["id"]), u["id"]))
	entries = extras + entries
	if face == null and entries.is_empty():
		hide_card(from)
		return
	_show(face, entries, rect, from, size)


func hide_card(from: Control) -> void:
	if from == owner_control:
		holder.visible = false
		owner_control = null


func _keyword_entries(icons: Array) -> Array:
	var out: Array = []
	for id in icons:
		out.append([id, CardWidget.KEYWORD_INFO[id][0], CardWidget.KEYWORD_INFO[id][1]])
	return out


func _show(face: Control, entries: Array, rect: Rect2, from: Control, size := BIG_SIZE) -> void:
	owner_control = from
	for child in holder.get_children():
		child.queue_free()
	var card_w: float = size.x + GAP if face != null else 0.0
	if face != null:
		holder.add_child(face)
	var glossary := _glossary(entries)
	holder.add_child(glossary)

	var view: Vector2 = holder.get_viewport_rect().size
	var width: float = card_w + (GLOSSARY_W if not entries.is_empty() else -GAP)
	var x: float = rect.end.x + GAP
	var right_side := x + width <= view.x
	if not right_side:
		x = rect.position.x - GAP - width
	var height: float = size.y if face != null else 200.0
	var y: float = clamp(rect.get_center().y - height / 2, 8, view.y - height - 8)
	holder.position = Vector2(max(8, x), y)
	if right_side:
		glossary.position = Vector2(card_w, 0)
	else:
		glossary.position = Vector2(0, 0)
		if face != null:
			face.position = Vector2(GLOSSARY_W + GAP, 0)
	holder.visible = true


func _glossary(entries: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(GLOSSARY_W, 0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in entries:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.12, 0.96)
		sb.border_color = Color(0.45, 0.47, 0.58)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if entry[0] != "":
			row.add_child(CardWidget.icon(entry[0], 30))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size = Vector2(GLOSSARY_W - (62 if entry[0] != "" else 24), 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_font_size_override("bold_font_size", 14)
		var title_color: Color = entry[3] if entry.size() > 3 else Color.WHITE
		text.text = "[b][color=#%s]%s[/color][/b]\n[color=#c8c8d4]%s[/color]" % [title_color.to_html(false), entry[1], entry[2]]
		row.add_child(text)
		panel.add_child(row)
		box.add_child(panel)
	return box
