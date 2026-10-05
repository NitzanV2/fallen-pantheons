extends SceneTree
## Plays many runs with a simple greedy bot and reports how much Core HP each fight costs.
##   godot --headless --path . --script res://tests/balance_sim.gd -- [runs_per_power] [no_powers]
##
## Primary metric: Core HP lost per fight, by fight type, floor band, god power and encounter.
## Secondary: matchups (god power vs elite / boss) and win, timeout and loss rates per encounter.
## Run win rate comes last: with an unfinished card pool it depends on too much at once.
## Every fight table is split by act; floors restart at 1 in each act.
##
## The bot is a rough stand-in for a thoughtful player: it blocks lanes with
## enemies, puts ranged and support units behind allies, and makes sensible
## run choices. Use the numbers to compare balance changes, not as absolutes.

const Data = preload("res://scripts/core/data.gd")
const Run = preload("res://scripts/core/run.gd")

const P := 0
const E := 1
const FRONT := 0
const BACK := 1
const RARITY_VALUE := {"Common": 1, "Uncommon": 2, "Rare": 3}
const POOLS := ["early", "late", "elite", "boss"]
## [label, first floor, last floor] using the 1-based floor numbers shown in game.
const FLOOR_BANDS := [["floors 1-6", 1, 6], ["floors 7-12", 7, 12], ["floors 13-14", 13, 14], ["boss (15)", 15, 15]]

