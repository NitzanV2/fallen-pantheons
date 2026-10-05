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
const ACTOR_GLOW := Color(1.0, 0.85, 0.35)

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
	for id in ["player", "enemy", "ley_line", "ruins", "quicksand", "sunlit", "flooded"]:
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
	var sunlit: bool = side == P and not snap.is_empty() and "%d:%d" % [row, lane] in snap.get("sunlit", [])
	if t == "" and sunlit:
		t = "sunlit"
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
		if "%d:%d" % [row, lane] in snap.get("quicksand_targets", []):
			draw_colored_polygon(quad, Color(0.95, 0.7, 0.3, 0.3))
		if sunlit and t != "sunlit":
			draw_colored_polygon(quad, Color(1.0, 0.85, 0.35, 0.25))
		if lane in snap.get("drowned_lanes", []):
			draw_colored_polygon(quad, Color(0.2, 0.65, 0.75, 0.3))
	if side == E and not snap.is_empty():
		for w in snap.get("waves", []):
			if w["lane"] == lane and w["row"] == row:
				draw_colored_polygon(quad, Color(0.25, 0.75, 0.85, 0.22))
				var center: Vector2 = (quad[0] + quad[1] + quad[2] + quad[3]) / 4.0
				var font := ThemeDB.fallback_font
				var text := "FERRY R%d" % w["round"]
				var fs := int(14 * depth)
				var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string_outline(font, center + Vector2(-width / 2, fs / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
				draw_string(font, center + Vector2(-width / 2, fs / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.7, 0.95, 1.0))
				break

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
		draw_string(font, c + Vector2(-11, 5), str(lane + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 14, GOLD)


## Lane and row effects are labelled outside the tiles, where tokens can't hide them.
func _draw_labels() -> void:
	if snap.is_empty():
		return
	var font: Font = CardWidget.TITLE_FONT
	var bottom: float = ROW_Y[3][1] + SLAB + 20
	for lane in LANES:
		var text := ""
		var color := Color(0.75, 0.9, 0.65)
		if snap["petrified_lane"] == lane:
			text = "PETRIFIED"
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
	for pair in [["judgement", u.get("judged", false)], ["revive", u["revive"]], ["poison", u.get("poisoned", false)], ["veil", u.get("veil", false)],
			["spellward", u.get("spellward", false)], ["frenzy", u["empowered"]]]:
		if pair[1]:
			status.add_child(CardWidget.icon(pair[0], 20 * sc))
	if u.get("burn", 0) > 0:
		status.add_child(_chip("burn", u["burn"], sc, Color(1.0, 0.75, 0.35)))
	for i in u.get("armaments", []).size():
		status.add_child(CardWidget.icon("armament", 20 * sc))
	for child in status.get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_END
	status.position = Vector2(size.x - 5 * sc - status.get_combined_minimum_size().x, 5 * sc)
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
		"toll":
			return "TOLL"
		"judge":
			return "JUDGE"
	var cut := text.split("(")[0].split(",")[0]
	return cut.replace("lanes ", "").replace("lane ", "").replace(" at", "").replace(" and ", "+").strip_edges().to_upper()


# ---------------------------------------------------------------- turn animation

## Animates one resolve event: the acting unit glows with its place in the turn order
## (popping in when its turn starts), melee attacks lunge, ranged attacks fire a bolt.
func play_event(ev: Dictionary, order: int, fresh: bool) -> void:
	var token := _token_for(ev.get("actor"))
	if token == null:
		return
	move_child(token, get_child_count() - 1)
	move_child(labels, get_child_count() - 1)
	_actor_glow(token, order, fresh)
	var enemy: bool = ev["actor"][0] == E
	if ev.has("target"):
		var target := _token_for(ev["target"])
		var to: Vector2 = target.position + target.size / 2 if target != null else token.position + token.size / 2
		var hit_delay := 0.12
		if ev.get("ranged", false):
			hit_delay = _shoot(token, to, enemy)
		else:
			_lunge(token, to)
		if ev.has("cleave"):
			_cleave(ev["cleave"], ev["target"], hit_delay)
		elif target != null:
			_impact(target, hit_delay)
	elif ev.get("core", false):
		_lunge(token, token.position + Vector2(token.size.x / 2, token.size.y + 400))


func _token_for(slot) -> Control:
	if slot == null:
		return null
	for t in tokens:
		if t.get_meta("slot") == slot:
			return t
	return null


func _actor_glow(token: Control, order: int, fresh: bool) -> void:
	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = ACTOR_GLOW
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(ACTOR_GLOW, 0.65)
	sb.shadow_size = 16
	glow.add_theme_stylebox_override("panel", sb)
	glow.size = token.size
	token.add_child(glow)

	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.2, 0.13, 0.03)
	bs.border_color = ACTOR_GLOW
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(16)
	bs.shadow_color = Color(0, 0, 0, 0.6)
	bs.shadow_size = 4
	badge.add_theme_stylebox_override("panel", bs)
	badge.size = Vector2(32, 32)
	badge.position = Vector2(token.size.x / 2 - 16, -20)
	badge.pivot_offset = badge.size / 2
	var num := CardWidget.number_label(str(order), 13, ACTOR_GLOW)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CardWidget.place(badge, num, 0, 1, -0.001, -0.001)
	token.add_child(badge)

	if fresh:
		token.scale = Vector2(1.12, 1.12)
		token.create_tween().tween_property(token, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		glow.modulate.a = 0.0
		glow.create_tween().tween_property(glow, "modulate:a", 1.0, 0.15)
		badge.scale = Vector2(0.3, 0.3)
		badge.create_tween().tween_property(badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _lunge(token: Control, to: Vector2) -> void:
	var start := token.position
	var dir := (to - (start + token.size / 2)).normalized()
	var tween := token.create_tween()
	tween.tween_property(token, "position", start + dir * 36, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(token, "position", start, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Fires a glowing bolt at `to`; returns how long it takes to arrive.
func _shoot(token: Control, to: Vector2, enemy: bool) -> float:
	var from := token.position + token.size / 2
	var start := token.position
	var recoil := token.create_tween()
	recoil.tween_property(token, "position", start - (to - from).normalized() * 10, 0.08)
	recoil.tween_property(token, "position", start, 0.15)
	var color := Color(1.0, 0.45, 0.4) if enemy else Color(1.0, 0.9, 0.55)
	var bolt := Panel.new()
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.lightened(0.5)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(color, 0.9)
	sb.shadow_size = 10
	bolt.add_theme_stylebox_override("panel", sb)
	bolt.size = Vector2(16, 16)
	bolt.position = from - bolt.size / 2
	add_child(bolt)
	var time := clampf(from.distance_to(to) / 1400.0, 0.12, 0.28)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "position", to - bolt.size / 2, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(bolt.queue_free)
	return time


## A slash sweeps left to right across every lane the cleave covers; each tile in reach flashes
## and every unit hit (main target and splash) takes its impact as the blade passes it.
# TODO: Mjolnir Shard also cleaves the back-row units behind front-row hits (combat._attack), but
# combat._cleave_preview doesn't report them yet, so they get no impact or tile flash here.
func _cleave(info: Dictionary, main_slot: Array, delay: float) -> void:
	var side: int = info["side"]
	var row: int = info["row"]
	var lanes: Array = info["lanes"]
	if lanes.is_empty():
		return
	var first := tile_quad(side, row, lanes[0], 0)
	var last := tile_quad(side, row, lanes[-1], 0)
	var y_mid: float = first[3].y - TOKEN_SIZE.y * ROW_SCALE[row_index(side, row)] * 0.5
	var x0: float = (first[0].x + first[3].x) / 2.0 + 10.0
	var x1: float = (last[1].x + last[2].x) / 2.0 - 10.0
	var sweep := 0.22

	for lane in lanes:
		var quad := tile_quad(side, row, lane)
		var tile := Polygon2D.new()
		tile.polygon = quad
		tile.color = Color(1.0, 0.35, 0.25, 0.0)
		add_child(tile)
		move_child(tile, 0)
		var cx: float = (quad[0].x + quad[1].x + quad[2].x + quad[3].x) / 4.0
		var at: float = delay + sweep * inverse_lerp(x0, x1, clampf(cx, x0, x1))
		var tw := tile.create_tween()
		tw.tween_interval(at)
		tw.tween_property(tile, "color:a", 0.5, 0.06)
		tw.tween_property(tile, "color:a", 0.0, 0.4)
		tw.tween_callback(tile.queue_free)

	var arc := Line2D.new()
	arc.width = 28.0
	arc.joint_mode = Line2D.LINE_JOINT_ROUND
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.1))
	curve.add_point(Vector2(0.75, 1.0))
	curve.add_point(Vector2(1, 0.3))
	arc.width_curve = curve
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.8, 0.5, 0.0), Color(1, 0.95, 0.8, 0.95), Color(1, 1, 1, 1)])
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	arc.gradient = grad
	add_child(arc)
	var bow := 20.0 if side == E else -20.0
	var draw_arc_to := func(p: float):
		var pts := PackedVector2Array()
		var steps := 16
		var tail := maxf(0.0, p - 0.55)
		for k in steps + 1:
			var t := lerpf(tail, p, k / float(steps))
			pts.append(Vector2(lerpf(x0, x1, t), y_mid - bow * sin(t * PI)))
		arc.points = pts
	arc.modulate.a = 0.0
	var tw := arc.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(arc, "modulate:a", 1.0, 0.01)
	tw.tween_method(draw_arc_to, 0.0, 1.0, sweep).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(draw_arc_to, 1.0, 1.55, 0.12)
	tw.tween_property(arc, "modulate:a", 0.0, 0.1)
	tw.tween_callback(arc.queue_free)

	for slot in [main_slot] + info["hits"]:
		var t := _token_for(slot)
		if t != null:
			var cx: float = t.position.x + t.size.x / 2
			_impact(t, delay + sweep * inverse_lerp(x0, x1, clampf(cx, x0, x1)))


func _impact(target: Control, delay: float) -> void:
	var start := target.position
	var shake := target.create_tween()
	shake.tween_interval(delay)
	for dx in [7.0, -6.0, 4.0, 0.0]:
		shake.tween_property(target, "position", start + Vector2(dx, 0), 0.04)
	var burst := Panel.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.95, 0.8, 0.85)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(1.0, 0.7, 0.3, 0.7)
	sb.shadow_size = 12
	burst.add_theme_stylebox_override("panel", sb)
	burst.size = Vector2(40, 40)
	burst.pivot_offset = burst.size / 2
	burst.position = start + target.size / 2 - burst.size / 2
	burst.scale = Vector2(0.2, 0.2)
	burst.modulate.a = 0.0
	add_child(burst)
	var tween := burst.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(burst, "modulate:a", 1.0, 0.01)
	tween.tween_property(burst, "scale", Vector2(1.8, 1.8), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.22)
	tween.tween_callback(burst.queue_free)


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
