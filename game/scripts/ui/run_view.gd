extends Control
## Run screen: map, rewards, shop, shrine, rest, and end screen. Fights open a BattleView.

signal exit_requested

const Data = preload("res://scripts/core/data.gd")
const Run = preload("res://scripts/core/run.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const MapCanvas = preload("res://scripts/ui/map_canvas.gd")

const MAP_SIZE := Vector2(980, 70 * Run.FLOORS)
const NODE_SIZE := Vector2(118, 40)
const NODE_COLORS := {
	"fight": Color(0.42, 0.24, 0.3), "elite": Color(0.72, 0.18, 0.24), "boss": Color(0.5, 0.1, 0.5),
	"shop": Color(0.66, 0.52, 0.14), "shrine": Color(0.28, 0.38, 0.7), "rest": Color(0.2, 0.52, 0.34),
}
const NODE_LABELS := {"fight": "Fight", "elite": "Elite", "boss": "BOSS", "shop": "Shop", "shrine": "Shrine", "rest": "Rest"}
const NODE_HELP := {
	"fight": "A Void encounter. Win for gold and a card.",
	"elite": "A Fallen Echo. Harder, but drops a relic and better cards.",
	"boss": "Defeat the boss to complete the act.",
	"shop": "Buy cards and relics, remove a card, or heal.",
	"shrine": "A strange encounter. It might be a gift, a gamble, or a trap.",
	"rest": "A sanctuary world: heal or remove a card.",
}

var run
var content: VBoxContainer
var sidebar_label: RichTextLabel
var relic_box: VBoxContainer
var deck_button: Button
var overlay: Control = null
var info_overlay: Control = null
var info_kind := ""
var fight = null
var map_button: Button
var abandon_confirm: ConfirmationDialog
var battle_view: Control = null
var flash := ""


func start(seed_value: int, patron: String) -> void:
	run = Run.new()
	run.setup(seed_value, patron)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show()


# ---------------------------------------------------------------- layout

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(320, 0)
	sidebar.add_theme_constant_override("separation", 8)
	root.add_child(sidebar)

	sidebar_label = RichTextLabel.new()
	sidebar_label.bbcode_enabled = true
	sidebar_label.fit_content = true
	sidebar_label.scroll_active = false
	sidebar.add_child(sidebar_label)

	deck_button = Button.new()
	deck_button.pressed.connect(_toggle_info.bind("deck"))
	sidebar.add_child(deck_button)
	map_button = _button("View map (M)", _toggle_info.bind("map"), sidebar)

	sidebar.add_child(_heading("Relics", 18))
	relic_box = VBoxContainer.new()
	sidebar.add_child(relic_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	abandon_confirm = ConfirmationDialog.new()
	abandon_confirm.title = "Abandon run?"
	abandon_confirm.dialog_text = "Are you sure you want to abandon this run?\nAll progress will be lost."
	abandon_confirm.ok_button_text = "Abandon"
	abandon_confirm.cancel_button_text = "Keep playing"
	abandon_confirm.confirmed.connect(func(): exit_requested.emit())
	add_child(abandon_confirm)
	_button("Abandon run", _confirm_abandon, sidebar)


func _confirm_abandon() -> void:
	abandon_confirm.popup_centered()
	abandon_confirm.get_cancel_button().grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		_toggle_info("map")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_D:
		_toggle_info("deck")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and info_overlay != null:
		_close_info()
		get_viewport().set_input_as_handled()


func _heading(text: String, size := 30) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _text(text: String, color := Color(0.8, 0.8, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, callback: Callable, parent: Control, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.disabled = not enabled
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	return row


func _update_sidebar() -> void:
	sidebar_label.text = "[font_size=22][b]Act 1[/b][/font_size]\n[font_size=18]Core HP: [b]%d[/b] / %d\nGold: [b]%d[/b][/font_size]\nFloor %d / %d   Fights won: %d\nBoss: [color=#e07ae0]%s[/color]\nSeed %d" % [
		run.core_hp, run.max_hp, run.gold, run.floor_number(), Run.FLOORS, run.fights_won,
		run.boss_name(), run.seed_value]
	deck_button.text = "View deck (D) - %d cards" % run.deck.size()
	map_button.visible = run.state != "map"
	for child in relic_box.get_children():
		child.queue_free()
	if run.relics.is_empty():
		relic_box.add_child(_text("None yet.", Color(0.6, 0.6, 0.65)))
	for id in run.relics:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = CardWidget.wrap_text(Data.RELICS[id]["text"])
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := CardWidget.art("relics", id, Data.RELICS[id]["name"], CardWidget.RELIC_COLOR, 12)
		icon.custom_minimum_size = Vector2(28, 28)
		row.add_child(icon)
		var l := _text(Data.RELICS[id]["name"])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		relic_box.add_child(row)


# ---------------------------------------------------------------- screens

func _show() -> void:
	for child in content.get_children():
		child.queue_free()
	_update_sidebar()
	match run.state:
		"map":
			_show_map()
		"combat":
			_start_combat()
		"reward":
			_show_reward()
		"shop":
			_show_shop()
		"shrine":
			_show_shrine()
		"rest":
			_show_rest()
		"victory", "defeat":
			_show_end()


func _show_map() -> void:
	content.add_child(_heading("The Dying Stars"))
	if flash != "":
		content.add_child(_text(flash, Color(1.0, 0.9, 0.55)))
		flash = ""
	content.add_child(_text("Choose your next destination (outlined in yellow). The path runs from the bottom to the boss at the top. Hover over a node for details."))
	content.add_child(_map_scroll(true))


## The map in a scroll area, scrolled so the current position is visible.
func _map_scroll(interactive: bool) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_map_canvas(interactive))
	var focus_floor: int = 0 if run.current == -1 else run.nodes[run.current]["floor"]
	var y: float = _node_pos({"index": 0, "count": 1, "floor": focus_floor}).y
	scroll.ready.connect(func():
		await get_tree().process_frame
		if is_instance_valid(scroll):
			scroll.scroll_vertical = int(y - scroll.size.y * 0.6))
	return scroll


## Draws the act map. When not interactive, the nodes can't be clicked.
func _map_canvas(interactive: bool) -> Control:
	var canvas = MapCanvas.new()
	canvas.custom_minimum_size = MAP_SIZE
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var available: Array = run.available_nodes()
	var lines: Array = []
	for node in run.nodes:
		for e in node["edges"]:
			var color := Color(0.3, 0.3, 0.36)
			var width := 2.0
			var step: int = run.path.find(node["id"])
			if step != -1 and step + 1 < run.path.size() and run.path[step + 1] == e:
				color = Color(0.3, 1.0, 0.45)
				width = 4.0
			elif node["id"] == run.current and available.has(e):
				color = Color(1.0, 0.85, 0.2)
				width = 3.0
			lines.append([_node_pos(node), _node_pos(run.nodes[e]), color, width])
	canvas.lines = lines
	canvas.queue_redraw()

	for node in run.nodes:
		var b := Button.new()
		b.text = NODE_LABELS[node["type"]]
		b.custom_minimum_size = NODE_SIZE
		b.size = NODE_SIZE
		b.position = _node_pos(node) - NODE_SIZE / 2
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = CardWidget.wrap_text(NODE_HELP[node["type"]])
		if node["type"] == "boss":
			var boss: Dictionary = run.boss_def()
			b.text = "BOSS: %s" % boss["short"]
			b.tooltip_text = CardWidget.wrap_text("%s\n%s\n%s" % [run.boss_name(), boss["hint"], NODE_HELP["boss"]])
		var reachable: bool = available.has(node["id"])
		var visited: bool = run.path.has(node["id"])
		var border := Color(0, 0, 0, 0)
		var border_w := 0
		if reachable:
			border = Color(1.0, 0.85, 0.2)
			border_w = 3
		elif visited:
			border = Color(0.3, 1.0, 0.45)
			border_w = 3
		CardWidget.style(b, NODE_COLORS[node["type"]], border, border_w)
		b.disabled = interactive and not reachable
		if not reachable and not visited:
			b.modulate = Color(1, 1, 1, 0.55)
		if node["id"] == run.current:
			b.text += " (here)"
		if interactive:
			b.pressed.connect(_on_node_pressed.bind(node["id"]))
		canvas.add_child(b)
	return canvas


func _node_pos(node: Dictionary) -> Vector2:
	var x: float = (node["index"] + 0.5) / node["count"] * MAP_SIZE.x
	var y: float = MAP_SIZE.y - 30 - node["floor"] * (MAP_SIZE.y - 60) / (Run.FLOORS - 1)
	return Vector2(x, y)


func _on_node_pressed(id: int) -> void:
	run.enter_node(id)
	_show()


func _start_combat() -> void:
	var c = run.make_combat()
	battle_view = BattleView.new()
	add_child(battle_view)
	battle_view.finished.connect(_on_combat_finished.bind(c))
	fight = c
	battle_view.map_requested.connect(_open_info.bind("map"))
	battle_view.deck_requested.connect(_open_info.bind("deck"))
	battle_view.abandon_requested.connect(_confirm_abandon)
	var title := "%s - Floor %d" % [run.battle_def()["name"], run.floor_number()]
	var bonus: Dictionary = run.enemy_bonus()
	if bonus["atk"] > 0 or bonus["hp"] > 0:
		title += "  (one enemy Empowered +%d ATK / +%d HP, +%d rounds)" % [bonus["atk"], bonus["hp"], bonus["rounds"]]
	battle_view.start_run_fight(c, title)


func _on_combat_finished(c) -> void:
	run.finish_combat(c)
	battle_view.queue_free()
	battle_view = null
	fight = null
	_close_info()
	_show()


func _show_reward() -> void:
	var r: Dictionary = run.reward
	content.add_child(_heading({"win": "Victory!", "timeout": "Time ran out"}[r["result"]]))
	if r["gold"] > 0:
		content.add_child(_text("+%d gold" % r["gold"], Color(1.0, 0.85, 0.3)))
	else:
		content.add_child(_text("No reward. The Core took the surviving enemies' Threat."))
	for note in r["notes"]:
		content.add_child(_text(note))
	if r["relic"] != "":
		content.add_child(_text("The Echo leaves behind a relic:", Color(1.0, 0.85, 0.3)))
		var relic_row := _row()
		var rb := CardWidget.relic_button(r["relic"])
		rb.disabled = true
		relic_row.add_child(rb)
	if r["cards"].is_empty():
		_button("Continue", _take_reward.bind(-1), content)
		return
	content.add_child(_text("Choose a card to add to your deck, or skip:"))
	var row := _row()
	for i in r["cards"].size():
		var b := CardWidget.card_button(r["cards"][i])
		b.pressed.connect(_take_reward.bind(i))
		row.add_child(b)
	_button("Skip card", _take_reward.bind(-1), content)


func _take_reward(i: int) -> void:
	run.finish_reward(i)
	_show()


func _show_shop() -> void:
	content.add_child(_heading("Shop"))
	content.add_child(_text("A merchant-echo drifts between the stars, trading relics of dead gods. You have %d gold." % run.gold))
	if flash != "":
		content.add_child(_text(flash, Color(1.0, 0.6, 0.5)))
		flash = ""

	content.add_child(_heading("Cards", 20))
	var row := _row()
	for i in run.shop["cards"].size():
		var item: Dictionary = run.shop["cards"][i]
		var col := VBoxContainer.new()
		var b := CardWidget.card_button(item["id"])
		b.disabled = item["sold"] or run.gold < item["price"]
		b.modulate = Color(1, 1, 1, 0.4 if b.disabled else 1.0)
		b.pressed.connect(func(): _shop_result(run.buy_card(i)))
		col.add_child(b)
		col.add_child(_text("SOLD" if item["sold"] else "%d gold" % item["price"]))
		row.add_child(col)

	if not run.shop["relics"].is_empty():
		content.add_child(_heading("Relics", 20))
		var relic_row := _row()
		for i in run.shop["relics"].size():
			var item: Dictionary = run.shop["relics"][i]
			var col := VBoxContainer.new()
			var b := CardWidget.relic_button(item["id"])
			b.disabled = item["sold"] or run.gold < item["price"]
			b.modulate = Color(1, 1, 1, 0.4 if b.disabled else 1.0)
			b.pressed.connect(func(): _shop_result(run.buy_relic(i)))
			col.add_child(b)
			col.add_child(_text("SOLD" if item["sold"] else "%d gold" % item["price"]))
			relic_row.add_child(col)

	content.add_child(_heading("Services", 20))
	var services := _row()
	_button("Remove a card (%d gold)" % Run.REMOVE_PRICE, func():
		_open_deck("Choose a card to remove", func(i): _shop_result(run.buy_remove(i))), services, run.can_buy_remove())
	_button("Heal %d Core HP (%d gold)" % [Run.HEAL_AMOUNT, Run.HEAL_PRICE], func(): _shop_result(run.buy_heal()), services, run.can_buy_heal())
	_button("Leave the shop", func():
		run.leave_node()
		_show(), content)


func _shop_result(err: String) -> void:
	flash = err
	_show()


func _show_shrine() -> void:
	var ev: Dictionary = Data.EVENTS[run.shrine["event"]]
	content.add_child(_heading(run.shrine_text(ev["name"])))
	content.add_child(_text(run.shrine_description()))
	if run.shrine["result"] != "":
		content.add_child(_text(run.shrine["result"], Color(1.0, 0.85, 0.3)))

	if run.shrine["pending"] == "choose":
		content.add_child(_text("Choose a card, or leave it:"))
		var row := _row()
		for i in run.shrine["cards"].size():
			var b := CardWidget.card_button(run.shrine["cards"][i])
			b.pressed.connect(func():
				run.shrine_take_card(i)
				_show())
			row.add_child(b)
		_button("Take nothing", func():
			run.shrine_take_card(-1)
			_show(), content)
		return

	if run.shrine["done"]:
		_button("Continue", func():
			run.leave_node()
			_show(), content)
		return

	var options: Array = run.shrine_options()
	for i in options.size():
		_button(run.shrine_text(options[i]["label"]), _on_shrine_option.bind(i), content, run.can_choose(i))


func _on_shrine_option(i: int) -> void:
	run.choose_option(i)
	if run.shrine["pending"] == "remove":
		_open_deck("Choose a card to remove", func(idx):
			run.shrine_remove(idx)
			_show(), func():
			run.shrine_cancel()
			_show())
		return
	_show()


func _show_rest() -> void:
	content.add_child(_heading("Sanctuary World"))
	content.add_child(_text("A quiet world the Void has not yet reached. The gods can recover here, or you can let one of them rest for good."))
	_button("Rest: heal %d Core HP" % Run.REST_HEAL, func():
		flash = "You rest and heal %d Core HP." % run.rest_heal()
		_show(), content, run.core_hp < run.max_hp)
	_button("Meditate: remove a card from your deck", func():
		_open_deck("Choose a card to remove", func(i):
			run.rest_remove(i)
			flash = "A card is laid to rest."
			_show()), content, run.deck.size() > Run.MIN_DECK)


func _show_end() -> void:
	var won: bool = run.state == "victory"
	if won:
		var faction: String = Data.CARDS[run.patron]["faction"]
		var scene := CardWidget.art("victory", faction, Data.CARDS[run.patron]["name"], CardWidget.FACTION_COLORS[faction], 64)
		if scene is TextureRect:
			scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		scene.custom_minimum_size = Vector2(0, 360)
		scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(scene)
	content.add_child(_heading("The Herald falls. Act 1 complete!" if won else "The Reliquary Core is lost.", 36))
	content.add_child(_text("Floor reached: %d / %d\nFights won: %d\nCore HP: %d\nGold: %d\nDeck: %d cards\nRelics: %d" % [
		run.floor_number(), Run.FLOORS, run.fights_won, max(run.core_hp, 0), run.gold, run.deck.size(), run.relics.size()]))
	_button("View final deck", func(): _open_deck("Final deck"), content)
	_button("Back to menu", func(): exit_requested.emit(), content)


# ---------------------------------------------------------------- overlays

## Opens a full-screen panel above everything, including a running fight.
func _new_overlay(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	sb.set_content_margin_all(30)
	overlay.add_theme_stylebox_override("panel", sb)
	add_child(overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	overlay.add_child(box)
	box.add_child(_heading(title))
	return box


## The map ("map") and deck ("deck") open on their own layer above everything (fights,
## shops, shrines, card pickers), so closing it returns to exactly what was showing.
func _toggle_info(kind: String) -> void:
	if info_kind == kind:
		_close_info()
	elif kind == "map" and run.state == "map":
		_close_info()
	else:
		_open_info(kind)


func _open_info(kind: String) -> void:
	_close_info()
	info_kind = kind
	info_overlay = PanelContainer.new()
	info_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	sb.set_content_margin_all(30)
	info_overlay.add_theme_stylebox_override("panel", sb)
	add_child(info_overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	info_overlay.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var title := _heading("The Dying Stars" if kind == "map" else "Your deck")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var other := _button("View deck (D)" if kind == "map" else "View map (M)", _toggle_info.bind("deck" if kind == "map" else "map"), header)
	other.custom_minimum_size = Vector2(180, 40)
	other.visible = kind == "map" or run.state != "map"
	var close := _button("Close (%s)" % ("M" if kind == "map" else "D"), _close_info, header)
	close.custom_minimum_size = Vector2(160, 40)
	if kind == "map":
		box.add_child(_text("Your path so far is outlined in green, and your next choices in yellow. Hover over a node for details."))
		box.add_child(_map_scroll(false))
	else:
		_fill_deck(box)


func _close_info() -> void:
	if info_overlay != null:
		info_overlay.queue_free()
		info_overlay = null
		info_kind = ""


## The run deck, plus the fight's card piles when a fight is in progress.
func _fill_deck(box: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	scroll.add_child(sections)
	if battle_view != null and fight != null:
		var piles := [
			["Draw pile (shown sorted, drawn in random order)", fight.deck],
			["Discard pile", fight.discard],
			["Exhausted this fight", fight.exhausted],
		]
		for pile in piles:
			sections.add_child(_heading("%s - %d" % [pile[0], pile[1].size()], 18))
			if not pile[1].is_empty():
				sections.add_child(_card_grid(pile[1].map(func(card): return card["id"])))
	sections.add_child(_heading("Full deck - %d" % run.deck.size(), 18))
	sections.add_child(_card_grid(run.deck))


func _card_grid(ids: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var sorted := ids.duplicate()
	sorted.sort()
	for id in sorted:
		grid.add_child(CardWidget.card_button(id))
	return grid


func _open_deck(title: String, on_pick := Callable(), on_cancel := Callable()) -> void:
	var box := _new_overlay(title)
	if on_pick.is_valid():
		box.add_child(_text("Click a card to choose it."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var order: Array = range(run.deck.size())
	order.sort_custom(func(a, b): return run.deck[a] < run.deck[b])
	for i in order:
		var b := CardWidget.card_button(run.deck[i])
		if on_pick.is_valid():
			b.pressed.connect(func():
				_close_overlay()
				on_pick.call(i))
		grid.add_child(b)

	_button("Cancel" if on_pick.is_valid() else "Close", func():
		_close_overlay()
		if on_cancel.is_valid():
			on_cancel.call(), box)


func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