## One entry per fight: {"id", "act", "pool", "power", "floor", "lost", "result"}. "lost" is Core HP lost in
## the fight, net of in-fight healing. A defeat ends the fight, so losses understate the true damage.
var fights: Array = []
var run_stats: Array = []
var no_powers := false
## "archetype=<key>": the bot drafts that archetype's cards first, and only its pantheon's patrons play.
var archetype := ""
const ARCHETYPES := {
	"doomed": ["einherjar", "shieldmaiden", "raven_of_odin", "berserker", "valkyrie", "ragnarok", "thor", "odin"],
	"raiders": ["raider", "longship", "ulfhednar", "loki"],
	"pack": ["ulfr_hunter", "call_of_the_pack", "geri", "freki", "blood_scent", "skoll_and_hati"],
	"olympians": ["hoplite", "peltast", "myrmidon", "athena", "apollo", "phalanx_formation", "achilles", "zeus"],
	"oracle": ["divine_favor", "pythia", "olympian_ichor", "hermes"],
	"eternal": ["mummy_guardian", "priest_of_ra", "sphinx", "anubis", "book_of_the_dead", "ra", "osiris"],
	"swarm": ["scarab_swarm", "sandswarm", "scarab_queen", "plague_of_locusts", "khepri"],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if not args.is_empty() else 100
	no_powers = args.has("no_powers")
	for a in args:
		if a.begins_with("archetype="):
			archetype = a.trim_prefix("archetype=")
	print("Balance: ", Data.BALANCE)
	if no_powers:
		print("God powers are never used")
	if archetype != "":
		print("Drafting archetype: ", archetype)
	for patron in Data.PATRONS:
		if archetype != "" and Data.CARDS[patron["card"]]["faction"] != Data.CARDS[ARCHETYPES[archetype][0]]["faction"]:
			continue
		for power in patron["powers"]:
			for s in range(1, runs + 1):
				var r := _play_run(s * 7 + power.length(), patron["card"], power)
				r["power"] = power
				run_stats.append(r)
	_report_hp()
	_report_encounters()
	_report_matchups()
	_report_runs()
	quit()


# ---------------------------------------------------------------- report

func _report_hp() -> void:
	print("")
	print("== CORE HP LOST PER FIGHT (primary) ==  avg (median / 90th percentile)")
	for act in range(1, Data.ACTS.size() + 1):
		var in_act: Array = fights.filter(func(f): return f["act"] == act)
		if in_act.is_empty():
			continue
		print("")
		var header := "%-24s" % ("ACT %d" % act)
		for pool in POOLS:
			header += "%-18s" % pool
		print(header + "all")
		for power in Data.GOD_POWERS:
			_hp_row(Data.GOD_POWERS[power]["name"], in_act.filter(func(f): return f["power"] == power))
		_hp_row("ALL POWERS", in_act)
		print("By floor band (all powers)")
		for band in FLOOR_BANDS:
			var in_band: Array = in_act.filter(func(f): return f["floor"] >= band[1] and f["floor"] <= band[2])
			print("  %-14s %5d fights   %s" % [band[0], in_band.size(), _summary(_lost(in_band))])


func _hp_row(label: String, rows: Array) -> void:
	var line := "%-24s" % label
	for pool in POOLS:
		line += "%-18s" % _summary(_lost(rows.filter(func(f): return f["pool"] == pool)))
	print(line + _summary(_lost(rows)))


func _report_encounters() -> void:
	print("")
	print("== ENCOUNTERS ==")
	print("%-4s %-20s %-6s %6s %8s %7s %6s %5s   %6s %8s %6s" % ["act", "encounter", "pool", "fights", "avg lost", "median", "p90", "max", "win%", "timeout%", "loss%"])
	var keys: Array = []
	for f in fights:
		var key: Array = [f["act"], POOLS.find(f["pool"]), f["id"], f["pool"]]
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	for key in keys:
		var rows: Array = fights.filter(func(f): return f["act"] == key[0] and f["id"] == key[2] and f["pool"] == key[3])
		var lost := _lost(rows)
		print("%-4d %-20s %-6s %6d %8.1f %7.1f %6.1f %5d   %6.1f %8.1f %6.1f" % [key[0], key[2], key[3], rows.size(), _avg(lost),
			_percentile(lost, 0.5), _percentile(lost, 0.9), lost.max(), _rate(rows, ["win"]), _rate(rows, ["timeout"]), _rate(rows, ["loss", "defeat"])])


## God power vs each elite and boss: avg Core HP lost / win%.
func _report_matchups() -> void:
	for act in range(1, Data.ACTS.size() + 1):
		for pool in ["elite", "boss"]:
			_matchup_table(act, pool, "elites" if pool == "elite" else "bosses")


func _matchup_table(act: int, pool: String, title: String) -> void:
	var rows_in: Array = fights.filter(func(f): return f["act"] == act and f["pool"] == pool)
	if rows_in.is_empty():
		return
	print("")
	print("== MATCHUPS (act %d): god power vs %s ==  avg HP lost / win%% (fights)" % [act, title])
	var ids: Array = []
	for f in rows_in:
		if not ids.has(f["id"]):
			ids.append(f["id"])
	ids.sort()
	var header := "%-24s" % ""
	for id in ids:
		header += "%-17s" % id
	print(header)
	for power in Data.GOD_POWERS:
		var line := "%-24s" % Data.GOD_POWERS[power]["name"]
		for id in ids:
			var rows: Array = rows_in.filter(func(f): return f["power"] == power and f["id"] == id)
			line += "%-17s" % ("-" if rows.is_empty() else "%.1f / %d%% (%d)" % [_avg(_lost(rows)), roundi(_rate(rows, ["win"])), rows.size()])
		print(line)


func _report_runs() -> void:
	print("")
	print("== RUNS (least reliable) ==  per act boss: reached% / HP entering")
	var total_wins := 0
	for power in Data.GOD_POWERS:
		var rows: Array = run_stats.filter(func(r): return r["power"] == power)
		var wins: int = rows.filter(func(r): return r["won"]).size()
		total_wins += wins
		var line := "%-24s" % Data.GOD_POWERS[power]["name"]
		for a in Data.ACTS.size():
			var reached: Array = rows.filter(func(r): return r["boss_hp"][a] >= 0)
			line += "act %d boss %5.1f%% / %4.1f   " % [a + 1, 100.0 * reached.size() / max(rows.size(), 1), _avg(reached.map(func(r): return r["boss_hp"][a]))]
		print(line + "upgrades %.1f   win %5.1f%%" % [_avg(rows.map(func(r): return r["upgrades"])), 100.0 * wins / max(rows.size(), 1)])
	print("%-24s win %5.1f%%" % ["OVERALL", 100.0 * total_wins / max(run_stats.size(), 1)])


func _lost(rows: Array) -> Array:
	return rows.map(func(f): return f["lost"])


func _summary(values: Array) -> String:
	if values.is_empty():
		return "-"
	return "%.1f (%d/%d)" % [_avg(values), roundi(_percentile(values, 0.5)), roundi(_percentile(values, 0.9))]


func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


func _percentile(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(q * sorted.size()), sorted.size() - 1)]


