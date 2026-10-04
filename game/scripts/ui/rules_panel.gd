extends ColorRect
## The in-battle rulebook: chapters on the left, illustrated rules on the right.
## Keep the rules in sync with combat.gd.

const CardWidget = preload("res://scripts/ui/card_widget.gd")

const GOLD := Color(0.95, 0.78, 0.35)
const TEXT := Color(0.88, 0.87, 0.92)
const MUTED := Color(0.66, 0.65, 0.74)
const ENEMY_RED := Color(1.0, 0.55, 0.5)
const CARD_BG := Color(0.12, 0.11, 0.17)
const PANEL_SIZE := Vector2(1420, 850)
## [title, icon]. Icons without a folder live in art/icons.
const CHAPTERS := [
	["Basics", "map/start.png"],
	["Attacking", "atk"],
	["Keywords", "ability"],
	["Cards & moves", "opt_card"],
	["Enemies", "map/elite.png"],
	["Terrain", "battle/tile_ley_line.jpg"],
]

var nav_buttons: Array = []
var pages: Array = []
var scroll: ScrollContainer


func _ready() -> void:
	color = Color(0, 0, 0, 0.72)
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.1, 0.98)
	sb.border_color = Color(GOLD, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)
	header.add_child(CardWidget.icon("rulebook", 58))
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(CardWidget._label("Rulebook", 32, GOLD, true))
	titles.add_child(CardWidget._label("How battles work. Press H at any time to open or close it.", 14, MUTED, false))
	var close := Button.new()
	close.text = "Close (Esc)"
	close.custom_minimum_size = Vector2(140, 42)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): visible = false)
	CardWidget.style_button(close, false, 15)
	header.add_child(close)
	box.add_child(_line())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(230, 0)
	nav.add_theme_constant_override("separation", 8)
	body.add_child(nav)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)

	var builders := [_basics, _attacking, _keywords, _cards, _enemies, _terrain]
	for i in CHAPTERS.size():
		var b := Button.new()
		b.text = CHAPTERS[i][0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		b.icon = _tex(CHAPTERS[i][1])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 38)
		b.add_theme_constant_override("h_separation", 12)
		b.pressed.connect(_select.bind(i))
		nav.add_child(b)
		nav_buttons.append(b)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		holder.add_child(page)
		pages.append(page)
		builders[i].call(page)
	_select(0)


func _select(index: int) -> void:
	for i in pages.size():
		pages[i].visible = i == index
		var b: Button = nav_buttons[i]
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font"]:
			b.remove_theme_color_override(key)
		b.remove_theme_font_override("font")
		CardWidget.style_button(b, i == index, 17)
	scroll.scroll_vertical = 0


# ---------------------------------------------------------------- chapters

func _basics(page: VBoxContainer) -> void:
	_heading(page, "map/fight.png", "Goal")
	_grid(page, 3, [
		["map/fight.png", "Destroy every enemy", "Clear the enemy side before the round limit to win the fight."],
		["hp", "Survivors hit your Core", "When time runs out, every surviving enemy hits your [b]Reliquary Core[/b] for its [b]Threat[/b]."],
		["revive", "Units may fall", "The run is lost only when the Core reaches 0 HP. Losing all your units does [b]not[/b] lose the fight - deploy again next round."],
	])

	_heading(page, "battle/tile_player.jpg", "The battlefield")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	page.add_child(row)
	row.add_child(BoardDiagram.new())
	row.add_child(_rich("""Both sides have [b]4 lanes[/b] and [b]2 rows[/b] (front and back).

Units fight [b]across their lane[/b]: your lane 1 faces enemy lane 1 (highlighted).

Your [b]front row[/b] meets the enemy. From the [b]back row[/b] only %s [b]Ranged[/b] units can attack, but it is safer.

An enemy whose lane is empty on your side hits your %s [b]Core[/b] instead.""" % [_i("ranged"), _i("hp")], 17))

	_heading(page, "start_round", "A round, step by step")
	_flow(page, [
		["faith", "1. Plan", "Gain Faith, draw cards and read enemy intents. Play cards and move units - nothing fights yet. [i]Undo round[/i] takes it all back."],
		["start_round", "2. Start of round", "Start-of-round effects: Support, Rally, Zeus, Scarab Queen, ..."],
		["spd", "3. Attacks", "Every unit attacks once, fastest first (see Attacking)."],
		["end_round", "4. End of round", "End-of-round effects: Growth, Apollo, Scarab Amulet, the Herald's Void Tide."],
	])
	_tip(page, "Press [b]END PLANNING[/b] to finish step 1. Steps 2 to 4 then play out automatically.")

	_heading(page, "map/void.png", "Round limit")
	page.add_child(_rich("Normal and elite fights last [b]3 rounds[/b]. Deeper floors add rounds (noted in the fight title), and Golden Fleece adds 1. The boss fight has no limit, but its Void Tide hits your Core every round."))


