extends Control
## Main menu: pick a patron to start a run. The single-battle sandbox sits behind a corner button.

const Data = preload("res://scripts/core/data.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const RunView = preload("res://scripts/ui/run_view.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const PlaytestOverlay = preload("res://scripts/ui/playtest_overlay.gd")
const CardPreview = preload("res://scripts/ui/card_preview.gd")
const Music = preload("res://scripts/ui/music.gd")

const PATRON_TILE := Vector2(360, 524)
const PATRON_ART_BOTTOM := 226
## The background is shifted up so the ghostly gods loom between the logo and the patron panels.
const BG_RECT := Rect2(-60, -125, 1720, 968)
const GOLD := Color(0.95, 0.78, 0.35)
const TITLE_CROP := Rect2(0.02, 0.28, 0.96, 0.48)
const TITLE_HEIGHT := 235
const LIST_GROUPS := {"neutral": "Neutral", "norse": "Norse", "greek": "Greek", "egypt": "Egyptian", "divine": "Divine (shrines only)", "other": "Tokens, curses and statuses"}
const RARITY_ORDER := ["Starter", "Common", "Uncommon", "Rare"]
const PATRON_PROMPT := "The gods are dead. Choose the pantheon whose echoes will defend the Reliquary."
const POWER_TILE := Vector2(420, 540)

var menu: Control
var subtitle: Label
var patron_row: HBoxContainer
var power_row: HBoxContainer
var power_back: Button
var sandbox: Control
var sandbox_button: Button
var card_list: Control = null
var battle_view: Control
var run_view: Control
var deck_option: OptionButton
var seed_box: SpinBox
var event_patron: OptionButton
var power_option: OptionButton
var power_upgraded: CheckBox
var relic_checks := {}
var deck_keys: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fill := ColorRect.new()
	fill.color = Color(0.04, 0.03, 0.07)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fill)
	var bg := TextureRect.new()
	bg.texture = load("res://art/ui/menu_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = BG_RECT.position
	bg.size = BG_RECT.size
	add_child(bg)
	_build_menu()
	_build_sandbox()
	add_child(CardPreview.new())
	add_child(PlaytestOverlay.new())
	Music.play("theme")


## The logo sits on pure black, so additive blending makes its background disappear.
func _title() -> Control:
	for pattern in CardWidget.ART_PATHS:
		var path: String = pattern % ["ui", "title_logo"]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			var size := tex.get_size()
			atlas.region = Rect2(size * TITLE_CROP.position, size * TITLE_CROP.size)
			var logo := TextureRect.new()
			logo.texture = atlas
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			logo.custom_minimum_size = Vector2(0, TITLE_HEIGHT)
			var blend := CanvasItemMaterial.new()
			blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			logo.material = blend
			return logo
	var title := Label.new()
	title.text = "Fallen Pantheons"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	return title


func _build_menu() -> void:
	menu = MarginContainer.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		menu.add_theme_constant_override("margin_" + side, 32)
	add_child(menu)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	menu.add_child(root)

	root.add_child(_title())
	subtitle = CardWidget._label(PATRON_PROMPT, 20, Color(0.82, 0.8, 0.9), true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	patron_row = HBoxContainer.new()
	patron_row.alignment = BoxContainer.ALIGNMENT_CENTER
	patron_row.add_theme_constant_override("separation", 44)
	root.add_child(patron_row)
	for patron in Data.PATRONS:
		patron_row.add_child(_patron_tile(patron))
	power_row = HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_row.add_theme_constant_override("separation", 44)
	power_row.visible = false
	root.add_child(power_row)

	power_back = Button.new()
	power_back.text = "Back to patrons"
	power_back.position = Vector2(24, 24)
	power_back.custom_minimum_size = Vector2(180, 40)
	power_back.pressed.connect(_show_patrons)
	power_back.visible = false
	CardWidget.style_button(power_back, false, 16)
	add_child(power_back)

	sandbox_button = Button.new()
	sandbox_button.text = "Battle sandbox"
	sandbox_button.tooltip_text = "Single test battles with a chosen deck, relics, and seed."
	sandbox_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sandbox_button.position = Vector2(-180, 24)
	sandbox_button.custom_minimum_size = Vector2(156, 36)
	sandbox_button.pressed.connect(_show_sandbox.bind(true))
	CardWidget.style_button(sandbox_button)
	add_child(sandbox_button)

## A patron as an ornate card: art, name, Core HP, starting card, its god powers, and a Choose banner.
func _patron_tile(patron: Dictionary) -> Button:
	var card: Dictionary = Data.CARDS[patron["card"]]
	var faction: String = card["faction"]
	var tint: Color = CardWidget.FACTION_COLORS[faction]
	var metal: Color = tint.lerp(GOLD, 0.35)

	var b := Button.new()
	b.custom_minimum_size = PATRON_TILE
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(_show_powers.bind(patron))
	var face := Control.new()
	face.size = PATRON_TILE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(face)

	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.08, 0.94)
	sb.border_color = metal
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(face, frame, 0, 0, -0.001, -0.001)
	var inner := Panel.new()
	var isb := StyleBoxFlat.new()
	isb.draw_center = false
	isb.set_border_width_all(1)
	isb.border_color = Color(metal.lightened(0.4), 0.5)
	isb.set_corner_radius_all(9)
	inner.add_theme_stylebox_override("panel", isb)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(face, inner, 5, 5, -5, -5)

	var art := CardWidget.art("patrons", faction, Data.FACTION_NAMES[faction], tint, 64)
	CardWidget.place(face, art, 10, 10, -10, PATRON_ART_BOTTOM)

	var ribbon := Panel.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = tint.darkened(0.6)
	rsb.border_color = metal
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(5)
	ribbon.add_theme_stylebox_override("panel", rsb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(face, ribbon, 24, PATRON_ART_BOTTOM - 18, -24, PATRON_ART_BOTTOM + 22)
	var name_label := CardWidget._label(Data.FACTION_NAMES[faction], 30, tint.lightened(0.45), true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CardWidget.place(ribbon, name_label, 0, -2, -0.001, -0.001)

	var y: float = PATRON_ART_BOTTOM + 28
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 8)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := CardWidget._label(Data.FACTION_TITLES[faction], 16, Color(0.75, 0.73, 0.82), false)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(title)
	sub.add_child(CardWidget._label("|", 16, Color(0.4, 0.38, 0.45), false))
	sub.add_child(CardWidget.icon("hp", 20))
	var core := CardWidget._label("Core %d" % patron["hp"], 16, Color(1.0, 0.72, 0.65), false)
	core.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(core)
	CardWidget.place(face, sub, 10, y, -10, y + 24)

	var card_row := _patron_row(CardWidget.art("cards", patron["card"], card["name"], tint, 20),
		"Starting card", card["name"], card["text"], CardWidget.RARITY_STYLES[card["rarity"]]["metal"], 6)
	CardWidget.place(face, card_row, 12, y + 32, -12, y + 108)
	card_row.mouse_entered.connect(func():
		var preview = get_tree().get_first_node_in_group("card_preview")
		if preview:
			preview.show_card(patron["card"], card_row))
	card_row.mouse_exited.connect(func():
		var preview = get_tree().get_first_node_in_group("card_preview")
		if preview:
			preview.hide_card(card_row))
	var powers_row := Panel.new()
	var prsb := StyleBoxFlat.new()
	prsb.bg_color = Color(1, 1, 1, 0.04)
	prsb.set_corner_radius_all(6)
	powers_row.add_theme_stylebox_override("panel", prsb)
	powers_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(face, powers_row, 12, y + 114, -12, y + 190)
	var powers_label := CardWidget._label("God powers (choose one)", 12, Color(0.56, 0.55, 0.63), false)
	CardWidget.place(powers_row, powers_label, 10, 4, -10, 22)
	for i in patron["powers"].size():
		var id: String = patron["powers"][i]
		var x: int = 8 + i * 166
		var disc := CardWidget.power_disc(id, 40)
		disc.position = Vector2(x, 26)
		powers_row.add_child(disc)
		var pname := CardWidget._label(Data.GOD_POWERS[id]["name"], 13, Color(0.92, 0.9, 0.96), false)
		pname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pname.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		CardWidget.place(powers_row, pname, x + 46, 22, x + 162, 72)

	var banner := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.72, 0.52, 0.16)
	bsb.border_color = Color(1.0, 0.88, 0.5)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(6)
	banner.add_theme_stylebox_override("panel", bsb)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(face, banner, 60, PATRON_TILE.y - 46, -60, PATRON_TILE.y - 12)
	var begin := CardWidget._label("CHOOSE", 22, Color(0.14, 0.08, 0.02), false)
	begin.add_theme_font_override("font", CardWidget.TITLE_FONT)
	begin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	begin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CardWidget.place(banner, begin, 0, -2, -0.001, -0.001)

	b.mouse_entered.connect(func():
		face.position.y = -8
		sb.shadow_color = Color(tint.lightened(0.2), 0.55)
		sb.shadow_size = 22
		sb.shadow_offset = Vector2.ZERO
		bsb.bg_color = Color(0.88, 0.66, 0.24))
	b.mouse_exited.connect(func():
		face.position.y = 0
		sb.shadow_color = Color(0, 0, 0, 0.6)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 5)
		bsb.bg_color = Color(0.72, 0.52, 0.16))
	return b


