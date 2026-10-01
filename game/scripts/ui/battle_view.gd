extends Control
## Battle screen: renders combat snapshots on the board and turns clicks and drags into combat actions.

signal exit_requested
signal finished
signal map_requested
signal deck_requested
signal abandon_requested

const Combat = preload("res://scripts/core/combat.gd")
const Data = preload("res://scripts/core/data.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")
const RulesPanel = preload("res://scripts/ui/rules_panel.gd")
const BoardView = preload("res://scripts/ui/board_view.gd")
const Music = preload("res://scripts/ui/music.gd")

const P := 0
const E := 1
const FRONT := 0
const BACK := 1
const STEP_DELAY := 0.45
const ATTACK_DELAY := 0.6
const BOARD_RECT := Rect2(0, 0, 1250, 640)
const SIDEBAR_RECT := Rect2(1262, 10, 328, 880)
const GOLD := Color(0.95, 0.78, 0.35)
const TERRAIN_COLORS := {"ley_line": Color(0.95, 0.75, 0.2), "ruins": Color(0.75, 0.6, 0.45), "quicksand": Color(0.9, 0.72, 0.4)}

var combat
var params := {}
var board: Control
var last_snap: Dictionary = {}
var hand_box: HBoxContainer
var round_label: Label
var round_sub: Label
var faith_label: Label
var core_label: Label
var core_bar: ProgressBar
var info_label: RichTextLabel
var relic_row: HFlowContainer
var relic_icons := {}
var hint_label: Label
var log_label: RichTextLabel
var end_button: Button
var cancel_button: Button
var restart_button: Button
var push_panel: PanelContainer
var push_title: Label
var push_outcomes := {}
var skip_button: Button
var menu_button: Button
var run_info_row: HBoxContainer
var abandon_button: Button
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
	_play_music()


## Runs a fight that belongs to a run. Emits `finished` when the player continues.
func start_run_fight(run_combat, title: String) -> void:
	run_mode = true
	params = {"battle": run_combat.battle, "relics": run_combat.relics}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	menu_button.visible = false
	run_info_row.visible = true
	abandon_button.visible = true
	combat = run_combat
	_begin("[b]%s[/b]" % title)
	_play_music()


func _play_music() -> void:
	Music.play("boss" if params["battle"].get("boss", false) else "battle")


func _exit_tree() -> void:
	Music.play("theme")
	var preview = get_tree().get_first_node_in_group("card_preview")
	if preview != null:
		preview.hide_card(board)


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
	var fill := ColorRect.new()
	fill.color = Color(0.07, 0.05, 0.12)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fill)
	var bg := TextureRect.new()
	bg.texture = load("res://art/battle/background.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2(-275, -150)
	bg.size = Vector2(1800, 1013)
	add_child(bg)

	board = BoardView.new()
	board.position = BOARD_RECT.position
	board.size = BOARD_RECT.size
	add_child(board)
	board.slot_pressed.connect(_on_slot_pressed)
	board.slot_hovered.connect(_on_slot_hovered)
	board.cancel_requested.connect(_on_cancel_pressed)
	board.set_drag_forwarding(_board_drag, _board_can_drop, _board_drop)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 8)
	hand_box.position = Vector2(10, 650)
	hand_box.size = Vector2(BOARD_RECT.size.x - 20, CardWidget.CARD_SIZE.y)
	add_child(hand_box)

	var rules_button := _button("Rulebook (H)", _toggle_help, self)
	rules_button.position = Vector2(14, 14)
	rules_button.custom_minimum_size = Vector2(186, 50)
	rules_button.add_theme_font_size_override("font_size", 16)
	CardWidget.button_icon(rules_button, "rulebook", 36)
	rules_button.tooltip_text = "How battles work: round order, targeting, keywords, enemies and terrain."

	_build_sidebar()
	_build_push_panel()
	_build_result_panel()


