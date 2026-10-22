extends Control
## Main menu, then a patron card, then one of that patron's god powers.

const Data = preload("res://scripts/core/data.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const RunView = preload("res://scripts/ui/run_view.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const PlaytestOverlay = preload("res://scripts/ui/playtest_overlay.gd")
const CardPreview = preload("res://scripts/ui/card_preview.gd")
const RulesPanel = preload("res://scripts/ui/rules_panel.gd")
const Music = preload("res://scripts/ui/music.gd")

const PATRON_TILE := Vector2(332, 544)
const PATRON_ART_BOTTOM := 322
const PATRON_GLOW := {
	"norse": Color(0.32, 0.55, 0.95),
	"greek": Color(0.95, 0.75, 0.32),
	"egypt": Color(0.28, 0.72, 0.34),
}
## Rounds the portrait corners and keeps the head in frame.
const PATRON_PORTRAIT_SHADER := "shader_type canvas_item;
uniform vec2 control_size = vec2(300.0, 300.0);
uniform vec2 tex_size = vec2(512.0, 512.0);
uniform float radius_px = 16.0;
void fragment() {
	vec2 p = UV * control_size;
	vec2 half_size = control_size * 0.5;
	vec2 q = abs(p - half_size) - (half_size - vec2(radius_px));
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius_px;
	float ca = control_size.x / max(control_size.y, 1.0);
	float ta = tex_size.x / max(tex_size.y, 1.0);
	vec2 uv = UV;
	if (ta > ca) {
		float s = ca / ta;
		uv.x = (UV.x - 0.5) * s + 0.5;
	} else {
		uv.y = UV.y * (ta / max(ca, 0.001));
	}
	vec4 col = texture(TEXTURE, uv);
	col.a *= 1.0 - smoothstep(-0.75, 0.9, dist);
	COLOR = col;
}
"
const POWER_TILE := Vector2(560, 500)
## The background is shifted up so the ghostly gods sit behind the logo.
const BG_RECT := Rect2(-60, -125, 1720, 968)
const GOLD := Color(0.95, 0.78, 0.35)
const CREAM := Color(0.94, 0.9, 0.82)
const MUTED := Color(0.7, 0.68, 0.76)
const TITLE_CROP := Rect2(0.02, 0.28, 0.96, 0.48)
## Drops the black behind a logo so the menu art shows through.
const LOGO_KEY_SHADER := "shader_type canvas_item;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float luma = max(col.r, max(col.g, col.b));
	col.a *= smoothstep(0.05, 0.22, luma);
	COLOR = col;
}
"
const LIST_GROUPS := {"neutral": "Neutral", "norse": "Norse", "greek": "Greek", "egypt": "Egyptian", "divine": "Divine (shrines only)", "other": "Tokens, curses and statuses"}
const RARITY_ORDER := ["Starter", "Common", "Uncommon", "Rare"]
const PATRON_SHORT := {"norse": "Norse", "greek": "Greek", "egypt": "Egypt"}

var menu: Control
var veil: ColorRect
var home_box: Control
var home_stage: Control
var home_logo: TextureRect
var play_button: Button
var codex_box: Control
var codex_dismiss: Button
var patron_box: Control
var power_box: Control
var patron_row: HBoxContainer
var power_row: HBoxContainer
var help_panel: ColorRect
var sandbox: Control
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
var custom_deck: Array = []
var deck_builder: Control = null
var builder_deck_box: VBoxContainer
var builder_title: Label
var act_option: OptionButton
var floor_box: SpinBox
var core_box: SpinBox
var core_max_box: SpinBox
var scaling_label: Label

const CUSTOM_DECK_FILE := "user://sandbox_deck.json"


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
	veil = ColorRect.new()
	veil.color = Color(0.02, 0.015, 0.05, 0.12)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_build_menu()
	_build_sandbox()
	add_child(CardPreview.new())
	add_child(PlaytestOverlay.new())
	Music.play("theme")


