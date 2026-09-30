extends Control
## Battle screen: renders combat snapshots and turns clicks into combat actions.

signal exit_requested
signal finished
signal map_requested
signal deck_requested
signal abandon_requested

const Combat = preload("res://scripts/core/combat.gd")
const Data = preload("res://scripts/core/data.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const RulesText = preload("res://scripts/ui/rules_text.gd")

const P := 0
const E := 1
const FRONT := 0
const BACK := 1
const SLOT_SIZE := Vector2(250, 112)
const PORTRAIT_W := 64
const STEP_DELAY := 0.45

const COLOR_EMPTY := Color(0.16, 0.16, 0.2)
const COLOR_PLAYER := Color(0.16, 0.26, 0.4)
const COLOR_ENEMY := Color(0.36, 0.16, 0.3)
const COLOR_PETRIFIED := Color(0.3, 0.33, 0.28)
const COLOR_TARGET := Color(1.0, 0.85, 0.2)
const COLOR_SELECTED := Color(0.3, 1.0, 0.45)
const TERRAIN_COLORS := {"ley_line": Color(0.95, 0.75, 0.2), "ruins": Color(0.6, 0.45, 0.3), "quicksand": Color(0.85, 0.7, 0.45)}

var combat
var params := {}
var slot_buttons := {}
var slot_labels := {}
var slot_portraits := {}
var hand_box: HBoxContainer
var status_label: RichTextLabel
var relic_row: HFlowContainer
var relic_icons := {}
var hint_label: Label
var log_label: RichTextLabel
var core_label: Label
var end_button: Button
var cancel_button: Button
var restart_button: Button
var push_left_button: Button
var push_right_button: Button
var skip_button: Button
var menu_button: Button
var run_info_row: HBoxContainer
var result_panel: PanelContainer
var result_label: Label
var single_buttons: HBoxContainer
var run_buttons: HBoxContainer
var run_mode := false
var help_panel: Control = null

var sel_hand := -1
var sel_move = null
var pair_first = null
var push_target = null
var animating := false
var skip_animation := false


func start(battle: Dictionary, deck_key: String, relics: Array, seed_value: int) -> void:
	params = {"battle": battle, "deck": deck_key, "relics": relics, "seed": seed_value}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_new_combat(seed_value)


## Runs a fight that belongs to a run. Emits `finished` when the player continues.
func start_run_fight(run_combat, title: String) -> void:
	run_mode = true
	params = {"battle": run_combat.battle, "relics": run_combat.relics}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	menu_button.visible = false
	run_info_row.visible = true
	combat = run_combat
	_begin("[b]%s[/b]" % title)


func _new_combat(seed_value: int) -> void:
	params["seed"] = seed_value
	combat = Combat.new()
	combat.setup(params["battle"], Data.deck_cards(params["deck"]), params["relics"], seed_value)
	_begin("[b]%s[/b] - deck: %s - seed %d" % [params["battle"]["name"], Data.DECKS[params["deck"]]["name"], seed_value])


func _begin(header: String) -> void:
	result_panel.visible = false
	log_label.clear()
	_log_line(header)
	_log_line("--- Round 1: plan your moves ---")
	_build_relic_row()
	_clear_selection()
	_set_hint("")
	_refresh()


# ---------------------------------------------------------------- layout

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)

	left.add_child(_section_label("THE VOID"))
	left.add_child(_build_grid(E, [BACK, FRONT]))
	left.add_child(_section_label("YOUR FORCES"))
	left.add_child(_build_grid(P, [FRONT, BACK]))

	core_label = Label.new()
	core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_label.add_theme_font_size_override("font_size", 20)
	core_label.custom_minimum_size = Vector2(0, 34)
	left.add_child(core_label)

	left.add_child(_section_label("HAND"))
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 8)
	left.add_child(hand_box)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	right.add_child(status_label)
	relic_row = HFlowContainer.new()
	relic_row.add_theme_constant_override("h_separation", 6)
	relic_row.add_theme_constant_override("v_separation", 6)
	right.add_child(relic_row)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(0, 66)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	right.add_child(hint_label)

	end_button = _button("End planning - resolve round", _on_end_pressed, right)
	end_button.custom_minimum_size = Vector2(0, 48)
	var push_row := HBoxContainer.new()
	right.add_child(push_row)
	push_left_button = _button("< Push left", _on_push.bind(-1), push_row)
	push_right_button = _button("Push right >", _on_push.bind(1), push_row)
	push_left_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	push_right_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button = _button("Cancel selection", _on_cancel_pressed, right)
	restart_button = _button("Restart planning (undo this round's plays)", _on_restart_pressed, right)
	restart_button.tooltip_text = CardWidget.wrap_text("Take back every card played and unit moved since this planning phase began.")
	skip_button = _button("Skip animation", func(): skip_animation = true, right)
	var help_button := _button("?  Rules and keywords (H)", _toggle_help, right)
	help_button.tooltip_text = "How battles work: round order, targeting, tiebreakers and keywords."
	menu_button = _button("Back to menu", func(): exit_requested.emit(), right)
	run_info_row = HBoxContainer.new()
	run_info_row.visible = false
	right.add_child(run_info_row)
	var map_button := _button("View map (M)", func(): map_requested.emit(), run_info_row)
	var deck_button := _button("View deck (D)", func(): deck_requested.emit(), run_info_row)
	var abandon_button := _button("Abandon run", func(): abandon_requested.emit(), run_info_row)
	for b in [map_button, deck_button, abandon_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 13)
	right.add_child(log_label)

	_build_result_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_H, KEY_F1]:
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and help_panel != null and help_panel.visible:
		help_panel.visible = false
		get_viewport().set_input_as_handled()


