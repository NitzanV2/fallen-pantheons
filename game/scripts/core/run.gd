extends RefCounted
## One run through Act 1: map, economy, rewards, shops, shrines, and rests.
## No UI code lives here. The UI reads `state` and calls the matching actions.
##
## States: map, combat, reward, shop, shrine, rest, victory, defeat.

const Data = preload("res://scripts/core/data.gd")
const Combat = preload("res://scripts/core/combat.gd")

const FLOORS := 15
const EARLY_FLOORS := 3
# Every map gets at least one node of each type inside each floor range (0-based floors).
const GUARANTEED := {
	"shop": [[3, 4, 5, 6], [8, 9, 10, 11]],
	"elite": [[4, 5, 6, 7], [9, 10, 11, 12]],
	"rest": [[6, 7, 8, 9]],
}
# A shop never connects to another shop, nor a rest to another rest, so a path can't visit two of the same in a row.
const SERVICES := ["shop", "rest"]
const MAX_HP: int = Data.BALANCE["core_hp"]
const MIN_DECK := 5
const REST_HEAL: int = Data.BALANCE["rest_heal"]
const CARD_PRICES := {"Common": 25, "Uncommon": 40, "Rare": 60}
const RELIC_PRICE: int = Data.BALANCE["relic_price"]
const REMOVE_PRICE: int = Data.BALANCE["remove_price"]
const HEAL_PRICE: int = Data.BALANCE["shop_heal_price"]
const HEAL_AMOUNT: int = Data.BALANCE["shop_heal_amount"]
const PANTHEONS := ["norse", "greek", "egypt"]
const RARITIES := ["Common", "Uncommon", "Rare"]
const NORMAL_ODDS := [70, 25, 5]
const ELITE_ODDS := [40, 45, 15]
const SHOP_ODDS := [55, 35, 10]
const RARITY_ONLY := {"Common": [100, 0, 0], "Uncommon": [0, 100, 0], "Rare": [0, 0, 100]}
const MIN_MAX_HP := 20

var seed_value := 0
var patron := ""
var map_rng := RandomNumberGenerator.new()
var reward_rng := RandomNumberGenerator.new()
var shop_rng := RandomNumberGenerator.new()
var event_rng := RandomNumberGenerator.new()
var encounter_rng := RandomNumberGenerator.new()

var deck: Array = []
var relics: Array = []
var core_hp := MAX_HP
var max_hp := MAX_HP
var gold := 0
var nodes: Array = []
var floors: Array = []
var current := -1
var path: Array = []
var state := "map"
var battle_id := ""
var last_battle_id := ""
var reward := {}
var shop := {}
var shrine := {}
var seen_events: Array = []
var fights_won := 0
var boss_id := ""


func setup(p_seed: int, p_patron: String) -> void:
	seed_value = p_seed
	patron = p_patron
	map_rng.seed = p_seed
	reward_rng.seed = p_seed * 31 + 1
	shop_rng.seed = p_seed * 31 + 2
	event_rng.seed = p_seed * 31 + 3
	encounter_rng.seed = p_seed * 31 + 4
	deck = Data.STARTER.duplicate()
	deck.append(patron)
	for p in Data.PATRONS:
		if p["card"] == patron:
			if p.has("relic"):
				relics.append(p["relic"])
			max_hp = p.get("hp", MAX_HP)
			core_hp = max_hp
	_generate_map()
	var bosses: Array = Data.BATTLE_POOLS.keys().filter(func(id): return Data.BATTLE_POOLS[id] == "boss")
	boss_id = bosses[map_rng.randi_range(0, bosses.size() - 1)]


func has_relic(id: String) -> bool:
	return id in relics


func floor_number() -> int:
	return 0 if current == -1 else nodes[current]["floor"] + 1


func _heal(amount: int) -> int:
	var healed: int = min(amount, max_hp - core_hp)
	core_hp += healed
	return healed


# ---------------------------------------------------------------- map