## The logo sits on pure black, so additive blending makes its background disappear.
func _title(height: float) -> Control:
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
			logo.custom_minimum_size = Vector2(0, height)
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
		menu.add_theme_constant_override("margin_" + side, 36)
	add_child(menu)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(root)

	home_box = Control.new()
	home_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(root, home_box, 0, 0, -0.001, -0.001)
	codex_dismiss = Button.new()
	codex_dismiss.focus_mode = Control.FOCUS_NONE
	codex_dismiss.visible = false
	codex_dismiss.pressed.connect(_close_codex)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		codex_dismiss.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	CardWidget.place(home_box, codex_dismiss, 0, 0, -0.001, -0.001)
	home_stage = VBoxContainer.new()
	home_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	home_stage.add_theme_constant_override("separation", 28)
	home_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(home_box, home_stage, 0, 48, -0.001, -140)
	home_stage.add_child(_home_logo())
	play_button = _play_button()
	home_stage.add_child(play_button)

	codex_box = Panel.new()
	codex_box.visible = false
	var hsb := CardWidget.glass_style(18, 0)
	hsb.bg_color = Color(0.05, 0.04, 0.09, 0.9)
	hsb.border_color = Color(GOLD, 0.28)
	codex_box.add_theme_stylebox_override("panel", hsb)
	CardWidget.place(home_box, codex_box, 0, 0, 400, -0.001)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(codex_box, column, 26, 28, -26, -28)
	column.add_child(_codex_row("opt_card", "New Run", "Choose a patron", _show_patrons, true))
	column.add_child(_codex_row("rulebook", "Rulebook", "How battles work", _toggle_rules, false))
	column.add_child(_codex_row("ui_map", "Sandbox", "Single test battles", _show_sandbox.bind(true), false))
	var close_gap := Control.new()
	close_gap.custom_minimum_size = Vector2(0, 18)
	close_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(close_gap)
	var close_row := CenterContainer.new()
	close_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_row.add_child(_text_link("Close", _close_codex))
	column.add_child(close_row)

	patron_box = _centered_column(14)
	patron_box.visible = false
	CardWidget.place(root, patron_box, 0, 0, -0.001, -0.001)
	patron_box.add_child(_title(96))
	var ask := CardWidget.heading("Who do you serve?", 26, CREAM)
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	patron_box.add_child(ask)
	patron_row = HBoxContainer.new()
	patron_row.alignment = BoxContainer.ALIGNMENT_CENTER
	patron_row.add_theme_constant_override("separation", 36)
	patron_box.add_child(patron_row)
	for patron in Data.PATRONS:
		patron_row.add_child(_patron_tile(patron))
	patron_box.add_child(_text_link("Back", _show_home.bind(true)))

	power_box = _centered_column(12)
	power_box.visible = false
	CardWidget.place(root, power_box, 0, 0, -0.001, -0.001)
	power_row = HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_row.add_theme_constant_override("separation", 28)
	power_box.add_child(power_row)


func _centered_column(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _v_spacer(weight := 1.0) -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = weight
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## One row of the main-menu list: an icon, a name, and a short line under it.
func _codex_row(icon: String, title: String, detail: String, callback: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 74)
	b.pressed.connect(callback)
	var styles := {}
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD, 0.1) if state == "hover" else Color(0, 0, 0, 0)
		sb.border_color = Color(GOLD, 0.85 if state == "hover" or primary else 0.22)
		sb.border_width_left = 3
		sb.border_width_bottom = 1
		sb.set_content_margin_all(0)
		sb.set_corner_radius_all(4)
		styles[state] = sb
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", styles["normal"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	CardWidget.place(b, row, 16, 8, -12, -8)
	var glyph := CardWidget.icon(icon, 28)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(CardWidget.heading(title, 20, CREAM if primary else Color(0.9, 0.88, 0.84)))
	text.add_child(CardWidget._label(detail, 13, MUTED, false))
	return b


