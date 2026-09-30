extends Control
## The battlefield: a courtyard seen in perspective, four rows of textured tiles and framed unit tokens.
## Reports hovers and clicks by hit-testing tokens and tiles; the battle view decides what they mean.

signal slot_pressed(side: int, row: int, lane: int)
signal slot_hovered(slot)
signal cancel_requested

const CardWidget = preload("res://scripts/ui/card_widget.gd")
const Data = preload("res://scripts/core/data.gd")

const P := 0
const E := 1
const LANES := 4
## Drawn rows from far to near: [side, row], the top and bottom edge, and the token scale.
const ROWS := [[E, 1], [E, 0], [P, 0], [P, 1]]
const ROW_Y := [[118.0, 218.0], [222.0, 330.0], [356.0, 472.0], [476.0, 600.0]]
const ROW_SCALE := [0.74, 0.82, 0.93, 1.0]
const CENTER_X := 625.0
const DIVIDER_Y := 343.0
const TOKEN_SIZE := Vector2(152, 148)
const SLAB := 9.0
const GOLD := Color(0.95, 0.78, 0.35)
const TARGET := Color(1.0, 0.85, 0.25)
const SELECTED := Color(0.35, 1.0, 0.5)

var snap: Dictionary = {}
var terrain := {}
var targets: Array = []
var selected: Array = []
var hover = null
var tokens: Array = []
var last_hp := {}
var pulse := 0.0
var textures := {}
var labels: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in ["player", "enemy", "ley_line", "ruins", "quicksand"]:
		textures[id] = load("res://art/battle/tile_%s.jpg" % id)
	labels = Control.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	labels.draw.connect(_draw_labels)
	add_child(labels)
	mouse_exited.connect(func(): set_hover(null))


func _process(delta: float) -> void:
	if not targets.is_empty():
		pulse += delta
		queue_redraw()


## `terrain` maps "side:row:lane" to a terrain id; `targets` and `selected` are [side, row, lane] lists.
func render(s: Dictionary, terrain_map: Dictionary, target_list: Array, selected_list: Array) -> void:
	snap = s
	terrain = terrain_map
	targets = target_list
	selected = selected_list
	_rebuild_tokens()
	queue_redraw()
	labels.queue_redraw()


# ---------------------------------------------------------------- geometry

static func half_width(y: float) -> float:
	return 318.0 + (y - 118.0) * 0.4


static func row_index(side: int, row: int) -> int:
	return 1 - row if side == E else 2 + row


static func key(side: int, row: int, lane: int) -> String:
	return "%d:%d:%d" % [side, row, lane]


func tile_quad(side: int, row: int, lane: int, inset := 3.0) -> PackedVector2Array:
	var i := row_index(side, row)
	var pts := PackedVector2Array()
	for corner in [[lane, 0], [lane + 1, 0], [lane + 1, 1], [lane, 1]]:
		var y: float = ROW_Y[i][corner[1]]
		pts.append(Vector2(CENTER_X + (corner[0] / float(LANES) * 2.0 - 1.0) * half_width(y), y))
	if inset > 0:
		var center := (pts[0] + pts[1] + pts[2] + pts[3]) / 4.0
		for k in 4:
			pts[k] += (center - pts[k]).normalized() * inset
	return pts


## Where a token standing on these lanes sits: bottom centre of the tile span.
func _token_anchor(side: int, row: int, lane: int, width: int) -> Vector2:
	var first := tile_quad(side, row, lane, 0)
	var last := tile_quad(side, row, lane + width - 1, 0)
	var i := row_index(side, row)
	return Vector2((first[3].x + last[2].x) / 2.0, ROW_Y[i][1] - 7.0 * ROW_SCALE[i])


func slot_at(pos: Vector2) -> Variant:
	for k in range(tokens.size() - 1, -1, -1):
		var t: Control = tokens[k]
		if Rect2(t.position, t.size).has_point(pos):
			return t.get_meta("slot")
	for i in range(ROWS.size() - 1, -1, -1):
		for lane in LANES:
			if Geometry2D.is_point_in_polygon(pos, tile_quad(ROWS[i][0], ROWS[i][1], lane, 0)):
				return [ROWS[i][0], ROWS[i][1], lane]
	return null


## Screen rectangle of the token on this slot, or of the tile when it is empty.
func slot_rect(slot: Array) -> Rect2:
	for t in tokens:
		if t.get_meta("slot") == slot:
			return t.get_global_rect()
	var quad := tile_quad(slot[0], slot[1], slot[2], 0)
	var rect := Rect2(quad[0], Vector2.ZERO)
	for p in quad:
		rect = rect.expand(p)
	return Rect2(rect.position + global_position, rect.size)


