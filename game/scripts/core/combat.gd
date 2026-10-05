extends RefCounted
## Deterministic combat rules for one fight. No UI code lives here.
##
## Flow: setup() starts round 1 in the plan phase. The UI calls play_unit(),
## play_spell(), and move_unit() during the plan phase, then end_plan(), which
## resolves the round and returns a list of events. Each event carries a
## snapshot of the board so the UI can replay the round step by step.

const Data = preload("res://scripts/core/data.gd")
const Unit = preload("res://scripts/core/unit.gd")

const PLAYER := 0
const ENEMY := 1
const FRONT := 0
const BACK := 1
const LANES := 4
const MAX_HAND := 7
const CORE := "core"
const UNPLAYABLE := ["curse", "status"]
## Pack: +1 ATK per other Wolf you control, up to this much.
const PACK_MAX := 4
## Skoll and Hati summon at start of round while you have fewer Wolves than this.
const SKOLL_WOLVES := 4

var rng := RandomNumberGenerator.new()
var battle: Dictionary
var relics: Array = []
var grid: Array = []
var terrain := {}
var deck: Array = []
var hand: Array = []
var discard: Array = []
var exhausted: Array = []
var core_hp := 0
var faith := 0
var round_num := 0
var max_rounds := 3
var is_boss := false
var phase := "plan"
var result := ""
var core_max := 0
var moves_left := 0
var longship_active := false
var spells_this_round := 0
var armaments_this_round := 0
## Faith added at the start of the next round (on top of the usual 3).
var faith_next := 0
var horus_round := 0
var intents := {}
var petrified_lane := -1
var sandstorm_row := -1
var transformed_uid := -1
var events: Array = []
## The unit taking its turn in the attack step, so its events can be tagged with it.
var actor = null
var aegis_used := false
var mead_used := false
var valhalla_returned := {}
var last_dead_ally = null
var enemy_bonus := {"atk": 0, "hp": 0}
var acted_this_plan := false
## The run's god power: {"id": power id, "nodes": owned upgrade ids}, or empty for none.
var power := {}
var power_uses := 0
var power_refunded := false
## Set once the power is used; the run then starts its floor cooldown.
var power_invoked := false
## How many times one of your units fell this fight (deaths and Revives).
var falls := 0
var _unmaking := false
var _plan_start := {}
var _next_uid := 1
var _next_cid := 1


# ---------------------------------------------------------------- setup

func setup(battle_def: Dictionary, deck_ids: Array, relic_ids: Array, seed_value: int) -> void:
	rng.seed = seed_value
	battle = battle_def
	relics = relic_ids.duplicate()
	grid = [[_empty_row(), _empty_row()], [_empty_row(), _empty_row()]]
	core_hp = battle_def["core"]
	core_max = battle_def.get("core_max", core_hp)
	is_boss = battle_def.get("boss", false)
	enemy_bonus = battle_def.get("enemy_bonus", enemy_bonus)
	max_rounds = 3 + enemy_bonus.get("rounds", 0) + (1 if has_relic("golden_fleece") else 0)
	power = battle_def.get("god_power", {})
	power_uses = 1 if Data.GOD_POWERS.has(power.get("id", "")) and power.get("ready", true) else 0
	for id in deck_ids:
		deck.append(_new_card(id))
	_shuffle(deck)
	for t in battle_def.get("terrain", []):
		terrain[_key(t[1], t[3], t[2])] = t[0]
	for e in battle_def["enemies"]:
		_spawn(e[0], ENEMY, e[1], e[2])
	_empower_random_enemy()
	var boss_bonus: Dictionary = battle_def.get("boss_bonus", {})
	if not boss_bonus.is_empty():
		for u in units(ENEMY):
			if Data.unit_def(u.id).get("kind", "") == "boss":
				u.atk += boss_bonus.get("atk", 0)
				u.max_hp += boss_bonus.get("hp", 0)
				u.hp = u.max_hp
				_log("%s grows stronger in the deeper dark (+%d ATK / +%d HP)." % [_unit_label(u), boss_bonus.get("atk", 0), boss_bonus.get("hp", 0)])
	if has_relic("sacred_hive"):
		var summoned := 0
		for lane in [1, 2, 0, 3]:
			if summoned < 2 and unit_at(PLAYER, BACK, lane) == null:
				_summon_scarab(PLAYER, BACK, lane, "Sacred Hive")
				summoned += 1
	if has_relic("void_touched_heart"):
		_damage_core(3, "Void-Touched Heart")
	_start_round()


func _empower_random_enemy() -> void:
	var bonus_atk: int = enemy_bonus.get("atk", 0)
	var bonus_hp: int = enemy_bonus.get("hp", 0)
	var enemies := units(ENEMY)
	if bonus_atk <= 0 and bonus_hp <= 0:
		return
	for i in mini(enemy_bonus.get("count", 1), enemies.size()):
		var u = enemies.pop_at(rng.randi_range(0, enemies.size() - 1))
		u.empowered = true
		u.atk += bonus_atk
		u.max_hp += bonus_hp
		u.hp = u.max_hp
		_log("%s is Empowered (+%d ATK / +%d HP)." % [_unit_label(u), bonus_atk, bonus_hp])


func _empty_row() -> Array:
	return [null, null, null, null]


func _new_card(id: String) -> Dictionary:
	var card := {"cid": _next_cid, "id": id}
	_next_cid += 1
	return card


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func has_relic(id: String) -> bool:
	return id in relics


# ---------------------------------------------------------------- grid helpers

func _key(side: int, row: int, lane: int) -> String:
	return "%d:%d:%d" % [side, row, lane]


func terrain_at(side: int, row: int, lane: int) -> String:
	return terrain.get(_key(side, row, lane), "")


func unit_at(side: int, row: int, lane: int):
	if lane < 0 or lane >= LANES or row < 0 or row > 1:
		return null
	return grid[side][row][lane]


func units(side: int) -> Array:
	var out: Array = []
	for row in 2:
		for lane in LANES:
			var u = grid[side][row][lane]
			if u != null and u.alive and not out.has(u):
				out.append(u)
	return out


func _place(u, row: int, lane: int) -> void:
	u.row = row
	u.lane = lane
	for i in u.width:
		grid[u.side][row][lane + i] = u


func _remove(u) -> void:
	for row in 2:
		for lane in LANES:
			if grid[u.side][row][lane] == u:
				grid[u.side][row][lane] = null


func _spawn(id: String, side: int, lane: int, row: int, card = null):
	var u = Unit.new()
	u.setup(_next_uid, id, Data.unit_def(id), side)
	_next_uid += 1
	u.card = card
	u.deployed_round = round_num
	_place(u, row, lane)
	return u


func _row_neighbors(u) -> Array:
	var out: Array = []
	var left = unit_at(u.side, u.row, u.lane - 1)
	var right = unit_at(u.side, u.row, u.lane + u.width)
	if left != null:
		out.append(left)
	if right != null:
		out.append(right)
	return out


func effective_atk(u) -> int:
	var a: int = u.atk + u.temp_atk
	if u.id == "scarab" and _has_living(u.side, "khepri"):
		a += 1
	if u.has_kw("pack"):
		a += mini(PACK_MAX, _wolf_count(u.side) - (1 if is_wolf(u) else 0))
	for card in u.armaments:
		a += Data.CARDS[card["id"]]["arm"].get("atk", 0) + (1 if u.id == "talos" else 0)
	if u.side == PLAYER and has_relic("dragon_prow") and u.moved_round == round_num:
		a += 2
	if terrain_at(u.side, u.row, u.lane) == "ley_line":
		a += 2
	if is_sunlit(u.side, u.row, u.lane):
		a += 1
	if u.id == "peltast" and unit_at(u.side, u.row, u.lane - 1) != null and unit_at(u.side, u.row, u.lane + 1) != null:
		a += 1
	if u.side == PLAYER and has_relic("flanking_banner") and (u.lane == 0 or u.lane == LANES - 1):
		a += 1
	if u.side == PLAYER and u.row == sandstorm_row:
		a -= 1
	return max(a, 0)


## Sunlit: the terrain, or a slot in a living Benben Stone's row, at most one lane from it. Player side only.
func is_sunlit(side: int, row: int, lane: int) -> bool:
	if side != PLAYER:
		return false
	if terrain_at(side, row, lane) == "sunlit":
		return true
	for l in [lane - 1, lane, lane + 1]:
		var b = unit_at(side, row, l)
		if b != null and b.id == "benben_stone":
			return true
	return false


## True if any of your slots in the lanes this (possibly wide) unit spans is Sunlit.
func _lane_sunlit(lane: int, width := 1) -> bool:
	for l in range(lane, lane + width):
		for row in 2:
			if is_sunlit(PLAYER, row, l):
				return true
	return false


func _sunlit_slots() -> Array:
	var out: Array = []
	for row in 2:
		for lane in LANES:
			if is_sunlit(PLAYER, row, lane):
				out.append("%d:%d" % [row, lane])
	return out


func _add_burn(t, amount: int) -> void:
	if not t.alive or amount <= 0:
		return
	t.burn += amount
	_log("%s Burns (%d)." % [_unit_label(t), t.burn])


func is_wolf(u) -> bool:
	return u.def.get("tribe", "") == "wolf"


func _wolf_count(side: int) -> int:
	return units(side).filter(is_wolf).size()


func has_flank(u) -> bool:
	return u.has_kw("flank") or (is_wolf(u) and _has_living(u.side, "skoll_and_hati"))


func effective_spd(u) -> int:
	if terrain_at(u.side, u.row, u.lane) == "quicksand":
		return maxi(u.spd - 1, 0)
	return u.spd


