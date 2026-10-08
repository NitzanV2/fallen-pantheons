extends Control
## Run screen: map, rewards, shop, shrine, rest, and end screen. Fights open a BattleView.

signal exit_requested

const Data = preload("res://scripts/core/data.gd")
const Run = preload("res://scripts/core/run.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const MapCanvas = preload("res://scripts/ui/map_canvas.gd")

const MAP_SIZE := Vector2(1200, 96 * Run.FLOORS)
const NODE_SIZES := {"fight": 66.0, "elite": 76.0, "boss": 150.0, "shop": 66.0, "shrine": 66.0, "rest": 66.0}
const NODE_COLORS := {
	"fight": Color(0.62, 0.52, 0.78), "elite": Color(0.92, 0.32, 0.3), "boss": Color(0.85, 0.12, 0.15),
	"shop": Color(0.95, 0.78, 0.35), "shrine": Color(0.4, 0.62, 1.0), "rest": Color(0.4, 0.85, 0.5),
}
const GOLD := Color(0.95, 0.78, 0.35)
const ART_SIZE := Vector2(540, 720)
const SANDBOX_GOLD := 150
const REACHABLE := Color(1.0, 0.88, 0.45)
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
var power_box: Button
var deck_button: Button
var overlay: Control = null
var info_overlay: Control = null
var info_kind := ""
var fight = null
var map_button: Button
var abandon_confirm: ConfirmationDialog
var battle_view: Control = null
var flash := ""
## Set for sandbox event tests: leaving the event returns to the sandbox instead of the map.
var sandbox_mode := false


func start(seed_value: int, patron: String, power := "") -> void:
	run = Run.new()
	run.setup(seed_value, patron, power)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show()


## Sandbox: opens one event (or "shop" / "rest") in a fresh run with some spare gold.
func start_test(seed_value: int, patron: String, event: String, pantheon := "") -> void:
	sandbox_mode = true
	run = Run.new()
	run.setup(seed_value, patron)
	run.gold = SANDBOX_GOLD
	match event:
		"shop":
			run._generate_shop()
			run.state = "shop"
		"rest":
			run.state = "rest"
		_:
			run.start_event(event)
			if pantheon != "":
				run.shrine["pantheon"] = pantheon
			run.state = "shrine"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show()


# ---------------------------------------------------------------- layout

func _build() -> void:
	var fill := ColorRect.new()
	fill.color = Color(0.04, 0.03, 0.07)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fill)
	var bg := TextureRect.new()
	bg.texture = load("res://art/ui/menu_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.55, 0.55, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(320, 0)
	side_panel.add_theme_stylebox_override("panel", CardWidget.glass_style(16, 18))
	root.add_child(side_panel)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 8)
	side_panel.add_child(sidebar)

	sidebar_label = RichTextLabel.new()
	sidebar_label.bbcode_enabled = true
	sidebar_label.fit_content = true
	sidebar_label.scroll_active = false
	sidebar.add_child(sidebar_label)

	power_box = Button.new()
	power_box.custom_minimum_size = Vector2(0, 94)
	power_box.pressed.connect(_open_power_tree)
	CardWidget.style_button(power_box)
	sidebar.add_child(power_box)

	deck_button = Button.new()
	deck_button.custom_minimum_size = Vector2(0, 40)
	deck_button.pressed.connect(_toggle_info.bind("deck"))
	CardWidget.style_button(deck_button)
	sidebar.add_child(deck_button)
	CardWidget.button_icon(deck_button, "ui_deck", 26)
	map_button = _button("View map (M)", _toggle_info.bind("map"), sidebar)
	CardWidget.button_icon(map_button, "ui_map", 26)

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
	_button("Back to sandbox" if sandbox_mode else "Abandon run", _confirm_abandon, sidebar)


func _confirm_abandon() -> void:
	if sandbox_mode:
		exit_requested.emit()
		return
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
	return CardWidget.heading(text, size, GOLD if size >= 30 else Color(0.92, 0.88, 0.8))


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
	CardWidget.style_button(b, false, 15)
	parent.add_child(b)
	return b


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	return row


func _update_sidebar() -> void:
	sidebar_label.text = ("[font=res://fonts/ui_font.tres][font_size=26][color=#f2c75a]Act %d[/color][/font_size][/font]\n" % run.act) + "[font_size=18][img=22]res://art/icons/hp.png[/img] Core [b]%d[/b] / %d\n[img=22]res://art/icons/opt_gold.png[/img] Gold [b]%d[/b][/font_size]\n[color=#a8a8b8]Floor[/color] %d / %d   [color=#a8a8b8]Fights won[/color] %d\n[color=#a8a8b8]Boss:[/color] [color=#ff7a70]%s[/color]\n[color=#77778a]Seed %d[/color]" % [
		run.core_hp, run.max_hp, run.gold, run.floor_number(), Run.FLOORS, run.fights_won,
		run.boss_name(), run.seed_value]
	_fill_power_box()
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


