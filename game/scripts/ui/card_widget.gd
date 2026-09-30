extends RefCounted
## Shared builders for card, relic, and styled buttons.

const Data = preload("res://scripts/core/data.gd")

const CARD_SIZE := Vector2(160, 240)
const RELIC_SIZE := Vector2(250, 110)
const CARD_ART_TOP := 28
const CARD_ART_BOTTOM := 104
const RELIC_ICON := 78
const RELIC_MARGIN := 0.15
const ART_PATHS := ["res://art/%s/%s.png", "res://art/%s/%s.jpg"]
const CARD_BG := Color(0.14, 0.14, 0.18)
const SELECTED := Color(0.3, 1.0, 0.45)
const FACTION_COLORS := {
	"neutral": Color(0.55, 0.55, 0.6), "norse": Color(0.25, 0.5, 0.85), "greek": Color(0.85, 0.65, 0.15),
	"egypt": Color(0.2, 0.65, 0.45), "token": Color(0.7, 0.7, 0.7), "curse": Color(0.55, 0.2, 0.65), "status": Color(0.45, 0.47, 0.55),
	"divine": Color(0.95, 0.92, 0.75),
}
const RELIC_COLOR := Color(0.6, 0.4, 0.2)
const ENEMY_COLORS := {"enemy": Color(0.55, 0.25, 0.6), "elite": Color(0.8, 0.3, 0.35), "boss": Color(0.9, 0.2, 0.2)}


## Art for a card, enemy, relic, or patron (`kind` is the folder under res://art).
## Draws a tinted placeholder with the name's initials until the image file exists.
static func art(kind: String, id: String, display_name: String, tint: Color, font_size := 28) -> Control:
	for pattern in ART_PATHS:
		var path: String = pattern % [kind, id]
		if ResourceLoader.exists(path):
			var tex := TextureRect.new()
			tex.texture = load(path)
			if kind == "relics":
				var atlas := AtlasTexture.new()
				atlas.atlas = tex.texture
				var size: Vector2 = tex.texture.get_size()
				atlas.region = Rect2(size * RELIC_MARGIN, size * (1.0 - 2.0 * RELIC_MARGIN))
				tex.texture = atlas
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tex
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.darkened(0.6)
	sb.border_color = tint.darkened(0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var initials := ""
	for word in display_name.split(" ", false).slice(0, 2):
		initials += word[0].to_upper()
	var label := Label.new()
	label.text = initials
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint.lightened(0.3))
	panel.add_child(label)
	return panel


## Adds `child` to `parent` filling the rectangle between the given offsets (negative = from the far edge).
static func place(parent: Control, child: Control, left: float, top: float, right: float, bottom: float) -> Control:
	child.anchor_right = 1.0 if right < 0 else 0.0
	child.anchor_bottom = 1.0 if bottom < 0 else 0.0
	child.offset_left = left
	child.offset_top = top
	child.offset_right = right
	child.offset_bottom = bottom
	parent.add_child(child)
	return child


## Breaks text into lines of at most `width` characters. Tooltips never wrap on their own.
static func wrap_text(text: String, width := 60) -> String:
	var out: Array = []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			if line != "" and line.length() + 1 + word.length() > width:
				out.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		out.append(line)
	return "\n".join(out)


static func style(button: Button, bg: Color, border: Color, border_w: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if state == "hover" else bg
		sb.set_border_width_all(border_w)
		sb.border_color = border
		sb.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, sb)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func overlay_label(parent: Control, font_size: int) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = 8
	rtl.offset_top = 6
	rtl.offset_right = -6
	rtl.offset_bottom = -4
	rtl.add_theme_font_size_override("normal_font_size", font_size)
	rtl.add_theme_font_size_override("bold_font_size", font_size + 1)
	parent.add_child(rtl)
	return rtl


## `cost` overrides the printed cost (shown in green) when an effect discounts the card.
static func card_button(card_id: String, selected := false, cost := -1) -> Button:
	var def: Dictionary = Data.CARDS[card_id]
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	style(button, CARD_BG, SELECTED if selected else FACTION_COLORS[def["faction"]], 4 if selected else 2)
	button.tooltip_text = wrap_text("%s\n%s" % [def["name"], def["text"]])
	var tint: Color = FACTION_COLORS[def["faction"]]
	overlay_label(button, 13).text = "[b]%s[/b]" % def["name"]
	place(button, art("cards", card_id, def["name"], tint, 32), 6, CARD_ART_TOP, -6, CARD_ART_BOTTOM)
	var cost_text := "Cost %d" % def["cost"]
	if cost >= 0 and cost < def["cost"]:
		cost_text = "[color=#80ff90]Cost %d[/color]" % cost
	var lines: Array = [
		"[color=#aaaabb]%s - %s %s - %s[/color]" % [cost_text, Data.FACTION_NAMES[def["faction"]], def["type"], def["rarity"]],
	]
	if def["rarity"] == "Divine":
		lines = ["[color=#aaaabb]%s -[/color] [color=#fff0b0]Divine %s[/color]" % [cost_text, def["type"]]]
	if def["type"] == "curse":
		lines = ["[color=#c070e0]Curse - Unplayable[/color]"]
	elif def["type"] == "status":
		lines = ["[color=#9aa0b8]Status - Unplayable[/color]"]
	if def["type"] == "unit":
		lines.append("ATK %d  HP %d  SPD %d" % [def["atk"], def["hp"], def["spd"]])
	lines.append("[color=#d0d0dd]%s[/color]" % def["text"])
	var body := overlay_label(button, 12)
	body.offset_top = CARD_ART_BOTTOM + 2
	body.text = "\n".join(lines)
	return button


static func relic_button(relic_id: String) -> Button:
	var def: Dictionary = Data.RELICS[relic_id]
	var button := Button.new()
	button.custom_minimum_size = RELIC_SIZE
	button.focus_mode = Control.FOCUS_NONE
	style(button, CARD_BG, RELIC_COLOR, 2)
	button.tooltip_text = wrap_text("%s\n%s" % [def["name"], def["text"]])
	place(button, art("relics", relic_id, def["name"], RELIC_COLOR, 26), 8, 8, 8 + RELIC_ICON, 8 + RELIC_ICON)
	var label := overlay_label(button, 12)
	label.offset_left = RELIC_ICON + 16
	label.text = "[b]%s[/b]\n[color=#aaaabb]Relic - %s[/color]\n[color=#d0d0dd]%s[/color]" % [def["name"], def["rarity"], def["text"]]
	return button