## Step two of a new run: the chosen patron's god powers.
func _show_powers(patron: Dictionary) -> void:
	for child in power_row.get_children():
		child.queue_free()
	for id in patron["powers"]:
		power_row.add_child(_power_tile(patron, id))
	var faction: String = Data.CARDS[patron["card"]]["faction"]
	subtitle.text = "Choose the %s god power you will carry into every fight." % Data.FACTION_NAMES[faction]
	patron_row.visible = false
	power_row.visible = true
	power_back.visible = true
	sandbox_button.visible = false
	power_row.modulate.a = 0.0
	power_row.create_tween().tween_property(power_row, "modulate:a", 1.0, 0.25)


func _show_patrons() -> void:
	subtitle.text = PATRON_PROMPT
	patron_row.visible = true
	power_row.visible = false
	power_back.visible = false
	sandbox_button.visible = true


## A god power as a glass tile: emblem, name, base effect, the upgrade tree, and a Begin banner.
func _power_tile(patron: Dictionary, id: String) -> Button:
	var power: Dictionary = Data.GOD_POWERS[id]
	var tint: Color = CardWidget.FACTION_COLORS[power["pantheon"]].lightened(0.2)
	var b := Button.new()
	b.custom_minimum_size = POWER_TILE
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(_start_run.bind(patron["card"], id))
	var panel := Panel.new()
	var sb := CardWidget.glass_style(18, 0)
	sb.bg_color = Color(0.05, 0.045, 0.085, 0.92)
	sb.border_color = Color(tint, 0.35)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(b, panel, 0, 0, -0.001, -0.001)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(panel, box, 26, 22, -26, -70)
	var disc := CardWidget.power_disc(id, 96, true)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(disc)
	var title := CardWidget.heading(power["name"], 26, tint.lightened(0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := CardWidget._label("Free, during planning. Recharges for %d floors after use" % Data.POWER_COOLDOWN_FLOORS, 13, Color(0.62, 0.6, 0.7), false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var text := CardWidget._label(power["text"], 16, Color(0.92, 0.9, 0.86), false)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var tree_title := CardWidget.heading("Upgrade tree", 15, GOLD)
	box.add_child(tree_title)
	var tree := RichTextLabel.new()
	tree.bbcode_enabled = true
	tree.fit_content = true
	tree.scroll_active = false
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.add_theme_font_size_override("normal_font_size", 13)
	tree.add_theme_font_size_override("bold_font_size", 13)
	tree.text = _tree_summary(power, Data.FACTION_NAMES[power["pantheon"]])
	box.add_child(tree)

	var banner := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.8, 0.6, 0.24)
	bsb.border_color = Color(1.0, 0.9, 0.62, 0.9)
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(8)
	banner.add_theme_stylebox_override("panel", bsb)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(panel, banner, 90, POWER_TILE.y - 54, -90, POWER_TILE.y - 16)
	var begin := CardWidget.heading("BEGIN RUN", 18, Color(0.14, 0.08, 0.02))
	begin.remove_theme_color_override("font_shadow_color")
	begin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	begin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CardWidget.place(banner, begin, 0, 0, -0.001, -0.001)

	b.mouse_entered.connect(func():
		sb.border_color = Color(tint, 0.85)
		sb.shadow_color = Color(tint, 0.35)
		bsb.bg_color = Color(0.9, 0.7, 0.32))
	b.mouse_exited.connect(func():
		sb.border_color = Color(tint, 0.35)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		bsb.bg_color = Color(0.8, 0.6, 0.24))
	CardWidget._hover_motion(b, 1.02)
	return b


## One line per branch: "Chain: Forked Bolt > Storm Chain", plus how upgrades are earned.
static func _tree_summary(power: Dictionary, pantheon_name: String) -> String:
	var branches := {}
	for n in power["nodes"]:
		var node: Dictionary = power["nodes"][n]
		if not branches.has(node["branch"]):
			branches[node["branch"]] = []
		branches[node["branch"]].append(node["name"])
	var lines: Array = []
	for branch in branches:
		lines.append("[b][color=#f2c75a]%s[/color][/b]  %s" % [branch, "  >  ".join(branches[branch])])
	lines.append("[color=#8f8ca0]Earn upgrades by drafting %s cards (at %s). Pact needs %d cards from other pantheons.[/color]" % [
		pantheon_name, ", ".join(Data.POWER_THRESHOLDS.map(func(t): return str(t))), Data.PACT_CARDS])
	return "\n".join(lines)


## "Starting card / relic" line: framed thumbnail, label, name and rules text. Clicks pass to the tile.
func _patron_row(thumb: Control, heading: String, title: String, text: String, edge: Color, radius: int) -> Control:
	var row := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var holder := Panel.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.08, 0.08, 0.12)
	hsb.border_color = edge
	hsb.set_border_width_all(2)
	hsb.set_corner_radius_all(radius)
	holder.add_theme_stylebox_override("panel", hsb)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	CardWidget.place(row, holder, 6, 7, 68, 69)
	CardWidget.place(holder, thumb, 2, 2, -2, -2)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_font_size_override("bold_font_size", 15)
	label.text = "[color=#8f8ca0]%s[/color]  [b]%s[/b]\n[color=#c8c6d4]%s[/color]" % [heading, title, text]
	CardWidget.place(row, label, 78, 6, -6, -4)
	return row


func _build_sandbox() -> void:
	sandbox = MarginContainer.new()
	sandbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		sandbox.add_theme_constant_override("margin_" + side, 40)
	sandbox.visible = false
	add_child(sandbox)
	var dim := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.03, 0.03, 0.06, 0.82)
	dsb.set_corner_radius_all(12)
	dsb.set_expand_margin_all(20)
	dim.add_theme_stylebox_override("panel", dsb)
	sandbox.add_child(dim)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	sandbox.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := CardWidget._label("Battle sandbox", 40, GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var cards := Button.new()
	cards.text = "Card list"
	cards.custom_minimum_size = Vector2(180, 40)
	cards.pressed.connect(_open_card_list)
	CardWidget.style_button(cards, false, 16)
	header.add_child(cards)
	var back := Button.new()
	back.text = "Back to patrons"
	back.custom_minimum_size = Vector2(180, 40)
	back.pressed.connect(_show_sandbox.bind(false))
	CardWidget.style_button(back, false, 16)
	header.add_child(back)

	var subtitle := Label.new()
	subtitle.text = "Single test battles and events. The deck and relic choices on the right apply only to battles."
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	root.add_child(subtitle)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 40)
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(600, 0)
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left.add_child(tabs)
	var battles_scroll := ScrollContainer.new()
	battles_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battles_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(battles_scroll)
	var events_scroll := battles_scroll.duplicate()
	left.add_child(events_scroll)
	var battles := VBoxContainer.new()
	battles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battles.add_theme_constant_override("separation", 8)
	battles_scroll.add_child(battles)
	var events := VBoxContainer.new()
	events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events.add_theme_constant_override("separation", 8)
	events_scroll.add_child(events)
	var tab_buttons: Array = []
	for tab in [["Battles", battles_scroll], ["Events", events_scroll]]:
		var b := Button.new()
		b.text = tab[0]
		b.custom_minimum_size = Vector2(150, 38)
		CardWidget.style_button(b, false, 16)
		tabs.add_child(b)
		tab_buttons.append(b)
	for i in tab_buttons.size():
		tab_buttons[i].pressed.connect(func():
			battles_scroll.visible = i == 0
			events_scroll.visible = i == 1
			for j in tab_buttons.size():
				var tb: Button = tab_buttons[j]
				tb.remove_theme_font_override("font")
				for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
					tb.remove_theme_color_override(c)
				CardWidget.style_button(tb, j == i, 16))
	tab_buttons[0].pressed.emit()
	for battle in Data.BATTLES:
		var row := HBoxContainer.new()
		var button := Button.new()
		button.text = battle["name"]
		button.custom_minimum_size = Vector2(320, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_start_battle.bind(battle))
		CardWidget.style_button(button, false, 16)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(button)
		var blurb := Label.new()
		blurb.text = "%s  (default deck: %s, Core %d)" % [battle["blurb"], Data.DECKS[battle["deck"]]["name"], battle["core"]]
		blurb.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blurb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.add_child(blurb)
		battles.add_child(row)
	_build_event_tests(events)

	var options_scroll := ScrollContainer.new()
	options_scroll.custom_minimum_size = Vector2(360, 0)
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(options_scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 8)
	options_scroll.add_child(options)

	options.add_child(_heading("Deck"))
	deck_option = OptionButton.new()
	deck_option.add_item("Battle default")
	for key in Data.DECKS:
		deck_keys.append(key)
		deck_option.add_item(Data.DECKS[key]["name"])
	options.add_child(deck_option)

	options.add_child(_heading("Seed (0 = random, also for runs)"))
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 999999
	seed_box.value = 0
	options.add_child(seed_box)

	options.add_child(_heading("God power"))
	power_option = OptionButton.new()
	power_option.add_item("None")
	for id in Data.GOD_POWERS:
		power_option.add_item(Data.GOD_POWERS[id]["name"])
	options.add_child(power_option)
	power_upgraded = CheckBox.new()
	power_upgraded.text = "With every upgrade"
	options.add_child(power_upgraded)

	options.add_child(_heading("Extra relics"))
	for id in Data.RELICS:
		var relic: Dictionary = Data.RELICS[id]
		if not relic["combat"]:
			continue
		var cb := CheckBox.new()
		cb.text = relic["name"]
		cb.tooltip_text = CardWidget.wrap_text(relic["text"])
		relic_checks[id] = cb
		options.add_child(cb)