func _text_link(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.pressed.connect(callback)
	return b


func _show_home(keep_codex := false) -> void:
	home_box.visible = true
	patron_box.visible = false
	power_box.visible = false
	veil.color = Color(0.02, 0.015, 0.05, 0.12)
	if keep_codex:
		_open_codex()
	else:
		_close_codex()


## The title screen: the logo centered, with Play Game beneath it.
func _home_logo() -> TextureRect:
	var logo := TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.custom_minimum_size = Vector2(920, 250)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = LOGO_KEY_SHADER
	mat.shader = shader
	logo.material = mat
	home_logo = logo
	for pattern in CardWidget.ART_PATHS:
		var path: String = pattern % ["ui", "title_logo"]
		if ResourceLoader.exists(path):
			var image: Image = load(path).get_image()
			var size := Vector2(image.get_size())
			var region := Rect2i(Vector2i(size * TITLE_CROP.position), Vector2i(size * TITLE_CROP.size))
			logo.texture = ImageTexture.create_from_image(image.get_region(region))
			break
	return logo


## Swaps the centered logo, used to compare marks before one is chosen.
func set_home_logo(path: String) -> void:
	var image := Image.new()
	if image.load(path) != OK:
		return
	var region := _logo_bounds(image)
	home_logo.texture = ImageTexture.create_from_image(image.get_region(region))


func _logo_bounds(image: Image) -> Rect2i:
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := 0
	var max_y := 0
	for y in range(0, height, 2):
		for x in range(0, width, 2):
			var pixel := image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x <= min_x:
		return Rect2i(0, 0, width, height)
	min_x = maxi(min_x - 12, 0)
	min_y = maxi(min_y - 12, 0)
	max_x = mini(max_x + 14, width)
	max_y = mini(max_y + 14, height)
	return Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)


func _play_button() -> Button:
	var b := Button.new()
	b.text = "Play Game"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(220, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", CardWidget.UI_FONT)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.16, 0.1, 0.03))
	b.add_theme_color_override("font_hover_color", Color(0.16, 0.1, 0.03))
	b.add_theme_color_override("font_pressed_color", Color(0.16, 0.1, 0.03))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.78, 0.6, 0.22) if state == "pressed" else Color(0.95, 0.78, 0.38)
		if state == "hover":
			sb.bg_color = Color(1.0, 0.88, 0.55)
		sb.set_corner_radius_all(25)
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(_open_codex)
	return b


func _open_codex() -> void:
	codex_box.visible = true
	codex_dismiss.visible = true
	play_button.visible = false
	_place_stage(true)


func _close_codex() -> void:
	codex_box.visible = false
	codex_dismiss.visible = false
	play_button.visible = true
	_place_stage(false)


func _place_stage(codex_open: bool) -> void:
	home_stage.offset_left = 420.0 if codex_open else 0.0
	home_stage.offset_right = -8.0 if codex_open else 0.0
	home_stage.offset_top = 36.0
	home_stage.offset_bottom = -120.0


func _set_card_veil() -> void:
	veil.color = Color(0.02, 0.015, 0.05, 0.58)