func _unit_label(u) -> String:
	var who := "" if u.side == PLAYER else "enemy "
	return "%s%s (L%d %s)" % [who, u.display_name(), u.lane + 1, "front" if u.row == FRONT else "back"]


# ---------------------------------------------------------------- events

## `extra` carries data for the battle animation, e.g. an attack's "target" slot or "core": true.
func _log(text: String, extra := {}) -> void:
	var ev := {"text": text, "snap": snapshot()}
	if actor != null:
		ev["actor"] = [actor.side, actor.row, actor.lane]
		ev["actor_uid"] = actor.uid
	ev.merge(extra)
	events.append(ev)


func snapshot() -> Dictionary:
	var g: Array = [[[], []], [[], []]]
	for side in 2:
		for row in 2:
			for lane in LANES:
				var u = grid[side][row][lane]
				if u == null:
					g[side][row].append(null)
				elif u.wide and u.lane != lane:
					g[side][row].append({"wide_part": true, "id": u.id, "side": u.side, "name": u.display_name(),
						"lanes": "%d-%d" % [u.lane + 1, u.lane + u.width]})
				else:
					g[side][row].append(_unit_snapshot(u))
	return {
		"grid": g,
		"core_hp": core_hp,
		"faith": faith,
		"round": round_num,
		"max_rounds": max_rounds,
		"is_boss": is_boss,
		"deck": deck.size(),
		"discard": discard.size(),
		"hand": hand.duplicate(true),
		"hand_costs": hand.map(card_cost),
		"petrified_lane": petrified_lane,
		"sandstorm_row": sandstorm_row,
		"result": result,
		"phase": phase,
		"moves_left": moves_left,
		"free_spell": free_spell_active(),
		"quicksand_targets": _quicksand_targets(),
		"sunlit": _sunlit_slots(),
		"void_tide": _void_tide(),
		"power_uses": power_uses,
		"power_ready": power.get("ready", true),
		"power_ready_floor": power.get("ready_floor", 0),
	}


## Core damage the living bosses' Void Tide deals at the end of each round (0 when none).
func _void_tide() -> int:
	var total := 0
	for e in units(ENEMY):
		total += int(e.def.get("void_tide", 0))
	return total


## Player slots Geomancers will turn into Quicksand this round, as "row:lane" keys.
func _quicksand_targets() -> Array:
	var out: Array = []
	for e in units(ENEMY):
		var slot: Array = intents.get(e.uid, {}).get("quicksand", [])
		if slot.size() == 2:
			out.append("%d:%d" % slot)
	return out


func _unit_snapshot(u) -> Dictionary:
	var intent: Dictionary = intents.get(u.uid, {})
	return {
		"uid": u.uid, "id": u.id, "name": u.display_name(), "side": u.side,
		"atk": effective_atk(u), "hp": u.hp, "max_hp": u.max_hp, "spd": effective_spd(u),
		"shield": u.shield, "threat": u.threat, "token": u.is_token, "empowered": u.empowered,
		"revive": (u.has_kw("revive") or (u.side == PLAYER and has_relic("ankh_of_eternity"))) and not u.revive_used,
		"text": u.def["text"], "intent": intent.get("text", ""), "intent_type": intent.get("type", ""), "width": u.width,
		"move_block": move_block(u) if phase == "plan" and u.side == PLAYER else "",
		"fresh": is_fresh(u),
		"poisoned": u.poisoned, "burn": u.burn, "swine": u.uid == transformed_uid,
		"veil": u.has_kw("veil") and u.veil_round != round_num,
		"spellward": u.side == ENEMY and is_spellwarded(u),
		"armaments": u.armaments.map(func(card): return card["id"]),
	}


# ---------------------------------------------------------------- rounds

func _start_round() -> void:
	round_num += 1
	phase = "plan"
	moves_left = 1 + _count_living(PLAYER, "loki")
	longship_active = false
	spells_this_round = 0
	armaments_this_round = 0
	for u in units(PLAYER) + units(ENEMY):
		u.temp_atk = 0
	faith = 3
	if round_num == 1 and has_relic("ember_of_faith"):
		faith += 1
	if has_relic("void_touched_heart"):
		faith += 1
	if faith_next > 0:
		faith += faith_next
		_log("+%d Faith this round." % faith_next)
		faith_next = 0
	_clear_unplayable()
	_draw(5 if round_num == 1 else 2)
	_declare_intents()
	acted_this_plan = false
	_plan_start = _capture()


func is_unplayable(card: Dictionary) -> bool:
	return card_def(card)["type"] in UNPLAYABLE


## Curses and statuses leave the hand at the start of the next round: curses to the
## discard pile, statuses exhausted. Their Core damage is never lethal.
func _clear_unplayable() -> void:
	var kept: Array = []
	for card in hand:
		var def := card_def(card)
		if not def["type"] in UNPLAYABLE:
			kept.append(card)
			continue
		if def["type"] == "status":
			exhausted.append(card)
		else:
			discard.append(card)
		var dmg: int = mini(def.get("core_damage", 0), core_hp - 1)
		if dmg > 0:
			_damage_core(dmg, def["name"])
	hand = kept


## Shuffles a status card into a random spot in the draw pile.
func _add_status(u, id: String) -> void:
	deck.insert(rng.randi_range(0, deck.size()), _new_card(id))
	_log("%s shuffles %s into your draw pile." % [u.display_name(), Data.CARDS[id]["name"]])


## Everything a plan-phase action can change. Units are copied so the saved
## board is unaffected by later play.
func _capture() -> Dictionary:
	var copies := {}
	var g: Array = []
	for side in 2:
		var rows: Array = []
		for row in 2:
			var cells: Array = []
			for lane in LANES:
				var u = grid[side][row][lane]
				if u != null and not copies.has(u):
					copies[u] = u.copy()
				cells.append(copies[u] if u != null else null)
			rows.append(cells)
		g.append(rows)
	return {
		"grid": g, "deck": deck.duplicate(), "hand": hand.duplicate(), "discard": discard.duplicate(),
		"exhausted": exhausted.duplicate(), "core_hp": core_hp, "faith": faith, "result": result,
		"moves_left": moves_left, "longship_active": longship_active, "spells_this_round": spells_this_round, "armaments_this_round": armaments_this_round,
		"faith_next": faith_next, "horus_round": horus_round,
		"intents": intents.duplicate(true), "petrified_lane": petrified_lane, "sandstorm_row": sandstorm_row,
		"aegis_used": aegis_used, "mead_used": mead_used, "valhalla_returned": valhalla_returned.duplicate(),
		"last_dead_ally": last_dead_ally, "next_uid": _next_uid, "next_cid": _next_cid, "rng": rng.state,
		"terrain": terrain.duplicate(), "transformed_uid": transformed_uid,
		"power_uses": power_uses, "power_refunded": power_refunded, "power_invoked": power_invoked, "falls": falls,
	}


func can_restart_plan() -> bool:
	return phase == "plan" and acted_this_plan


## Undoes every deployment, spell and move made during the current plan phase.
func restart_plan() -> String:
	if not can_restart_plan():
		return "Nothing to undo this round."
	var s: Dictionary = _plan_start
	grid = s["grid"]
	deck = s["deck"]
	hand = s["hand"]
	discard = s["discard"]
	exhausted = s["exhausted"]
	core_hp = s["core_hp"]
	faith = s["faith"]
	result = s["result"]
	moves_left = s["moves_left"]
	longship_active = s["longship_active"]
	spells_this_round = s["spells_this_round"]
	armaments_this_round = s["armaments_this_round"]
	faith_next = s["faith_next"]
	horus_round = s["horus_round"]
	intents = s["intents"]
	petrified_lane = s["petrified_lane"]
	sandstorm_row = s["sandstorm_row"]
	aegis_used = s["aegis_used"]
	mead_used = s["mead_used"]
	valhalla_returned = s["valhalla_returned"]
	last_dead_ally = s["last_dead_ally"]
	_next_uid = s["next_uid"]
	_next_cid = s["next_cid"]
	rng.state = s["rng"]
	terrain = s["terrain"]
	transformed_uid = s["transformed_uid"]
	power_uses = s["power_uses"]
	power_refunded = s["power_refunded"]
	power_invoked = s["power_invoked"]
	falls = s["falls"]
	acted_this_plan = false
	_plan_start = _capture()
	events.clear()
	_log("Planning restarted.")
	return ""


func _draw(n: int) -> void:
	for i in n:
		if hand.size() >= MAX_HAND:
			return
		if deck.is_empty():
			if discard.is_empty():
				return
			deck = discard
			discard = []
			_shuffle(deck)
		var card: Dictionary = deck.pop_back()
		hand.append(card)
		var faith_change: int = card_def(card).get("draw_faith", 0)
		if faith_change != 0:
			faith = maxi(0, faith + faith_change)
			_log("%s: %+d Faith this round." % [card_def(card)["name"], faith_change])