func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.position = SIDEBAR_RECT.position
	panel.size = SIDEBAR_RECT.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.08, 0.86)
	sb.border_color = Color(GOLD, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	round_label = CardWidget._label("", 26, GOLD, true)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(round_label)
	round_sub = CardWidget._label("", 13, Color(0.7, 0.68, 0.78), false)
	round_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(round_sub)

	var faith_row := HBoxContainer.new()
	faith_row.add_theme_constant_override("separation", 8)
	faith_row.tooltip_text = "Faith pays for cards. It refills at the start of every round."
	box.add_child(faith_row)
	faith_row.add_child(CardWidget.icon("faith", 40))
	var faith_title := CardWidget._label("FAITH", 18, Color(0.75, 0.85, 1.0), true)
	faith_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faith_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	faith_row.add_child(faith_title)
	faith_label = CardWidget.number_label("0", 22, Color.WHITE)
	faith_row.add_child(faith_label)

	var core_row := HBoxContainer.new()
	core_row.add_theme_constant_override("separation", 8)
	core_row.tooltip_text = "The Reliquary Core. Enemies that reach it damage it; the fight is lost at 0."
	box.add_child(core_row)
	core_row.add_child(CardWidget.icon("hp", 40))
	var core_box := VBoxContainer.new()
	core_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_box.add_theme_constant_override("separation", 3)
	core_row.add_child(core_box)
	var core_head := HBoxContainer.new()
	core_box.add_child(core_head)
	var core_title := CardWidget._label("CORE", 18, Color(1.0, 0.7, 0.62), true)
	core_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_head.add_child(core_title)
	core_label = CardWidget.number_label("0", 14, Color.WHITE)
	core_head.add_child(core_label)
	core_bar = ProgressBar.new()
	core_bar.show_percentage = false
	core_bar.custom_minimum_size = Vector2(0, 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.04, 0.05)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.25, 0.22)
	bar_fill.set_corner_radius_all(4)
	core_bar.add_theme_stylebox_override("background", bar_bg)
	core_bar.add_theme_stylebox_override("fill", bar_fill)
	core_box.add_child(core_bar)

	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.add_theme_font_size_override("normal_font_size", 13)
	box.add_child(info_label)

	relic_row = HFlowContainer.new()
	relic_row.add_theme_constant_override("h_separation", 6)
	relic_row.add_theme_constant_override("v_separation", 6)
	box.add_child(relic_row)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(0, 74)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	box.add_child(hint_label)

	end_button = _button("END PLANNING", _on_end_pressed, box, true)
	end_button.custom_minimum_size = Vector2(0, 52)
	end_button.tooltip_text = "Resolve the round: every unit acts in Speed order."
	var edit_row := HBoxContainer.new()
	box.add_child(edit_row)
	cancel_button = _button("Cancel", _on_cancel_pressed, edit_row)
	cancel_button.tooltip_text = "Drop the current selection (right-click or Esc also works)."
	restart_button = _button("Undo round", _on_restart_pressed, edit_row)
	restart_button.tooltip_text = CardWidget.wrap_text("Take back every card played and unit moved since this planning phase began.")
	skip_button = _button("Skip animation", func(): skip_animation = true, box)
	for b in [cancel_button, restart_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button = _button("Back to menu", func(): exit_requested.emit(), box)
	run_info_row = HBoxContainer.new()
	run_info_row.visible = false
	box.add_child(run_info_row)
	var map_button := _button("Map (M)", func(): map_requested.emit(), run_info_row)
	var deck_button := _button("Deck (D)", func(): deck_requested.emit(), run_info_row)
	CardWidget.button_icon(map_button, "ui_map")
	CardWidget.button_icon(deck_button, "ui_deck")
	for b in [map_button, deck_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0, 0, 0, 0.35)
	lsb.set_corner_radius_all(6)
	lsb.set_content_margin_all(8)
	log_panel.add_theme_stylebox_override("panel", lsb)
	box.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_font_size_override("bold_font_size", 12)
	log_label.add_theme_color_override("default_color", Color(0.82, 0.82, 0.88))
	log_panel.add_child(log_label)
	abandon_button = _button("Abandon run", func(): abandon_requested.emit(), box)
	abandon_button.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_H, KEY_F1]:
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif push_target != null and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		_on_push(-1 if event.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and help_panel != null and help_panel.visible:
		help_panel.visible = false
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _has_selection():
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _toggle_help() -> void:
	if help_panel == null:
		help_panel = RulesPanel.new()
		add_child(help_panel)
	else:
		help_panel.visible = not help_panel.visible
	if help_panel.visible:
		move_child(help_panel, get_child_count() - 1)


func _button(text: String, callback: Callable, parent: Control, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	CardWidget.style_button(b, primary, 22 if primary else 14)
	parent.add_child(b)
	return b


## The direction prompt for push spells, centred over the player's grid so the enemy row stays visible.
func _build_push_panel() -> void:
	push_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.09, 0.94)
	sb.border_color = Color(0.55, 0.8, 1.0, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0.3, 0.6, 1.0, 0.35)
	sb.shadow_size = 18
	push_panel.add_theme_stylebox_override("panel", sb)
	push_panel.visible = false
	add_child(push_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	push_panel.add_child(box)
	push_title = CardWidget._label("", 24, GOLD, true)
	push_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(push_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for direction in [-1, 1]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		var b := _button("PUSH LEFT" if direction < 0 else "PUSH RIGHT", _on_push.bind(direction), col, true)
		b.custom_minimum_size = Vector2(250, 76)
		b.add_theme_font_size_override("font_size", 20)
		CardWidget.button_icon(b, "push_left" if direction < 0 else "push_right", 56)
		b.add_theme_constant_override("h_separation", 12)
		if direction > 0:
			b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.tooltip_text = "Keyboard: %s arrow" % ("Left" if direction < 0 else "Right")
		var outcome := CardWidget._label("", 14, Color(0.85, 0.85, 0.92), false)
		outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(outcome)
		push_outcomes[direction] = outcome
	var cancel := _button("Cancel (Esc)", _on_cancel_pressed, box)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.custom_minimum_size = Vector2(160, 34)


func _update_push_panel() -> void:
	var u = combat._at(push_target) if push_target != null else null
	push_panel.visible = u != null
	if u == null:
		return
	push_title.text = "Push %s which way?" % u.display_name()
	for direction in push_outcomes:
		var dest: int = push_target[2] + direction
		var other = combat.unit_at(push_target[0], push_target[1], dest)
		var text := "Moves to lane %d" % (dest + 1)
		if dest < 0 or dest >= Combat.LANES:
			text = "Slams into the edge: 3 damage"
		elif other != null and other.has_kw("immovable"):
			text = "Hits the Immovable %s: 3 damage" % other.display_name()
		elif other != null:
			text = "Collides with %s: 3 damage each" % other.display_name()
		push_outcomes[direction].text = text
	push_panel.reset_size()
	push_panel.position = Vector2((BOARD_RECT.size.x - push_panel.size.x) / 2, 385)


func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(520, 220)
	result_panel.position = Vector2(-260, -110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.97)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.9, 0.8, 0.4)
	sb.set_corner_radius_all(8)
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
	_button("Continue", func(): finished.emit(), run_buttons, true)
	result_panel.visible = false


# ---------------------------------------------------------------- rendering

func _refresh() -> void:
	_render(combat.snapshot())


func _render(snap: Dictionary) -> void:
	last_snap = snap
	var terrain := {}
	for side in 2:
		for row in 2:
			for lane in 4:
				var t: String = combat.terrain_at(side, row, lane)
				if t != "":
					terrain[BoardView.key(side, row, lane)] = t
	board.render(snap, terrain, _current_targets(), _selected_slots())
	_render_status(snap)
	_render_hand(snap)
	var over: bool = snap["phase"] == "over"
	end_button.disabled = animating or over
	cancel_button.disabled = animating or not _has_selection()
	restart_button.disabled = animating or not combat.can_restart_plan()
	skip_button.disabled = not animating
	_update_push_panel()
	if board.hover != null:
		_on_slot_hovered(board.hover)


func _selected_slots() -> Array:
	var out: Array = []
	if sel_move != null:
		out.append([P, sel_move[0], sel_move[1]])
	for s in [pair_first, push_target]:
		if s != null:
			out.append(s)
	return out


func _on_slot_hovered(slot) -> void:
	var preview = get_tree().get_first_node_in_group("card_preview")
	if preview == null or last_snap.is_empty():
		return
	if slot == null:
		preview.hide_card(board)
		return
	var u = last_snap["grid"][slot[0]][slot[1]][slot[2]]
	var anchor: Array = slot
	if u != null and u.get("wide_part", false):
		for lane in 4:
			var other = last_snap["grid"][slot[0]][slot[1]][lane]
			if other != null and not other.get("wide_part", false) and other["id"] == u["id"]:
				u = other
				anchor = [slot[0], slot[1], lane]
				break
	if u != null and u.get("wide_part", false):
		u = null
	preview.show_unit(u if u != null else {}, board.slot_rect(anchor), board, _slot_extras(last_snap, slot, u))


## Glossary lines for a hovered slot: live stats, intent, statuses, terrain and lane effects.
func _slot_extras(snap: Dictionary, slot: Array, u) -> Array:
	var side: int = slot[0]
	var row: int = slot[1]
	var lane: int = slot[2]
	var out: Array = []
	if u != null:
		if side == E and u["intent"] != "":
			var threat := "\nThreat %d: the Core takes %d if it survives the last round." % [u["threat"], u["threat"]] if u["threat"] > 0 else ""
			out.append(["atk" if u["intent_type"] == "attack" else "ability", "Intent", u["intent"] + threat, Color(1.0, 0.6, 0.55)])
		out.append(["", "Now", "ATK %d   HP %d/%d   SPD %d" % [u["atk"], u["hp"], u["max_hp"], u["spd"]], GOLD])
		if u["shield"] > 0:
			out.append(["shield", "Shield %d" % u["shield"], "Absorbs that much damage before HP."])
		if u["revive"]:
			out.append(["revive", "Revive ready", "The first time it dies this fight, it returns with 1 HP."])
		if u["empowered"]:
			out.append(["frenzy", "Empowered", "Boosted with extra ATK and HP for this fight."])
		if u.get("poisoned", false):
			out.append(["poison", "Poisoned", "Takes 1 damage at the end of every round until healed."])
		if u.get("veil", false):
			out.append(["veil", "Veil up", "Ignores the next damage it takes this round."])
		if u.get("spellward", false):
			out.append(["spellward", "Spellwarded", "Your spells can't target it."])
		if u.get("swine", false):
			out.append(["", "Swine", "Transformed: can't attack or use start-of-round effects this round.", Color(1.0, 0.6, 0.8)])
		if u.get("move_block", "") != "":
			out.append(["", "Can't move", u["move_block"], Color(0.7, 0.7, 0.8)])
	var terrain: String = combat.terrain_at(side, row, lane)
	if terrain != "":
		out.append(["", Data.TERRAIN[terrain]["name"], Data.TERRAIN[terrain]["text"], TERRAIN_COLORS[terrain]])
	if side == P:
		if snap["petrified_lane"] == lane:
			out.append(["", "Petrified", "Units in this lane skip their action this round.", Color(0.75, 0.9, 0.65)])
		if snap["sandstorm_row"] == row:
			out.append(["", "Sandstorm", "Units in this row get -1 ATK this round.", Color(0.98, 0.78, 0.42)])
		if snap.get("lane_warnings", {}).has(lane):
			out.append(["", "Danger", snap["lane_warnings"][lane], Color(1.0, 0.5, 0.4)])
		if "%d:%d" % [row, lane] in snap.get("quicksand_targets", []):
			out.append(["", "Quicksand incoming", "At the end of the round this slot sinks into Quicksand.", TERRAIN_COLORS["quicksand"]])
	return out


func _build_relic_row() -> void:
	for child in relic_row.get_children():
		child.queue_free()
	relic_icons.clear()
	for id in params["relics"]:
		var relic: Dictionary = Data.RELICS[id]
		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(46, 46)
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.tooltip_text = CardWidget.wrap_text("%s (%s)\n%s" % [relic["name"], relic["rarity"], relic["text"]])
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.16, 0.12, 0.2)
		frame.border_color = GOLD.darkened(0.25)
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(23)
		frame.corner_detail = 16
		frame.set_content_margin_all(6)
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
	if snap["is_boss"]:
		round_label.text = "Round %d" % snap["round"]
		round_sub.text = "Boss fight: no round limit"
	else:
		round_label.text = "Round %d / %d" % [snap["round"], snap["max_rounds"]]
		round_sub.text = "Survivors deal their Threat when time runs out"
	faith_label.text = str(snap["faith"])
	var core: int = max(snap["core_hp"], 0)
	core_bar.max_value = max(combat.core_max, core, 1)
	core_bar.value = core
	core_label.text = "%d/%d" % [core, int(core_bar.max_value)]
	info_label.text = "[color=#a8a8b8]Deck[/color] %d   [color=#a8a8b8]Discard[/color] %d   [color=#a8a8b8]Moves left[/color] %d%s" % [
		snap["deck"], snap["discard"], snap["moves_left"],
		"\n[color=#80ff90]Next spell is free (Hermes)[/color]" if snap["free_spell"] else "",
	]
	_update_relic_icons()


func _render_hand(snap: Dictionary) -> void:
	for child in hand_box.get_children():
		child.queue_free()
	var cards: Array = snap["hand"]
	for i in cards.size():
		var def: Dictionary = Data.CARDS[cards[i]["id"]]
		var cost: int = 0 if def["type"] == "spell" and snap["free_spell"] else def["cost"]
		var button := CardWidget.card_button(cards[i]["id"], i == sel_hand, cost)
		button.pressed.connect(_on_hand_pressed.bind(i))
		button.set_drag_forwarding(_hand_drag.bind(i), Callable(), Callable())
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


# ---------------------------------------------------------------- drag and drop

func _hand_drag(_pos: Vector2, i: int) -> Variant:
	if animating or combat.phase != "plan" or i >= combat.hand.size():
		return null
	if sel_hand != i:
		_on_hand_pressed(i)
	if sel_hand != i:
		return null
	var preview := Control.new()
	var face := CardWidget.card_face(combat.hand[i]["id"], CardWidget.CARD_SIZE * 0.7, false, true)
	face.position = -face.size / 2
	face.modulate = Color(1, 1, 1, 0.9)
	preview.add_child(face)
	set_drag_preview(preview)
	var card_preview = get_tree().get_first_node_in_group("card_preview")
	if card_preview:
		card_preview.holder.visible = false
	return {"hand": i}


func _board_drag(pos: Vector2) -> Variant:
	if animating or combat.phase != "plan" or sel_move == null:
		return null
	var slot = board.slot_at(pos)
	if slot == null or slot[0] != P or slot[1] != sel_move[0] or slot[2] != sel_move[1]:
		return null
	var u = last_snap["grid"][P][slot[1]][slot[2]]
	var preview := Control.new()
	var def: Dictionary = Data.CARDS[u["id"]]
	var art := CardWidget.art("cards", u["id"], def["name"], CardWidget.FACTION_COLORS[def["faction"]], 20)
	art.size = Vector2(90, 90)
	art.position = Vector2(-45, -45)
	art.modulate = Color(1, 1, 1, 0.85)
	preview.add_child(art)
	set_drag_preview(preview)
	return {"move": true}


func _board_can_drop(pos: Vector2, data) -> bool:
	var slot = board.slot_at(pos)
	board.set_hover(slot)
	return data is Dictionary and slot != null and _slot_in(_current_targets(), slot)


func _board_drop(pos: Vector2, _data) -> void:
	var slot = board.slot_at(pos)
	if slot != null:
		_on_slot_pressed(slot[0], slot[1], slot[2])


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
		text = "Drag a card onto a highlighted tile (or click the card, then the tile). Drag one of your units to an empty tile to move it. Hover over anything for details."
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
		_set_hint("Deploy %s: choose an empty tile on your side." % def["name"])
	else:
		_set_hint({
			"ally": "Choose one of your units.",
			"ally_card": "Choose one of your units to return to your hand.",
			"ally_slot": "Choose a %s tile on your side without terrain (a unit may stand there)." % ("front" if def.get("row", 0) == 0 else "back"),
			"enemy": "Choose an enemy unit.",
			"enemy_front": "Choose an enemy front unit to push.",
			"enemy_pair": "Choose the first enemy to swap.",
			"empty_ally_slot": "Choose an empty tile for the returning ally.",
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
			_set_hint("Move %s: drag or click it to an empty tile on your side." % u.display_name())
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
	var order := 0
	var last_actor := -1
	for ev in events:
		_log_line(ev["text"])
		var actor_uid: int = ev.get("actor_uid", -1)
		var fresh := actor_uid != -1 and actor_uid != last_actor
		if fresh:
			order += 1
		last_actor = actor_uid
		if not skip_animation:
			_render(ev["snap"])
			if actor_uid != -1:
				board.play_event(ev, order, fresh)
			var attack: bool = ev.has("target") or ev.has("core")
			await get_tree().create_timer(ATTACK_DELAY if attack else STEP_DELAY).timeout
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
	move_child(result_panel, get_child_count() - 1)


func _log_line(text: String) -> void:
	if text.begins_with("---"):
		log_label.append_text("\n[b][color=#e6c75a]%s[/color][/b]\n" % text)
	else:
		log_label.append_text(text + "\n")