## A patron as a glass card: glowing frame, bust portrait, name, core, and Choose.
func _patron_tile(patron: Dictionary) -> Button:
	var card: Dictionary = Data.CARDS[patron["card"]]
	var faction: String = card["faction"]
	var glow: Color = PATRON_GLOW[faction]
	var b := Button.new()
	b.custom_minimum_size = PATRON_TILE
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Starts with %s" % card["name"]
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(_show_powers.bind(patron))
	var face := Control.new()
	face.size = PATRON_TILE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(face)

	var frame := Panel.new()
	var sb := CardWidget.glass_style(22, 0)
	sb.bg_color = Color(0.035, 0.03, 0.06, 0.72)
	sb.border_color = Color(glow, 0.9)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(glow, 0.38)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2.ZERO
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(face, frame, 0, 0, -0.001, -0.001)

	var art := _patron_portrait(faction, glow)
	CardWidget.place(frame, art, 14, 14, -14, PATRON_ART_BOTTOM)

	var name_label := CardWidget.heading(PATRON_SHORT[faction].to_upper(), 26, CREAM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CardWidget.place(frame, name_label, 16, PATRON_ART_BOTTOM + 8, -16, PATRON_ART_BOTTOM + 42)
	var sub := CardWidget._label(Data.FACTION_TITLES[faction], 15, MUTED, false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CardWidget.place(frame, sub, 16, PATRON_ART_BOTTOM + 40, -16, PATRON_ART_BOTTOM + 64)

	var core_row := HBoxContainer.new()
	core_row.alignment = BoxContainer.ALIGNMENT_CENTER
	core_row.add_theme_constant_override("separation", 8)
	core_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem := _core_mark(glow)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	core_row.add_child(gem)
	var core := CardWidget._label("Core %d" % patron["hp"], 15, CREAM, false)
	core.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core_row.add_child(core)
	CardWidget.place(frame, core_row, 16, PATRON_ART_BOTTOM + 72, -16, PATRON_ART_BOTTOM + 98)

	var banner := _gold_banner("CHOOSE")
	CardWidget.place(frame, banner, 62, PATRON_TILE.y - 58, -62, PATRON_TILE.y - 18)
	b.mouse_entered.connect(func():
		face.position.y = -10
		sb.border_color = Color(glow.lightened(0.25), 1.0)
		sb.shadow_color = Color(glow, 0.7)
		sb.shadow_size = 36)
	b.mouse_exited.connect(func():
		face.position.y = 0
		sb.border_color = Color(glow, 0.9)
		sb.shadow_color = Color(glow, 0.38)
		sb.shadow_size = 22)
	return b


## The small four-pane mark beside Core, tinted to the patron.
func _core_mark(glow: Color) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(14, 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pane := 6
	var gap := 2
	for row in 2:
		for col in 2:
			var sq := ColorRect.new()
			sq.color = glow
			sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sq.position = Vector2(col * (pane + gap), row * (pane + gap))
			sq.size = Vector2(pane, pane)
			root.add_child(sq)
	return root


func _patron_portrait(faction: String, glow: Color) -> Control:
	var art := CardWidget.art("patrons", faction, PATRON_SHORT[faction], glow, 64)
	if not art is TextureRect or (art as TextureRect).texture == null:
		return art
	var tex: Texture2D = (art as TextureRect).texture
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = PATRON_PORTRAIT_SHADER
	mat.shader = shader
	mat.set_shader_parameter("tex_size", tex.get_size())
	mat.set_shader_parameter("radius_px", 16.0)
	art.material = mat
	art.resized.connect(func():
		if art.size.x > 1.0:
			mat.set_shader_parameter("control_size", art.size))
	return art


func _show_powers(patron: Dictionary) -> void:
	for child in power_box.get_children():
		if child != power_row:
			power_box.remove_child(child)
			child.queue_free()
	for child in power_row.get_children():
		child.queue_free()
	var faction: String = Data.CARDS[patron["card"]]["faction"]
	var header := HBoxContainer.new()
	header.add_child(_text_link("<  %s" % PATRON_SHORT[faction], _show_patrons))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	power_box.add_child(header)
	power_box.add_child(_title(84))
	var ask := CardWidget.heading("Which power do you carry?", 24, CREAM)
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_box.add_child(ask)
	power_box.move_child(power_row, power_box.get_child_count() - 1)
	for id in patron["powers"]:
		power_row.add_child(_power_tile(patron, id))
	_show_power_box()


func _show_patrons() -> void:
	home_box.visible = false
	patron_box.visible = true
	power_box.visible = false
	veil.color = Color(0.015, 0.01, 0.04, 0.22)


func _show_power_box() -> void:
	home_box.visible = false
	patron_box.visible = false
	power_box.visible = true
	_set_card_veil()
	power_box.modulate.a = 0.0
	power_box.create_tween().tween_property(power_box, "modulate:a", 1.0, 0.25)


## One god power: the effect is the headline, and each branch is a column of upgrade names.
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
	sb.bg_color = Color(0.05, 0.04, 0.08, 0.92)
	sb.border_color = Color(tint, 0.4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(b, panel, 0, 0, -0.001, -0.001)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(panel, box, 26, 16, -26, -16)
	var disc := CardWidget.power_disc(id, 72, true)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(disc)
	var title := CardWidget.heading(power["name"], 24, tint.lightened(0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_center_text(power["text"], 16, CREAM, POWER_TILE.x - 90))
	var recharge := CardWidget._label("Free during planning. Recharges for %d floors." % Data.POWER_COOLDOWN_FLOORS, 13, MUTED, false)
	recharge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(recharge)
	box.add_child(_power_tree(power))
	box.add_child(_center_text("Tier 3 needs %d %s cards. Hover a branch to read its upgrades." % [Data.TIER3_DEVOTION, PATRON_SHORT[power["pantheon"]]], 12, MUTED, POWER_TILE.x - 90))
	var hold := CenterContainer.new()
	var banner := _gold_banner("BEGIN RUN")
	banner.custom_minimum_size = Vector2(220, 40)
	hold.add_child(banner)
	box.add_child(hold)
	b.mouse_entered.connect(func():
		sb.border_color = Color(tint, 0.9)
		sb.shadow_color = Color(tint, 0.35))
	b.mouse_exited.connect(func():
		sb.border_color = Color(tint, 0.4)
		sb.shadow_color = Color(0, 0, 0, 0.45))
	CardWidget._hover_motion(b, 1.015)
	return b


## Wrapped, centered text whose height follows the words, so the next line never draws over it.
func _center_text(text: String, font_size: int, color: Color, width: float) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_color_override("default_color", color)
	l.text = "[center]%s[/center]" % text
	return l


func _gold_banner(caption: String) -> Panel:
	var banner := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.8, 0.6, 0.24)
	bsb.border_color = Color(1.0, 0.9, 0.62, 0.9)
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(22)
	banner.add_theme_stylebox_override("panel", bsb)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var begin := CardWidget.heading(caption, 16, Color(0.14, 0.08, 0.02))
	begin.remove_theme_color_override("font_shadow_color")
	begin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	begin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CardWidget.place(banner, begin, 0, 0, -0.001, -0.001)
	return banner


## Branch names down a column. Hovering the column shows each upgrade's text.
func _power_tree(power: Dictionary) -> HBoxContainer:
	var branches := {}
	var order: Array = []
	for n in power["nodes"]:
		var node: Dictionary = power["nodes"][n]
		var branch: String = node["branch"]
		if not branches.has(branch):
			branches[branch] = []
			order.append(branch)
		branches[branch].append(node)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for branch in order:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_PASS
		var lines: PackedStringArray = []
		for node in branches[branch]:
			lines.append("%s: %s" % [node["name"], node["text"]])
		col.tooltip_text = CardWidget.wrap_text("\n".join(lines), 46)
		var head := CardWidget.heading(branch.to_upper(), 13, GOLD)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		for node in branches[branch]:
			col.add_child(_center_text(node["name"], 13, Color(0.86, 0.84, 0.9), 150))
		row.add_child(col)
	return row


func _toggle_rules() -> void:
	if run_view != null or battle_view != null:
		return
	if help_panel == null:
		help_panel = RulesPanel.new()
		add_child(help_panel)
	else:
		help_panel.visible = not help_panel.visible
	if help_panel.visible:
		move_child(help_panel, get_child_count() - 1)


func _unhandled_input(event: InputEvent) -> void:
	if run_view != null or battle_view != null:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_H, KEY_F1]:
		_toggle_rules()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and help_panel != null and help_panel.visible:
		help_panel.visible = false
		get_viewport().set_input_as_handled()

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
	_load_custom_deck()
	deck_option.add_item("")
	_refresh_custom_deck_item()
	options.add_child(deck_option)
	var edit_deck := Button.new()
	edit_deck.text = "Build custom deck"
	edit_deck.custom_minimum_size = Vector2(0, 38)
	edit_deck.pressed.connect(_open_deck_builder)
	CardWidget.style_button(edit_deck, false, 15)
	options.add_child(edit_deck)

	options.add_child(_heading("Run conditions"))
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	options.add_child(act_row)
	act_option = OptionButton.new()
	for i in Data.ACTS.size():
		act_option.add_item("Act %d: %s" % [i + 1, Data.ACTS[i]["name"]])
	act_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_option.item_selected.connect(func(_i): _update_scaling_label())
	act_row.add_child(act_option)
	floor_box = _labeled_spin(options, "Floor (0 = no floor scaling)", 0, 15, 0)
	floor_box.value_changed.connect(func(_v): _update_scaling_label())
	scaling_label = Label.new()
	scaling_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	scaling_label.add_theme_font_size_override("font_size", 14)
	scaling_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scaling_label.custom_minimum_size = Vector2(320, 0)
	options.add_child(scaling_label)
	core_box = _labeled_spin(options, "Core HP (0 = battle default)", 0, 999, 0)
	core_max_box = _labeled_spin(options, "Max Core HP (0 = same as Core HP)", 0, 999, 0)
	_update_scaling_label()

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
	if not show:
		_show_home(true)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	return l


func _hide_menus() -> void:
	menu.visible = false
	sandbox.visible = false
	if help_panel != null:
		help_panel.visible = false


func _start_battle(battle: Dictionary) -> void:
	var deck: Variant = battle["deck"]
	if deck_option.selected > deck_keys.size():
		if custom_deck.is_empty():
			_open_deck_builder()
			return
		deck = custom_deck
	elif deck_option.selected > 0:
		deck = deck_keys[deck_option.selected - 1]
	battle = _apply_run_conditions(battle)
	var relics: Array = battle["relics"].duplicate()
	for id in relic_checks:
		if relic_checks[id].button_pressed and not relics.has(id):
			relics.append(id)
	var seed_value := int(seed_box.value)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)

	if power_option.selected > 0:
		var power_id: String = Data.GOD_POWERS.keys()[power_option.selected - 1]
		battle["god_power"] = {"id": power_id, "nodes": Data.GOD_POWERS[power_id]["nodes"].keys() if power_upgraded.button_pressed else []}

	_hide_menus()
	battle_view = BattleView.new()
	add_child(battle_view)
	battle_view.exit_requested.connect(_back_to_menu)
	battle_view.start(battle, deck, relics, seed_value)


## Same Empowered enemies, extra rounds, act boss bonus and Core HP a run would give this
## battle at the chosen act and floor. Bosses skip floor scaling, as in a run.
static func _run_conditions(battle: Dictionary, act: int, floor_number: int, core: int, core_max: int) -> Dictionary:
	var b := battle.duplicate(true)
	var act_def: Dictionary = Data.ACTS[act]
	var every: int = Data.BALANCE["scaling_every_floors"]
	if not b.get("boss", false) and every > 0 and floor_number > 0:
		var steps: int = (floor_number - 1) / every + act_def["empower_steps"]
		if steps > 0:
			b["enemy_bonus"] = {"atk": Data.BALANCE["empower_atk"], "hp": Data.BALANCE["empower_hp"],
				"count": steps * Data.BALANCE["empowered_per_step"], "rounds": steps * Data.BALANCE["scaling_rounds"]}
	if b.get("boss", false) and not act_def["boss_bonus"].is_empty():
		b["boss_bonus"] = act_def["boss_bonus"]
	if core > 0:
		b["core"] = core
	b["core_max"] = maxi(core_max, b["core"])
	return b


func _apply_run_conditions(battle: Dictionary) -> Dictionary:
	return _run_conditions(battle, act_option.selected, int(floor_box.value), int(core_box.value), int(core_max_box.value))


func _update_scaling_label() -> void:
	var b := _run_conditions({"core": 0}, act_option.selected, int(floor_box.value), 0, 0)
	var parts: Array = []
	if b.has("enemy_bonus"):
		var eb: Dictionary = b["enemy_bonus"]
		parts.append("Normal and elite fights: %d Empowered %s (+%d ATK, +%d HP), +%d %s." % [eb["count"],
			"enemy" if eb["count"] == 1 else "enemies", eb["atk"], eb["hp"], eb["rounds"], "round" if eb["rounds"] == 1 else "rounds"])
	else:
		parts.append("No floor scaling.")
	var boss_bonus: Dictionary = Data.ACTS[act_option.selected]["boss_bonus"]
	if not boss_bonus.is_empty():
		parts.append("Bosses: +%d ATK, +%d HP." % [boss_bonus.get("atk", 0), boss_bonus.get("hp", 0)])
	scaling_label.text = " ".join(parts)


func _labeled_spin(parent: Control, text: String, lo: int, hi: int, value: int) -> SpinBox:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	parent.add_child(label)
	var box := SpinBox.new()
	box.min_value = lo
	box.max_value = hi
	box.value = value
	parent.add_child(box)
	return box


func _refresh_custom_deck_item() -> void:
	deck_option.set_item_text(deck_keys.size() + 1, "Custom deck (%d cards)" % custom_deck.size())


func _load_custom_deck() -> void:
	if not FileAccess.file_exists(CUSTOM_DECK_FILE):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_DECK_FILE))
	if parsed is Array:
		custom_deck = parsed.filter(func(id): return id is String and Data.CARDS.has(id))