func _declare_intents() -> void:
	intents.clear()
	petrified_lane = -1
	sandstorm_row = -1
	transformed_uid = -1
	for e in units(ENEMY):
		var it := {}
		match e.id:
			"void_charger":
				if round_num % 2 == 0:
					var lane := _lane_with_fewest_player_units()
					it = {"type": "charge", "lane": lane, "text": "CHARGE lane %d" % (lane + 1)}
				else:
					it = {"type": "attack", "text": "Attack lane %d" % (e.lane + 1)}
			"echo_of_medusa":
				var lane := 1 if round_num == 1 else _lane_with_most_player_atk()
				petrified_lane = lane
				it = {"type": "petrify", "lane": lane, "text": "PETRIFY lane %d" % (lane + 1)}
			"echo_of_set":
				sandstorm_row = FRONT if round_num % 2 == 1 else BACK
				it = {"type": "sandstorm", "text": "SANDSTORM your %s row" % ("front" if sandstorm_row == FRONT else "back")}
			"void_herald":
				if e.hp * 2 > e.max_hp:
					var lane := _lane_of_strongest_player_unit()
					it = {"type": "target", "lane": lane, "text": "TARGET lane %d" % (lane + 1)}
				else:
					var lane := _lane_with_most_player_units()
					it = {"type": "strike", "lane": lane, "text": "STRIKE lane %d" % (lane + 1)}
			"hel":
				it = {"type": "attack", "text": "HARVEST lowest HP"}
			"apep":
				var lanes: Array = [_lane_with_most_player_units()]
				if e.hp * 2 <= e.max_hp:
					lanes.append(_lane_with_most_player_units(lanes[0]))
				lanes.sort()
				var names: Array = lanes.map(func(l): return str(l + 1))
				it = {"type": "constrict", "lanes": lanes, "text": "CONSTRICT lane%s %s" % ["s" if lanes.size() > 1 else "", " and ".join(names)]}
			"void_wisp":
				it = {"type": "attack", "text": "Snipe lowest HP"}
			"hollow_archer", "carrion_harpy":
				it = {"type": "attack", "text": "Attack lane %d (back first)" % (e.lane + 1)}
			"siege_engine":
				if round_num % 2 == 1:
					it = {"type": "aim", "text": "LOADING (fires next round)"}
				else:
					it = {"type": "siege", "text": "SIEGE your most crowded lane"}
			"null_idol":
				it = {"type": "wait", "text": "Ward its neighbours"}
			"hollow_geomancer":
				var slot := _quicksand_slot()
				it = {"type": "attack", "text": "Attack lane %d" % (e.lane + 1), "quicksand": slot}
				if slot.size() == 2:
					it["text"] += ", QUICKSAND your lane %d %s" % [slot[1] + 1, "front" if slot[0] == FRONT else "back"]
			"echo_of_circe":
				var victim = _costliest_player_unit()
				it = {"type": "attack", "text": "Attack lane %d" % (e.lane + 1)}
				if victim != null:
					transformed_uid = victim.uid
					it["text"] = "TRANSFORM %s, attack lane %d" % [victim.display_name(), e.lane + 1]
			_:
				if e.row == BACK and not e.has_kw("ranged"):
					it = {"type": "wait", "text": "Wait"}
				else:
					it = {"type": "attack", "text": "Attack lane %d" % (e.lane + 1)}
		var status: String = Data.ENEMIES[e.id].get("status_card", "")
		if status != "" and it["type"] == "attack":
			it["text"] += " (+%s)" % Data.CARDS[status]["name"]
		intents[e.uid] = it


## The slot of your highest-ATK unit not already on terrain, else the first free front slot. [row, lane]
func _quicksand_slot() -> Array:
	var best = null
	for u in units(PLAYER):
		if terrain_at(PLAYER, u.row, u.lane) == "" and (best == null or effective_atk(u) > effective_atk(best)):
			best = u
	if best != null:
		return [best.row, best.lane]
	for lane in [1, 2, 0, 3]:
		if terrain_at(PLAYER, FRONT, lane) == "":
			return [FRONT, lane]
	return []


## Circe's victim: highest card cost, then highest ATK. Tokens are never chosen.
func _costliest_player_unit():
	var best = null
	var best_cost := 0
	for u in units(PLAYER):
		var cost: int = Data.CARDS[u.id]["cost"] if Data.CARDS.has(u.id) else 0
		if cost > best_cost or (cost == best_cost and best != null and effective_atk(u) > effective_atk(best)):
			best = u
			best_cost = cost
	return best


func _lane_with_fewest_player_units() -> int:
	var best := 0
	var best_count := 99
	for lane in LANES:
		var count := 0
		for row in 2:
			if unit_at(PLAYER, row, lane) != null:
				count += 1
		if count < best_count:
			best_count = count
			best = lane
	return best


func _lane_with_most_player_units(exclude := -1) -> int:
	var best := 0 if exclude != 0 else 1
	var best_score := -1
	for lane in LANES:
		if lane == exclude:
			continue
		var count := 0
		var total := 0
		for row in 2:
			var u = unit_at(PLAYER, row, lane)
			if u != null:
				count += 1
				total += effective_atk(u)
		var score := count * 100 + total
		if score > best_score:
			best_score = score
			best = lane
	return best


func _lane_with_most_player_atk() -> int:
	var best := 0
	var best_total := -1
	for lane in LANES:
		var total := 0
		for row in 2:
			var u = unit_at(PLAYER, row, lane)
			if u != null:
				total += effective_atk(u)
		if total > best_total:
			best_total = total
			best = lane
	return best


func _lane_of_strongest_player_unit() -> int:
	var best := 1
	var best_atk := -1
	for lane in LANES:
		for row in 2:
			var u = unit_at(PLAYER, row, lane)
			if u != null and effective_atk(u) > best_atk:
				best_atk = effective_atk(u)
				best = lane
	return best


# ---------------------------------------------------------------- plan phase actions

func card_def(card: Dictionary) -> Dictionary:
	return Data.CARDS[card["id"]]


## Hermes makes the first spell of each round free.
func free_spell_active() -> bool:
	return spells_this_round == 0 and _has_living(PLAYER, "hermes")


func card_cost(card: Dictionary) -> int:
	var def := card_def(card)
	if card.get("free_round", -1) == round_num:
		return 0
	if def["type"] == "spell" and free_spell_active():
		return 0
	if def["type"] == "armament" and armaments_this_round == 0 and _has_living(PLAYER, "forge_apprentice"):
		return maxi(0, def["cost"] - 1)
	return def["cost"]


func can_afford(hand_index: int) -> bool:
	var card: Dictionary = hand[hand_index]
	return phase == "plan" and not is_unplayable(card) and card_cost(card) <= faith


## Returns every legal target for a hand card as slot arrays [side, row, lane].
func valid_targets(hand_index: int) -> Array:
	var out: Array = []
	if not can_afford(hand_index):
		return out
	var def := card_def(hand[hand_index])
	return _targets_for(def, "empty_ally_slot" if def["type"] == "unit" else def["target"])


## Legal targets of the given kind. `def` is a card or a god power ("row" for ally_slot).
func _targets_for(def: Dictionary, kind: String) -> Array:
	var out: Array = []
	match kind:
		"empty_ally_slot":
			if def.get("needs_fallen", false) and not _book_target_available():
				return out
			for row in 2:
				for lane in LANES:
					if unit_at(PLAYER, row, lane) == null:
						out.append([PLAYER, row, lane])
		"ally":
			for u in units(PLAYER):
				out.append([PLAYER, u.row, u.lane])
		"ally_slot":
			for row in 2:
				for lane in LANES:
					if _terrain_slot_ok(def, row, lane):
						out.append([PLAYER, row, lane])
		"ally_card":
			for u in units(PLAYER):
				if u.card != null:
					out.append([PLAYER, u.row, u.lane])
		"enemy":
			for u in units(ENEMY):
				if not is_spellwarded(u):
					out.append([ENEMY, u.row, u.lane])
		"enemy_burning":
			for u in units(ENEMY):
				if u.burn > 0 and not is_spellwarded(u):
					out.append([ENEMY, u.row, u.lane])
		"enemy_front":
			for u in units(ENEMY):
				if u.row == FRONT and not u.has_kw("immovable") and not is_spellwarded(u):
					out.append([ENEMY, FRONT, u.lane])
		"enemy_pair":
			for u in units(ENEMY):
				if not u.has_kw("immovable") and not is_spellwarded(u):
					out.append([ENEMY, u.row, u.lane])
	return out


## Spellward units, and units next to one (left, right, in front or behind), can't be targeted by spells.
func is_spellwarded(u) -> bool:
	if u.has_kw("spellward"):
		return true
	for w in units(u.side):
		if w != u and w.has_kw("spellward") and _adjacent(w, u):
			return true
	return false


func _adjacent(a, b) -> bool:
	var overlap: bool = a.lane < b.lane + b.width and b.lane < a.lane + a.width
	if a.row != b.row:
		return overlap
	return a.lane + a.width == b.lane or b.lane + b.width == a.lane


## Row -1 means either row.
func _terrain_slot_ok(def: Dictionary, row: int, lane: int) -> bool:
	return (def["row"] < 0 or row == def["row"]) and terrain_at(PLAYER, row, lane) == ""


func _book_target_available() -> bool:
	return last_dead_ally != null and discard.has(last_dead_ally)


func play_unit(hand_index: int, lane: int, row: int) -> String:
	if phase != "plan":
		return "Not in the plan phase."
	var card: Dictionary = hand[hand_index]
	var def := card_def(card)
	if def["type"] in UNPLAYABLE:
		return "%s can't be played." % def["name"]
	if def["type"] != "unit":
		return "That card is a spell."
	if def["cost"] > faith:
		return "Not enough Faith."
	if unit_at(PLAYER, row, lane) != null:
		return "That slot is occupied."
	faith -= def["cost"]
	hand.remove_at(hand_index)
	var u = _spawn(card["id"], PLAYER, lane, row, card)
	u.from_hand = true
	acted_this_plan = true
	events.clear()
	_log("Deployed %s." % _unit_label(u))
	if u.id == "loki":
		moves_left += 1
		_log("Loki grants an extra move this round.")
	if u.id == "cyclops_smith":
		var commons: Array = Data.CARDS.keys().filter(func(id): return Data.CARDS[id]["type"] == "armament" and Data.CARDS[id]["rarity"] == "Common")
		var forged := _new_card(commons[rng.randi_range(0, commons.size() - 1)])
		forged["free_round"] = round_num
		forged["forged"] = true
		if hand.size() < MAX_HAND:
			hand.append(forged)
			_log("The Cyclops forges a %s (free this round)." % Data.CARDS[forged["id"]]["name"])
		else:
			discard.append(forged)
			_log("The Cyclops forges a %s, but your hand is full." % Data.CARDS[forged["id"]]["name"])
	return ""


