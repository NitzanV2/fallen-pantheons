extends RefCounted
## Shared builders for card, relic, and styled buttons.

const Data = preload("res://scripts/core/data.gd")

const CARD_SIZE := Vector2(160, 240)
const RELIC_SIZE := Vector2(250, 110)
const CARD_ART_TOP := 28
const CARD_ART_BOTTOM := 104
const RELIC_ICON := 78
const ART_PATHS := ["res://art/%s/%s.png", "res://art/%s/%s.jpg"]
const CARD_BG := Color(0.14, 0.14, 0.18)
const SELECTED := Color(0.3, 1.0, 0.45)
const FACTION_COLORS := {
	"neutral": Color(0.55, 0.55, 0.6), "norse": Color(0.25, 0.5, 0.85), "greek": Color(0.85, 0.65, 0.15),
	"egypt": Color(0.2, 0.65, 0.45), "token": Color(0.7, 0.7, 0.7), "curse": Color(0.55, 0.2, 0.65), "status": Color(0.45, 0.47, 0.55),
	"divine": Color(0.95, 0.92, 0.75),
}
const TITLE_FONT = preload("res://fonts/title_font.tres")
const NUMBER_FONT = preload("res://fonts/PressStart2P.ttf")
const RARITY_STYLES := {
	"Starter": {"metal": Color(0.42, 0.43, 0.48), "light": Color(0.68, 0.7, 0.75)},
	"Token": {"metal": Color(0.42, 0.43, 0.48), "light": Color(0.68, 0.7, 0.75)},
	"Common": {"metal": Color(0.6, 0.38, 0.2), "light": Color(0.9, 0.63, 0.38)},
	"Uncommon": {"metal": Color(0.6, 0.65, 0.72), "light": Color(0.93, 0.96, 1.0), "gem": Color(0.25, 0.55, 1.0)},
	"Rare": {"metal": Color(0.8, 0.6, 0.16), "light": Color(1.0, 0.88, 0.45), "gem": Color(0.68, 0.3, 1.0), "glow": Color(1.0, 0.78, 0.25, 0.4)},
	"Divine": {"metal": Color(0.93, 0.88, 0.68), "light": Color(1, 1, 1), "gem": Color(0.55, 0.95, 1.0), "glow": Color(1.0, 0.97, 0.8, 0.45)},
	"Curse": {"metal": Color(0.32, 0.12, 0.4), "light": Color(0.62, 0.3, 0.78), "gem": Color(0.85, 0.15, 0.3)},
	"Status": {"metal": Color(0.3, 0.31, 0.36), "light": Color(0.5, 0.52, 0.58)},
	"enemy": {"metal": Color(0.42, 0.24, 0.52), "light": Color(0.72, 0.5, 0.88)},
	"elite": {"metal": Color(0.68, 0.2, 0.24), "light": Color(1.0, 0.52, 0.5), "gem": Color(1.0, 0.3, 0.3)},
	"boss": {"metal": Color(0.62, 0.08, 0.1), "light": Color(1.0, 0.38, 0.3), "gem": Color(1.0, 0.15, 0.1), "glow": Color(1.0, 0.2, 0.1, 0.4)},
}
const ENEMY_TYPE_LINES := {"enemy": "Void enemy", "elite": "Elite enemy", "boss": "Boss"}
## Icon id -> [display name, rule]. Names are bolded in full card text.
const KEYWORD_INFO := {
	"ranged": ["Ranged", "Can attack from the back row. Can't target units on Ruins."],
	"taunt": ["Taunt", "Enemies attacking from its lane or an adjacent lane must target it."],
	"cleave": ["Cleave", "Also hits the units in the lanes on both sides of the target, in the same row."],
	"pierce": ["Pierce", "Damage beyond what kills the target carries to the unit behind it."],
	"revive": ["Revive", "Once per fight: when it dies, it returns in the same slot with 1 HP."],
	"reinforce": ["Reinforce", "When the ally in front of it dies, it steps into the front slot."],
	"immovable": ["Immovable", "Can't be pushed or swapped and takes no collision damage."],
	"airborne": ["Airborne", "Melee attacks can't target it."],
	"veil": ["Veil", "Ignores the first damage it takes each round."],
	"frenzy": ["Frenzy", "Gains +1 ATK each time it takes damage and survives."],
	"poison": ["Poison", "Units it hits take 1 damage at the end of every round until healed."],
	"spellward": ["Spellward", "Your spells can't target it or the enemies next to it."],
	"thorns": ["Thorns", "Melee units that attack it take damage."],
	"split": ["Split", "When it dies, two smaller copies appear."],
	"shield": ["Shield", "Absorbs damage before HP. Stacks and lasts the whole fight."],
	"on_death": ["On-Death", "Triggers when the unit dies (and when it Revives)."],
	"growth": ["Growth", "End of round: gains the listed stats."],
	"support": ["Support", "Start of round: helps the ally directly in front of it."],
	"rally": ["Rally", "Start of round: its row neighbours gain ATK for the rest of the fight."],
	"summon": ["Summon", "Creates a token in an empty slot. Tokens never join your deck."],
	"exhaust": ["Exhaust", "After you cast it, the card is gone for the rest of this fight."],
	"start_round": ["Start of round", "Triggers at the start of each Resolve phase."],
	"end_round": ["End of round", "Triggers after every unit has attacked."],
	"ability": ["Ability", "Has a special effect - see the card text."],
}
## [icon id, phrases that mark it in card text]. Checked in order after the card's keywords.
const TRIGGERS := [
	["shield", ["Shield"]], ["on_death", ["On-Death"]], ["growth", ["Growth"]], ["support", ["Support"]],
	["rally", ["Rally"]], ["summon", ["Summon"]], ["exhaust", ["Exhaust"]], ["split", ["Split:"]], ["thorns", ["Thorns"]],
	["start_round", ["Start of round", "Start of each round"]], ["end_round", ["End of round", "End of each round"]],
]
const RELIC_COLOR := Color(0.6, 0.4, 0.2)
## Where each boss's face sits in its art (fraction of the image height), so wide crops show it.
const ART_FOCUS := {"void_herald": 0.34, "hel": 0.28, "apep": 0.3}
const ENEMY_COLORS := {"enemy": Color(0.55, 0.25, 0.6), "elite": Color(0.8, 0.3, 0.35), "boss": Color(0.9, 0.2, 0.2)}