func _generate_map() -> void:
	nodes.clear()
	floors.clear()
	for f in FLOORS:
		var count := 3
		if f == FLOORS - 1:
			count = 1
		elif f == FLOORS - 2:
			count = map_rng.randi_range(2, 3)
		elif f > 0:
			count = map_rng.randi_range(2, 4)
		var ids: Array = []
		for i in count:
			var node := {"id": nodes.size(), "floor": f, "index": i, "count": count, "type": _roll_type(f), "edges": []}
			nodes.append(node)
			ids.append(node["id"])
		floors.append(ids)
	for f in FLOORS - 1:
		_connect_floors(floors[f], floors[f + 1])
	_separate_services()
	for type in GUARANTEED:
		for range_floors in GUARANTEED[type]:
			_ensure_type(type, range_floors, range_floors[range_floors.size() / 2])


func _roll_type(f: int) -> String:
	if f == 0:
		return "fight"
	if f == FLOORS - 1:
		return "boss"
	if f == FLOORS - 2:
		return "rest"
	var weights := {"fight": 45, "shrine": 20, "shop": 12, "elite": 15 if f >= EARLY_FLOORS else 0, "rest": 8 if f >= 5 else 0}
	var total := 0
	for t in weights:
		total += weights[t]
	var roll := map_rng.randi_range(1, total)
	for t in weights:
		roll -= weights[t]
		if roll <= 0:
			return t
	return "fight"


## Neighbours of `id` that would clash with it if it had `type` (a shop next to a shop, or a rest next to a rest).
func _clashes(id: int, type: String) -> Array:
	if not type in SERVICES:
		return []
	return _neighbours(id).filter(func(n): return nodes[n]["type"] == type)


## Nodes one step away from `id`, on the floor above or below.
func _neighbours(id: int) -> Array:
	var result: Array = nodes[id]["edges"].duplicate()
	var f: int = nodes[id]["floor"]
	if f > 0:
		for other in floors[f - 1]:
			if nodes[other]["edges"].has(id):
				result.append(other)
	return result


## Top-down, so the fixed pre-boss rest floor is never changed.
func _separate_services() -> void:
	for f in range(FLOORS - 3, 0, -1):
		for id in floors[f]:
			var type: String = nodes[id]["type"]
			if type in SERVICES and nodes[id]["edges"].any(func(n): return nodes[n]["type"] == type):
				_replace_service(id)


func _replace_service(id: int) -> void:
	var type := _roll_type(nodes[id]["floor"])
	while type in SERVICES:
		type = _roll_type(nodes[id]["floor"])
	nodes[id]["type"] = type


## True if the node can lose its type without breaking the pre-boss floor or a guarantee.
func _removable(id: int) -> bool:
	var type: String = nodes[id]["type"]
	var f: int = nodes[id]["floor"]
	if f == FLOORS - 2:
		return false
	for range_floors in GUARANTEED.get(type, []):
		if not f in range_floors:
			continue
		var others := 0
		for g in range_floors:
			for other in floors[g]:
				if other != id and nodes[other]["type"] == type:
					others += 1
		if others == 0:
			return false
	return true


func _ensure_type(type: String, in_floors: Array, fallback_floor: int) -> void:
	for f in in_floors:
		for id in floors[f]:
			if nodes[id]["type"] == type:
				return
	var order: Array = [fallback_floor] + in_floors.filter(func(f): return f != fallback_floor)
	var free := func(id): return not (nodes[id]["type"] in GUARANTEED)
	var clean := func(id): return free.call(id) and _clashes(id, type).is_empty()
	var clearable := func(id): return _removable(id) and _clashes(id, type).all(_removable)
	for pick in [clean, clearable]:
		for f in order:
			var ids: Array = floors[f].filter(pick)
			if not ids.is_empty():
				var chosen: int = ids[map_rng.randi_range(0, ids.size() - 1)]
				for n in _clashes(chosen, type):
					_replace_service(n)
				nodes[chosen]["type"] = type
				return


func _nearest(i: int, n_from: int, n_to: int) -> int:
	return clampi(int((i + 0.5) / n_from * n_to), 0, n_to - 1)


func _connect_floors(a: Array, b: Array) -> void:
	for i in a.size():
		_add_edge(a[i], b[_nearest(i, a.size(), b.size())])
	for j in b.size():
		var has_incoming := false
		for id in a:
			if nodes[id]["edges"].has(b[j]):
				has_incoming = true
		if not has_incoming:
			_add_edge(a[_nearest(j, b.size(), a.size())], b[j])
	for i in a.size():
		if map_rng.randf() >= 0.35:
			continue
		var targets: Array = nodes[a[i]]["edges"].map(func(id): return nodes[id]["index"])
		var j: int = int(targets.max()) + 1 if map_rng.randf() < 0.5 else int(targets.min()) - 1
		if j >= 0 and j < b.size() and not nodes[a[i]]["edges"].has(b[j]) and not _crosses(a, i, j):
			_add_edge(a[i], b[j])