func play_spell(hand_index: int, targets: Array, direction := 0) -> String:
	if phase != "plan":
		return "Not in the plan phase."
	var card: Dictionary = hand[hand_index]
	var def := card_def(card)
	if def["type"] in UNPLAYABLE:
		return "%s can't be played." % def["name"]
	if def["type"] != "spell" and def["type"] != "armament":
		return "That card is a unit."
	var cost := card_cost(card)
	if cost > faith:
		return "Not enough Faith."
	var err := _check_targets(def, targets, direction)
	if err != "":
		return err
	faith -= cost
	hand.remove_at(hand_index)
	if def["type"] == "armament":
		armaments_this_round += 1
		acted_this_plan = true
		events.clear()
		_attach(_at(targets[0]), card)
		return ""
	spells_this_round += 1
	acted_this_plan = true
	events.clear()
	_log("Cast %s%s." % [def["name"], " for free (Hermes)" if cost < def["cost"] else ""])
	_resolve_spell(card, targets, direction)
	if def.get("exhaust", false):
		exhausted.append(card)
	else:
		discard.append(card)
	_on_spell_cast()
	_check_enemies_cleared()
	if result != "":
		_finish_fight()
	return ""


func _check_targets(def: Dictionary, targets: Array, direction: int) -> String:
	var kind: String = def["target"]
	match kind:
		"none":
			return ""
		"ally":
			if targets.size() != 1 or targets[0][0] != PLAYER or _at(targets[0]) == null:
				return "Choose one of your units."
		"ally_slot":
			if targets.size() != 1 or targets[0][0] != PLAYER or (def["row"] >= 0 and targets[0][1] != def["row"]):
				return "Choose a %sslot on your grid." % ["", "front ", "back "][def["row"] + 1]
			if not _terrain_slot_ok(def, targets[0][1], targets[0][2]):
				return "That slot already has terrain."
		"ally_card":
			if targets.size() != 1 or targets[0][0] != PLAYER or _at(targets[0]) == null:
				return "Choose one of your units."
			if _at(targets[0]).card == null:
				return "Summoned tokens have no card to return."
		"enemy":
			if targets.size() != 1 or targets[0][0] != ENEMY or _at(targets[0]) == null:
				return "Choose an enemy unit."
			if is_spellwarded(_at(targets[0])):
				return "That enemy is Spellward."
		"enemy_burning":
			if targets.size() != 1 or targets[0][0] != ENEMY or _at(targets[0]) == null or _at(targets[0]).burn <= 0:
				return "Choose a Burning enemy."
			if is_spellwarded(_at(targets[0])):
				return "That enemy is Spellward."
		"enemy_front":
			if targets.size() != 1 or targets[0][0] != ENEMY or targets[0][1] != FRONT or _at(targets[0]) == null:
				return "Choose an enemy front unit."
			if is_spellwarded(_at(targets[0])):
				return "That enemy is Spellward."
			if _at(targets[0]).has_kw("immovable"):
				return "Immovable units cannot be pushed."
			if direction != -1 and direction != 1:
				return "Choose a push direction."
		"enemy_pair":
			if targets.size() != 2 or targets[0][0] != ENEMY or targets[1][0] != ENEMY:
				return "Choose two enemy units."
			var a = _at(targets[0])
			var b = _at(targets[1])
			if a == null or b == null or a == b or a.row != b.row:
				return "Choose two different enemy units in the same row."
			if a.has_kw("immovable") or b.has_kw("immovable"):
				return "Immovable units cannot be swapped."
			if is_spellwarded(a) or is_spellwarded(b):
				return "Spellward units cannot be swapped."
		"empty_ally_slot":
			if targets.size() != 1 or targets[0][0] != PLAYER or _at(targets[0]) != null:
				return "Choose an empty slot on your grid."
			if def.get("needs_fallen", false) and not _book_target_available():
				return "No fallen ally to return."
	return ""


func _at(slot: Array):
	return unit_at(slot[0], slot[1], slot[2])


# ---------------------------------------------------------------- god power

func power_def() -> Dictionary:
	return Data.GOD_POWERS.get(power.get("id", ""), {})


func _up(node: String) -> bool:
	return node in power.get("nodes", [])


func power_targets() -> Array:
	if phase != "plan" or power_uses <= 0:
		return []
	return _targets_for(power_def(), power_def()["target"])


func can_use_power() -> bool:
	return not power_targets().is_empty()


## Impact damage of the god power's push (Poseidon's Tide).
func power_push_damage() -> int:
	return 4 if _up("wave_1") else 2


func use_power(targets: Array, direction := 0) -> String:
	if phase != "plan":
		return "Not in the plan phase."
	if power_uses <= 0:
		if not power.get("ready", true):
			return "Your god power is recharging (ready on floor %d)." % power.get("ready_floor", 0)
		return "Your god power is spent for this fight."
	var def := power_def()
	var err := _check_targets(def, targets, direction)
	if err != "":
		return err
	power_uses -= 1
	power_invoked = true
	acted_this_plan = true
	events.clear()
	_log("Invoked %s." % def["name"])
	_resolve_power(targets, direction)
	_check_enemies_cleared()
	if result != "":
		_finish_fight()
	return ""


func _resolve_power(targets: Array, direction: int) -> void:
	var t = _at(targets[0]) if not targets.is_empty() else null
	match power["id"]:
		"tyrs_oath":
			var hp: int = t.hp
			var bonus := 2 if _up("blood_1") else 1
			_log("Tyr's Oath: %s is sacrificed." % _unit_label(t))
			t.hp = 0
			_kill(t)
			for a in units(PLAYER):
				if a == t:
					continue
				if _up("blood_2"):
					a.atk += bonus
				else:
					a.temp_atk += bonus
			_log("Your other units gain +%d ATK%s." % [bonus, " for the fight" if _up("blood_2") else " this round"])
			if _up("oath_1"):
				_heal_core(hp, "Hand of Tyr")
			if _up("oath_2") and not t.alive and t.card != null and discard.has(t.card):
				discard.erase(t.card)
				hand.append(t.card)
				_log("Sworn Return: %s returns to your hand." % t.display_name())
			if _up("pact"):
				faith += 1
				_log("Blood Pact: +1 Faith.")
		"thors_thunderclap":
			var dmg := 3 + (mini(falls, 3) if _up("storm_1") else 0)
			var lane: int = t.lane
			var main = t
			var hits := [[t, dmg]]
			if _up("hammer_1"):
				var other = unit_at(ENEMY, 1 - t.row, t.lane)
				if other != null and other != t:
					hits.append([other, dmg])
			if _up("hammer_2"):
				for side_unit in [unit_at(ENEMY, t.row, t.lane - 1), unit_at(ENEMY, t.row, t.lane + t.width)]:
					if side_unit != null and side_unit != t:
						hits.append([side_unit, 2])
			_log("Thor's Thunderclap strikes %s." % _unit_label(t))
			for h in hits:
				_deal_damage(h[0], h[1], "effect")
			if _up("pact"):
				for row in 2:
					var a = unit_at(PLAYER, row, lane)
					if a != null:
						a.shield += 2
						_log("Storm Shield: %s gains Shield 2." % a.display_name())
			if _up("storm_2") and not main.alive and not power_refunded:
				power_refunded = true
				power_uses += 1
				_log("Thunder Returns: Thor's Thunderclap can be used again.")
		"zeus_lightning_bolt":
			var hit: Array = [t]
			_log("Zeus's Lightning Bolt strikes %s." % _unit_label(t))
			_deal_damage(t, 4 if _up("sky_1") else 2, "effect")
			for n in (3 if _up("chain_1") else 1):
				var pool: Array = units(ENEMY).filter(func(e): return not hit.has(e))
				if pool.is_empty():
					break
				var next = pool[rng.randi_range(0, pool.size() - 1)]
				hit.append(next)
				_log("The bolt chains to %s." % _unit_label(next))
				_deal_damage(next, 2 if _up("chain_2") else 1, "effect")
			if _up("sky_2"):
				var kills: int = hit.filter(func(e): return not e.alive).size()
				if kills > 0:
					faith += kills
					_log("Divine Spark: +%d Faith." % kills)
			if _up("pact"):
				for a in units(PLAYER):
					if a.has_kw("ranged"):
						a.temp_atk += 1
				_log("Charged Ranks: your Ranged units gain +1 ATK this round.")
		"poseidons_tide":
			var impact := power_push_damage()
			var moved := _push(t, direction, impact)
			if moved and _up("wave_2") and t.alive:
				_log("Riptide drags %s under." % _unit_label(t))
				_deal_damage(t, impact, "effect")
			if _up("undertow_1") and t.alive:
				var a = unit_at(PLAYER, FRONT, t.lane)
				if a != null and effective_atk(a) > 0:
					_log("Ambush Current: %s strikes %s." % [a.display_name(), t.display_name()])
					_deal_damage(t, effective_atk(a), "effect")
			if _up("undertow_2"):
				moves_left += 1
				_log("Flowing Ranks: +1 move this round.")
			if _up("pact"):
				_draw(1)
				_log("Sea Spray: drew a card.")
		"osiris_return":
			var fallen: Dictionary = last_dead_ally
			discard.erase(fallen)
			var u = _spawn(fallen["id"], PLAYER, targets[0][2], targets[0][1], fallen)
			last_dead_ally = null
			if not _up("life_1"):
				u.hp = 1
			if _up("life_2"):
				u.shield += 3
			if _up("wings_1"):
				u.atk += 2
			if _up("wings_2") and not u.has_kw("revive"):
				u.bonus_kw.append("revive")
			_log("Osiris returns %s with %d HP." % [_unit_label(u), u.hp])
			if _up("pact"):
				_heal_core(3, "Gift of the Nile")
		"sekhmets_plague":
			var lanes: Array = range(t.lane, t.lane + t.width)
			if _up("plague_1"):
				lanes = range(t.lane - 1, t.lane + t.width + 1)
			var hit: Array = []
			for lane in lanes:
				for row in 2:
					var e = unit_at(ENEMY, row, lane)
					if e != null and not hit.has(e):
						hit.append(e)
			_log("Sekhmet's Plague sweeps lane%s %s." % ["s" if lanes.size() > 1 else "", ", ".join(lanes.filter(func(l): return l >= 0 and l < LANES).map(func(l): return str(l + 1)))])
			for e in hit:
				if not e.poisoned:
					e.poisoned = true
					_log("%s is Poisoned." % _unit_label(e))
			if _up("hunt_1"):
				for e in hit:
					_deal_damage(e, 1, "effect")
			if _up("pact"):
				for a in units(PLAYER):
					_heal(a, 1, "Sun's Mercy")