func _save_custom_deck() -> void:
	var f := FileAccess.open(CUSTOM_DECK_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(custom_deck))


## Full card grid on the left (click to add a copy), the deck on the right (click to remove one).
func _open_deck_builder(filter := "all") -> void:
	_close_deck_builder()
	deck_builder = PanelContainer.new()
	deck_builder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08)
	sb.set_content_margin_all(30)
	deck_builder.add_theme_stylebox_override("panel", sb)
	add_child(deck_builder)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	deck_builder.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	builder_title = CardWidget._label("", 32, GOLD, true)
	builder_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(builder_title)
	for key in ["all"] + LIST_GROUPS.keys():
		var b := Button.new()
		b.text = "All" if key == "all" else LIST_GROUPS[key]
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = key == filter
		b.pressed.connect(_open_deck_builder.bind(key))
		CardWidget.style_button(b, false, 15)
		header.add_child(b)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(120, 40)
	done.pressed.connect(_close_deck_builder)
	CardWidget.style_button(done, true, 20)
	header.add_child(done)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
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
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for id in ids:
			var b := CardWidget.card_button(id)
			b.pressed.connect(_builder_add.bind(id))
			grid.add_child(b)
		sections.add_child(grid)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(340, 0)
	side.add_theme_constant_override("separation", 8)
	columns.add_child(side)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	side.add_child(tools)
	var preset := OptionButton.new()
	preset.add_item("Start from...")
	for key in deck_keys:
		preset.add_item(Data.DECKS[key]["name"])
	preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset.item_selected.connect(func(i):
		if i > 0:
			custom_deck = Data.deck_cards(deck_keys[i - 1]).duplicate()
			_builder_changed()
		preset.select(0))
	tools.add_child(preset)
	var clear := Button.new()
	clear.text = "Clear"
	clear.custom_minimum_size = Vector2(90, 36)
	clear.pressed.connect(func():
		custom_deck.clear()
		_builder_changed())
	CardWidget.style_button(clear, false, 15)
	tools.add_child(clear)
	var hint := Label.new()
	hint.text = "Click a card on the left to add a copy. Click a card here to remove one."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	side.add_child(hint)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(deck_scroll)
	builder_deck_box = VBoxContainer.new()
	builder_deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_deck_box.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(builder_deck_box)
	_refresh_builder_deck()