## The god power in the sidebar: emblem, name and progress toward the next upgrade. Click for the tree.
func _fill_power_box() -> void:
	for child in power_box.get_children():
		child.queue_free()
	var power: Dictionary = Data.GOD_POWERS[run.power]
	power_box.tooltip_text = CardWidget.wrap_text("%s (once per fight; after use it recharges for %d floors)\n%s\n\nClick to see the upgrade tree." % [
		power["name"], Data.POWER_COOLDOWN_FLOORS, Data.power_text(run.power, run.power_nodes)])
	var charged: bool = run.power_charged(run.floor_number() + 1)
	var disc := CardWidget.power_disc(run.power, 54, charged)
	disc.position = Vector2(10, 20)
	disc.modulate = Color(1, 1, 1, 1.0 if charged else 0.5)
	power_box.add_child(disc)
	var title := CardWidget.heading(power["name"], 16, Color(0.95, 0.92, 0.85))
	CardWidget.place(power_box, title, 74, 10, -8, 34)
	var charge := CardWidget._label("Ready" if charged else "Recharging - ready on floor %d" % run.power_ready_floor, 12,
		Color(0.55, 0.9, 0.6) if charged else Color(0.95, 0.7, 0.45), false)
	CardWidget.place(power_box, charge, 74, 36, -8, 54)
	var next: int = run.next_threshold()
	var status := "%d/%d upgrades" % [run.power_nodes.size(), Data.POWER_THRESHOLDS.size() + Data.ACTS.size() - 1]
	if next != -1:
		status += "   %s cards %d/%d" % [Data.FACTION_NAMES[run.main_pantheon()], run.devotion, next]
	var l := CardWidget._label(status, 12, Color(0.68, 0.66, 0.76), false)
	CardWidget.place(power_box, l, 74, 56, -8, 76)
	for c in [title, charge, l]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shown on the map step after a card pushed devotion past a threshold.
func _show_upgrade() -> void:
	var power: Dictionary = Data.GOD_POWERS[run.power]
	var box := _centered_panel("%s answers your devotion" % power["god"])
	box.get_parent().custom_minimum_size = Vector2(980, 0)
	box.add_child(_power_header(run.power))
	var from_devotion: int = Data.POWER_THRESHOLDS.filter(func(t): return run.devotion >= t).size()
	if run.power_nodes.size() < from_devotion:
		box.add_child(_rich("You have drafted [b]%d %s cards[/b]. Choose one upgrade for your god power." % [run.devotion, Data.FACTION_NAMES[run.main_pantheon()]]))
	else:
		box.add_child(_rich("Your victory over the act boss earns [b]a free upgrade[/b]. Choose one for your god power."))
	box.add_child(_power_tree(true))