func _attacking(page: VBoxContainer) -> void:
	_heading(page, "spd", "Who acts first")
	page.add_child(_rich("Units act from [b]highest %s SPD to lowest[/b]. A unit killed before its turn does not act. Ties are broken in this order:" % _i("spd")))
	_numbered_row(page, ["Your units before enemies", "Lower lane number first", "Front row before back row"])

	_heading(page, "ranged", "Who can attack")
	_grid(page, 3, [
		["atk", "Front row", "Always attacks."],
		["ranged", "Back row", "Attacks only if [b]Ranged[/b]. Melee units wait there, but their Support, Rally and Reinforce still work."],
		["shield", "No counter-damage", "Only the attacker deals damage."],
	])

	_heading(page, "taunt", "Choosing a target", "checked top to bottom")
	_steps(page, [
		["taunt", "Taunt", "An enemy with Taunt in the attacker's lane or an adjacent lane must be attacked - own lane first, then the lane to the left, then the right. A back-row Taunt unit only counts if nothing stands in front of it."],
		["atk", "Own lane", "The front unit, or the back unit if the front slot is empty."],
		["push_right", "Empty lane", "[b]Your[/b] units attack the nearest lane that has an enemy (left before right when equally close), front unit first. [b]Enemies[/b] hit your Core instead."],
	])

	_heading(page, "airborne", "Out of reach")
	_grid(page, 2, [
		["battle/tile_ruins.jpg", "Ruins block Ranged", "Ranged attackers can't target a unit standing on Ruins."],
		["airborne", "Airborne dodges melee", "Melee attackers can't target Airborne enemies."],
	])
	page.add_child(_rich("Units an attacker can't target are skipped as if the slot were empty. With [b]Eye of Horus[/b], your Ranged units check the back row before the front row."))

	_heading(page, "enemies/void_wisp.jpg", "Enemies with their own targeting")
	_grid(page, 3, [
		["enemies/void_wisp.jpg", "Void Wisp", "Snipes your lowest-HP unit."],
		["enemies/hollow_archer.jpg", "Hollow Archer", "Hits your back row first."],
		["enemies/carrion_harpy.jpg", "Carrion Harpy", "Hits your back row first."],
	], 64)