func _toggle_help() -> void:
	if help_panel == null:
		_build_help_panel()
	else:
		help_panel.visible = not help_panel.visible
	if help_panel.visible:
		move_child(help_panel, get_child_count() - 1)


func _build_help_panel() -> void:
	help_panel = ColorRect.new()
	help_panel.color = Color(0, 0, 0, 0.7)
	help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(help_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 160)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 50)
	help_panel.add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.border_color = Color(0.95, 0.75, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inner.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "How battles work"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("Close (Esc)", func(): help_panel.visible = false, header)
	close.custom_minimum_size = Vector2(130, 38)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	for section in RulesText.SECTIONS:
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.text = section[1]
		text.add_theme_font_size_override("normal_font_size", 17)
		text.add_theme_font_size_override("bold_font_size", 17)
		text.add_theme_font_size_override("italics_font_size", 17)
		text.add_theme_constant_override("line_separation", 4)
		text.add_theme_constant_override("table_h_separation", 16)
		text.add_theme_constant_override("table_v_separation", 6)
		var pad := StyleBoxEmpty.new()
		pad.set_content_margin_all(14)
		text.add_theme_stylebox_override("normal", pad)
		tabs.add_child(text)
		tabs.set_tab_title(tabs.get_tab_count() - 1, "  %s  " % section[0])


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68))
	return l


func _button(text: String, callback: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _build_grid(side: int, rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for row in rows:
		var label := Label.new()
		label.text = "FRONT" if row == FRONT else "BACK"
		label.custom_minimum_size = Vector2(60, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68))
		grid.add_child(label)
		for lane in 4:
			var button := Button.new()
			button.custom_minimum_size = SLOT_SIZE
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_on_slot_pressed.bind(side, row, lane))
			var portrait := Control.new()
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			CardWidget.place(button, portrait, 4, 4, 4 + PORTRAIT_W, -4)
			var rtl := CardWidget.overlay_label(button, 13)
			grid.add_child(button)
			slot_buttons[_key(side, row, lane)] = button
			slot_labels[_key(side, row, lane)] = rtl
			slot_portraits[_key(side, row, lane)] = portrait
	return grid