func _resolve_spell(card: Dictionary, targets: Array, direction: int) -> void:
	match card["id"]:
		"warding":
			var u = _at(targets[0])
			u.shield += 4
			_log("%s gains Shield 4." % _unit_label(u))
		"faith_surge":
			faith += 2
			_log("Gained 2 Faith.")
		"channel_ley_line", "raise_ruins", "dawn_ritual":
			var slot: Array = targets[0]
			var terrain_id: String = Data.CARDS[card["id"]]["terrain"]
			terrain[_key(PLAYER, slot[1], slot[2])] = terrain_id
			_log("Lane %d %s becomes %s." % [slot[2] + 1, "front" if slot[1] == FRONT else "back", Data.TERRAIN[terrain_id]["name"]])
		"phalanx_formation":
			for u in units(PLAYER):
				if u.row == FRONT:
					u.shield += 2
					u.atk += 1
			_log("Front-row allies gain Shield 2 and +1 ATK.")
		"rebuke":
			_push(_at(targets[0]), direction)
		"transposition":
			var a = _at(targets[0])
			var b = _at(targets[1])
			var a_lane: int = a.lane
			var b_lane: int = b.lane
			_remove(a)
			_remove(b)
			_place(a, a.row, b_lane)
			_place(b, b.row, a_lane)
			_log("Swapped %s and %s." % [a.display_name(), b.display_name()])
		"ragnarok":
			var u = _at(targets[0])
			var lane: int = u.lane
			var dmg: int = u.hp
			_log("Ragnarok consumes %s for %d damage." % [_unit_label(u), dmg])
			u.hp = 0
			_kill(u)
			for row in 2:
				var t = unit_at(ENEMY, row, lane)
				if t != null:
					_deal_damage(t, dmg, "effect")
		"book_of_the_dead":
			var fallen: Dictionary = last_dead_ally
			discard.erase(fallen)
			var u = _spawn(fallen["id"], PLAYER, targets[0][2], targets[0][1], fallen)
			last_dead_ally = null
			_log("Book of the Dead returns %s." % _unit_label(u))
		"longship":
			moves_left += 2
			longship_active = true
			_log("Gained 2 extra moves. Units you move this round gain Shield 2.")
		"divine_favor":
			var u = _at(targets[0])
			u.temp_atk += 2
			_log("%s gains +2 ATK this round." % _unit_label(u))
		"olympian_ichor":
			var u = _at(targets[0])
			_heal(u, 4, "Olympian Ichor")
			u.atk += 1
			_log("%s gains +1 ATK." % _unit_label(u))
		"call_of_the_pack":
			var slot: Array = targets[0]
			_summon_wolf(PLAYER, slot[1], slot[2], "Call of the Pack")
			if unit_at(PLAYER, 1 - slot[1], slot[2]) == null:
				_summon_wolf(PLAYER, 1 - slot[1], slot[2], "Call of the Pack")
		"blood_scent":
			var t = _at(targets[0])
			var wolves: Array = units(PLAYER).filter(is_wolf)
			_log("Your Wolves catch the scent of %s." % _unit_label(t))
			for w in wolves:
				if t.alive:
					_deal_damage(t, effective_atk(w), "effect")
		"sandswarm":
			for lane in LANES:
				if unit_at(PLAYER, FRONT, lane) == null:
					_summon_scarab(PLAYER, FRONT, lane, "Sandswarm")
		"noon_blaze":
			_log("Noon Blaze scorches the Sunlit lanes.")
			for e in units(ENEMY):
				if _lane_sunlit(e.lane, e.width):
					_add_burn(e, 3)
		"eye_of_ra":
			var t = _at(targets[0])
			_log("The Eye of Ra fixes on %s." % _unit_label(t))
			_add_burn(t, t.burn)
		"plague_of_locusts":
			var dmg := units(PLAYER).size()
			var t = _at(targets[0])
			_log("A plague of locusts descends on %s." % _unit_label(t))
			if dmg > 0:
				_deal_damage(t, dmg, "effect")
		"divine_insight":
			_draw(2)
			_log("Drew 2 cards.")
		"ambrosia":
			faith += 2
			_log("Gained 2 Faith.")
		"aegis_of_olympus":
			for u in units(PLAYER):
				u.shield += 3
			_log("All allies gain Shield 3.")
		"thread_of_fate":
			var u = _at(targets[0])
			_remove(u)
			u.alive = false
			hand.append(u.card)
			discard.append_array(u.armaments)
			u.armaments.clear()
			_log("The Thread of Fate returns %s to your hand." % u.display_name())


func _summon_scarab(side: int, row: int, lane: int, source: String) -> void:
	var s = _spawn("scarab", side, lane, row)
	_log("%s summons a Scarab (%s)." % [source, _unit_label(s)])


## A unit holds one Armament (Talos any number); a new one sends the old card to the discard pile.
func _attach(u, card: Dictionary) -> void:
	var arm: Dictionary = Data.CARDS[card["id"]]["arm"]
	if u.id != "talos" and not u.armaments.is_empty():
		var old: Dictionary = u.armaments.pop_back()
		_detach_stats(u, old)
		discard.append(old)
		_log("%s sets aside its %s." % [u.display_name(), Data.CARDS[old["id"]]["name"]])
	u.armaments.append(card)
	var hp: int = arm.get("hp", 0)
	u.max_hp += hp
	u.hp += hp
	_log("%s takes up the %s." % [_unit_label(u), Data.CARDS[card["id"]]["name"]])


func _detach_stats(u, card: Dictionary) -> void:
	var hp: int = Data.CARDS[card["id"]]["arm"].get("hp", 0)
	u.max_hp -= hp
	u.hp = clampi(u.hp, 1, u.max_hp)


## When an armed unit dies for good, its Armaments shuffle into the draw pile.
func _return_armaments(u) -> void:
	for card in u.armaments:
		deck.insert(rng.randi_range(0, deck.size()), card)
		_log("The %s falls from %s and returns to your draw pile." % [Data.CARDS[card["id"]]["name"], u.display_name()])
	u.armaments.clear()


func _summon_wolf(side: int, row: int, lane: int, source: String) -> void:
	var w = _spawn("wolf", side, lane, row)
	_log("%s summons a Wolf (%s)." % [source, _unit_label(w)])


## Nearest empty slot in its own row (left first on ties), then in the other row.
func _summon_wolf_near(u, source: String) -> void:
	var lanes: Array = range(LANES)
	lanes.sort_custom(func(a, b): return absi(a - u.lane) < absi(b - u.lane) or (absi(a - u.lane) == absi(b - u.lane) and a < b))
	for row in [u.row, 1 - u.row]:
		for lane in lanes:
			if unit_at(u.side, row, lane) == null:
				_summon_wolf(u.side, row, lane, source)
				return


func _count_living(side: int, id: String) -> int:
	var n := 0
	for u in units(side):
		if u.id == id:
			n += 1
	return n


func _first_enemy_in_lane(lane: int):
	var t = unit_at(ENEMY, FRONT, lane)
	return t if t != null else unit_at(ENEMY, BACK, lane)


func _heal_core(amount: int, source: String) -> void:
	var healed: int = mini(amount, core_max - core_hp)
	if healed > 0:
		core_hp += healed
		_log("%s heals the Core for %d (%d)." % [source, healed, core_hp])


func _on_spell_cast() -> void:
	for u in units(PLAYER):
		if not u.alive:
			continue
		if u.id == "pythia":
			var t = _first_enemy_in_lane(u.lane)
			if t != null:
				_log("Pythia's prophecy strikes %s." % t.display_name())
				_deal_damage(t, 1, "effect")
		elif u.id == "hermes":
			u.shield += 1
			_log("Hermes gains Shield 1.")
	for e in units(ENEMY):
		if e.has_kw("spellward"):
			e.shield += 2
			_log("%s absorbs the spell (Shield 2)." % e.display_name())
	if has_relic("oracles_tripod") and spells_this_round == 2:
		faith += 1
		_log("Oracle's Tripod: +1 Faith.")


func _on_moved(u, from_lane: int) -> void:
	u.moved_round = round_num
	if longship_active:
		u.shield += 2
		_log("Longship: %s gains Shield 2." % u.display_name())
	match u.id:
		"raider":
			u.atk += 1
			_log("Raider gains +1 ATK.")
		"ulfhednar":
			var t = unit_at(ENEMY, FRONT, u.lane)
			if u.lane != from_lane and t != null:
				_log("Ulfhednar pounces on %s." % t.display_name())
				_deal_damage(t, effective_atk(u), "effect")
	for i in _count_living(PLAYER, "loki"):
		if not u.alive:
			break
		var hit: Array = []
		for row in 2:
			var t = unit_at(ENEMY, row, u.lane)
			if t != null and not hit.has(t):
				hit.append(t)
		if not hit.is_empty():
			_log("Loki's trickery strikes lane %d." % (u.lane + 1))
		for t in hit:
			_deal_damage(t, 1, "effect")