## Art for a card, enemy, relic, or patron (`kind` is the folder under res://art).
## Draws a tinted placeholder with the name's initials until the image file exists.
static func art(kind: String, id: String, display_name: String, tint: Color, font_size := 28) -> Control:
	for pattern in ART_PATHS:
		var path: String = pattern % [kind, id]
		if ResourceLoader.exists(path):
			var tex := TextureRect.new()
			tex.texture = load(path)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if kind == "relics" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if kind == "enemies" and ART_FOCUS.has(id):
				focus_art(tex, ART_FOCUS[id])
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


## Crops `tex` around a point `focus_y` (fraction of the image height) instead of the center,
## recomputed whenever it resizes. `zoom` > 1 crops tighter around that point.
static func focus_art(tex: TextureRect, focus_y: float, zoom := 1.0) -> void:
	var source: Texture2D = tex.texture
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2.ZERO, source.get_size())
	tex.texture = atlas
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	var update := func():
		if tex.size.x <= 0 or tex.size.y <= 0:
			return
		var full: Vector2 = source.get_size()
		var aspect: float = tex.size.x / tex.size.y
		var h: float = minf(full.y, full.x / aspect) / zoom
		var w: float = h * aspect
		if w > full.x:
			w = full.x
			h = w / aspect
		var y: float = clampf(full.y * focus_y - h * 0.42, 0.0, full.y - h)
		atlas.region = Rect2((full.x - w) / 2, y, w, h)
	tex.resized.connect(update)
	update.call()


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