func _rate(rows: Array, results: Array) -> float:
	return 100.0 * rows.filter(func(f): return f["result"] in results).size() / max(rows.size(), 1)


# ---------------------------------------------------------------- run decisions

func _play_run(seed_value: int, patron: String, power: String) -> Dictionary:
	var run = Run.new()
	run.setup(seed_value, patron, power)
	var boss_hp: Array = []
	boss_hp.resize(Data.ACTS.size())
	boss_hp.fill(-1)
	var guard := 0
	while not (run.state in ["victory", "defeat"]) and guard < 400:
		guard += 1
		match run.state:
			"act_complete":
				run.start_next_act()
			"map":
				while run.pending_upgrades() > 0:
					run.choose_upgrade(_choose_upgrade(run))
				run.enter_node(_choose_node(run))
			"combat":
				if run.nodes[run.current]["type"] == "boss":
					boss_hp[run.act - 1] = run.core_hp
				var before: int = run.core_hp
				var c = run.make_combat()
				var type: String = run.nodes[run.current]["type"]
				_play_fight(c, type != "fight" or run.floor_number() + Data.POWER_COOLDOWN_FLOORS + 1 <= Run.FLOORS)
				var result: String = c.result
				if result == "":
					print("WARNING: %s did not finish within the round guard" % run.battle_id)
					result = "loss"
				fights.append({"id": run.battle_id, "act": run.act, "pool": run.battle_pool, "power": power,
					"floor": run.floor_number(), "lost": before - c.core_hp, "result": result})
				run.finish_combat(c)
			"reward":
				run.finish_reward(_choose_card(run, run.reward["cards"]))
			"shop":
				_shop(run)
			"shrine":
				_shrine(run)
			"rest":
				if run.core_hp <= run.max_hp - 8 or run.deck.size() <= Run.MIN_DECK:
					run.rest_heal()
				else:
					run.rest_remove(_worst_card(run))
	return {"won": run.state == "victory", "act": run.act, "floor": run.floor_number(), "boss_hp": boss_hp, "max_hp": run.max_hp,
		"upgrades": run.power_nodes.size()}


## Finishes a branch before starting the next; Pact comes last.
func _choose_upgrade(run) -> String:
	var options: Array = run.upgrade_options()
	var nodes: Dictionary = Data.GOD_POWERS[run.power]["nodes"]
	var best: String = options[0]
	for id in options:
		if _upgrade_score(nodes[id]) > _upgrade_score(nodes[best]):
			best = id
	return best


func _upgrade_score(node: Dictionary) -> int:
	return -1 if node["branch"] == "Pact" else node["tier"]


func _choose_node(run) -> int:
	var best := -1
	var best_score := -999.0
	var hp_ratio: float = float(run.core_hp) / run.max_hp
	for id in run.available_nodes():
		var score := 0.0
		match run.nodes[id]["type"]:
			"fight": score = 5
			"elite": score = 8 if hp_ratio > 0.7 else -5
			"shop": score = 6 if run.gold >= 60 else 1
			"shrine": score = 4
			"rest": score = 9 if hp_ratio < 0.6 else 2
			"boss": score = 10
		score += run.map_rng.randf() * 0.5
		if score > best_score:
			best_score = score
			best = id
	return best


func _card_value(run, id: String) -> float:
	var def: Dictionary = Data.CARDS[id]
	var v: float = RARITY_VALUE.get(def["rarity"], 0) * 2.0
	if def["faction"] == run.main_pantheon():
		v += 1.5
	if def["type"] == "spell":
		v -= 1.0
	if archetype != "" and id in ARCHETYPES[archetype]:
		v += 4.0
	return v