## Returns true if the unit moved, false if it hit the edge or another unit.
func _push(u, direction: int, impact := 3) -> bool:
	var dest: int = u.lane + direction
	if dest < 0 or dest >= LANES:
		_log("%s is slammed against the edge." % _unit_label(u))
		_deal_damage(u, impact, "effect")
		return false
	var other = unit_at(ENEMY, FRONT, dest)
	if other != null and other.has_kw("immovable"):
		_log("%s collides with the Immovable %s." % [_unit_label(u), other.display_name()])
		_deal_damage(u, impact, "effect")
		return false
	if other != null:
		_log("%s collides with %s." % [_unit_label(u), other.display_name()])
		_deal_damage(u, impact, "effect")
		_deal_damage(other, impact, "effect")
		return false
	_remove(u)
	_place(u, FRONT, dest)
	_log("Pushed %s to lane %d." % [u.display_name(), dest + 1])
	return true


func can_move(u) -> bool:
	return move_block(u) == ""


func _entered_this_plan(u) -> bool:
	return u.side == PLAYER and phase == "plan" and u.deployed_round == round_num


## Units deployed from hand during this plan phase aren't locked in yet: they can be
## repositioned freely (no move used, no move triggers, Quicksand ignored).
func is_fresh(u) -> bool:
	return _entered_this_plan(u) and u.from_hand


## Why a unit can't move right now, or "" if it can.
func move_block(u) -> String:
	if is_fresh(u):
		return ""
	if _entered_this_plan(u):
		return "Summoned this round"
	if terrain_at(u.side, u.row, u.lane) == "quicksand":
		return "Stuck in Quicksand"
	return ""


func move_unit(from_lane: int, from_row: int, to_lane: int, to_row: int) -> String:
	if phase != "plan":
		return "Not in the plan phase."
	var u = unit_at(PLAYER, from_row, from_lane)
	if u == null:
		return "No unit there."
	if not is_fresh(u) and moves_left <= 0:
		return "No moves left this round."
	if not can_move(u):
		return "%s can't move: %s." % [u.display_name(), move_block(u).to_lower()]
	if unit_at(PLAYER, to_row, to_lane) != null:
		return "Destination is occupied."
	_remove(u)
	_place(u, to_row, to_lane)
	if is_fresh(u):
		acted_this_plan = true
		events.clear()
		_log("Repositioned %s." % _unit_label(u))
		return ""
	moves_left -= 1
	acted_this_plan = true
	events.clear()
	_log("Moved %s." % _unit_label(u))
	_on_moved(u, from_lane)
	_check_enemies_cleared()
	if result != "":
		_finish_fight()
	return ""


# ---------------------------------------------------------------- resolve phase

func end_plan() -> Array:
	events.clear()
	if phase != "plan":
		return events
	phase = "resolve"
	_log("--- Round %d ---" % round_num)

	if sandstorm_row != -1:
		_log("Sandstorm: your %s row has -1 ATK this round." % ("front" if sandstorm_row == FRONT else "back"))

	if has_relic("spartan_standard"):
		var shielded: Array = []
		for u in units(PLAYER):
			if u.row == FRONT and _row_neighbors(u).size() == 2:
				shielded.append(u)
		for u in shielded:
			u.shield += 1
		if not shielded.is_empty():
			_log("Spartan Standard: %d front-row allies gain Shield 1." % shielded.size())

	for u in _initiative_order():
		if result != "":
			break
		if u.alive:
			_start_of_round(u)

	var order := _initiative_order()
	for u in order:
		if result != "":
			break
		if u.alive:
			actor = u
			_act(u)
			actor = null

	if result == "":
		for u in _initiative_order():
			if result != "":
				break
			if u.alive:
				_end_of_round(u)

	if result == "":
		for u in units(PLAYER) + units(ENEMY):
			if u.poisoned and u.alive and result == "":
				_log("Poison eats at %s." % _unit_label(u))
				_deal_damage(u, 2 if u.side == ENEMY and _up("plague_2") else 1, "poison")

	if result == "":
		_tick_burn()

	if result == "" and has_relic("scarab_amulet"):
		for u in units(PLAYER):
			_heal(u, 1, "Scarab Amulet")

	if result == "":
		for boss in units(ENEMY):
			match boss.id:
				"void_herald":
					_herald_end_of_round(boss)
				"hel":
					_hel_end_of_round(boss)
				"apep":
					_apep_end_of_round(boss)

	_end_round_checks()
	return events.duplicate()


## Burn deals its value, then drops by 1 (a death or Revive ends it).
func _tick_burn() -> void:
	for u in units(PLAYER) + units(ENEMY):
		if u.burn > 0 and u.alive and result == "":
			var amount: int = u.burn
			_log("%s burns for %d." % [_unit_label(u), amount])
			_deal_damage(u, amount, "burn")
			if u.alive and u.burn == amount:
				u.burn -= 1


func _initiative_order() -> Array:
	var all: Array = units(PLAYER) + units(ENEMY)
	all.sort_custom(func(a, b):
		if effective_spd(a) != effective_spd(b):
			return effective_spd(a) > effective_spd(b)
		if a.side != b.side:
			return a.side < b.side
		if a.lane != b.lane:
			return a.lane < b.lane
		return a.row < b.row)
	return all


func _start_of_round(u) -> void:
	if u.uid == transformed_uid:
		return
	if u.side == PLAYER and u.row == BACK:
		var front = unit_at(PLAYER, FRONT, u.lane)
		if front != null:
			if u.id == "athena":
				front.shield += 3
				_log("Athena shields %s (+3)." % front.display_name())
			elif u.id == "priest_of_ra":
				_heal(front, 2, "Priest of Ra")
	var rally: int = u.def.get("rally", 0)
	if rally > 0:
		if u.side == PLAYER and has_relic("laurel_wreath"):
			rally *= 2
		for n in _row_neighbors(u):
			n.atk += rally
		_log("%s rallies its neighbors (+%d ATK)." % [_unit_label(u), rally])
	if u.id == "scarab_queen":
		var lanes: Array = range(LANES)
		lanes.sort_custom(func(a, b): return absi(a - u.lane) < absi(b - u.lane) or (absi(a - u.lane) == absi(b - u.lane) and a < b))
		for lane in lanes:
			if unit_at(u.side, u.row, lane) == null:
				_summon_scarab(u.side, u.row, lane, "Scarab Queen")
				break
	for card in u.armaments:
		var shield: int = Data.CARDS[card["id"]]["arm"].get("shield_round", 0)
		if shield > 0:
			u.shield += shield
			_log("%s's %s grants Shield %d." % [_unit_label(u), Data.CARDS[card["id"]]["name"], shield])
	if u.id == "solar_barque" and is_sunlit(u.side, u.row, u.lane):
		for n in _row_neighbors(u):
			n.shield += 2
		_log("The Solar Barque shields its neighbors (Shield 2).")
	if u.id == "skoll_and_hati" and _wolf_count(u.side) < SKOLL_WOLVES:
		_summon_wolf_near(u, "Skoll and Hati")
	if u.id == "myrmidon":
		var count := _row_neighbors(u).size()
		if count > 0:
			u.shield += count
			_log("Myrmidon gains Shield %d." % count)
	if u.id == "zeus":
		var hit: Array = []
		for lane in LANES:
			if unit_at(PLAYER, FRONT, lane) == null:
				continue
			for row in 2:
				var t = unit_at(ENEMY, row, lane)
				if t != null and not hit.has(t):
					hit.append(t)
		if not hit.is_empty():
			_log("Zeus calls lightning.")
			for t in hit:
				_deal_damage(t, 2, "effect")


func _end_of_round(u) -> void:
	match u.id:
		"sphinx":
			u.atk += 1
			u.max_hp += 1
			u.hp += 1
			_log("Sphinx grows (+1/+1).")
		"ra":
			u.atk += 2
			_log("Ra grows (+2 ATK).")
		"apollo":
			for a in units(u.side):
				if a.row == u.row:
					_heal(a, 2, "Apollo")
		"freki":
			if u.attacked_round == round_num:
				_summon_wolf_near(u, "Freki")
		"hollow_geomancer":
			var slot: Array = intents.get(u.uid, {}).get("quicksand", [])
			if slot.size() == 2 and terrain_at(PLAYER, slot[0], slot[1]) == "":
				terrain[_key(PLAYER, slot[0], slot[1])] = "quicksand"
				_log("The Geomancer turns your lane %d %s into Quicksand." % [slot[1] + 1, "front" if slot[0] == FRONT else "back"])


## Phase 1 summons a Void Spawn every round and a Void Wisp in the back row every second round.
func _herald_end_of_round(boss) -> void:
	var phase_one: bool = boss.hp * 2 > boss.max_hp
	if phase_one:
		var slot := _first_empty_enemy_slot()
		if slot.size() == 2:
			var spawn = _spawn("void_spawn", ENEMY, slot[0], slot[1])
			_log("The Herald summons %s." % _unit_label(spawn))
	if phase_one and round_num % 2 == 0:
		for lane in [0, 3, 1, 2]:
			if unit_at(ENEMY, BACK, lane) == null:
				var wisp = _spawn("void_wisp", ENEMY, lane, BACK)
				_log("The Herald calls %s to the back row." % _unit_label(wisp))
				break
	_damage_core(boss.def["void_tide"], "The Void Tide", false, {"void_tide": boss.def["void_tide"]})