## Puts a small icon from art/icons in front of a button's label.
static func button_icon(b: Button, icon: String, width := 22) -> void:
	b.icon = load("res://art/icons/%s.png" % icon)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", width)
	b.add_theme_constant_override("h_separation", 8)


## The shared UI button look: dark with a bronze edge, or gold for the main action on a screen.
static func style_button(b: Button, primary := false, font_size := 14) -> void:
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(6)
		if primary:
			sb.bg_color = {"normal": Color(0.72, 0.52, 0.16), "hover": Color(0.85, 0.63, 0.22), "pressed": Color(0.6, 0.42, 0.12), "disabled": Color(0.25, 0.23, 0.22)}[state]
			sb.border_color = Color(1.0, 0.88, 0.5) if state != "disabled" else Color(0.4, 0.38, 0.36)
			sb.set_border_width_all(2)
			sb.shadow_color = Color(1.0, 0.75, 0.25, 0.35) if state != "disabled" else Color(0, 0, 0, 0)
			sb.shadow_size = 6
		else:
			sb.bg_color = {"normal": Color(0.12, 0.11, 0.17, 0.95), "hover": Color(0.2, 0.18, 0.26, 0.95), "pressed": Color(0.08, 0.08, 0.12), "disabled": Color(0.1, 0.1, 0.13, 0.6)}[state]
			sb.border_color = Color(0.5, 0.44, 0.34, 0.8) if state != "hover" else Color(0.85, 0.7, 0.4)
			sb.set_border_width_all(1)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if primary:
		b.add_theme_font_override("font", TITLE_FONT)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color(0.14, 0.08, 0.02))
		b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.5))
	b.add_theme_font_size_override("font_size", font_size)


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


## A compact card: art, cost, name, stats and keyword icons. Hovering it shows the full card (see card_preview.gd).
## `cost` overrides the printed cost (shown in green) when an effect discounts the card.
static func card_button(card_id: String, selected := false, cost := -1) -> Button:
	var def: Dictionary = Data.CARDS[card_id]
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var face := card_face(card_id, CARD_SIZE, false, selected, cost)
	button.add_child(face)
	button.mouse_entered.connect(func():
		face.position.y = -6
		var preview = _preview()
		if preview:
			preview.show_card(card_id, button, cost))
	button.mouse_exited.connect(func():
		face.position.y = 0
		var preview = _preview()
		if preview:
			preview.hide_card(button))
	button.tree_exiting.connect(func():
		var preview = _preview()
		if preview:
			preview.hide_card(button))
	return button


static func _preview():
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("card_preview") if tree else null


## Draws a card of the given size. `full` adds the type line and the whole rules text (hover preview).
static func card_face(card_id: String, size: Vector2, full: bool, selected := false, cost := -1) -> Control:
	return _face(Data.CARDS[card_id], card_id, "cards", size, full, selected, cost)


## An enemy drawn as a full card, framed by its kind (enemy, elite, boss).
static func enemy_face(enemy_id: String, size: Vector2) -> Control:
	var def: Dictionary = enemy_def(enemy_id)
	return _face(def, enemy_id, "enemies", size, true)


static func enemy_def(enemy_id: String) -> Dictionary:
	var def: Dictionary = Data.ENEMIES[enemy_id].duplicate()
	def["type"] = "enemy"
	def["rarity"] = def["kind"]
	return def