func _keywords(page: VBoxContainer) -> void:
	page.add_child(_rich("Hover over any unit or card to see its full text. The icons on a card show which of these it has."))
	_heading(page, "ability", "Keywords")
	_grid(page, 2, [
		["shield", "Shield X", "Absorbs the next X damage before HP. Stacks and lasts the whole fight."],
		["taunt", "Taunt", "Enemies attacking from its lane or an adjacent lane must target it."],
		["ranged", "Ranged", "Can attack from the back row. Can't target units on Ruins."],
		["cleave", "Cleave", "Also hits the units in the lanes on both sides of the target, in the same row, for full damage."],
		["pierce", "Pierce", "Damage beyond what kills the target carries to the unit behind it. An enemy's Pierce continues into your Core."],
		["rally", "Rally X", "Start of round: its row neighbours gain +X ATK for the rest of the fight. Stacks every round."],
		["support", "Support", "Start of round: helps the ally directly in front of it (same lane). Works from the back row."],
		["reinforce", "Reinforce", "When the ally in front of it dies, it immediately steps into the front slot."],
		["on_death", "On-Death", "Triggers when the unit dies (and also when it Revives)."],
		["revive", "Revive", "Once per fight: when it dies, its On-Death and other units' \"whenever an ally dies\" effects trigger, then it returns in the same slot with 1 HP."],
		["growth", "Growth", "End of round: gains the listed stats."],
		["summon", "Summon", "Creates a token (like a 1/1 Scarab) in an empty slot. Tokens never join your deck."],
		["exhaust", "Exhaust", "After you cast it, the card is gone for the rest of this fight."],
		["immovable", "Immovable", "Can't be pushed or swapped and takes no collision damage."],
		["hp", "Threat", "Damage the enemy deals to your Core if it survives until time runs out."],
		["map/elite.png", "Empowered", "On deeper floors, one enemy per fight gets bonus ATK and HP. It is marked on the board."],
	])
	_heading(page, "thorns", "Enemy keywords")
	_grid(page, 2, [
		["thorns", "Thorns X", "Melee units that attack it take X damage. Ranged attacks and spells are safe."],
		["airborne", "Airborne", "Melee attacks can't target it (Cleave splash skips it too). Use Ranged units and spells."],
		["veil", "Veil", "Ignores the first damage it takes each round, however small. Open with a weak hit, then strike hard."],
		["split", "Split", "When it dies, two smaller copies appear in its slot and the nearest empty slot in its row (left first)."],
		["frenzy", "Frenzy", "Gains +1 ATK each time it takes damage and survives. Kill it in one burst."],
		["poison", "Poison", "Units it hits are Poisoned: they take 1 damage at the end of every round. Any heal cures it, even at full HP."],
		["spellward", "Spellward", "Your spells can't target it or the enemies next to it (left, right, in front, behind). It gains Shield 2 whenever you cast a spell."],
	])


func _cards(page: VBoxContainer) -> void:
	_heading(page, "faith", "Faith and your hand")
	_grid(page, 2, [
		["faith", "Faith", "You get [b]3 Faith[/b] each Plan phase to pay for cards. Unspent Faith is lost."],
		["ui_deck", "Drawing", "Draw [b]5 cards[/b] in round 1 and [b]2[/b] in each later round. Your hand carries over between rounds, up to [b]7 cards[/b] - with a full hand, extra draws stay in the deck. When the deck runs out, the discard pile is shuffled into a new deck."],
	])
	_heading(page, "opt_card", "Playing cards")
	_grid(page, 2, [
		["cards/ark_sentinel.jpg", "Units", "Deploy into any empty slot on your grid. When a unit dies, its card goes to the discard pile and can be drawn again this fight."],
		["cards/divine_favor.jpg", "Spells", "Go to the discard pile after casting, unless they [b]Exhaust[/b]."],
	], 64)
	_tip(page, "Dimmed cards can't be played right now: not enough Faith, or no legal target.")
	page.add_child(_rich("[b]God power:[/b] the power you chose for the run sits in the sidebar (or press [b]G[/b]). Use it during planning; it costs no Faith. After a fight where you used it, it [b]recharges for 3 floors[/b] - save it for fights that matter. Drafting cards of your patron's pantheon unlocks upgrades for it between fights."))
	_heading(page, "push_right", "Moving units")
	page.add_child(_rich("Once per round, click one of your units, then an empty slot on your grid, to move it (or drag it there). Some cards give extra moves (Loki, Longship). The status panel shows your moves left.\n\nUnits that entered the board this round - deployed, returned by Book of the Dead, or summoned by a spell - aren't locked in yet: until you end planning you can move them freely, as often as you like, without using a move (this doesn't count as moving for Raider, Ulfhednar, Loki or Longship). Other units on Quicksand can't move at all."))
	_heading(page, "opt_curse", "Curses and statuses")
	page.add_child(_rich("They can't be played and just take up space. They leave your hand at the start of the next round: curses go to the discard pile, statuses are exhausted. Some also cost Faith or Core HP - read the card.\nEnemies marked [color=#ff9a9a](+Void Web)[/color] or similar shuffle a status card into your draw pile each time they attack."))