func _close_deck_builder() -> void:
	if deck_builder != null:
		deck_builder.queue_free()
		deck_builder = null


func _builder_add(id: String) -> void:
	custom_deck.append(id)
	_builder_changed()


func _builder_remove(id: String) -> void:
	custom_deck.erase(id)
	_builder_changed()


func _builder_changed() -> void:
	_save_custom_deck()
	_refresh_custom_deck_item()
	deck_option.select(deck_keys.size() + 1)
	_refresh_builder_deck()


func _refresh_builder_deck() -> void:
	builder_title.text = "Custom deck - %d cards" % custom_deck.size()
	for child in builder_deck_box.get_children():
		child.queue_free()
	var counts := {}
	for id in custom_deck:
		counts[id] = counts.get(id, 0) + 1
	var ids: Array = counts.keys()
	ids.sort_custom(_card_before)
	for id in ids:
		var def: Dictionary = Data.CARDS[id]
		var b := Button.new()
		b.text = "%d  %s   x%d" % [def["cost"], def["name"], counts[id]]
		b.tooltip_text = CardWidget.wrap_text(def.get("text", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_builder_remove.bind(id))
		CardWidget.style_button(b, false, 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		builder_deck_box.add_child(b)
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "Empty. A custom deck needs at least one card."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		builder_deck_box.add_child(empty)


func _start_run(patron: String, power := "") -> void:
	var seed_value := int(seed_box.value)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	_hide_menus()
	run_view = RunView.new()
	add_child(run_view)
	run_view.exit_requested.connect(_back_to_menu)
	run_view.start(seed_value, patron, power)


## Sandbox battles return to the sandbox; runs return to the main menu.
func _back_to_menu() -> void:
	var to_sandbox: bool = battle_view != null or (run_view != null and run_view.sandbox_mode)
	for view in [battle_view, run_view]:
		if view != null:
			view.queue_free()
	battle_view = null
	run_view = null
	if to_sandbox:
		_show_home(true)
		_show_sandbox(true)
	else:
		sandbox.visible = false
		menu.visible = true
		_show_home(false)