static func _face(def: Dictionary, card_id: String, art_kind: String, size: Vector2, full: bool, selected := false, cost := -1) -> Control:
	var s: float = size.x / CARD_SIZE.x
	var rs: Dictionary = RARITY_STYLES.get(def["rarity"], RARITY_STYLES["Starter"])
	var tint: Color = FACTION_COLORS[def["faction"]] if def.has("faction") else ENEMY_COLORS[def["kind"]]
	var root := Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12)
	sb.set_border_width_all(int(round(4 * s)))
	sb.border_color = SELECTED if selected else rs["metal"]
	sb.set_corner_radius_all(int(round(10 * s)))
	if selected:
		sb.shadow_color = Color(SELECTED, 0.55)
		sb.shadow_size = int(10 * s)
	elif rs.has("glow"):
		sb.shadow_color = rs["glow"]
		sb.shadow_size = int(9 * s)
	else:
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = int(4 * s)
		sb.shadow_offset = Vector2(0, 3 * s)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(root, frame, 0, 0, -0.001, -0.001)
	var inner := Panel.new()
	var isb := StyleBoxFlat.new()
	isb.draw_center = false
	isb.set_border_width_all(max(1, int(s)))
	isb.border_color = Color(rs["light"], 0.55)
	isb.set_corner_radius_all(int(round(7 * s)))
	inner.add_theme_stylebox_override("panel", isb)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: float = 4 * s
	place(root, inner, m, m, -m, -m)

	var text_len: int = def["text"].length()
	var art_bottom: float = (146 if not full else (74 if text_len > 400 else (84 if text_len > 300 else (100 if text_len > 180 else 118)))) * s
	place(root, art(art_kind, card_id, def["name"], tint, int(32 * s)), 8 * s, 8 * s, -8 * s, art_bottom)

	var ribbon := Panel.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = tint.darkened(0.55)
	rsb.border_color = tint.darkened(0.1)
	rsb.set_border_width_all(max(1, int(s)))
	rsb.set_corner_radius_all(int(3 * s))
	ribbon.add_theme_stylebox_override("panel", rsb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(root, ribbon, 6 * s, art_bottom - 4 * s, -6 * s, art_bottom + 20 * s)
	var name_label := _label(def["name"], int((14 if def["name"].length() <= 14 else 12) * s), Color(0.96, 0.94, 0.88), true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	place(ribbon, name_label, 2, 0, -2, -0.001)

	var y: float = art_bottom + 22 * s
	if full:
		var sub := _label(_type_line(def), int(10 * s), Color(0.7, 0.7, 0.78), false)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place(root, sub, 8 * s, y, -8 * s, y + 14 * s)
		y += 15 * s
	if def["type"] in ["unit", "enemy"]:
		var stats := HBoxContainer.new()
		stats.alignment = BoxContainer.ALIGNMENT_CENTER
		stats.add_theme_constant_override("separation", int(8 * s))
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for pair in [["atk", def["atk"]], ["hp", def["hp"]], ["spd", def["spd"]]]:
			stats.add_child(_stat_chip(pair[0], pair[1], 18 * s))
		place(root, stats, 6 * s, y, -6 * s, y + 20 * s)
		y += 23 * s
	elif not full:
		var short := _label(Data.CARD_SHORT.get(card_id, ""), int(11 * s), Color(0.85, 0.85, 0.92), false)
		short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		short.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		short.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		place(root, short, 8 * s, y, -8 * s, y + 30 * s)
		y += 31 * s

	var icons: Array = def_icons(def, card_id)
	if full:
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text_px: float = 6.6 if text_len > 400 else (7.0 if text_len > 300 else (8.0 if text_len > 180 else 9.5))
		text.add_theme_font_size_override("normal_font_size", int(text_px * s))
		text.add_theme_font_size_override("bold_font_size", int(text_px * s))
		text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
		text.text = "[center]%s[/center]" % bold_keywords(def["text"])
		place(root, text, 10 * s, y + 2 * s, -10 * s, -8 * s)
	elif not icons.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(3 * s))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in icons.slice(0, 5):
			row.add_child(icon(id, 22 * s))
		place(root, row, 6 * s, size.y - 32 * s, -6 * s, size.y - 8 * s)

	if def["type"] in ["unit", "spell"]:
		var gem := Panel.new()
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0.1, 0.13, 0.3)
		gsb.border_color = rs["light"]
		gsb.set_border_width_all(max(1, int(2 * s)))
		gsb.set_corner_radius_all(int(15 * s))
		gsb.shadow_color = Color(0, 0, 0, 0.5)
		gsb.shadow_size = int(3 * s)
		gem.add_theme_stylebox_override("panel", gsb)
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.position = Vector2(-3, -3) * s
		gem.size = Vector2(30, 30) * s
		root.add_child(gem)
		var shown: int = cost if cost >= 0 else def["cost"]
		var cost_label := number_label(str(shown), 13 * s, Color(0.5, 1.0, 0.6) if shown < def["cost"] else Color.WHITE)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place(gem, cost_label, 1 * s, 1 * s, -0.001, -0.001)
	if rs.has("gem"):
		var jewel := Panel.new()
		var jsb := StyleBoxFlat.new()
		jsb.bg_color = rs["gem"]
		jsb.border_color = rs["light"]
		jsb.set_border_width_all(max(1, int(s)))
		jsb.set_corner_radius_all(int(2 * s))
		jewel.add_theme_stylebox_override("panel", jsb)
		jewel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g: float = 11 * s
		jewel.size = Vector2(g, g)
		jewel.pivot_offset = Vector2(g, g) / 2
		jewel.rotation = PI / 4
		jewel.position = Vector2(size.x / 2 - g / 2, -g / 2 + 1 * s)
		root.add_child(jewel)
	return root