func set_hover(slot) -> void:
	if slot == hover:
		return
	hover = slot
	queue_redraw()
	slot_hovered.emit(slot)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_hover(slot_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var slot = slot_at(event.position)
			if slot != null:
				slot_pressed.emit(slot[0], slot[1], slot[2])
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
			accept_event()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var outline := PackedVector2Array([tile_quad(E, 1, 0, 0)[0], tile_quad(E, 1, 3, 0)[1], tile_quad(P, 1, 3, 0)[2], tile_quad(P, 1, 0, 0)[3]])
	var shadow := PackedVector2Array()
	for p in outline:
		shadow.append(p + (p - Vector2(CENTER_X, 360)).normalized() * 16 + Vector2(0, 14))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.38))

	for i in ROWS.size():
		var side: int = ROWS[i][0]
		var row: int = ROWS[i][1]
		for lane in LANES:
			_draw_tile(side, row, lane, i)
	_draw_divider()
	for t in tokens:
		var foot: Vector2 = t.position + Vector2(t.size.x / 2, t.size.y)
		_draw_ellipse(foot + Vector2(0, -2), Vector2(t.size.x * 0.5, t.size.x * 0.13), Color(0, 0, 0, 0.45))


func _draw_tile(side: int, row: int, lane: int, i: int) -> void:
	var slot := [side, row, lane]
	var quad := tile_quad(side, row, lane)
	var t: String = terrain.get(key(side, row, lane), "")
	var depth: float = ROW_SCALE[i]
	var slab := PackedVector2Array([quad[3], quad[2], quad[2] + Vector2(0, SLAB * depth), quad[3] + Vector2(0, SLAB * depth)])
	draw_colored_polygon(slab, Color(0.09, 0.06, 0.12) if side == E else Color(0.2, 0.14, 0.09))

	var shade: float = 0.62 + 0.38 * (depth - 0.74) / 0.26
	if side == E:
		shade *= 0.9
	var tex: Texture2D = textures[t] if t != "" else textures["player" if side == P else "enemy"]
	var colors := PackedColorArray()
	for k in 4:
		colors.append(Color(shade, shade, shade))
	draw_polygon(quad, colors, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)

	if side == P and not snap.is_empty():
		if snap["petrified_lane"] == lane:
			draw_colored_polygon(quad, Color(0.55, 0.68, 0.5, 0.38))
		if snap["sandstorm_row"] == row:
			draw_colored_polygon(quad, Color(0.95, 0.72, 0.35, 0.22))
		if snap.get("lane_warnings", {}).has(lane):
			draw_colored_polygon(quad, Color(1.0, 0.25, 0.15, 0.2 + 0.08 * sin(pulse * 4.0)))
		if "%d:%d" % [row, lane] in snap.get("quicksand_targets", []):
			draw_colored_polygon(quad, Color(0.95, 0.7, 0.3, 0.3))

	var closed := quad.duplicate()
	closed.append(quad[0])
	draw_polyline(closed, Color(0, 0, 0, 0.55), 1.5, true)
	if _has(targets, slot):
		draw_colored_polygon(quad, Color(TARGET, 0.12 + 0.08 * sin(pulse * 5.0)))
		draw_polyline(closed, TARGET, 3.0, true)
	if _has(selected, slot):
		draw_colored_polygon(quad, Color(SELECTED, 0.16))
		draw_polyline(closed, SELECTED, 3.0, true)
	elif hover == slot:
		draw_colored_polygon(quad, Color(1, 1, 1, 0.08))
		draw_polyline(closed, Color(1, 1, 1, 0.55), 2.0, true)