func _hel_end_of_round(hel) -> void:
	hel.atk += 1
	_log("The grave hungers: Hel gains +1 ATK.")
	for lane in [1, 2]:
		if unit_at(ENEMY, FRONT, lane) == null:
			var d = _spawn("draugr", ENEMY, lane, FRONT)
			_log("Hel raises %s." % _unit_label(d))


func _apep_end_of_round(boss) -> void:
	var stripped := false
	for u in units(PLAYER):
		if u.shield > 0:
			u.shield = 0
			stripped = true
	if stripped:
		_log("Devour Light: your units lose their Shield.")
	for lane in [1, 2, 0, 3]:
		if unit_at(ENEMY, FRONT, lane) == null:
			var b = _spawn("serpent_brood", ENEMY, lane, FRONT)
			_log("%s hatches." % _unit_label(b))
			break
	_damage_core(boss.def["void_tide"], "The Void Tide", false, {"void_tide": boss.def["void_tide"]})


func _apep_act(u) -> void:
	for lane in intents.get(u.uid, {}).get("lanes", []):
		_log("Apep CONSTRICTS lane %d!" % (lane + 1))
		for row in 2:
			var t = unit_at(PLAYER, row, lane)
			if t != null:
				_unmaking = true
				_deal_damage(t, effective_atk(u), "effect")
				_unmaking = false


func _siege_act(u) -> void:
	var it: Dictionary = intents.get(u.uid, {})
	if it.get("type", "") != "siege":
		return
	var lane := _lane_with_most_player_units()
	_log("The Siege Engine bombards lane %d!" % (lane + 1))
	for row in 2:
		var t = unit_at(PLAYER, row, lane)
		if t != null:
			_deal_damage(t, effective_atk(u), "effect")


func _first_empty_enemy_slot() -> Array:
	for row in 2:
		for lane in LANES:
			if unit_at(ENEMY, row, lane) == null:
				return [lane, row]
	return []


func _act(u) -> void:
	if u.side == PLAYER and u.lane == petrified_lane:
		_log("%s is petrified and cannot act." % _unit_label(u))
		return
	if u.uid == transformed_uid:
		_log("%s is a Swine this round and cannot act." % _unit_label(u))
		return
	if u.id == "void_herald":
		_herald_act(u)
		return
	if u.id == "apep":
		_apep_act(u)
		return
	if u.id == "siege_engine":
		_siege_act(u)
		return
	if u.row == BACK and not u.has_kw("ranged"):
		return
	if u.id == "benben_stone":
		return
	if u.id == "void_charger":
		var it: Dictionary = intents.get(u.uid, {})
		if it.get("type", "") == "charge":
			_charge(u, it["lane"])
	var atk := effective_atk(u)
	if atk <= 0:
		return
	var target = _pick_target(u, u.lane)
	if target == null:
		return
	if target is String:
		_log("%s hits the Core." % _unit_label(u), {"core": true})
		_damage_core(atk, u.display_name(), true)
	else:
		_attack(u, target, atk)
		if u.row == FRONT and is_wolf(u):
			_flank(u, target)
	if u.side == ENEMY and Data.ENEMIES[u.id].has("status_card"):
		_add_status(u, Data.ENEMIES[u.id]["status_card"])


## Flank: the Wolf behind `front` follows up on the same target (or the front Wolf's next one if it fell).
func _flank(front, target) -> void:
	var b = unit_at(front.side, BACK, front.lane)
	if b == null or not b.alive or not is_wolf(b) or not has_flank(b) or b.uid == transformed_uid:
		return
	var t = target if target.alive else _pick_target(front, front.lane)
	if t == null or t is String or not _can_target(b, t):
		return
	var atk := effective_atk(b)
	if atk <= 0:
		return
	var prev = actor
	actor = b
	_log("%s flanks behind %s." % [_unit_label(b), front.display_name()])
	_attack(b, t, atk)
	actor = prev


func _attack(u, target, atk: int) -> void:
	u.attacked_round = round_num
	var ranged: bool = u.has_kw("ranged")
	var dmg := atk
	if ranged and u.side == PLAYER and has_relic("eye_of_horus") and target.row == BACK:
		dmg += 1
	if u.id == "horus" and target.burn > 0:
		dmg += 2
	var extra := {"target": [target.side, target.row, target.lane], "ranged": ranged}
	if u.has_kw("cleave"):
		extra["cleave"] = _cleave_preview(u, target)
	_log("%s attacks %s." % [_unit_label(u), _unit_label(target)], extra)
	var hit: Array = [target]
	var behind = unit_at(target.side, BACK, target.lane) if target.row == FRONT else null
	var excess := _deal_damage(target, dmg, "ranged" if ranged else "melee")
	var thorns: int = target.def.get("thorns", 0)
	if thorns > 0 and not ranged and u.alive:
		_log("%s is cut by thorns." % _unit_label(u))
		_deal_damage(u, thorns, "thorns")
	if u.has_kw("poison") and target.alive and target.side != u.side and not target.poisoned:
		target.poisoned = true
		_log("%s is Poisoned." % _unit_label(target))
	if target.side != u.side:
		_add_burn(target, u.def.get("burn", 0) + (1 if is_sunlit(u.side, u.row, u.lane) else 0))

	if u.has_kw("pierce") and excess > 0 and behind != null and behind.alive:
		_deal_damage(behind, excess, "pierce")

	if u.has_kw("cleave"):
		for lane in [target.lane - 1, target.lane + target.width]:
			var t = unit_at(target.side, target.row, lane)
			if t != null and not hit.has(t) and _can_target(u, t):
				hit.append(t)
				_deal_damage(t, atk, "cleave")
		if u.side == PLAYER and has_relic("mjolnir_shard"):
			for h in hit.duplicate():
				if h.row == FRONT:
					var b = unit_at(h.side, BACK, h.lane)
					if b != null and not hit.has(b) and _can_target(u, b):
						hit.append(b)
						_deal_damage(b, atk, "cleave")


## For the cleave animation: the row and lane span the swing covers, and the splash slots it will hit.
func _cleave_preview(u, target) -> Dictionary:
	var lanes := range(max(0, target.lane - 1), min(LANES, target.lane + target.width + 1))
	var hits: Array = []
	for lane in [target.lane - 1, target.lane + target.width]:
		var t = unit_at(target.side, target.row, lane)
		if t != null and t != target and _can_target(u, t):
			hits.append([t.side, t.row, t.lane])
	return {"side": target.side, "row": target.row, "lanes": lanes, "hits": hits}


func _charge(u, lane: int) -> void:
	if u.lane == lane:
		return
	var occupant = unit_at(ENEMY, FRONT, lane)
	if occupant != null and occupant.has_kw("immovable"):
		return
	var old_lane: int = u.lane
	_remove(u)
	if occupant != null:
		_remove(occupant)
		_place(occupant, FRONT, old_lane)
	_place(u, FRONT, lane)
	_log("%s charges into lane %d!" % [u.display_name(), lane + 1])


func _herald_act(u) -> void:
	var it: Dictionary = intents.get(u.uid, {})
	var lane: int = it.get("lane", 1)
	if it.get("type", "") == "strike":
		_log("The Herald STRIKES lane %d!" % (lane + 1))
		var any := false
		for row in 2:
			var t = unit_at(PLAYER, row, lane)
			if t != null:
				any = true
				_deal_damage(t, 5, "effect")
		if not any:
			_damage_core(5, "The Herald", true)
		for side_lane in [lane - 1, lane + 1]:
			var t = unit_at(PLAYER, FRONT, side_lane)
			if t != null:
				_deal_damage(t, 5, "cleave")
		return
	var target = _lane_target(u, lane)
	if target is String:
		_log("The Herald hits the Core through lane %d." % (lane + 1))
		_damage_core(effective_atk(u), "The Herald", true)
	else:
		_attack(u, target, effective_atk(u))


func _can_target(attacker, t) -> bool:
	if attacker.has_kw("ranged") and terrain_at(t.side, t.row, t.lane) == "ruins":
		return false
	if not attacker.has_kw("ranged") and t.has_kw("airborne"):
		return false
	return true


func _row_order(u) -> Array:
	if u.side == PLAYER and u.has_kw("ranged") and has_relic("eye_of_horus"):
		return [BACK, FRONT]
	return [FRONT, BACK]


func _lane_target(u, lane: int):
	var opp: int = 1 - u.side
	for row in _row_order(u):
		var t = unit_at(opp, row, lane)
		if t != null and _can_target(u, t):
			return t
	return CORE


func _pick_target(u, lane: int):
	var opp: int = 1 - u.side

	for l in [lane, lane - 1, lane + 1]:
		for row in [FRONT, BACK]:
			var t = unit_at(opp, row, l)
			if t == null or not t.has_kw("taunt") or not _can_target(u, t):
				continue
			if row == BACK and unit_at(opp, FRONT, l) != null:
				continue
			return t

	if u.id in ["void_wisp", "hel"]:
		var best = null
		for t in units(opp):
			if _can_target(u, t) and (best == null or t.hp < best.hp):
				best = t
		return best if best != null else CORE

	if u.id in ["hollow_archer", "carrion_harpy"]:
		for row in [BACK, FRONT]:
			var t = unit_at(opp, row, lane)
			if t != null and _can_target(u, t):
				return t
		return CORE

	var own = _lane_target(u, lane)
	if not (own is String):
		return own
	if u.side == ENEMY:
		return CORE

	for d in range(1, LANES):
		for l in [lane - d, lane + d]:
			for row in _row_order(u):
				var t = unit_at(opp, row, l)
				if t != null and _can_target(u, t):
					return t
	return null