func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(520, 220)
	result_panel.position = Vector2(-260, -110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.97)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.9, 0.8, 0.4)
	sb.set_content_margin_all(20)
	result_panel.add_theme_stylebox_override("panel", sb)
	add_child(result_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	result_panel.add_child(box)
	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 22)
	box.add_child(result_label)
	single_buttons = HBoxContainer.new()
	box.add_child(single_buttons)
	_button("Retry (same seed)", func(): _new_combat(params["seed"]), single_buttons)
	_button("Retry (new seed)", func(): _new_combat(randi_range(1, 999999)), single_buttons)
	_button("Back to menu", func(): exit_requested.emit(), single_buttons)
	run_buttons = HBoxContainer.new()
	box.add_child(run_buttons)
	_button("Continue", func(): finished.emit(), run_buttons)
	result_panel.visible = false


# ---------------------------------------------------------------- rendering

func _key(side: int, row: int, lane: int) -> String:
	return "%d:%d:%d" % [side, row, lane]


func _refresh() -> void:
	_render(combat.snapshot())


func _render(snap: Dictionary) -> void:
	var targets := _current_targets()
	for side in 2:
		for row in 2:
			for lane in 4:
				_render_slot(snap, side, row, lane, targets)
	_render_status(snap)
	_render_hand(snap)
	var over: bool = snap["phase"] == "over"
	end_button.disabled = animating or over
	cancel_button.disabled = animating or not _has_selection()
	restart_button.disabled = animating or not combat.can_restart_plan()
	skip_button.disabled = not animating
	push_left_button.visible = push_target != null
	push_right_button.visible = push_target != null


func _render_slot(snap: Dictionary, side: int, row: int, lane: int, targets: Array) -> void:
	var key := _key(side, row, lane)
	var u = snap["grid"][side][row][lane]
	var terrain: String = combat.terrain_at(side, row, lane)
	var petrified: bool = side == P and snap["petrified_lane"] == lane
	var lines: Array = []
	var text_line := -1
	var bg := COLOR_EMPTY
	var tooltip := ""

	if u == null:
		lines.append("[color=#777790]Lane %d %s[/color]" % [lane + 1, "front" if row == FRONT else "back"])
	elif u.get("wide_part", false):
		bg = COLOR_ENEMY
		lines.append("[b]%s[/b]" % u["name"])
		lines.append("[color=#bbbbcc](same unit, spans lanes %s)[/color]" % u["lanes"])
	else:
		bg = COLOR_PLAYER if side == P else COLOR_ENEMY
		var shield := "  [color=#7fd4ff]Shield %d[/color]" % u["shield"] if u["shield"] > 0 else ""
		var revive := "  [color=#e6c75a]Revive[/color]" if u["revive"] else ""
		var empowered := "  [color=#ff7a50]EMPOWERED[/color]" if u["empowered"] else ""
		var tags := ""
		if u.get("poisoned", false):
			tags += "  [color=#9ae66e]Poisoned[/color]"
		if u.get("veil", false):
			tags += "  [color=#c8b4ff]Veil[/color]"
		if u.get("spellward", false):
			tags += "  [color=#8fd0ff]Spellward[/color]"
		lines.append("[b]%s[/b]%s%s%s" % [u["name"], revive, empowered, tags])
		if u.get("swine", false):
			lines.append("[color=#ff9ad0]SWINE: can't act[/color]")
		lines.append("ATK [b]%d[/b]   HP [b]%d[/b]/%d   SPD %d%s" % [u["atk"], u["hp"], u["max_hp"], u["spd"], shield])
		if side == E:
			lines.append("[color=#ff9a9a]Intent: %s[/color]   Threat %d" % [u["intent"], u["threat"]])
		else:
			text_line = lines.size()
			lines.append("[color=#c0c0d0][font_size=11]%s[/font_size][/color]" % u["text"])
			if u.get("move_block", "") != "":
				lines.append("[color=#8a8aa0][font_size=11]%s[/font_size][/color]" % u["move_block"])
		tooltip = "%s\n%s" % [u["name"], u["text"]]

	if terrain != "":
		lines.append("[color=#%s]%s[/color]" % [TERRAIN_COLORS[terrain].to_html(false), Data.TERRAIN[terrain]["name"]])
		tooltip += ("\n" if tooltip != "" else "") + "%s: %s" % [Data.TERRAIN[terrain]["name"], Data.TERRAIN[terrain]["text"]]
	if petrified:
		bg = COLOR_PETRIFIED
		lines.append("[color=#c8e6a0]PETRIFIED this round[/color]")
	if side == P and snap["sandstorm_row"] == row:
		lines.append("[color=#e6c080]Sandstorm: -1 ATK this round[/color]")
	if side == P and snap.get("lane_warnings", {}).has(lane):
		lines.append("[color=#ff8a6a]%s[/color]" % snap["lane_warnings"][lane])
	if side == P and "%d:%d" % [row, lane] in snap.get("quicksand_targets", []):
		lines.append("[color=#d9b36e]Sinks into Quicksand![/color]")
	# The slot fits about four lines; status lines matter more than the card text, which stays in the tooltip.
	if text_line != -1 and lines.size() > 4:
		lines.remove_at(text_line)

	var border := Color(0, 0, 0, 0)
	var border_w := 0
	if terrain != "":
		border = TERRAIN_COLORS[terrain]
		border_w = 2
	if _slot_in(targets, [side, row, lane]):
		border = COLOR_TARGET
		border_w = 4
	if _is_selected_slot(side, row, lane):
		border = COLOR_SELECTED
		border_w = 4

	var button: Button = slot_buttons[key]
	CardWidget.style(button, bg, border, border_w)
	button.tooltip_text = CardWidget.wrap_text(tooltip)
	slot_labels[key].text = "\n".join(lines)
	slot_labels[key].offset_left = 8 if u == null else PORTRAIT_W + 12
	_set_portrait(slot_portraits[key], u)