func _choose_card(run, cards: Array) -> int:
	if cards.is_empty() or run.deck.size() >= 22:
		return -1
	var best := 0
	for i in cards.size():
		if _card_value(run, cards[i]) > _card_value(run, cards[best]):
			best = i
	return best


func _worst_card(run) -> int:
	for i in run.deck.size():
		if run.deck[i] == "ark_sentinel":
			return i
	return 0


func _shop(run) -> void:
	for i in run.shop["relics"].size():
		run.buy_relic(i)
	if run.core_hp < run.max_hp * 0.6 and run.can_buy_heal():
		run.buy_heal()
	var order: Array = range(run.shop["cards"].size())
	order.sort_custom(func(a, b): return _card_value(run, run.shop["cards"][a]["id"]) > _card_value(run, run.shop["cards"][b]["id"]))
	for i in order:
		if _card_value(run, run.shop["cards"][i]["id"]) >= 4:
			run.buy_card(i)
	if run.can_buy_remove() and run.deck.has("ark_sentinel"):
		run.buy_remove(_worst_card(run))
	run.leave_node()


## Takes the first option that isn't a plain "leave", skipping risky ones when HP is low.
func _shrine(run) -> void:
	var guard := 0
	while not run.shrine["done"] and guard < 10:
		guard += 1
		var options: Array = run.shrine_options()
		var healthy: bool = run.core_hp >= run.max_hp * 0.6
		var pick := -1
		for i in options.size():
			var o: Dictionary = options[i]
			if not run.can_choose(i) or not (o.has("fx") or o.has("outcomes") or o.has("cost")):
				continue
			if not healthy and (o.has("outcomes") or o.has("cost")):
				continue
			if o.get("fx", {}).get("hp", 0) > 0 and run.core_hp > run.max_hp - 10:
				continue
			pick = i
			break
		if pick == -1:
			for i in options.size():
				if run.can_choose(i):
					pick = i
			if pick == -1:
				break
		run.choose_option(pick)
		if run.shrine["pending"] == "remove":
			run.shrine_remove(_worst_card(run))
		elif run.shrine["pending"] == "choose":
			run.shrine_take_card(_choose_card(run, run.shrine["cards"]))
	run.leave_node()


# ---------------------------------------------------------------- combat decisions

func _play_fight(c, power_allowed := true) -> void:
	var guard := 0
	while c.phase == "plan" and guard < 40:
		guard += 1
		for step in 10:
			if c.phase != "plan" or not _play_best_card(c):
				break
		if c.phase == "plan" and power_allowed and not no_powers:
			_use_power(c)
		if c.phase == "plan":
			c.end_plan()


## Uses the god power once it has a worthwhile target.
func _use_power(c) -> void:
	var targets: Array = c.power_targets()
	if targets.is_empty():
		return
	match c.power["id"]:
		"tyrs_oath":
			var allies: Array = c.units(P)
			if allies.size() < 3:
				return
			var weakest = allies[0]
			for u in allies:
				if u.atk + u.hp < weakest.atk + weakest.hp:
					weakest = u
			c.use_power([[P, weakest.row, weakest.lane]])
		"poseidons_tide":
			var t: Array = targets[0]
			for dir in [-1, 1]:
				var dest: int = t[2] + dir
				if dest < 0 or dest > 3 or c.unit_at(E, FRONT, dest) != null:
					c.use_power([t], dir)
					return
			if c.round_num >= 3:
				c.use_power([t], 1 if t[2] < 2 else -1)
		"osiris_return":
			var slot := _best_slot(c, c.last_dead_ally["id"])
			if not slot.is_empty() and targets.has([P, slot[1], slot[0]]):
				c.use_power([[P, slot[1], slot[0]]])
		_:
			var best: Array = targets[0]
			var best_threat := -1
			for t in targets:
				var u = c.unit_at(t[0], t[1], t[2])
				if u != null and u.atk + u.threat > best_threat:
					best_threat = u.atk + u.threat
					best = t
			c.use_power([best])