func _draw_divider() -> void:
	var hw := half_width(DIVIDER_Y)
	var left := Vector2(CENTER_X - hw, DIVIDER_Y)
	var right := Vector2(CENTER_X + hw, DIVIDER_Y)
	draw_line(left, right, Color(GOLD, 0.25), 7.0, true)
	draw_line(left, right, Color(GOLD, 0.7), 2.0, true)
	var font: Font = CardWidget.NUMBER_FONT
	for lane in LANES:
		var c := Vector2(CENTER_X + ((lane + 0.5) / LANES * 2.0 - 1.0) * hw, DIVIDER_Y)
		draw_circle(c, 11, Color(0.08, 0.06, 0.1))
		draw_arc(c, 11, 0, TAU, 24, GOLD, 2.0, true)
		draw_string(font, c + Vector2(-11, 5), str(lane + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 10, GOLD)


## Lane and row effects are labelled outside the tiles, where tokens can't hide them.
func _draw_labels() -> void:
	if snap.is_empty():
		return
	var font: Font = CardWidget.TITLE_FONT
	var bottom: float = ROW_Y[3][1] + SLAB + 20
	for lane in LANES:
		var text := ""
		var color := Color(1.0, 0.55, 0.45)
		if snap.get("lane_warnings", {}).has(lane):
			text = snap["lane_warnings"][lane]
		elif snap["petrified_lane"] == lane:
			text = "PETRIFIED"
			color = Color(0.75, 0.9, 0.65)
		if text != "":
			var quad := tile_quad(P, 1, lane, 0)
			var cx: float = (quad[2].x + quad[3].x) / 2.0
			labels.draw_string_outline(font, Vector2(cx - 130, bottom), text, HORIZONTAL_ALIGNMENT_CENTER, 260, 16, 5, Color(0, 0, 0, 0.9))
			labels.draw_string(font, Vector2(cx - 130, bottom), text, HORIZONTAL_ALIGNMENT_CENTER, 260, 16, color)
	if snap["sandstorm_row"] in [0, 1]:
		var i := row_index(P, snap["sandstorm_row"])
		var y: float = (ROW_Y[i][0] + ROW_Y[i][1]) / 2.0
		var x: float = CENTER_X - half_width(y) - 16
		for line in [["SANDSTORM", 0], ["-1 ATK", 18]]:
			labels.draw_string_outline(font, Vector2(x - 150, y + line[1]), line[0], HORIZONTAL_ALIGNMENT_RIGHT, 150, 16, 5, Color(0, 0, 0, 0.9))
			labels.draw_string(font, Vector2(x - 150, y + line[1]), line[0], HORIZONTAL_ALIGNMENT_RIGHT, 150, 16, Color(0.98, 0.78, 0.42))


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)


static func _has(list: Array, slot: Array) -> bool:
	for s in list:
		if s[0] == slot[0] and s[1] == slot[1] and s[2] == slot[2]:
			return true
	return false


# ---------------------------------------------------------------- tokens

func _rebuild_tokens() -> void:
	for t in tokens:
		t.queue_free()
	tokens.clear()
	var hp_now := {}
	for i in ROWS.size():
		var side: int = ROWS[i][0]
		var row: int = ROWS[i][1]
		for lane in LANES:
			var u = snap["grid"][side][row][lane]
			if u == null or u.get("wide_part", false):
				continue
			var width: int = u.get("width", 1)
			var sc: float = ROW_SCALE[i]
			var w: float = TOKEN_SIZE.x * sc
			if width > 1:
				var span := tile_quad(side, row, lane + width - 1, 0)[2].x - tile_quad(side, row, lane, 0)[3].x
				w = span - 40 * sc
			var token := _make_token(u, sc, w, _has(selected, [side, row, lane]))
			var foot := _token_anchor(side, row, lane, width)
			token.position = foot - Vector2(token.size.x / 2, token.size.y)
			token.set_meta("slot", [side, row, lane])
			add_child(token)
			tokens.append(token)
			hp_now[u["uid"]] = u["hp"]
			if last_hp.has(u["uid"]) and last_hp[u["uid"]] != u["hp"]:
				_flash(token, u["hp"] - last_hp[u["uid"]])
	last_hp = hp_now
	move_child(labels, get_child_count() - 1)