## Shows the unit's art (player units reuse their card art). Rebuilt only when the unit changes.
func _set_portrait(holder: Control, u) -> void:
	var art_key := "" if u == null else "%d:%s" % [u["side"], u["id"]]
	if holder.get_meta("art_key", "") == art_key:
		return
	holder.set_meta("art_key", art_key)
	for child in holder.get_children():
		child.queue_free()
	if u == null:
		return
	var art: Control
	if u["side"] == P:
		var def: Dictionary = Data.CARDS[u["id"]]
		art = CardWidget.art("cards", u["id"], def["name"], CardWidget.FACTION_COLORS[def["faction"]], 24)
	else:
		var def: Dictionary = Data.ENEMIES[u["id"]]
		art = CardWidget.art("enemies", u["id"], def["name"], CardWidget.ENEMY_COLORS[def["kind"]], 24)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(art)


func _build_relic_row() -> void:
	for child in relic_row.get_children():
		child.queue_free()
	relic_icons.clear()
	var label := Label.new()
	label.text = "Relics:" if not params["relics"].is_empty() else "Relics: none"
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	relic_row.add_child(label)
	for id in params["relics"]:
		var relic: Dictionary = Data.RELICS[id]
		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(38, 38)
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.tooltip_text = CardWidget.wrap_text("%s (%s)\n%s" % [relic["name"], relic["rarity"], relic["text"]])
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.12, 0.12, 0.17)
		frame.border_color = CardWidget.RELIC_COLOR
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(4)
		frame.set_content_margin_all(2)
		holder.add_theme_stylebox_override("panel", frame)
		holder.add_child(CardWidget.art("relics", id, relic["name"], CardWidget.RELIC_COLOR, 12))
		relic_row.add_child(holder)
		relic_icons[id] = holder


## Once-per-fight relics dim after they trigger.
func _update_relic_icons() -> void:
	var spent := {"aegis_fragment": combat.aegis_used, "mead_of_the_einherjar": combat.mead_used}
	for id in relic_icons:
		relic_icons[id].modulate = Color(1, 1, 1, 0.35) if spent.get(id, false) else Color.WHITE