func _enemies(page: VBoxContainer) -> void:
	_heading(page, "atk", "Intents")
	page.add_child(_rich("Each enemy shows its plan on a ribbon under its portrait. Intents are chosen at the start of the Plan phase and [b]lock onto a lane[/b], so you can move units out of a targeted lane to dodge."))
	_grid(page, 2, [
		["atk", "Attack lane X", "A normal attack, using the targeting rules."],
		["reinforce", "Wait", "A melee enemy in the back row. It does nothing unless it Reinforces."],
		["enemies/void_charger.jpg", "CHARGE lane X", "Moves into that front slot (swapping with any enemy there), then attacks."],
		["enemies/echo_of_medusa.jpg", "PETRIFY lane X", "Your units in that lane skip their action this round."],
		["enemies/echo_of_set.jpg", "SANDSTORM", "Your units in that row have -1 ATK this round."],
		["enemies/siege_engine.jpg", "AIM / SIEGE lane X", "Aims one round, then hits both of your slots in that lane for its ATK the next. The lane is marked on your side - move out before it fires."],
		["enemies/hollow_geomancer.jpg", "QUICKSAND", "Turns that slot of yours into Quicksand at the end of the round."],
		["enemies/echo_of_circe.jpg", "TRANSFORM", "Circe turns that unit into a Swine for the round: it can't attack or use start-of-round effects."],
		["enemies/void_herald.jpg", "TARGET / STRIKE", "The Void Herald's attacks. STRIKE deals 5 to both slots of a lane and to the front units beside it."],
		["enemies/hel.jpg", "HARVEST", "Hel attacks your lowest-HP unit."],
		["enemies/apep.jpg", "CONSTRICT lane X", "Apep hits both of your slots in that lane."],
	], 60)

	_heading(page, "map/void.png", "Bosses")
	page.add_child(_rich("Each run faces one of three bosses, shown on the map from the start (hover the boss node). Boss fights have no round limit, and each boss favours some strategies and punishes others."))
	_grid(page, 3, [
		["enemies/void_herald.jpg", "Void Herald", "Fills lanes 2-3. Its Void Tide deals 5 to your Core every round, so slow decks suffer."],
		["enemies/hel.jpg", "Hel", "Hides behind Draugr that rise again each round. HARVEST hits your lowest-HP unit, and every unit you lose for good heals her 2 and costs the Core 2. She grows stronger each round - keep your units alive."],
		["enemies/apep.jpg", "Apep", "Coils across the whole back row. Shield is useless while it lives, units it kills can't Revive, and CONSTRICT crushes whole lanes - move out of them."],
	], 92)
	_tip(page, "When Hel or Apep falls, their minions go with them.")


func _terrain(page: VBoxContainer) -> void:
	_heading(page, "battle/tile_ley_line.jpg", "Terrain")
	_grid(page, 3, [
		["battle/tile_ley_line.jpg", "Ley Line", "Gold border. The unit in this slot has [b]+2 ATK[/b]."],
		["battle/tile_ruins.jpg", "Ruins", "Brown border. Cover: Ranged attacks can't target the unit in this slot."],
		["battle/tile_quicksand.jpg", "Quicksand", "Sand border. The unit in this slot can't be moved and has [b]-1 SPD[/b]. Only enemy Geomancers create it."],
	], 72)
	page.add_child(_rich("Terrain can appear on either side of the board - enemy archers sometimes shelter in Ruins, and enemies on a Ley Line hit harder.\n\nTerrain belongs to the [b]slot[/b], not the unit: moving a unit off it loses the effect. A slot holds one terrain at a time. [b]Channel Ley Line[/b] creates a Ley Line on a front slot and [b]Raise Ruins[/b] creates Ruins on a back slot, for the rest of the fight - only on slots without terrain, but a unit may already stand there."))

	_heading(page, "push_left", "Pushing and collisions")
	page.add_child(_rich("[b]Rebuke[/b] pushes an enemy front unit one lane. You pick the direction, and the prompt shows what will happen."))
	_grid(page, 3, [
		["push_right", "Open lane", "The unit simply moves over."],
		["cleave", "Hits a unit", "Both units take [b]3 damage[/b] and stay put. An Immovable unit takes none - only the pushed one is hurt."],
		["push_left", "Hits the edge", "The pushed unit takes [b]3 damage[/b]."],
	])


# ---------------------------------------------------------------- building blocks

func _tex(id: String) -> Texture2D:
	var path := ("res://art/%s" % id) if "/" in id else ("res://art/icons/%s.png" % id)
	return load(path) if ResourceLoader.exists(path) else null