func _make_token(u: Dictionary, sc: float, width: float, is_selected: bool) -> Control:
	var enemy: bool = u["side"] == E
	var size := Vector2(width, TOKEN_SIZE.y * sc)
	var root := Control.new()
	root.size = size
	root.pivot_offset = Vector2(size.x / 2, size.y)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var metal: Color
	var tint: Color
	if enemy:
		var kind: String = Data.ENEMIES[u["id"]]["kind"]
		metal = CardWidget.RARITY_STYLES[kind]["metal"]
		tint = CardWidget.ENEMY_COLORS[kind]
	else:
		var def: Dictionary = Data.CARDS[u["id"]]
		metal = CardWidget.RARITY_STYLES.get(def["rarity"], CardWidget.RARITY_STYLES["Starter"])["metal"]
		tint = CardWidget.FACTION_COLORS[def["faction"]]

	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09)
	sb.border_color = SELECTED if is_selected else metal
	sb.set_border_width_all(max(2, int(round(3 * sc))))
	sb.set_corner_radius_all(int(8 * sc))
	sb.shadow_color = Color(SELECTED, 0.6) if is_selected else Color(0, 0, 0, 0.5)
	sb.shadow_size = int((10 if is_selected else 4) * sc)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardWidget.place(root, frame, 0, 0, -0.001, -0.001)

	var bar_h: float = 26 * sc
	var art_bottom: float = size.y - bar_h - 4 * sc
	var art := CardWidget.art("enemies" if enemy else "cards", u["id"], u["name"], tint, int(24 * sc))
	if u.get("swine", false):
		art.modulate = Color(1.0, 0.6, 0.78)
	CardWidget.place(root, art, 4 * sc, 4 * sc, -4 * sc, art_bottom)

	if enemy and u.get("intent", "") != "":
		root.add_child(_intent_ribbon(u, sc, Rect2(4 * sc, art_bottom - 20 * sc, size.x - 8 * sc, 20 * sc)))

	var ratio: float = clamp(float(u["hp"]) / max(1, u["max_hp"]), 0.0, 1.0)
	var hp_back := ColorRect.new()
	hp_back.color = Color(0.15, 0.03, 0.04)
	hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_back.position = Vector2(4 * sc, art_bottom)
	hp_back.size = Vector2(size.x - 8 * sc, 4 * sc)
	root.add_child(hp_back)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.35, 0.85, 0.4) if ratio > 0.5 else (Color(0.95, 0.75, 0.2) if ratio > 0.25 else Color(0.95, 0.25, 0.2))
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.size = Vector2(hp_back.size.x * ratio, hp_back.size.y)
	hp_back.add_child(hp_fill)

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(_chip("atk", u["atk"], sc, Color.WHITE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(spacer)
	stats.add_child(_chip("hp", u["hp"], sc, Color(1.0, 0.55, 0.5) if u["hp"] < u["max_hp"] else Color.WHITE))
	CardWidget.place(root, stats, 6 * sc, size.y - bar_h, -6 * sc, size.y - 3 * sc)

	if u["shield"] > 0:
		var badge := CardWidget.icon("shield", 30 * sc)
		badge.position = Vector2(-9, -9) * sc
		badge.size = Vector2(30, 30) * sc
		root.add_child(badge)
		var num := CardWidget.number_label(str(u["shield"]), 11 * sc, Color.WHITE)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		CardWidget.place(badge, num, 0, 1 * sc, -0.001, -0.001)

	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", int(2 * sc))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["revive", u["revive"]], ["poison", u.get("poisoned", false)], ["veil", u.get("veil", false)],
			["spellward", u.get("spellward", false)], ["frenzy", u["empowered"]]]:
		if pair[1]:
			status.add_child(CardWidget.icon(pair[0], 20 * sc))
	status.position = Vector2(size.x - 25 * sc, 5 * sc)
	root.add_child(status)
	return root


func _chip(icon_id: String, value: int, sc: float, color: Color) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", int(2 * sc))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(CardWidget.icon(icon_id, 20 * sc))
	chip.add_child(CardWidget.number_label(str(value), 12 * sc, color))
	return chip


## Attacks show the damage; special moves show their name, e.g. "CHARGE 3".
func _intent_ribbon(u: Dictionary, sc: float, rect: Rect2) -> Control:
	var ribbon := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.04, 0.08, 0.9)
	sb.border_color = Color(1.0, 0.4, 0.35, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(3 * sc))
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.position = rect.position
	ribbon.size = rect.size
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(3 * sc))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var type: String = u.get("intent_type", "")
	if type == "attack":
		row.add_child(CardWidget.icon("atk", 16 * sc))
		row.add_child(CardWidget.number_label(str(u["atk"]), 11 * sc, Color(1.0, 0.85, 0.8)))
	else:
		var label := CardWidget._label(short_intent(u["intent"], type), int(13 * sc), Color(1.0, 0.82, 0.55), true)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
	CardWidget.place(ribbon, row, 0, 0, -0.001, -0.001)
	return ribbon


static func short_intent(text: String, type: String) -> String:
	match type:
		"wait":
			return "WARD" if text.begins_with("Ward") else "WAIT"
		"sandstorm":
			return "SANDSTORM"
	var cut := text.split("(")[0].split(",")[0]
	return cut.replace("lanes ", "").replace("lane ", "").replace(" at", "").replace(" and ", "+").strip_edges().to_upper()


func _flash(token: Control, delta_hp: int) -> void:
	token.modulate = Color(1.0, 0.4, 0.4) if delta_hp < 0 else Color(0.5, 1.0, 0.55)
	token.create_tween().tween_property(token, "modulate", Color.WHITE, 0.35)
	var num := CardWidget.number_label("%+d" % delta_hp, 16, Color(1.0, 0.45, 0.4) if delta_hp < 0 else Color(0.5, 1.0, 0.55))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.size = Vector2(80, 24)
	num.position = token.position + Vector2(token.size.x / 2 - 40, 8)
	add_child(num)
	var tween := num.create_tween()
	tween.set_parallel(true)
	tween.tween_property(num, "position:y", num.position.y - 34, 0.8)
	tween.tween_property(num, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(num.queue_free)