func _play_best_card(c) -> bool:
	var best_score := 0.0
	var best_action := Callable()
	for i in c.hand.size():
		if not c.can_afford(i):
			continue
		var option := _evaluate(c, i)
		if option["score"] > best_score:
			best_score = option["score"]
			best_action = option["action"]
	if not best_action.is_valid():
		return false
	best_action.call()
	return true


func _evaluate(c, i: int) -> Dictionary:
	var card: Dictionary = c.hand[i]
	var def: Dictionary = Data.CARDS[card["id"]]
	var none := {"score": 0.0, "action": Callable()}
	if def["type"] == "unit":
		var slot := _best_slot(c, card["id"])
		if slot.is_empty():
			return none
		return {"score": 10.0 + def["cost"] * 3 + slot[2] * 0.1, "action": func(): c.play_unit(i, slot[0], slot[1])}
	match card["id"]:
		"faith_surge":
			return {"score": 100.0, "action": func(): c.play_spell(i, [])}
		"channel_ley_line":
			var strongest = null
			for u in c.units(P):
				if c.valid_targets(i).has([P, u.row, u.lane]) and u.atk > 0 and (strongest == null or u.atk > strongest.atk):
					strongest = u
			if strongest != null:
				return {"score": 6.0 + strongest.atk, "action": func(): c.play_spell(i, [[P, FRONT, strongest.lane]])}
			var has_unit := false
			for other in c.hand:
				if Data.CARDS[other["id"]]["type"] == "unit" and c.card_cost(other) <= c.faith - def["cost"]:
					has_unit = true
			var slots: Array = c.valid_targets(i).filter(func(t): return c.unit_at(P, t[1], t[2]) == null)
			if not has_unit or slots.is_empty():
				return none
			var slot: Array = slots[0]
			for s in slots:
				if c.unit_at(E, FRONT, s[2]) != null or c.unit_at(E, BACK, s[2]) != null:
					slot = s
					break
			return {"score": 22.0, "action": func(): c.play_spell(i, [slot])}
		"warding":
			var t = _most_threatened_ally(c)
			if t == null:
				return none
			return {"score": 6.0, "action": func(): c.play_spell(i, [[P, t.row, t.lane]])}
		"phalanx_formation":
			var front := 0
			for u in c.units(P):
				if u.row == FRONT:
					front += 1
			return {"score": 4.0 + front if front >= 2 else 0.0, "action": func(): c.play_spell(i, [])}
		"rebuke":
			for t in c.valid_targets(i):
				for dir in [-1, 1]:
					var dest: int = t[2] + dir
					if dest < 0 or dest > 3 or c.unit_at(E, FRONT, dest) != null:
						return {"score": 7.0, "action": func(): c.play_spell(i, [t], dir)}
			return none
		"book_of_the_dead":
			var targets: Array = c.valid_targets(i)
			if targets.is_empty():
				return none
			var slot := _best_slot(c, c.last_dead_ally["id"])
			if slot.is_empty():
				return none
			return {"score": 9.0, "action": func(): c.play_spell(i, [[P, slot[1], slot[0]]])}
		"divine_insight":
			return {"score": 90.0, "action": func(): c.play_spell(i, [])}
		"ambrosia":
			return {"score": 95.0, "action": func(): c.play_spell(i, [])}
		"aegis_of_olympus":
			var count: int = c.units(P).size()
			return {"score": 3.0 * count if count >= 2 else 0.0, "action": func(): c.play_spell(i, [])}
		"divine_favor":
			for u in c.units(P):
				if u.row == FRONT and c.unit_at(E, FRONT, u.lane) != null:
					return {"score": 5.0, "action": func(): c.play_spell(i, [[P, u.row, u.lane]])}
			return none
		"olympian_ichor":
			var best = null
			for u in c.units(P):
				if u.max_hp - u.hp >= 3 and (best == null or u.max_hp - u.hp > best.max_hp - best.hp):
					best = u
			if best == null:
				return none
			return {"score": 6.0, "action": func(): c.play_spell(i, [[P, best.row, best.lane]])}
		"call_of_the_pack":
			var best_lane := -1
			for lane in 4:
				if c.unit_at(P, FRONT, lane) == null and c.unit_at(P, BACK, lane) == null:
					if best_lane == -1 or c.unit_at(E, FRONT, lane) != null:
						best_lane = lane
			if best_lane == -1:
				return none
			return {"score": 9.0 + c._wolf_count(P), "action": func(): c.play_spell(i, [[P, FRONT, best_lane]])}
		"blood_scent":
			var wolves: int = c._wolf_count(P)
			if wolves < 2:
				return none
			var target = null
			for t in c.units(E):
				if c.valid_targets(i).has([E, t.row, t.lane]) and (target == null or (t.hp + t.shield <= wolves and t.atk + t.threat > target.atk + target.threat)):
					target = t
			if target == null:
				return none
			var kills: bool = target.hp + target.shield <= wolves
			return {"score": 3.0 + wolves + (5.0 if kills else 0.0), "action": func(): c.play_spell(i, [[E, target.row, target.lane]])}
		"sandswarm":
			var empty := 0
			for lane in 4:
				if c.unit_at(P, FRONT, lane) == null and c.unit_at(E, FRONT, lane) != null:
					empty += 1
			return {"score": 3.0 * empty if empty >= 2 else 0.0, "action": func(): c.play_spell(i, [])}
		"plague_of_locusts":
			var dmg: int = c.units(P).size()
			var target = null
			for t in c.units(E):
				if target == null or (t.hp + t.shield <= dmg and t.threat >= target.threat):
					target = t
			if target == null or dmg < 3:
				return none
			return {"score": 5.0 + (5.0 if target.hp + target.shield <= dmg else 0.0), "action": func(): c.play_spell(i, [[E, target.row, target.lane]])}
	return none