## Inline icon for rich text.
func _i(id: String) -> String:
	return "[img=22x22]res://art/icons/%s.png[/img]" % id


## Icons are drawn as-is; enemy, card and tile art get a rounded frame.
func _picture(id: String, px: float) -> Control:
	if not "/" in id or id.begins_with("map/"):
		var icon := TextureRect.new()
		icon.texture = _tex(id)
		icon.custom_minimum_size = Vector2(px, px)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return icon
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(px, px)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08)
	sb.set_corner_radius_all(int(px * 0.18))
	frame.add_theme_stylebox_override("panel", sb)
	var art := TextureRect.new()
	art.texture = _tex(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(art)
	if id.begins_with("enemies/") and art.texture != null:
		CardWidget.focus_art(art, CardWidget.ART_FOCUS.get(id.get_file().get_basename(), 0.4), 1.15)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = ENEMY_RED.darkened(0.2) if id.begins_with("enemies/") else Color(GOLD, 0.8)
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(int(px * 0.18))
	ring.add_theme_stylebox_override("panel", rs)
	frame.add_child(ring)
	return frame


func _rich(text: String, font_size := 16) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	for key in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		rtl.add_theme_font_size_override(key, font_size)
	rtl.add_theme_color_override("default_color", TEXT)
	rtl.add_theme_constant_override("line_separation", 3)
	rtl.text = text
	return rtl


func _line() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.3)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _heading(page: VBoxContainer, icon: String, text: String, note := "") -> void:
	if page.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		page.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	page.add_child(row)
	var pic := _picture(icon, 36)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var title := CardWidget._label(text, 24, GOLD, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	if note != "":
		var hint := CardWidget._label("(%s)" % note, 14, MUTED, false)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hint)
	page.add_child(_line())


func _card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = Color(0.5, 0.44, 0.34, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


## A card with a picture beside a title and description: [picture, title, text].
func _card(item: Array, px: float) -> PanelContainer:
	var panel := _card_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_picture(item[0], px))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(CardWidget._label(item[1], 17, GOLD, true))
	col.add_child(_rich(item[2], 15))
	return panel


func _grid(page: VBoxContainer, columns: int, items: Array, px := 46) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	for item in items:
		grid.add_child(_card(item, px))