func _render_status(snap: Dictionary) -> void:
	var round_text := "Round %d / %d" % [snap["round"], snap["max_rounds"]]
	if snap["is_boss"]:
		round_text = "Round %d (boss: no round limit)" % snap["round"]
	status_label.text = "[font_size=20][b]%s[/b][/font_size]\n[font_size=18]Faith: [b]%d[/b]   Core HP: [b]%d[/b][/font_size]\nDeck %d   Discard %d   Moves left: %d%s" % [
		round_text, snap["faith"], max(snap["core_hp"], 0), snap["deck"], snap["discard"],
		snap["moves_left"], "   [color=#80ff90]Next spell free (Hermes)[/color]" if snap["free_spell"] else "",
	]
	_update_relic_icons()
	core_label.text = "RELIQUARY CORE  -  %d HP" % max(snap["core_hp"], 0)


func _render_hand(snap: Dictionary) -> void:
	for child in hand_box.get_children():
		child.queue_free()
	var cards: Array = snap["hand"]
	for i in cards.size():
		var def: Dictionary = Data.CARDS[cards[i]["id"]]
		var cost: int = 0 if def["type"] == "spell" and snap["free_spell"] else def["cost"]
		var button := CardWidget.card_button(cards[i]["id"], i == sel_hand, cost)
		button.pressed.connect(_on_hand_pressed.bind(i))
		var affordable: bool = not animating and snap["phase"] == "plan" and not def["type"] in Combat.UNPLAYABLE and cost <= snap["faith"]
		button.modulate = Color(1, 1, 1, 1.0 if affordable else 0.45)
		hand_box.add_child(button)


func _current_targets() -> Array:
	if animating or combat.phase != "plan":
		return []
	if sel_hand >= 0 and sel_hand < combat.hand.size():
		if push_target != null:
			return []
		var targets: Array = combat.valid_targets(sel_hand)
		if pair_first != null:
			return targets.filter(func(t): return t[1] == pair_first[1] and t != pair_first)
		return targets
	if sel_move != null:
		var out: Array = []
		for row in 2:
			for lane in 4:
				if combat.unit_at(P, row, lane) == null:
					out.append([P, row, lane])
		return out
	return []


func _slot_in(list: Array, slot: Array) -> bool:
	for s in list:
		if s[0] == slot[0] and s[1] == slot[1] and s[2] == slot[2]:
			return true
	return false


func _is_selected_slot(side: int, row: int, lane: int) -> bool:
	if sel_move != null and side == P and sel_move[0] == row and sel_move[1] == lane:
		return true
	for s in [pair_first, push_target]:
		if s != null and s[0] == side and s[1] == row and s[2] == lane:
			return true
	return false


# ---------------------------------------------------------------- input

func _has_selection() -> bool:
	return sel_hand >= 0 or sel_move != null


func _clear_selection() -> void:
	sel_hand = -1
	sel_move = null
	pair_first = null
	push_target = null


func _set_hint(text: String) -> void:
	if text == "":
		text = "Click a card, then a highlighted slot. Click one of your units, then an empty slot, to move it (one move per round; units deployed this round can't move). Hover over anything for details."
	hint_label.text = text


func _on_cancel_pressed() -> void:
	_clear_selection()
	_set_hint("")
	_refresh()


func _on_restart_pressed() -> void:
	if animating:
		return
	_clear_selection()
	_apply(combat.restart_plan())


func _on_hand_pressed(i: int) -> void:
	if animating or combat.phase != "plan":
		return
	if sel_hand == i:
		_on_cancel_pressed()
		return
	_clear_selection()
	if combat.is_unplayable(combat.hand[i]):
		_set_hint("%s can't be played. It leaves your hand at the start of the next round." % combat.card_def(combat.hand[i])["name"])
		_refresh()
		return
	if not combat.can_afford(i):
		_set_hint("Not enough Faith for that card.")
		_refresh()
		return
	var def: Dictionary = combat.card_def(combat.hand[i])
	if def["type"] == "spell" and def["target"] == "none":
		_apply(combat.play_spell(i, []))
		return
	sel_hand = i
	if combat.valid_targets(i).is_empty():
		_set_hint("%s has no legal target right now." % def["name"])
	elif def["type"] == "unit":
		_set_hint("Deploy %s: click an empty slot on your grid." % def["name"])
	else:
		_set_hint({
			"ally": "Choose one of your units.",
			"ally_card": "Choose one of your units to return to your hand.",
			"ally_slot": "Choose a %s slot on your grid without terrain (a unit may stand there)." % ("front" if def.get("row", 0) == 0 else "back"),
			"enemy": "Choose an enemy unit.",
			"enemy_front": "Choose an enemy front unit to push.",
			"enemy_pair": "Choose the first enemy to swap.",
			"empty_ally_slot": "Choose an empty slot for the returning ally.",
		}[def["target"]])
	_refresh()