## Returns [lane, row, score] for the best empty slot, or [] if none is useful.
func _best_slot(c, id: String) -> Array:
	var def: Dictionary = Data.CARDS[id]
	var kws: Array = def.get("keywords", [])
	var ranged: bool = "ranged" in kws
	var support: bool = id in ["athena", "priest_of_ra", "valkyrie"]
	var best: Array = []
	var best_score := 0.0
	for row in 2:
		for lane in 4:
			if c.unit_at(P, row, lane) != null:
				continue
			var enemy_here: bool = c.unit_at(E, FRONT, lane) != null or c.unit_at(E, BACK, lane) != null
			var ally_front = c.unit_at(P, FRONT, lane)
			var score := 0.0
			if row == FRONT:
				if ranged or support:
					score = 2.0 + (1.0 if enemy_here else 0.0)
				else:
					score = 10.0 + (6.0 if enemy_here else 0.0)
					if "taunt" in kws:
						for l in [lane - 1, lane + 1]:
							if l >= 0 and l < 4 and c.unit_at(E, FRONT, l) != null:
								score += 2.0
			else:
				if support:
					score = 12.0 if ally_front != null else 0.0
				elif ranged:
					score = 8.0 + (4.0 if ally_front != null else 0.0) + (2.0 if enemy_here else 0.0)
			if def.get("tribe", "") == "wolf":
				var flanker: bool = "flank" in kws or c._has_living(P, "skoll_and_hati") or id == "skoll_and_hati"
				var behind = c.unit_at(P, BACK, lane)
				if row == FRONT and behind != null and c.is_wolf(behind) and c.has_flank(behind):
					score += 4.0
				elif row == BACK and flanker and id != "skoll_and_hati" and ally_front != null and c.is_wolf(ally_front):
					score = 18.0 + (4.0 if enemy_here else 0.0)
			var terrain: String = c.terrain_at(P, row, lane)
			if terrain == "ley_line" and score > 0:
				score += 3.0
			if terrain == "ruins" and row == BACK and score > 0:
				score += 2.0
			if c.petrified_lane == lane:
				score -= 8.0
			if score > best_score:
				best_score = score
				best = [lane, row, score]
	return best


func _most_threatened_ally(c):
	var best = null
	var best_threat := 0
	for u in c.units(P):
		if u.row != FRONT:
			continue
		var e = c.unit_at(E, FRONT, u.lane)
		if e != null and e.atk >= u.hp + u.shield - 1 and e.atk > best_threat:
			best_threat = e.atk
			best = u
	return best