## One button per event (the pantheon shrine once per pantheon), plus the shop and rest site.
## Each opens that screen in a fresh run as the chosen patron, and leaving it returns here.
func _build_event_tests(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	parent.add_child(header)
	var heading := _heading("Test an event")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var patron_label := Label.new()
	patron_label.text = "Test as:"
	patron_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	header.add_child(patron_label)
	event_patron = OptionButton.new()
	for p in Data.PATRONS:
		event_patron.add_item(Data.CARDS[p["card"]]["name"])
	header.add_child(event_patron)

	var hint := Label.new()
	hint.text = "Opens the event with %d gold. Leaving it returns to the sandbox." % RunView.SANDBOX_GOLD
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	parent.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var tests: Array = []
	for id in Data.EVENTS:
		var ev: Dictionary = Data.EVENTS[id]
		if id == "pantheon_shrine":
			for pantheon in ["norse", "greek", "egypt"]:
				tests.append([ev["name"].replace("{pantheon}", Data.FACTION_NAMES[pantheon]), id, pantheon, ev["text"].replace("{pantheon}", Data.FACTION_NAMES[pantheon])])
		else:
			tests.append([ev["name"], id, "", ev["text"]])
	tests.append(["Shop", "shop", "", "The Wandering Market."])
	tests.append(["Rest site", "rest", "", "Sanctuary World."])
	for t in tests:
		var b := Button.new()
		b.text = t[0]
		b.tooltip_text = CardWidget.wrap_text(t[3])
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_start_event_test.bind(t[1], t[2]))
		CardWidget.style_button(b, false, 15)
		grid.add_child(b)