func _open_power_tree() -> void:
	var box := _new_overlay(Data.GOD_POWERS[run.power]["name"])
	box.add_child(_power_header(run.power))
	box.add_child(_rich("Upgrades are earned at %s %s cards drafted (%d so far). The Pact needs %d cards from other pantheons (%d so far)." % [
		", ".join(Data.POWER_THRESHOLDS.map(func(t): return str(t))), Data.FACTION_NAMES[run.main_pantheon()], run.devotion, Data.PACT_CARDS, run.foreign]))
	box.add_child(_power_tree(false))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var close := _button("Close", _close_overlay, box)
	close.custom_minimum_size = Vector2(200, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _power_header(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var disc := CardWidget.power_disc(id, 76, true)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(disc)
	var text := _rich("[b]Base:[/b] %s" % Data.GOD_POWERS[id]["text"], 17)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	return row


## One column per branch, tiers top to bottom. When `pickable`, the nodes you can take are buttons.
func _power_tree(pickable: bool) -> HBoxContainer:
	var power: Dictionary = Data.GOD_POWERS[run.power]
	var options: Array = run.upgrade_options()
	var columns := {}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for n in power["nodes"]:
		var node: Dictionary = power["nodes"][n]
		if not columns.has(node["branch"]):
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 10)
			var label := CardWidget.heading(node["branch"].to_upper(), 16, GOLD)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(label)
			row.add_child(col)
			columns[node["branch"]] = col
		var state := "owned" if run.power_nodes.has(n) else ("open" if options.has(n) else "locked")
		columns[node["branch"]].add_child(_tree_node(n, node, state, pickable and state == "open"))
	return row


func _tree_node(id: String, node: Dictionary, state: String, pickable: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 110)
	CardWidget.style_button(b, false)
	var accent: Color = {"owned": GOLD, "open": REACHABLE, "locked": Color(0.5, 0.48, 0.56)}[state]
	for s in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s)
		sb.border_color = Color(accent, {"owned": 0.95, "open": 0.9 if pickable else 0.45, "locked": 0.25}[state])
		sb.set_border_width_all(2 if state == "owned" or pickable else 1)
		if state == "owned":
			sb.bg_color = sb.bg_color.lerp(GOLD, 0.16)
		if pickable:
			sb.shadow_color = Color(accent, 0.35 if s == "hover" else 0.18)
			sb.shadow_size = 14 if s == "hover" else 8
	if pickable:
		b.pressed.connect(_pick_upgrade.bind(id))
	else:
		b.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(b, box, 14, 10, -14, -10)
	var tag: String = {"owned": "OWNED", "open": "CHOOSE" if pickable else ("OPEN AT NEXT UPGRADE" if run.next_threshold() != -1 else "NOT CHOSEN"), "locked": _requirement(node)}[state]
	var head := CardWidget._label("Tier %d  -  %s" % [node["tier"], tag] if node["branch"] != "Pact" else tag, 11, Color(accent, 0.9), true)
	box.add_child(head)
	var title := CardWidget.heading(node["name"], 16, Color(0.96, 0.94, 0.88) if state != "locked" else Color(0.7, 0.68, 0.75))
	box.add_child(title)
	var text := CardWidget._label(node["text"], 13, Color(0.82, 0.8, 0.86) if state != "locked" else Color(0.6, 0.58, 0.66), false)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	for c in [head, title, text]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _requirement(node: Dictionary) -> String:
	if node["branch"] == "Pact":
		return "NEEDS %d CARDS FROM OTHER PANTHEONS (%d)" % [Data.PACT_CARDS, run.foreign]
	if node["tier"] >= 3:
		return "NEEDS TIER 2 AND %d %s CARDS (%d)" % [Data.TIER3_DEVOTION, Data.FACTION_NAMES[run.main_pantheon()].to_upper(), run.devotion]
	return "NEEDS TIER %d" % (node["tier"] - 1)


func _pick_upgrade(id: String) -> void:
	var err: String = run.choose_upgrade(id)
	if err == "":
		var node: Dictionary = Data.GOD_POWERS[run.power]["nodes"][id]
		flash = "%s: %s" % [node["name"], node["text"]]
	_show()


# ---------------------------------------------------------------- screens

func _show() -> void:
	if sandbox_mode and run.state == "map":
		exit_requested.emit()
		return
	for child in content.get_children():
		child.queue_free()
	_update_sidebar()
	match run.state:
		"map":
			if run.pending_upgrades() > 0:
				_show_upgrade()
			else:
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
		"act_complete":
			_show_act_complete()
		"victory", "defeat":
			_show_end()
	if run.state != "combat":
		_fade_in(content)


func _fade_in(c: CanvasItem, duration := 0.3) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_map() -> void:
	content.add_child(_map_header())
	if flash != "":
		content.add_child(_text(flash, Color(1.0, 0.9, 0.55)))
		flash = ""
	content.add_child(_text("Choose your next destination (the glowing nodes). The path climbs from the Reliquary to the boss at the top. Hover over a node for details."))
	content.add_child(_map_scroll(true))