## Applies damage and returns the excess beyond what the target could absorb.
func _deal_damage(t, amount: int, kind: String) -> int:
	if not t.alive or amount <= 0:
		return 0
	if t.has_kw("veil") and t.veil_round != round_num:
		t.veil_round = round_num
		_log("%s's Veil turns aside %d damage." % [_unit_label(t), amount])
		return 0
	if t.id == "achilles":
		if kind == "melee":
			_log("Achilles shrugs off the melee attack.")
			return 0
		if kind in ["ranged", "cleave", "pierce"]:
			amount *= 2
	var devoured: bool = t.side == PLAYER and _has_living(ENEMY, "apep")
	var absorbed: int = 0 if devoured else min(t.shield, amount)
	t.shield -= absorbed
	amount -= absorbed
	var before: int = t.hp
	t.hp -= amount
	var excess: int = max(0, amount - before)
	if absorbed > 0:
		_log("%s takes %d (%d blocked by Shield)." % [_unit_label(t), amount, absorbed])
	else:
		_log("%s takes %d." % [_unit_label(t), amount])
	if t.hp <= 0:
		_kill(t)
	elif amount > 0 and t.has_kw("frenzy"):
		t.atk += 1
		_log("%s is driven into a Frenzy (+1 ATK)." % _unit_label(t))
	return excess


## Any heal also cures Poison, even at full HP.
func _heal(u, amount: int, source: String) -> void:
	if u.poisoned:
		u.poisoned = false
		_log("%s cures %s's Poison." % [source, u.display_name()])
	var healed: int = min(amount, u.max_hp - u.hp)
	if healed > 0:
		u.hp += healed
		_log("%s heals %s for %d." % [source, u.display_name(), healed])


func _damage_core(amount: int, source: String, enemy_hit := false, extra := {}) -> void:
	if enemy_hit and has_relic("wardens_plate"):
		amount = max(1, amount - 2)
	core_hp -= amount
	_log("%s deals %d to the Core (%d left)." % [source, amount, max(core_hp, 0)], extra)
	if core_hp <= 0 and result == "":
		result = "defeat"


func _kill(u) -> void:
	if not u.alive:
		return

	if u.side == PLAYER and u.row == FRONT and has_relic("aegis_fragment") and not aegis_used:
		aegis_used = true
		u.hp = 1
		_log("Aegis Fragment saves %s at 1 HP." % u.display_name())
		return

	var can_revive: bool = u.has_kw("revive") or (u.side == PLAYER and not u.is_token and has_relic("ankh_of_eternity"))
	if can_revive and not u.revive_used and _unmaking:
		_log("Apep unmakes %s - it cannot Revive." % u.display_name())
	elif can_revive and not u.revive_used:
		u.revive_used = true
		u.shield = 0
		u.poisoned = false
		u.burn = 0
		_log("%s falls..." % _unit_label(u))
		_on_death(u)
		_death_triggers(u)
		if u.side == PLAYER and _has_living(PLAYER, "osiris", u):
			u.hp = u.max_hp
			u.atk += 2
		else:
			u.hp = 1
		_log("%s revives with %d HP!" % [_unit_label(u), u.hp])
		if u.side == PLAYER and has_relic("ankh_of_eternity"):
			_damage_core(2, "Ankh of Eternity")
		_check_enemies_cleared()
		return

	u.alive = false
	_remove(u)
	_log("%s dies." % _unit_label(u))
	_return_armaments(u)
	if u.side == ENEMY and u.poisoned and _up("hunt_2"):
		_heal_core(2, "Feast")
	if u.side == ENEMY and u.burn > 0 and horus_round != round_num and _has_living(PLAYER, "horus"):
		horus_round = round_num
		faith_next += 1
		_log("Horus claims the burning soul: +1 Faith next round.")

	if u.side == PLAYER and not u.is_token:
		last_dead_ally = u.card
		if has_relic("valhallas_gate") and not valhalla_returned.has(u.card["cid"]):
			valhalla_returned[u.card["cid"]] = true
			hand.append(u.card)
			_log("Valhalla's Gate returns %s to your hand." % u.display_name())
		else:
			discard.append(u.card)

	_on_death(u)
	_split(u)
	_death_triggers(u)
	_reinforce(u)
	if u.side == PLAYER:
		for hel in units(ENEMY):
			if hel.id == "hel":
				_log("Toll of the Dead.")
				_heal(hel, 2, "Toll of the Dead")
				_damage_core(2, "Toll of the Dead")
	if u.id in ["hel", "apep"]:
		for minion in units(ENEMY):
			minion.alive = false
			_remove(minion)
		_log("With %s gone, its minions crumble." % u.display_name())
	_check_enemies_cleared()


func _has_living(side: int, id: String, exclude = null) -> bool:
	for a in units(side):
		if a.id == id and a != exclude:
			return true
	return false


func _on_death(u) -> void:
	match u.id:
		"einherjar":
			for row in 2:
				var a = unit_at(u.side, row, u.lane)
				if a != null and a != u:
					a.atk += 2
					_log("Einherjar's death inspires %s (+2 ATK)." % a.display_name())
		"shieldmaiden":
			for n in [unit_at(u.side, u.row, u.lane - 1), unit_at(u.side, u.row, u.lane + 1)]:
				if n != null:
					n.shield += 3
					_log("Shieldmaiden's death shields %s (+3)." % n.display_name())
		"raven_of_odin":
			_draw(1)
			_log("The Raven brings you a card.")
		"scarab_swarm":
			# A reviving Swarm still holds its slot, so the Scarab takes the other row.
			for row in [u.row, 1 - u.row]:
				if unit_at(u.side, row, u.lane) == null:
					var s = _spawn("scarab", u.side, u.lane, row)
					_log("A Scarab crawls out (%s)." % _unit_label(s))
					break


## Split: two copies appear in its own slot and the nearest empty slot in its row (left first).
func _split(u) -> void:
	var into: String = u.def.get("split", "")
	if into == "":
		return
	var lanes: Array = []
	for d in LANES:
		for lane in ([u.lane] if d == 0 else [u.lane - d, u.lane + d]):
			if lanes.size() < 2 and lane >= 0 and lane < LANES and unit_at(u.side, u.row, lane) == null:
				lanes.append(lane)
	for lane in lanes:
		var s = _spawn(into, u.side, lane, u.row)
		_log("%s splits off from %s." % [_unit_label(s), u.display_name()])


## "Whenever an ally dies" effects. Also fire when a unit Revives, but never for the unit itself.
func _death_triggers(u) -> void:
	if u.side == PLAYER:
		falls += 1
	if u.side == PLAYER and has_relic("mead_of_the_einherjar") and not mead_used:
		mead_used = true
		for a in units(PLAYER):
			if a != u:
				a.atk += 1
		_log("Mead of the Einherjar: your allies gain +1 ATK.")
	for w in units(PLAYER) + units(ENEMY):
		if not w.alive or w == u:
			continue
		if w.id == "berserker" and w.side == u.side:
			w.atk += 1
			_log("Berserker rages (+1 ATK).")
		elif w.id == "anubis":
			w.atk += 1
			w.max_hp += 1
			w.hp += 1
			_log("Anubis feeds on the death (+1/+1).")
		elif w.id == "echo_of_fenrir" and u.side == PLAYER:
			w.atk += 1
			_log("Fenrir grows stronger (+1 ATK).")
		elif w.id == "geri" and w.side == u.side and is_wolf(u):
			w.atk += 1
			w.max_hp += 1
			w.hp += 1
			_log("Geri howls for the fallen Wolf (+1/+1).")
		elif w.id == "khepri" and w.side == u.side and u.side == PLAYER and u.id == "scarab":
			_heal_core(1, "Khepri")
		elif w.id == "odin" and w.side == u.side and u.side == PLAYER:
			var t = unit_at(ENEMY, FRONT, u.lane)
			if t != null:
				_log("Odin's ravens avenge the fallen.")
				_deal_damage(t, 2, "effect")


func _reinforce(u) -> void:
	if u.row != FRONT or unit_at(u.side, FRONT, u.lane) != null:
		return
	var b = unit_at(u.side, BACK, u.lane)
	if b == null or not b.has_kw("reinforce"):
		return
	_remove(b)
	_place(b, FRONT, u.lane)
	if b.id == "valkyrie":
		b.atk += u.atk
	if has_relic("gjallarhorn") and b.side == PLAYER:
		b.shield += 4
	_log("%s steps forward to reinforce lane %d." % [b.display_name(), u.lane + 1])


func _check_enemies_cleared() -> void:
	if result == "" and units(ENEMY).is_empty():
		result = "win"


func _end_round_checks() -> void:
	if result == "":
		if units(ENEMY).is_empty():
			result = "win"
		elif not is_boss and round_num >= max_rounds:
			result = "timeout"
	if result == "":
		_start_round()
		_log("--- Round %d: plan your moves ---" % round_num)
		return
	_finish_fight()


func _finish_fight() -> void:
	if result == "timeout":
		for e in units(ENEMY):
			if e.threat > 0:
				_damage_core(e.threat, "%s (Threat)" % e.display_name(), true)
		if core_hp <= 0:
			result = "defeat"
	phase = "over"
	var text: String = {
		"win": "Victory! All enemies are destroyed.",
		"timeout": "Time is up. Surviving enemies strike the Core.",
		"defeat": "The Reliquary Core is destroyed. The run is over.",
	}[result]
	_log(text)


# ---------------------------------------------------------------- test helpers

## Places a unit directly, bypassing cost and hand. Used by tests.
func debug_place(id: String, side: int, lane: int, row: int):
	var card = _new_card(id) if side == PLAYER and Data.CARDS.has(id) else null
	var u = _spawn(id, side, lane, row, card)
	u.deployed_round = 0
	return u
