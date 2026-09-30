extends Control
## Main menu: pick a patron to start a run. The single-battle sandbox sits behind a corner button.

const Data = preload("res://scripts/core/data.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const RunView = preload("res://scripts/ui/run_view.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const PlaytestOverlay = preload("res://scripts/ui/playtest_overlay.gd")
const CardPreview = preload("res://scripts/ui/card_preview.gd")

const PATRON_TILE := Vector2(380, 600)
const PATRON_ART := Vector2(356, 300)
const TITLE_CROP := Rect2(0.02, 0.28, 0.96, 0.48)
const TITLE_HEIGHT := 130
const LIST_GROUPS := {"neutral": "Neutral", "norse": "Norse", "greek": "Greek", "egypt": "Egyptian", "divine": "Divine (shrines only)", "other": "Tokens, curses and statuses"}
const RARITY_ORDER := ["Starter", "Common", "Uncommon", "Rare"]

var menu: Control
var sandbox: Control
var sandbox_button: Button
var card_list: Control = null
var battle_view: Control
var run_view: Control
var deck_option: OptionButton
var seed_box: SpinBox
var relic_checks := {}
var deck_keys: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_menu()
	_build_sandbox()
	add_child(CardPreview.new())
	add_child(PlaytestOverlay.new())


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
	var subtitle := Label.new()
	subtitle.text = "The gods are dead. Choose the pantheon whose echoes will defend the Reliquary."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	subtitle.add_theme_font_size_override("font_size", 18)
	root.add_child(subtitle)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var patrons := HBoxContainer.new()
	patrons.add_theme_constant_override("separation", 28)
	center.add_child(patrons)
	for patron in Data.PATRONS:
		patrons.add_child(_patron_tile(patron))

	sandbox_button = Button.new()
	sandbox_button.text = "Battle sandbox"
	sandbox_button.tooltip_text = "Single test battles with a chosen deck, relics, and seed."
	sandbox_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sandbox_button.position = Vector2(-180, 24)
	sandbox_button.custom_minimum_size = Vector2(156, 36)
	sandbox_button.pressed.connect(_show_sandbox.bind(true))
	add_child(sandbox_button)


func _patron_tile(patron: Dictionary) -> Button:
	var card: Dictionary = Data.CARDS[patron["card"]]
	var relic: Dictionary = Data.RELICS[patron["relic"]]
	var faction: String = card["faction"]
	var tint: Color = CardWidget.FACTION_COLORS[faction]

	var b := Button.new()
	b.custom_minimum_size = PATRON_TILE
	b.focus_mode = Control.FOCUS_NONE
	CardWidget.style(b, CardWidget.CARD_BG, tint, 3)
	b.pressed.connect(_start_run.bind(patron["card"]))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	CardWidget.place(b, box, 12, 12, -12, -12)

	var art := CardWidget.art("patrons", faction, Data.FACTION_NAMES[faction], tint, 64)
	art.custom_minimum_size = PATRON_ART
	box.add_child(art)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 15)
	text.text = "[center][font_size=26][b][color=#%s]%s[/color][/b][/font_size]\n[color=#aaaabb]%s  -  Core HP %d[/color][/center]\n[b]Starting card - %s[/b]\n[color=#c8c8d6]%s[/color]\n[b]Starting relic - %s[/b]\n[color=#c8c8d6]%s[/color]" % [
		tint.lightened(0.25).to_html(false), Data.FACTION_NAMES[faction], Data.FACTION_TITLES[faction], patron["hp"],
		card["name"], card["text"], relic["name"], relic["text"]]
	box.add_child(text)

	var begin := Label.new()
	begin.text = "Begin run"
	begin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	begin.add_theme_font_size_override("font_size", 20)
	begin.add_theme_color_override("font_color", tint.lightened(0.3))
	box.add_child(begin)
	return b


func _build_sandbox() -> void:
	sandbox = MarginContainer.new()
	sandbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		sandbox.add_theme_constant_override("margin_" + side, 40)
	sandbox.visible = false
	add_child(sandbox)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	sandbox.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Battle sandbox"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 40)
	header.add_child(title)
	var cards := Button.new()
	cards.text = "Card list"
	cards.custom_minimum_size = Vector2(180, 40)
	cards.pressed.connect(_open_card_list)
	header.add_child(cards)
	var back := Button.new()
	back.text = "Back to patrons"
	back.custom_minimum_size = Vector2(180, 40)
	back.pressed.connect(_show_sandbox.bind(false))
	header.add_child(back)

	var subtitle := Label.new()
	subtitle.text = "Single test battles. The deck and relic choices on the right apply only to these."
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	root.add_child(subtitle)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 40)
	root.add_child(columns)

	var battles := VBoxContainer.new()
	battles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battles.custom_minimum_size = Vector2(600, 0)
	battles.add_theme_constant_override("separation", 8)
	columns.add_child(battles)
	for battle in Data.BATTLES:
		var row := HBoxContainer.new()
		var button := Button.new()
		button.text = battle["name"]
		button.custom_minimum_size = Vector2(320, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_start_battle.bind(battle))
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
		header.add_child(b)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(_close_card_list)
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

	_hide_menus()
	battle_view = BattleView.new()
	add_child(battle_view)
	battle_view.exit_requested.connect(_back_to_menu)
	battle_view.start(battle, deck_key, relics, seed_value)


func _start_run(patron: String) -> void:
	var seed_value := int(seed_box.value)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	_hide_menus()
	run_view = RunView.new()
	add_child(run_view)
	run_view.exit_requested.connect(_back_to_menu)
	run_view.start(seed_value, patron)


## Sandbox battles return to the sandbox; runs return to the patron screen.
func _back_to_menu() -> void:
	var to_sandbox := battle_view != null
	for view in [battle_view, run_view]:
		if view != null:
			view.queue_free()
	battle_view = null
	run_view = null
	_show_sandbox(to_sandbox)