## Title plus a legend of the node icons.
func _map_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var title := _heading("Act %d: %s" % [run.act, run.act_def()["name"]])
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for type in ["fight", "elite", "shop", "shrine", "rest"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.tooltip_text = CardWidget.wrap_text(NODE_HELP[type])
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := _node_face(type, 30, NODE_COLORS[type], NODE_COLORS[type], false)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var l := _text(NODE_LABELS[type], Color(0.85, 0.83, 0.9))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(l)
		header.add_child(item)
	return header


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
	canvas.background = load("res://art/map/background_soft.jpg")
	canvas.tint = run.act_def()["map_tint"]

	var available: Array = run.available_nodes()
	var paths: Array = []
	for node in run.nodes:
		for e in node["edges"]:
			var style := "normal"
			var step: int = run.path.find(node["id"])
			if step != -1 and step + 1 < run.path.size() and run.path[step + 1] == e:
				style = "taken"
			elif node["id"] == run.current and available.has(e):
				style = "next"
			paths.append([_node_pos(node), _node_pos(run.nodes[e]), style,
				NODE_SIZES[node["type"]] / 2, NODE_SIZES[run.nodes[e]["type"]] / 2])
	if run.current == -1:
		for id in available:
			var target: Dictionary = run.nodes[id]
			paths.append([_start_pos(), _node_pos(target), "next", 40.0, NODE_SIZES[target["type"]] / 2])
	else:
		for id in run.nodes.filter(func(n): return n["floor"] == 0).map(func(n): return n["id"]):
			var style := "taken" if run.path.size() > 0 and run.path[0] == id else "normal"
			var first: Dictionary = run.nodes[id]
			paths.append([_start_pos(), _node_pos(first), style, 40.0, NODE_SIZES[first["type"]] / 2])
	canvas.paths = paths

	var start := _node_face("start", 80, GOLD, GOLD, run.current == -1)
	start.position = _start_pos() - start.size / 2
	start.tooltip_text = "The Reliquary: where every run begins. Defend its Core on the way to the boss."
	start.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(start)

	var current_floor: int = -1 if run.current == -1 else run.nodes[run.current]["floor"]
	for node in run.nodes:
		var reachable: bool = available.has(node["id"])
		var visited: bool = run.path.has(node["id"])
		var passed: bool = node["floor"] <= current_floor and not visited
		var b := _map_node(node, reachable and interactive, visited, passed, node["id"] == run.current)
		if interactive and reachable:
			b.pressed.connect(_on_node_pressed.bind(node["id"]))
		canvas.add_child(b)
	return canvas


## A glass disc with the node's glyph. Reachable nodes glow, breathe and carry a rotating orbit;
## visited nodes dim to gold, passed ones fade out. Nodes fade in floor by floor when the map opens.
func _map_node(node: Dictionary, reachable: bool, visited: bool, passed: bool, here: bool) -> Button:
	var type: String = node["type"]
	var d: float = NODE_SIZES[type]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(d, d)
	b.position = _node_pos(node) - b.size / 2
	b.pivot_offset = b.size / 2
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.tooltip_text = CardWidget.wrap_text("%s\n%s" % [NODE_LABELS[type], NODE_HELP[type]])

	var tint: Color = NODE_COLORS[type]
	var art := ""
	var focus := -1.0
	if type == "boss":
		var boss: Dictionary = run.boss_def()
		var boss_id: String = boss["enemies"][0][0]
		focus = CardWidget.ART_FOCUS.get(boss_id, -1.0)
		for pattern in CardWidget.ART_PATHS:
			if ResourceLoader.exists(pattern % ["enemies", boss_id]):
				art = pattern % ["enemies", boss_id]
		b.tooltip_text = CardWidget.wrap_text("BOSS: %s\n%s\n%s" % [run.boss_name(), boss["hint"], NODE_HELP["boss"]])
	var ring: Color = REACHABLE if reachable else (GOLD if visited or here else tint)
	var face := _node_face(type, d, tint, ring, reachable or here, art, focus)
	b.add_child(face)

	if type == "boss":
		var name_label := CardWidget.heading(run.boss_def()["short"].to_upper(), 22, Color(1.0, 0.6, 0.55))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(260, 30)
		name_label.position = Vector2(d / 2 - 130, d + 8)
		b.add_child(name_label)
	if visited and not here:
		face.modulate = Color(0.7, 0.66, 0.6)
	elif passed:
		b.modulate = Color(1, 1, 1, 0.3)
	elif not reachable and not here:
		face.modulate = Color(0.78, 0.76, 0.86)
	if here:
		b.add_child(_pill("YOU", Vector2(-36, d / 2)))

	if reachable:
		var orbit := OrbitRing.new()
		orbit.color = REACHABLE
		orbit.size = Vector2(d + 18, d + 18)
		orbit.position = Vector2(-9, -9)
		orbit.pivot_offset = orbit.size / 2
		b.add_child(orbit)
		b.move_child(orbit, 0)
		orbit.create_tween().set_loops().tween_property(orbit, "rotation", TAU, 7.0).from(0.0)
		var breathe := face.create_tween().set_loops()
		breathe.tween_property(face, "modulate", Color(1.15, 1.12, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(face, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)
		b.mouse_entered.connect(func():
			b.create_tween().tween_property(b, "scale", Vector2(1.14, 1.14), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		b.mouse_exited.connect(func():
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	else:
		b.mouse_filter = Control.MOUSE_FILTER_PASS

	var target_alpha := b.modulate.a
	b.modulate.a = 0.0
	b.scale = Vector2(0.7, 0.7)
	var intro := b.create_tween().set_parallel(true)
	var delay: float = 0.15 + node["floor"] * 0.035
	intro.tween_property(b, "modulate:a", target_alpha, 0.35).set_delay(delay)
	intro.tween_property(b, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b


## The disc behind every map icon: dark glass, a soft glow in the ring colour, a hairline inner ring
## and the type's glyph (or, for the boss, its portrait clipped to the circle).
func _node_face(type: String, d: float, tint: Color, ring: Color, glow: bool, art := "", focus := -1.0) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(d, d)
	root.pivot_offset = root.size / 2

	var disc := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.06, 0.05, 0.1, 0.9)
	dsb.set_corner_radius_all(int(d))
	dsb.corner_detail = 24
	dsb.shadow_color = Color(ring, 0.5) if glow else Color(0, 0, 0, 0.55)
	dsb.shadow_size = int(d * 0.28) if glow else int(d * 0.1)
	disc.add_theme_stylebox_override("panel", dsb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(root, disc, 0, 0, -0.001, -0.001)

	if art != "":
		var mask := Panel.new()
		var msb := StyleBoxFlat.new()
		msb.bg_color = Color(0.05, 0.05, 0.1)
		msb.set_corner_radius_all(int(d))
		msb.corner_detail = 24
		mask.add_theme_stylebox_override("panel", msb)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		CardWidget.place(root, mask, 3, 3, -3.001, -3.001)
		var tex := TextureRect.new()
		tex.texture = load(art)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CardWidget.place(mask, tex, 0, 0, -0.001, -0.001)
		if focus >= 0.0:
			CardWidget.focus_art(tex, focus, 1.8)
	else:
		var glyph := TextureRect.new()
		glyph.texture = load("res://art/glyphs/%s.svg" % type)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.modulate = tint.lightened(0.25)
		var inset := d * 0.24
		CardWidget.place(root, glyph, inset, inset, -inset - 0.001, -inset - 0.001)

	for layer in [[Color(ring, 0.95), max(2, int(d / 28)), 0.0], [Color(ring, 0.22), 1, d * 0.1]]:
		var edge := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = layer[0]
		sb.set_border_width_all(layer[1])
		sb.set_corner_radius_all(int(d))
		sb.corner_detail = 24
		sb.anti_aliasing_size = 1.2
		edge.add_theme_stylebox_override("panel", sb)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inset: float = layer[2]
		CardWidget.place(root, edge, inset, inset, -inset - 0.001, -inset - 0.001)
	return root


## A small rounded label centred on `center`, e.g. the "YOU" marker.
func _pill(text: String, center: Vector2) -> PanelContainer:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.78, 0.38)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.shadow_color = Color(1.0, 0.75, 0.3, 0.4)
	sb.shadow_size = 6
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := CardWidget.heading(text, 11, Color(0.15, 0.09, 0.03))
	l.remove_theme_color_override("font_shadow_color")
	pill.add_child(l)
	pill.position = center - Vector2(24, 10)
	pill.custom_minimum_size = Vector2(48, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return pill


## Three thin arcs that slowly circle a node you can travel to.
class OrbitRing extends Control:
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := size.x / 2 - 2
		for k in 3:
			var a := k * TAU / 3.0
			draw_arc(c, r, a, a + TAU / 5.0, 24, Color(color, 0.85), 2.0, true)
			draw_arc(c, r, a, a + TAU / 5.0, 24, Color(color, 0.18), 6.0, true)


## Nodes spread across the width with a small, stable wobble so the map doesn't look like a grid.
func _node_pos(node: Dictionary) -> Vector2:
	var margin: float = MAP_SIZE.x * 0.12
	var x: float = margin + (node["index"] + 0.5) / node["count"] * (MAP_SIZE.x - 2 * margin)
	var top := 110.0
	var bottom := 170.0
	var y: float = MAP_SIZE.y - bottom - node["floor"] * (MAP_SIZE.y - top - bottom) / (Run.FLOORS - 1)
	var id: int = node.get("id", 0)
	if node.get("count", 1) > 1:
		x += sin(id * 12.9898) * 26.0
		y += cos(id * 7.233) * 10.0
	return Vector2(x, y)


## The Reliquary at the bottom of the map, where every run begins.
func _start_pos() -> Vector2:
	return Vector2(MAP_SIZE.x / 2, MAP_SIZE.y - 60)


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
	if bonus["count"] > 0:
		title += "  (%s Empowered +%d ATK / +%d HP, +%d rounds)" % [
			"one enemy" if bonus["count"] == 1 else "%d enemies" % bonus["count"], bonus["atk"], bonus["hp"], bonus["rounds"]]
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
	var box := _centered_panel({"win": "Victory!", "timeout": "Time ran out"}[r["result"]])
	if r["gold"] > 0:
		box.add_child(_icon_line("opt_gold", "+%d gold" % r["gold"], GOLD))
	else:
		box.add_child(_rich("No reward. The Core took the surviving enemies' Threat."))
	for note in r["notes"]:
		box.add_child(_rich(note))
	if r["relic"] != "":
		box.add_child(_icon_line("opt_relic", "The Echo leaves behind a relic:", GOLD))
		var rb := CardWidget.relic_button(r["relic"])
		rb.disabled = true
		box.add_child(_centered(rb))
	if r["cards"].is_empty():
		_option("Continue.", "opt_leave", _take_reward.bind(-1), box)
		return
	box.add_child(_icon_line("opt_card", "Choose a card to add to your deck, or skip:", Color(0.92, 0.88, 0.8)))
	var row := _card_row(box)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in r["cards"].size():
		var b := CardWidget.card_button(r["cards"][i])
		b.pressed.connect(_take_reward.bind(i))
		row.add_child(b)
	_option("Skip the card.", "opt_leave", _take_reward.bind(-1), box)


func _take_reward(i: int) -> void:
	run.finish_reward(i)
	_show()


func _show_shop() -> void:
	var box := _scene("res://art/events/shop.jpg", "The Wandering Market",
		"A merchant-echo drifts between the stars, trading relics of dead gods. You have [color=#f2c75a][b]%d gold[/b][/color]." % run.gold)
	if flash != "":
		box.add_child(_rich(flash, 16, Color(1.0, 0.6, 0.5)))
		flash = ""

	var row := _card_row(box)
	for i in run.shop["cards"].size():
		var item: Dictionary = run.shop["cards"][i]
		var b := CardWidget.card_button(item["id"])
		b.pressed.connect(func(): _shop_result(run.buy_card(i)))
		row.add_child(_shop_item(b, item))

	if not run.shop["relics"].is_empty():
		var relic_row := _card_row(box)
		for i in run.shop["relics"].size():
			var item: Dictionary = run.shop["relics"][i]
			var b := CardWidget.relic_button(item["id"])
			b.pressed.connect(func(): _shop_result(run.buy_relic(i)))
			relic_row.add_child(_shop_item(b, item))

	var services := HBoxContainer.new()
	services.add_theme_constant_override("separation", 10)
	box.add_child(services)
	for b in [
		_option("Remove a card: %d gold" % Run.REMOVE_PRICE, "opt_remove", func():
			_open_deck("Choose a card to remove", func(i): _shop_result(run.buy_remove(i))), services, run.can_buy_remove()),
		_option("Heal %d Core HP: %d gold" % [Run.HEAL_AMOUNT, Run.HEAL_PRICE], "opt_heal", func(): _shop_result(run.buy_heal()), services, run.can_buy_heal()),
		_option("Leave the market.", "opt_leave", func():
			run.leave_node()
			_show(), services),
	]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## A shop card or relic with its price tag underneath; sold or unaffordable items fade out.
func _shop_item(b: Button, item: Dictionary) -> VBoxContainer:
	b.disabled = item["sold"] or run.gold < item["price"]
	b.modulate = Color(1, 1, 1, 0.4 if b.disabled else 1.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(b)
	if item["sold"]:
		var sold := CardWidget._label("SOLD", 18, Color(0.6, 0.58, 0.55), true)
		sold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sold)
	else:
		var tag := _icon_line("opt_gold", "", GOLD)
		tag.alignment = BoxContainer.ALIGNMENT_CENTER
		tag.add_child(CardWidget.number_label(str(item["price"]), 18, GOLD if run.gold >= item["price"] else Color(1.0, 0.5, 0.45)))
		col.add_child(tag)
	return col


func _shop_result(err: String) -> void:
	flash = err
	_show()


func _show_shrine() -> void:
	var id: String = run.shrine["event"]
	var ev: Dictionary = Data.EVENTS[id]
	if id == "pantheon_shrine":
		id += "_" + run.shrine["pantheon"]
	var box := _scene("res://art/events/%s.jpg" % id, run.shrine_text(ev["name"]), run.shrine_description())
	if run.shrine["result"] != "":
		box.add_child(_rich("[i]%s[/i]" % run.shrine["result"], 18, Color(1.0, 0.85, 0.45)))

	if run.shrine["pending"] == "choose":
		box.add_child(_icon_line("opt_card", "Choose a card, or leave it:", Color(0.92, 0.88, 0.8)))
		var row := _card_row(box)
		for i in run.shrine["cards"].size():
			var b := CardWidget.card_button(run.shrine["cards"][i])
			b.pressed.connect(func():
				run.shrine_take_card(i)
				_show())
			row.add_child(b)
		_option("Take nothing.", "opt_leave", func():
			run.shrine_take_card(-1)
			_show(), box)
		return

	if run.shrine["done"]:
		_option("Continue.", "opt_leave", func():
			run.leave_node()
			_show(), box)
		return

	var options: Array = run.shrine_options()
	for i in options.size():
		_option(run.shrine_text(options[i]["label"]), _option_icon(options[i]), _on_shrine_option.bind(i), box, run.can_choose(i))


## Picks the icon for an event option from what it costs or does.
func _option_icon(opt: Dictionary) -> String:
	var cost: Dictionary = opt.get("cost", {})
	var fx: Dictionary = opt.get("fx", {})
	if cost.is_empty() and fx.is_empty() and not opt.has("outcomes"):
		return "opt_leave"
	if cost.has("max_hp"):
		return "opt_max_hp"
	if cost.has("hp"):
		return "hp"
	if opt.has("outcomes"):
		return "opt_dice"
	if cost.has("gold"):
		return "opt_gold"
	if fx.has("remove") or fx.has("remove_random"):
		return "opt_remove"
	if fx.has("choose") or fx.has("card"):
		return "opt_card"
	if fx.has("relic"):
		return "opt_relic"
	if fx.get("hp", 0) > 0:
		return "opt_heal"
	if fx.get("hp", 0) < 0:
		return "hp"
	if fx.has("gold"):
		return "opt_gold"
	return "opt_curse"


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
	var box := _scene("res://art/events/rest.jpg", "Sanctuary World",
		"A quiet world the Void has not yet reached. The gods can recover here, or you can let one of them rest for good.")
	box.add_child(_rich("Core HP: [b]%d[/b] / %d" % [run.core_hp, run.max_hp], 17, Color(0.75, 0.75, 0.82)))
	_option("Rest: heal %d Core HP." % Run.REST_HEAL, "opt_heal", func():
		flash = "You rest and heal %d Core HP." % run.rest_heal()
		_show(), box, run.core_hp < run.max_hp)
	_option("Meditate: remove a card from your deck.", "opt_remove", func():
		_open_deck("Choose a card to remove", func(i):
			run.rest_remove(i)
			flash = "A card is laid to rest."
			_show()), box, run.deck.size() > Run.MIN_DECK)


## Between acts: the heal and the free upgrade, then on to the next act's map.
func _show_act_complete() -> void:
	var s: Dictionary = run.act_summary
	var next: Dictionary = Data.ACTS[run.act]
	var box := _centered_panel("%s falls. Act %d complete!" % [s["boss"], s["act"]])
	box.add_child(_rich("The path leads deeper, into [b]Act %d: %s[/b]." % [run.act + 1, next["name"]], 19, GOLD))
	box.add_child(_rich("- Healed [b]%d[/b] Core HP (%d%% of what was missing). Core HP: [b]%d[/b] / %d\n- Your god power is recharged, and you earn [b]a free upgrade[/b].\n- Enemies in the next act are stronger, and so are the rewards. Next boss: [color=#ff7a70]%s[/color]" % [
		s["healed"], roundi(Data.ACT_HEAL * 100), run.core_hp, run.max_hp, Data.ENEMIES[Data.battle(run.boss_ids[run.act])["enemies"][0][0]]["name"]], 17))
	var go := _button("Descend into Act %d" % (run.act + 1), func():
		run.start_next_act()
		_show(), box)
	CardWidget.style_button(go, true, 18)
	go.custom_minimum_size = Vector2(0, 52)


func _show_end() -> void:
	var won: bool = run.state == "victory"
	var box := _centered_panel("%s falls. The run is complete!" % run.boss_name() if won else "The Reliquary Core is lost.")
	if won:
		var faction: String = Data.CARDS[run.patron]["faction"]
		var scene := CardWidget.art("victory", faction, Data.CARDS[run.patron]["name"], CardWidget.FACTION_COLORS[faction], 64)
		if scene is TextureRect:
			scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		scene.custom_minimum_size = Vector2(0, 340)
		box.add_child(scene)
	box.add_child(_rich("Reached: [b]Act %d, floor %d[/b] / %d\nFights won: [b]%d[/b]\nCore HP: [b]%d[/b]\nGold: [b]%d[/b]\nDeck: [b]%d[/b] cards\nRelics: [b]%d[/b]" % [
		run.act, run.floor_number(), Run.FLOORS, run.fights_won, max(run.core_hp, 0), run.gold, run.deck.size(), run.relics.size()]))
	_option("View final deck.", "opt_card", func(): _open_deck("Final deck"), box)
	var menu := _button("Back to menu", func(): exit_requested.emit(), box)
	CardWidget.style_button(menu, true, 18)
	menu.custom_minimum_size = Vector2(0, 48)


# ---------------------------------------------------------------- scene panels

func _panel_style() -> StyleBoxFlat:
	return CardWidget.glass_style(18, 28)


## Event-style screen: a framed illustration on the left and a titled panel on the right.
## Returns the panel's box for the text and options.
func _scene(art: String, title: String, text: String) -> VBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 22)
	content.add_child(row)

	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.06, 0.05, 0.09)
	fsb.set_corner_radius_all(18)
	fsb.corner_detail = 12
	fsb.shadow_color = Color(0, 0, 0, 0.6)
	fsb.shadow_size = 22
	fsb.shadow_offset = Vector2(0, 8)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var pic := TextureRect.new()
	if ResourceLoader.exists(art):
		pic.texture = load(art)
	pic.custom_minimum_size = ART_SIZE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(pic)
	var edge := Panel.new()
	var esb := StyleBoxFlat.new()
	esb.draw_center = false
	esb.border_color = Color(1, 1, 1, 0.14)
	esb.set_border_width_all(1)
	esb.set_corner_radius_all(18)
	esb.corner_detail = 12
	edge.add_theme_stylebox_override("panel", esb)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(edge)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(0, ART_SIZE.y + 16)
	row.add_child(panel)
	return _panel_box(panel, title, text)


## A panel centered in the content area, for screens without an illustration.
func _centered_panel(title: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	return _panel_box(panel, title, "")


func _panel_box(panel: PanelContainer, title: String, text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var heading := _heading(title, 36)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	box.add_child(_divider())
	if text != "":
		box.add_child(_rich(text))
	return box


func _divider() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(GOLD, 0.0), Color(GOLD, 0.9), Color(GOLD, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 1
	var line := TextureRect.new()
	line.texture = tex
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 2)
	return line


func _rich(text: String, size := 18, color := Color(0.88, 0.86, 0.82)) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.text = text
	rtl.add_theme_font_size_override("normal_font_size", size)
	rtl.add_theme_font_size_override("bold_font_size", size)
	rtl.add_theme_font_size_override("italics_font_size", size)
	rtl.add_theme_color_override("default_color", color)
	return rtl


func _icon_line(icon: String, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(CardWidget.icon(icon, 26))
	if text != "":
		var l := CardWidget._label(text, 18, color, false)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	return row


func _card_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	return row


func _centered(child: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.add_child(child)
	return center


## A wide choice button with an icon on the left, used for event options and services.
func _option(text: String, icon: String, callback: Callable, parent: Control, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	var path := "res://art/icons/%s.png" % icon
	if ResourceLoader.exists(path):
		b.icon = load(path)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 58)
	b.disabled = not enabled
	b.pressed.connect(callback)
	CardWidget.style_button(b, false, 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
	b.add_theme_constant_override("icon_max_width", 34)
	b.add_theme_constant_override("h_separation", 14)
	b.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- overlays

## Opens a full-screen panel above everything, including a running fight.
func _new_overlay(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.03, 0.06, 0.97)
	sb.set_content_margin_all(30)
	overlay.add_theme_stylebox_override("panel", sb)
	add_child(overlay)
	_fade_in(overlay, 0.2)

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
	sb.bg_color = Color(0.035, 0.03, 0.06, 0.97)
	sb.set_content_margin_all(30)
	info_overlay.add_theme_stylebox_override("panel", sb)
	add_child(info_overlay)
	_fade_in(info_overlay, 0.2)

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
	CardWidget.button_icon(other, "ui_deck" if kind == "map" else "ui_map", 26)
	other.visible = kind == "map" or run.state != "map"
	var close := _button("Close (%s)" % ("M" if kind == "map" else "D"), _close_info, header)
	close.custom_minimum_size = Vector2(160, 40)
	if kind == "map":
		box.add_child(_text("Your path so far is marked in gold, and your next choices glow. Hover over a node for details."))
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