## "Norse unit - Rare", "Curse - Unplayable", ...
static func type_line(card_id: String) -> String:
	return _type_line(Data.CARDS[card_id])


static func _type_line(def: Dictionary) -> String:
	if def["type"] == "enemy":
		return ENEMY_TYPE_LINES[def["kind"]]
	if def["type"] in ["curse", "status"]:
		return "%s - Unplayable" % def["type"].capitalize()
	if def["rarity"] == "Divine":
		return "Divine %s" % def["type"]
	return "%s %s - %s" % [Data.FACTION_NAMES[def["faction"]], def["type"], def["rarity"]]


## Keyword and trigger icons for a card, in display order.
static func card_icons(card_id: String) -> Array:
	return def_icons(Data.CARDS[card_id], card_id)


## Enemies never get the generic "ability" icon: their preview always shows the full text.
static func def_icons(def: Dictionary, card_id: String) -> Array:
	var out: Array = []
	for kw in def.get("keywords", []):
		if KEYWORD_INFO.has(kw):
			out.append(kw)
	var text: String = def["text"]
	for trigger in TRIGGERS:
		if trigger[0] in out:
			continue
		for phrase in trigger[1]:
			if text.findn(phrase) != -1 or (trigger[0] == "exhaust" and def.get("exhaust", false)):
				out.append(trigger[0])
				break
	if def["type"] == "unit" and out.size() == def.get("keywords", []).size():
		var rest := text
		for kw in def.get("keywords", []):
			rest = rest.replacen(KEYWORD_INFO[kw][0] + ".", "")
		if rest.strip_edges() != "" and card_id != "scarab":
			out.append("ability")
	return out


static func bold_keywords(text: String) -> String:
	for id in KEYWORD_INFO:
		var word: String = KEYWORD_INFO[id][0]
		text = text.replace(word, "[b]%s[/b]" % word)
	return text


static func icon(id: String, px: float) -> TextureRect:
	var tex := TextureRect.new()
	var path := "res://art/icons/%s.png" % id
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	tex.custom_minimum_size = Vector2(px, px)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex


static func _stat_chip(id: String, value: int, px: float) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", int(px * 0.12))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon(id, px))
	chip.add_child(number_label(str(value), px * 0.75, Color.WHITE))
	return chip


## Numbers use a blockier pixel font whose digits stay distinct at small sizes.
static func number_label(text: String, px: float, color: Color) -> Label:
	var l := _label(text, int(px), color, true)
	l.add_theme_font_override("font", NUMBER_FONT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func _label(text: String, font_size: int, color: Color, title: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title:
		l.add_theme_font_override("font", TITLE_FONT)
		l.add_theme_constant_override("outline_size", max(2, font_size / 5))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


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