func _crosses(a: Array, i: int, j: int) -> bool:
	for k in a.size():
		if k == i:
			continue
		for e in nodes[a[k]]["edges"]:
			var t: int = nodes[e]["index"]
			if (k < i and t > j) or (k > i and t < j):
				return true
	return false


func _add_edge(from_id: int, to_id: int) -> void:
	if not nodes[from_id]["edges"].has(to_id):
		nodes[from_id]["edges"].append(to_id)


func available_nodes() -> Array:
	if state != "map":
		return []
	if current == -1:
		return floors[0].duplicate()
	return nodes[current]["edges"].duplicate()


func enter_node(id: int) -> String:
	if not available_nodes().has(id):
		return "That node is not reachable."
	current = id
	path.append(id)
	var type: String = nodes[id]["type"]
	match type:
		"fight", "elite", "boss":
			battle_id = _pick_battle(type, nodes[id]["floor"])
			state = "combat"
		"shop":
			_generate_shop()
			state = "shop"
		"shrine":
			_pick_event()
			state = "shrine"
		"rest":
			state = "rest"
	return ""


func leave_node() -> void:
	if state in ["shop", "shrine", "rest"]:
		state = "map"


# ---------------------------------------------------------------- combat

func _pick_battle(type: String, floor_index: int) -> String:
	if type == "boss":
		return boss_id
	var pool := type
	if type == "fight":
		pool = "early" if floor_index < EARLY_FLOORS else "late"
	var candidates: Array = []
	for id in Data.BATTLE_POOLS:
		if Data.BATTLE_POOLS[id] == pool and id != last_battle_id:
			candidates.append(id)
	if candidates.is_empty():
		for id in Data.BATTLE_POOLS:
			if Data.BATTLE_POOLS[id] == pool:
				candidates.append(id)
	var pick: String = candidates[encounter_rng.randi_range(0, candidates.size() - 1)]
	last_battle_id = pick
	return pick


func battle_def() -> Dictionary:
	return Data.battle(battle_id)


func boss_def() -> Dictionary:
	return Data.battle(boss_id)


func boss_name() -> String:
	return Data.ENEMIES[boss_def()["enemies"][0][0]]["name"]


## Floor scaling: the Empowered enemy's bonus and extra fight rounds, {"atk", "hp", "rounds"}.
func enemy_bonus() -> Dictionary:
	var every: int = Data.BALANCE["scaling_every_floors"]
	if every <= 0 or current == -1 or nodes[current]["type"] == "boss":
		return {"atk": 0, "hp": 0, "rounds": 0}
	var steps: int = nodes[current]["floor"] / every
	return {"atk": steps * Data.BALANCE["empower_atk"], "hp": steps * Data.BALANCE["empower_hp"],
		"rounds": steps * Data.BALANCE["scaling_rounds"]}


func make_combat():
	var b: Dictionary = battle_def().duplicate(true)
	b["core"] = core_hp
	b["core_max"] = max_hp
	b["enemy_bonus"] = enemy_bonus()
	var c = Combat.new()
	c.setup(b, deck, relics, seed_value * 1000 + current)
	return c


func finish_combat(c) -> void:
	core_hp = clampi(c.core_hp, 0, max_hp)
	var type: String = nodes[current]["type"]
	if c.result == "defeat" or core_hp <= 0:
		state = "defeat"
		return
	if type == "boss":
		fights_won += 1
		state = "victory"
		return
	reward = {"result": c.result, "gold": 0, "cards": [], "relic": "", "notes": []}
	if c.result == "win":
		fights_won += 1
		reward["gold"] = Data.BALANCE["elite_gold"] if type == "elite" else Data.BALANCE["win_gold"]
		if has_relic("pilgrims_pouch"):
			reward["gold"] += 8
			reward["notes"].append("Pilgrim's Pouch: +8 gold.")
		if has_relic("healing_ampoule"):
			reward["notes"].append("Healing Ampoule: healed %d." % _heal(3))
		reward["cards"] = _card_choices(ELITE_ODDS if type == "elite" else NORMAL_ODDS, reward_rng)
		if type == "elite":
			var relic := _random_relic(reward_rng)
			if relic != "":
				relics.append(relic)
				reward["relic"] = relic
	elif c.result == "timeout":
		reward["gold"] = Data.BALANCE["timeout_gold"]
	gold += reward["gold"]
	state = "reward"