func _on_slot_pressed(side: int, row: int, lane: int) -> void:
	if animating or combat.phase != "plan":
		return
	var slot := [side, row, lane]
	if sel_hand >= 0:
		_target_with_card(slot)
		return
	if side != P:
		return
	var u = combat.unit_at(P, row, lane)
	if sel_move == null:
		if u == null:
			return
		if combat.moves_left <= 0:
			_set_hint("No moves left this round.")
		elif not combat.can_move(u):
			_set_hint("%s can't move: %s." % [u.display_name(), combat.move_block(u).to_lower()])
		else:
			sel_move = [row, lane]
			_set_hint("Move %s: click an empty slot on your grid." % u.display_name())
		_refresh()
		return
	if u == null:
		_apply(combat.move_unit(sel_move[1], sel_move[0], lane, row))
	elif sel_move[0] == row and sel_move[1] == lane:
		_on_cancel_pressed()
	else:
		sel_move = [row, lane]
		_refresh()


func _target_with_card(slot: Array) -> void:
	if push_target != null:
		return
	if not _slot_in(_current_targets(), slot):
		_set_hint("That is not a legal target for this card.")
		return
	var def: Dictionary = combat.card_def(combat.hand[sel_hand])
	if def["type"] == "unit":
		_apply(combat.play_unit(sel_hand, slot[2], slot[1]))
		return
	match def["target"]:
		"ally", "ally_card", "ally_slot", "enemy", "empty_ally_slot":
			_apply(combat.play_spell(sel_hand, [slot]))
		"enemy_front":
			push_target = slot
			_set_hint("Push which way?")
			_refresh()
		"enemy_pair":
			if pair_first == null:
				pair_first = slot
				_set_hint("Choose the second enemy in the same row.")
				_refresh()
			else:
				_apply(combat.play_spell(sel_hand, [pair_first, slot]))


func _on_push(direction: int) -> void:
	if push_target == null:
		return
	_apply(combat.play_spell(sel_hand, [push_target], direction))


func _apply(err: String) -> void:
	if err != "":
		_set_hint(err)
		_refresh()
		return
	for ev in combat.events:
		_log_line(ev["text"])
	_clear_selection()
	_set_hint("")
	_refresh()
	_check_over()


func _on_end_pressed() -> void:
	if animating or combat.phase != "plan":
		return
	_clear_selection()
	animating = true
	skip_animation = false
	_set_hint("Resolving...")
	var events: Array = combat.end_plan()
	for ev in events:
		_log_line(ev["text"])
		if not skip_animation:
			_render(ev["snap"])
			await get_tree().create_timer(STEP_DELAY).timeout
	animating = false
	_set_hint("")
	_refresh()
	_check_over()


func _check_over() -> void:
	if combat.phase != "over":
		return
	var headline: String = {
		"win": "Victory!",
		"timeout": "Time ran out",
		"defeat": "The Core is destroyed",
	}[combat.result]
	result_label.text = "%s\nCore HP remaining: %d\nRounds played: %d" % [headline, max(combat.core_hp, 0), combat.round_num]
	single_buttons.visible = not run_mode
	run_buttons.visible = run_mode
	result_panel.visible = true


func _log_line(text: String) -> void:
	if text.begins_with("---"):
		log_label.append_text("\n[b][color=#e6c75a]%s[/color][/b]\n" % text)
	else:
		log_label.append_text(text + "\n")
