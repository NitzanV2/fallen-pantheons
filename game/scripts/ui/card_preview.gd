extends CanvasLayer
## Enlarged card with its keyword glossary, shown beside whichever compact card the mouse is over.

const CardWidget = preload("res://scripts/ui/card_widget.gd")

const BIG_SIZE := Vector2(300, 450)
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
	owner_control = from
	for child in holder.get_children():
		child.queue_free()
	var card := CardWidget.card_face(card_id, BIG_SIZE, true, false, cost)
	holder.add_child(card)
	var glossary := _glossary(card_id)
	holder.add_child(glossary)

	var view: Vector2 = holder.get_viewport_rect().size
	var rect: Rect2 = from.get_global_rect()
	var width: float = BIG_SIZE.x + (GAP + GLOSSARY_W if glossary.get_child_count() > 0 else 0)
	var x: float = rect.end.x + GAP
	var right_side := x + width <= view.x
	if not right_side:
		x = rect.position.x - GAP - width
	var y: float = clamp(rect.get_center().y - BIG_SIZE.y / 2, 8, view.y - BIG_SIZE.y - 8)
	holder.position = Vector2(max(8, x), y)
	if right_side:
		glossary.position = Vector2(BIG_SIZE.x + GAP, 0)
	else:
		glossary.position = Vector2(0, 0)
		card.position = Vector2(GLOSSARY_W + GAP, 0)
	holder.visible = true


func hide_card(from: Control) -> void:
	if from == owner_control:
		holder.visible = false
		owner_control = null


func _glossary(card_id: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(GLOSSARY_W, 0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in CardWidget.card_icons(card_id):
		var info: Array = CardWidget.KEYWORD_INFO[id]
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
		row.add_child(CardWidget.icon(id, 30))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size = Vector2(GLOSSARY_W - 62, 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_font_size_override("bold_font_size", 14)
		text.text = "[b]%s[/b]\n[color=#c8c8d4]%s[/color]" % info
		row.add_child(text)
		panel.add_child(row)
		box.add_child(panel)
	return box