func finish_reward(card_index: int) -> void:
	if state != "reward":
		return
	if card_index >= 0 and card_index < reward["cards"].size():
		deck.append(reward["cards"][card_index])
	state = "map"


# ---------------------------------------------------------------- cards and relics

func owned_pantheons() -> Array:
	var out: Array = []
	for id in deck:
		var f: String = Data.CARDS[id]["faction"]
		if f in PANTHEONS and not out.has(f):
			out.append(f)
	return out


func _card_choices(odds: Array, rng: RandomNumberGenerator) -> Array:
	var picks: Array = []
	var owned := owned_pantheons()
	var unowned: Array = PANTHEONS.filter(func(p): return not owned.has(p))
	if not owned.is_empty():
		picks.append(_roll_card(odds, owned, picks, rng))
	if not unowned.is_empty():
		picks.append(_roll_card(odds, unowned, picks, rng))
	while picks.size() < 3:
		picks.append(_roll_card(odds, [], picks, rng))
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks


func _roll_rarity(odds: Array, rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(1, 100)
	for i in RARITIES.size():
		roll -= odds[i]
		if roll <= 0:
			return RARITIES[i]
	return "Common"


func _roll_card(odds: Array, factions: Array, exclude: Array, rng: RandomNumberGenerator) -> String:
	var rarity := _roll_rarity(odds, rng)
	var pool := _card_pool(rarity, factions, exclude)
	if pool.is_empty():
		pool = _card_pool("", factions, exclude)
	if pool.is_empty():
		pool = _card_pool("", [], exclude)
	return pool[rng.randi_range(0, pool.size() - 1)]


func _card_pool(rarity: String, factions: Array, exclude: Array) -> Array:
	var out: Array = []
	for id in Data.CARDS:
		var def: Dictionary = Data.CARDS[id]
		if def.get("token", false) or def["rarity"] == "Starter" or exclude.has(id):
			continue
		if (def["rarity"] == "Divine") != (rarity == "Divine"):
			continue
		if rarity != "" and def["rarity"] != rarity:
			continue
		if not factions.is_empty() and not factions.has(def["faction"]):
			continue
		out.append(id)
	return out


func _random_relic(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var pool: Array = []
	for id in Data.RELICS:
		if Data.RELICS[id].get("pool", true) and not relics.has(id) and not exclude.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


func _relics_left() -> bool:
	for id in Data.RELICS:
		if Data.RELICS[id].get("pool", true) and not relics.has(id):
			return true
	return false


func card_price(id: String) -> int:
	return CARD_PRICES[Data.CARDS[id]["rarity"]]


# ---------------------------------------------------------------- shop

func _generate_shop() -> void:
	shop = {"cards": [], "relics": [], "remove_used": false, "heal_used": false}
	var picked: Array = []
	for i in 3:
		var id := _roll_card(SHOP_ODDS, [], picked, shop_rng)
		picked.append(id)
		shop["cards"].append({"id": id, "price": card_price(id), "sold": false})
	var listed: Array = []
	for i in 2:
		var relic := _random_relic(shop_rng, listed)
		if relic != "":
			listed.append(relic)
			shop["relics"].append({"id": relic, "price": RELIC_PRICE, "sold": false})


func buy_card(i: int) -> String:
	var item: Dictionary = shop["cards"][i]
	if item["sold"]:
		return "Already sold."
	if gold < item["price"]:
		return "Not enough gold."
	gold -= item["price"]
	item["sold"] = true
	deck.append(item["id"])
	return ""


func buy_relic(i: int) -> String:
	var item: Dictionary = shop["relics"][i]
	if item["sold"]:
		return "Already sold."
	if gold < item["price"]:
		return "Not enough gold."
	gold -= item["price"]
	item["sold"] = true
	relics.append(item["id"])
	return ""


func can_buy_remove() -> bool:
	return not shop["remove_used"] and gold >= REMOVE_PRICE and deck.size() > MIN_DECK


func buy_remove(deck_index: int) -> String:
	if not can_buy_remove():
		return "You cannot remove a card right now."
	gold -= REMOVE_PRICE
	shop["remove_used"] = true
	deck.remove_at(deck_index)
	return ""


func can_buy_heal() -> bool:
	return not shop["heal_used"] and gold >= HEAL_PRICE and core_hp < max_hp


func buy_heal() -> String:
	if not can_buy_heal():
		return "You cannot heal right now."
	gold -= HEAL_PRICE
	shop["heal_used"] = true
	_heal(HEAL_AMOUNT)
	return ""


# ---------------------------------------------------------------- shrine

## Events already met this run are skipped until every event has been seen.
## Rare events have a lower "weight".
func _pick_event() -> void:
	var ids: Array = Data.EVENTS.keys().filter(func(id): return not seen_events.has(id))
	if ids.is_empty():
		ids = Data.EVENTS.keys()
	var total := 0
	for ev_id in ids:
		total += Data.EVENTS[ev_id].get("weight", Data.EVENT_WEIGHT)
	var roll := event_rng.randi_range(1, total)
	var id: String = ids[-1]
	for ev_id in ids:
		roll -= Data.EVENTS[ev_id].get("weight", Data.EVENT_WEIGHT)
		if roll <= 0:
			id = ev_id
			break
	seen_events.append(id)
	start_event(id)


func start_event(id: String) -> void:
	shrine = {
		"event": id, "stage": "",
		"pantheon": PANTHEONS[event_rng.randi_range(0, PANTHEONS.size() - 1)],
		"pending": "", "done": false, "result": "", "cards": [],
	}


func shrine_text(text: String) -> String:
	return text.replace("{pantheon}", Data.FACTION_NAMES[shrine["pantheon"]])


func _shrine_stage() -> Dictionary:
	var ev: Dictionary = Data.EVENTS[shrine["event"]]
	return ev if shrine["stage"] == "" else ev["stages"][shrine["stage"]]


func shrine_description() -> String:
	return shrine_text(_shrine_stage()["text"])


func shrine_options() -> Array:
	return _shrine_stage()["options"]


func can_choose(i: int) -> bool:
	var option: Dictionary = shrine_options()[i]
	var cost: Dictionary = option.get("cost", {})
	if core_hp <= cost.get("hp", 0) or gold < cost.get("gold", 0):
		return false
	if cost.has("max_hp") and max_hp - cost["max_hp"] < MIN_MAX_HP:
		return false
	var fx: Dictionary = option.get("fx", {})
	if (fx.has("remove") or fx.has("remove_random")) and deck.size() <= MIN_DECK:
		return false
	return true


func choose_option(i: int) -> String:
	if shrine["done"] or shrine["pending"] != "" or not can_choose(i):
		return "You cannot choose that."
	var option: Dictionary = shrine_options()[i]
	var notes: Array = _pay_cost(option.get("cost", {}))
	var outcome: Dictionary = _roll_outcome(option["outcomes"]) if option.has("outcomes") else option
	var fx: Dictionary = outcome.get("fx", {})
	notes.append_array(_apply_fx(fx))
	shrine["result"] = shrine_text(outcome.get("text", ""))
	for note in notes:
		shrine["result"] += "\n- " + note
	if fx.has("goto"):
		shrine["stage"] = fx["goto"]
	elif shrine["pending"] == "":
		shrine["done"] = true
	return ""


func _roll_outcome(outcomes: Array) -> Dictionary:
	var total := 0
	for o in outcomes:
		total += o["weight"]
	var roll := event_rng.randi_range(1, total)
	for o in outcomes:
		roll -= o["weight"]
		if roll <= 0:
			return o
	return outcomes[-1]


func _pay_cost(cost: Dictionary) -> Array:
	var notes: Array = []
	if cost.get("hp", 0) > 0:
		core_hp -= cost["hp"]
		notes.append("Lost %d Core HP." % cost["hp"])
	if cost.get("gold", 0) > 0:
		gold -= cost["gold"]
		notes.append("Paid %d gold." % cost["gold"])
	if cost.get("max_hp", 0) > 0:
		max_hp -= cost["max_hp"]
		core_hp = mini(core_hp, max_hp)
		notes.append("Max Core HP reduced by %d." % cost["max_hp"])
	return notes


## Applies shrine effects and returns a line describing each one.
func _apply_fx(fx: Dictionary) -> Array:
	var notes: Array = []
	var g: int = fx.get("gold", 0)
	if g > 0:
		gold += g
		notes.append("Gained %d gold." % g)
	elif g < 0 and gold > 0:
		var lost := mini(-g, gold)
		gold -= lost
		notes.append("Lost %d gold." % lost)
	var hp: int = fx.get("hp", 0)
	if hp > 0:
		notes.append("Healed %d Core HP." % _heal(hp))
	elif hp < 0:
		var lost := mini(-hp, core_hp - 1)
		core_hp -= lost
		notes.append("Lost %d Core HP." % lost)
	var m: int = fx.get("max_hp", 0)
	if m != 0:
		max_hp = maxi(MIN_MAX_HP, max_hp + m)
		core_hp = clampi(core_hp + maxi(m, 0), 1, max_hp)
		notes.append("Max Core HP %+d." % m)
	if fx.has("card"):
		var id := ""
		if fx["card"] == "Divine":
			id = _divine_cards(1)[0]
		else:
			var odds: Array = NORMAL_ODDS if fx["card"] == "any" else RARITY_ONLY[fx["card"]]
			id = _roll_card(odds, [], [], event_rng)
		deck.append(id)
		notes.append("%s joins your deck." % Data.CARDS[id]["name"])
	if fx.has("relic"):
		var relic := _random_relic(event_rng)
		if relic == "":
			gold += 40
			notes.append("No relics remain. Gained 40 gold instead.")
		else:
			relics.append(relic)
			notes.append("Gained %s: %s" % [Data.RELICS[relic]["name"], Data.RELICS[relic]["text"]])
	if fx.has("curse"):
		deck.append(fx["curse"])
		notes.append("%s is added to your deck." % Data.CARDS[fx["curse"]]["name"])
	for n in fx.get("remove_random", 0):
		if deck.size() <= MIN_DECK:
			break
		var idx := event_rng.randi_range(0, deck.size() - 1)
		notes.append("%s is taken from your deck." % Data.CARDS[deck[idx]]["name"])
		deck.remove_at(idx)
	if fx.has("remove"):
		shrine["pending"] = "remove"
	if fx.has("choose"):
		var cards: Array = []
		if fx["choose"] == "Divine":
			cards = _divine_cards(2)
		else:
			var pantheon: bool = fx["choose"] == "pantheon"
			var odds: Array = NORMAL_ODDS if pantheon else RARITY_ONLY[fx["choose"]]
			var factions: Array = [shrine["pantheon"]] if pantheon else []
			for n in 3:
				cards.append(_roll_card(odds, factions, cards, event_rng))
		shrine["cards"] = cards
		shrine["pending"] = "choose"
	return notes


## Up to n different Divine cards.
func _divine_cards(n: int) -> Array:
	var pool := _card_pool("Divine", [], [])
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(event_rng.randi_range(0, pool.size() - 1)))
	return out


func _add_result(line: String) -> void:
	shrine["result"] += ("\n- " if shrine["result"] != "" else "") + line


func shrine_remove(deck_index: int) -> void:
	if shrine["pending"] != "remove":
		return
	var name: String = Data.CARDS[deck[deck_index]]["name"]
	deck.remove_at(deck_index)
	shrine["pending"] = ""
	shrine["done"] = true
	_add_result("%s is removed from your deck." % name)


func shrine_take_card(i: int) -> void:
	if shrine["pending"] != "choose":
		return
	if i >= 0 and i < shrine["cards"].size():
		deck.append(shrine["cards"][i])
		_add_result("%s joins your deck." % Data.CARDS[shrine["cards"][i]]["name"])
	else:
		_add_result("You take nothing.")
	shrine["pending"] = ""
	shrine["done"] = true


func shrine_cancel() -> void:
	shrine["pending"] = ""
	shrine["result"] = ""


# ---------------------------------------------------------------- rest

func rest_heal() -> int:
	if state != "rest":
		return 0
	var healed := _heal(REST_HEAL)
	state = "map"
	return healed


func rest_remove(deck_index: int) -> String:
	if state != "rest":
		return "Not at a rest site."
	if deck.size() <= MIN_DECK:
		return "Your deck is too small."
	deck.remove_at(deck_index)
	state = "map"
	return ""