func _start_event_test(event: String, pantheon: String) -> void:
	var seed_value := int(seed_box.value)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	_hide_menus()
	run_view = RunView.new()
	add_child(run_view)
	run_view.exit_requested.connect(_back_to_menu)
	run_view.start_test(seed_value, Data.PATRONS[event_patron.selected]["card"], event, pantheon)


## Every card in the game, grouped by faction. `filter` is a LIST_GROUPS key or "all".
func _open_card_list(filter := "all") -> void:
	_close_card_list()
	card_list = PanelContainer.new()
	card_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08)
	sb.set_content_margin_all(30)
	card_list.add_theme_stylebox_override("panel", sb)
	add_child(card_list)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card_list.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title := Label.new()
	title.text = "Card list - %d cards" % Data.CARDS.size()
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for key in ["all"] + LIST_GROUPS.keys():
		var b := Button.new()
		b.text = "All" if key == "all" else LIST_GROUPS[key]
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = key == filter
		b.pressed.connect(_open_card_list.bind(key))
		CardWidget.style_button(b, false, 15)
		header.add_child(b)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(_close_card_list)
	CardWidget.style_button(close, true, 20)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	scroll.add_child(sections)
	for group in LIST_GROUPS:
		if filter != "all" and filter != group:
			continue
		var ids: Array = Data.CARDS.keys().filter(func(id): return _list_group(id) == group)
		ids.sort_custom(_card_before)
		sections.add_child(_heading("%s - %d" % [LIST_GROUPS[group], ids.size()]))
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for id in ids:
			grid.add_child(CardWidget.card_button(id))
		sections.add_child(grid)


