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
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.05, 0.045, 0.08, 0.86)
	ssb.border_color = Color(GOLD, 0.45)
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(10)
	ssb.set_content_margin_all(14)
	side_panel.add_theme_stylebox_override("panel", ssb)
	root.add_child(side_panel)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 8)
	side_panel.add_child(sidebar)

	sidebar_label = RichTextLabel.new()
	sidebar_label.bbcode_enabled = true
	sidebar_label.fit_content = true
	sidebar_label.scroll_active = false
	sidebar.add_child(sidebar_label)

	deck_button = Button.new()
	deck_button.custom_minimum_size = Vector2(0, 40)
	deck_button.pressed.connect(_toggle_info.bind("deck"))
	CardWidget.style_button(deck_button)
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
	return CardWidget._label(text, size + 4, GOLD if size >= 30 else Color(0.92, 0.88, 0.8), true)


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
	sidebar_label.text = "[font_size=26][color=#f2c75a]Act 1[/color][/font_size]\n[font_size=18][img=22]res://art/icons/hp.png[/img] Core [b]%d[/b] / %d\n[img=22]res://art/map/shop.png[/img] Gold [b]%d[/b][/font_size]\n[color=#a8a8b8]Floor[/color] %d / %d   [color=#a8a8b8]Fights won[/color] %d\n[color=#a8a8b8]Boss:[/color] [color=#ff7a70]%s[/color]\n[color=#77778a]Seed %d[/color]" % [
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
	content.add_child(_map_header())
	if flash != "":
		content.add_child(_text(flash, Color(1.0, 0.9, 0.55)))
		flash = ""
	content.add_child(_text("Choose your next destination (the glowing medallions). The path climbs from the Reliquary to the boss at the top. Hover over a node for details."))
	content.add_child(_map_scroll(true))


## Title plus a legend of the node icons.
func _map_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var title := _heading("The Dying Stars")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for type in ["fight", "elite", "shop", "shrine", "rest"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.tooltip_text = CardWidget.wrap_text(NODE_HELP[type])
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := _medallion_face("res://art/map/%s.png" % type, 30, NODE_COLORS[type])
		icon.custom_minimum_size = Vector2(30, 30)
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
	canvas.background = load("res://art/map/background.jpg")

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

	var start := _medallion_face("res://art/map/start.png", 80, GOLD, run.current == -1)
	start.size = Vector2(80, 80)
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


## A medallion: circular art in a metal ring. Reachable nodes glow and pulse; visited ones dim.
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

	var ring_color: Color = NODE_COLORS[type]
	var path := "res://art/map/%s.png" % type
	if type == "boss":
		var boss: Dictionary = run.boss_def()
		for pattern in CardWidget.ART_PATHS:
			if ResourceLoader.exists(pattern % ["enemies", boss["enemies"][0][0]]):
				path = pattern % ["enemies", boss["enemies"][0][0]]
		b.tooltip_text = CardWidget.wrap_text("BOSS: %s\n%s\n%s" % [run.boss_name(), boss["hint"], NODE_HELP["boss"]])
	if reachable:
		ring_color = REACHABLE
	elif visited or here:
		ring_color = GOLD
	var face := _medallion_face(path, d, ring_color, reachable or here)
	face.size = b.size
	b.add_child(face)

	if type == "boss":
		var name_label := CardWidget._label(run.boss_def()["short"].to_upper(), 22, Color(1.0, 0.55, 0.5), true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(240, 30)
		name_label.position = Vector2(d / 2 - 120, d + 4)
		b.add_child(name_label)
	if visited and not here:
		face.modulate = Color(0.62, 0.6, 0.58)
	elif passed:
		b.modulate = Color(1, 1, 1, 0.35)
	elif not reachable and not here:
		face.modulate = Color(0.82, 0.8, 0.88)
	if here:
		var marker := CardWidget._label("YOU", 13, REACHABLE, true)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.size = Vector2(60, 18)
		marker.position = Vector2(d / 2 - 30, -20)
		b.add_child(marker)

	if reachable:
		var tween := b.create_tween().set_loops()
		tween.tween_property(face, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(face, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		face.pivot_offset = b.size / 2
		b.mouse_entered.connect(func(): b.scale = Vector2(1.12, 1.12))
		b.mouse_exited.connect(func(): b.scale = Vector2.ONE)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b


## The glow sits on its own panel: a clipping panel with a shadow would clip the art to a square.
func _medallion_face(path: String, d: float, ring_color: Color, glow := false) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo := Panel.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0, 0, 0, 0.5)
	hsb.set_corner_radius_all(int(d))
	hsb.shadow_color = Color(ring_color, 0.55) if glow else Color(0, 0, 0, 0.6)
	hsb.shadow_size = int(d / 5) if glow else 4
	halo.add_theme_stylebox_override("panel", hsb)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(root, halo, 0, 0, -0.001, -0.001)

	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1)
	sb.border_color = ring_color
	sb.set_border_width_all(max(2, int(d / 16)))
	sb.set_corner_radius_all(int(d))
	ring.add_theme_stylebox_override("panel", sb)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	CardWidget.place(root, ring, 0, 0, -0.001, -0.001)
	var tex := TextureRect.new()
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: float = max(2, d / 16)
	CardWidget.place(ring, tex, inset, inset, -inset, -inset)
	var rim := Panel.new()
	var rsb := StyleBoxFlat.new()
	rsb.draw_center = false
	rsb.border_color = Color(ring_color.lightened(0.4), 0.6)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(int(d))
	rim.add_theme_stylebox_override("panel", rsb)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(ring, rim, inset, inset, -inset, -inset)
	return root


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