## Steps in a row joined by arrows: [picture, title, text].
func _flow(page: VBoxContainer, items: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	for i in items.size():
		if i > 0:
			var arrow := _picture("push_right", 30)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(arrow)
		var panel := _card_panel()
		panel.size_flags_stretch_ratio = 1.0
		row.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		panel.add_child(col)
		var pic := _picture(items[i][0], 52)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
		var title := CardWidget._label(items[i][1], 18, GOLD, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(title)
		var text := _rich("[center]%s[/center]" % items[i][2], 14)
		col.add_child(text)


## Priority list, top to bottom, each with a number badge: [picture, title, text].
func _steps(page: VBoxContainer, items: Array) -> void:
	for i in items.size():
		var panel := _card_panel()
		page.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var badge := _badge(i + 1)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
		var pic := _picture(items[i][0], 44)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		col.add_child(CardWidget._label(items[i][1], 17, GOLD, true))
		col.add_child(_rich(items[i][2], 15))


## Short ordered rules side by side, each with a number badge.
func _numbered_row(page: VBoxContainer, items: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	for i in items.size():
		var panel := _card_panel()
		row.add_child(panel)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
		panel.add_child(inner)
		inner.add_child(_badge(i + 1))
		var label := CardWidget._label(items[i], 15, TEXT, false)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(label)


func _badge(n: int) -> Control:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(32, 32)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.16, 0.06)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	badge.add_theme_stylebox_override("panel", sb)
	var label := CardWidget.number_label(str(n), 13, GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(label)
	return badge


func _tip(page: VBoxContainer, text: String) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.14, 0.2, 0.9)
	sb.border_color = Color(0.5, 0.75, 1.0, 0.8)
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	page.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var pic := _picture("rulebook", 26)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	row.add_child(_rich(text, 15))


## A small top-down sketch of the board: enemy rows above, yours below, lane 1 highlighted, the Core at the bottom.
class BoardDiagram extends Control:
	const CW = preload("res://scripts/ui/card_widget.gd")
	const LANE_W := 80.0
	const ROW_H := 54.0
	const LEFT := 112.0
	const GAP := 28.0
	const CORE_H := 38.0
	const ROW_NAMES := ["Enemy back", "Enemy front", "Your front", "Your back"]
	const GOLD := Color(0.95, 0.78, 0.35)

	var tiles := {}
	var faces := {}
	var heart: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(LEFT + LANE_W * 4 + 4, ROW_H * 4 + GAP + CORE_H + 16)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tiles = {"enemy": load("res://art/battle/tile_enemy.jpg"), "player": load("res://art/battle/tile_player.jpg")}
		heart = load("res://art/icons/hp.png")
		# [lane, drawn row] -> portrait
		faces = {
			Vector2i(0, 1): load("res://art/enemies/void_spawn.jpg"),
			Vector2i(2, 1): load("res://art/enemies/hollowed_bulwark.jpg"),
			Vector2i(3, 0): load("res://art/enemies/hollow_archer.jpg"),
			Vector2i(0, 2): load("res://art/cards/ark_sentinel.jpg"),
			Vector2i(1, 3): load("res://art/cards/echo_archer.jpg"),
		}

	func _row_y(r: int) -> float:
		return r * ROW_H + (GAP if r >= 2 else 0.0)

	func _draw() -> void:
		var font: Font = CW.TITLE_FONT
		for r in 4:
			var y := _row_y(r)
			var enemy := r < 2
			draw_string(font, Vector2(0, y + ROW_H / 2 + 6), ROW_NAMES[r], HORIZONTAL_ALIGNMENT_LEFT, LEFT - 8, 15,
				Color(1.0, 0.6, 0.55) if enemy else Color(0.7, 0.85, 1.0))
			for lane in 4:
				var rect := Rect2(LEFT + lane * LANE_W + 2, y + 2, LANE_W - 4, ROW_H - 4)
				draw_texture_rect(tiles["enemy" if enemy else "player"], rect, false, Color(1, 1, 1, 0.9))
				draw_rect(rect, Color(0, 0, 0, 0.55), false, 1.0)
				var face: Texture2D = faces.get(Vector2i(lane, r))
				if face != null:
					var side := ROW_H - 12
					var dest := Rect2(rect.get_center() - Vector2(side, side) / 2, Vector2(side, side))
					var full := face.get_size()
					var sq := minf(full.x, full.y)
					draw_texture_rect_region(face, dest, Rect2((full.x - sq) / 2, 0, sq, sq))
					draw_rect(dest, Color(1.0, 0.45, 0.4) if enemy else GOLD, false, 2.0)
		var mid := 2 * ROW_H + GAP / 2
		draw_line(Vector2(LEFT, mid), Vector2(LEFT + LANE_W * 4, mid), Color(GOLD, 0.5), 2.0)
		for lane in 4:
			var c := Vector2(LEFT + (lane + 0.5) * LANE_W, mid)
			draw_circle(c, 11, Color(0.1, 0.08, 0.05))
			draw_arc(c, 11, 0, TAU, 24, GOLD, 2.0)
			draw_string(CW.NUMBER_FONT, c + Vector2(-12, 5), str(lane + 1), HORIZONTAL_ALIGNMENT_CENTER, 24, 11, GOLD)
		var grid_h := 4 * ROW_H + GAP
		draw_rect(Rect2(LEFT, 0, LANE_W, grid_h), Color(GOLD, 0.9), false, 2.0)
		var core := Rect2(LEFT, grid_h + 12, LANE_W * 4, CORE_H)
		draw_rect(core, Color(0.28, 0.06, 0.08, 0.95))
		draw_rect(core, Color(1.0, 0.45, 0.4, 0.9), false, 2.0)
		draw_texture_rect(heart, Rect2(core.position + Vector2(10, 5), Vector2(28, 28)), false)
		draw_string(font, Vector2(core.position.x, core.position.y + 25), "RELIQUARY CORE", HORIZONTAL_ALIGNMENT_CENTER, core.size.x, 17, Color(1.0, 0.8, 0.75))