func _close_card_list() -> void:
	if card_list != null:
		card_list.queue_free()
		card_list = null


func _list_group(id: String) -> String:
	var faction: String = Data.CARDS[id]["faction"]
	return faction if LIST_GROUPS.has(faction) else "other"


## Starter, Common, Uncommon, Rare, then everything else; then by cost and name.
func _card_before(a: String, b: String) -> bool:
	var da: Dictionary = Data.CARDS[a]
	var db: Dictionary = Data.CARDS[b]
	var ra: int = RARITY_ORDER.find(da["rarity"])
	var rb: int = RARITY_ORDER.find(db["rarity"])
	ra = ra if ra >= 0 else RARITY_ORDER.size()
	rb = rb if rb >= 0 else RARITY_ORDER.size()
	if ra != rb:
		return ra < rb
	if da["cost"] != db["cost"]:
		return da["cost"] < db["cost"]
	return da["name"] < db["name"]


func _show_sandbox(show: bool) -> void:
	sandbox.visible = show
	menu.visible = not show
	sandbox_button.visible = not show


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	return l


func _hide_menus() -> void:
	menu.visible = false
	sandbox.visible = false
	sandbox_button.visible = false
	power_back.visible = false


func _start_battle(battle: Dictionary) -> void:
	var deck_key: String = battle["deck"]
	if deck_option.selected > 0:
		deck_key = deck_keys[deck_option.selected - 1]
	var relics: Array = battle["relics"].duplicate()
	for id in relic_checks:
		if relic_checks[id].button_pressed and not relics.has(id):
			relics.append(id)
	var seed_value := int(seed_box.value)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)

	if power_option.selected > 0:
		var power_id: String = Data.GOD_POWERS.keys()[power_option.selected - 1]
		battle = battle.duplicate()
		battle["god_power"] = {"id": power_id, "nodes": Data.GOD_POWERS[power_id]["nodes"].keys() if power_upgraded.button_pressed else []}

	_hide_menus()
	battle_view = BattleView.new()
	add_child(battle_view)
	battle_view.exit_requested.connect(_back_to_menu)
	battle_view.start(battle, deck_key, relics, seed_value)


func _start_run(patron: String, power := "") -> void:
	var seed_value := int(seed_box.value)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	_hide_menus()
	run_view = RunView.new()
	add_child(run_view)
	run_view.exit_requested.connect(_back_to_menu)
	run_view.start(seed_value, patron, power)


## Sandbox battles return to the sandbox; runs return to the patron screen.
func _back_to_menu() -> void:
	var to_sandbox: bool = battle_view != null or (run_view != null and run_view.sandbox_mode)
	for view in [battle_view, run_view]:
		if view != null:
			view.queue_free()
	battle_view = null
	run_view = null
	_show_patrons()
	_show_sandbox(to_sandbox)
