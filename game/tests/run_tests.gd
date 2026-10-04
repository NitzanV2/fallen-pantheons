extends SceneTree
## Headless rules tests. Run from the game folder:
##   godot --headless --script res://tests/run_tests.gd

const Combat = preload("res://scripts/core/combat.gd")
const Data = preload("res://scripts/core/data.gd")
const Run = preload("res://scripts/core/run.gd")
const CardWidget = preload("res://scripts/ui/card_widget.gd")

const P := 0
const E := 1
const F := 0
const B := 1

var checks := 0
var failures := 0


func _initialize() -> void:
	test_lane_attack()
	test_empty_lane_hits_core()
	test_taunt()
	test_pierce()
	test_eye_of_horus()
	test_new_enemy_keywords()
	test_siege_quicksand_circe()
	test_valkyrie_reinforce()
	test_revive()
	test_achilles()
	test_timeout_threat()
	test_herald_round()
	test_hel()
	test_apep()
	test_charger_charges()
	test_spells()
	test_raiders()
	test_oracle()
	test_swarm()
	test_divine()
	test_terrain_cards()
	test_restart_plan()
	test_patron_relics()
	test_god_powers()
	test_power_upgrades()
	test_round_scaling()
	test_tooltip_wrap()
	fuzz_all_battles()
	test_maps()
	test_reward_rule()
	test_no_loss_when_units_die()
	test_curses()
	test_status_cards()
	test_event_data()
	fuzz_shrines()
	fuzz_runs()
	print("")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: " + label)


func fresh(core := 50, boss := false, relics: Array = []):
	var c = Combat.new()
	c.setup({"core": core, "enemies": [], "terrain": [], "boss": boss}, [], relics, 1)
	return c


func test_lane_attack() -> void:
	var c = fresh()
	var s = c.debug_place("ark_sentinel", P, 0, F)
	var e = c.debug_place("void_spawn", E, 0, F)
	c.end_plan()
	check(e.hp == 1, "lane attack: sentinel hits spawn for 2")
	check(s.hp == 2, "lane attack: spawn hits sentinel for 2")


func test_empty_lane_hits_core() -> void:
	var c = fresh()
	c.debug_place("ark_sentinel", P, 0, F)
	var e = c.debug_place("void_spawn", E, 2, F)
	c.end_plan()
	check(c.core_hp == 48, "empty lane: spawn hits the Core for 2")
	check(e.hp == 1, "empty lane: player unit retargets the nearest lane")


func test_taunt() -> void:
	var c = fresh()
	c.debug_place("ark_sentinel", P, 0, F)
	var spawn = c.debug_place("void_spawn", E, 0, F)
	var bulwark = c.debug_place("hollowed_bulwark", E, 1, F)
	c.end_plan()
	check(bulwark.hp == 6, "taunt: bulwark in adjacent lane is attacked")
	check(spawn.hp == 3, "taunt: spawn in own lane is ignored")


func test_eye_of_horus() -> void:
	for relic in [true, false]:
		var c = fresh(50, false, ["eye_of_horus"] if relic else [])
		c.debug_place("ark_sentinel", P, 0, F)
		c.debug_place("echo_archer", P, 0, B)
		var front = c.debug_place("void_spawn", E, 0, F)
		var back = c.debug_place("void_spawn", E, 0, B)
		c.end_plan()
		if relic:
			check(not back.alive and front.hp == 1, "eye of horus: archer hits the back row for 3")
		else:
			check(back.hp == 3 and not front.alive, "eye of horus: without it the archer hits the front")

	var c = fresh(50, false, ["eye_of_horus"])
	c.debug_place("echo_archer", P, 0, B)
	c.debug_place("ark_sentinel", P, 0, F)
	var bulwark = c.debug_place("hollowed_bulwark", E, 1, F)
	var back = c.debug_place("void_spawn", E, 0, B)
	c.end_plan()
	check(back.hp == 3 and bulwark.hp < bulwark.max_hp, "eye of horus: Taunt still takes priority")


func test_new_enemy_keywords() -> void:
	var c = fresh()
	var s = c.debug_place("ark_sentinel", P, 0, F)
	var husk = c.debug_place("thorned_husk", E, 0, F)
	c.end_plan()
	check(husk.hp == 4 and s.hp == 2, "thorns: melee attacker takes 1 back (plus the husk's hit)")

	c = fresh()
	s = c.debug_place("ark_sentinel", P, 0, F)
	var harpy = c.debug_place("carrion_harpy", E, 0, F)
	c.end_plan()
	check(harpy.hp == harpy.max_hp, "airborne: melee can't hit it")
	c = fresh()
	c.debug_place("ark_sentinel", P, 0, F)
	c.debug_place("echo_archer", P, 1, B)
	harpy = c.debug_place("carrion_harpy", E, 0, F)
	c.end_plan()
	check(harpy.hp == harpy.max_hp - 2, "airborne: ranged units still hit it")

	c = fresh()
	c.debug_place("ark_sentinel", P, 0, F).shield = 20
	c.debug_place("echo_archer", P, 0, B)
	var acolyte = c.debug_place("veiled_acolyte", E, 0, F)
	c.end_plan()
	check(acolyte.hp == 2, "veil: the first hit each round is ignored")
	c.end_plan()
	check(not acolyte.alive, "veil: it recharges but the second hit still lands")

	c = fresh()
	var ooze = c.debug_place("void_ooze", E, 1, F)
	c._deal_damage(ooze, ooze.hp, "effect")
	var a = c.unit_at(E, F, 1)
	var b = c.unit_at(E, F, 0)
	check(a != null and a.id == "oozeling" and b != null and b.id == "oozeling", "split: two Oozelings in its slot and the left neighbour")

	c = fresh()
	var ghoul = c.debug_place("frenzied_ghoul", E, 0, F)
	c._deal_damage(ghoul, 2, "effect")
	check(ghoul.atk == 3, "frenzy: +1 ATK after surviving damage")

	c = fresh()
	s = c.debug_place("ark_sentinel", P, 0, F)
	c.debug_place("plague_bearer", E, 0, B)
	c.end_plan()
	check(s.poisoned and s.hp == 2, "poison: hit for 1 and poisoned for 1 more at end of round")
	c._heal(s, 1, "test")
	check(not s.poisoned, "poison: any heal cures it")

	c = fresh()
	var idol = c.debug_place("null_idol", E, 1, F)
	c.debug_place("void_spawn", E, 0, F)
	var far = c.debug_place("void_spawn", E, 3, F)
	c.hand = [c._new_card("plague_of_locusts")]
	c.debug_place("ark_sentinel", P, 0, F)
	check(c.valid_targets(0) == [[E, F, 3]], "spellward: the idol and its neighbour can't be targeted")
	check(c.play_spell(0, [[E, F, 0]]) != "", "spellward: casting at a warded enemy fails")
	check(c.play_spell(0, [[E, F, 3]]) == "" and idol.shield == 2 and far.hp == 2, "spellward: the idol gains Shield 2 per spell")


func test_siege_quicksand_circe() -> void:
	var c = fresh()
	c.debug_place("siege_engine", E, 1, B)
	var front = c.debug_place("ark_sentinel", P, 2, F)
	var back = c.debug_place("ark_sentinel", P, 2, B)
	c._declare_intents()
	check(c.snapshot()["lane_warnings"].has(2), "siege: aimed lane is marked")
	c.end_plan()
	check(front.hp == 4 and back.hp == 4, "siege: nothing fires in the aim round")
	check(c.move_unit(2, F, 0, F) == "", "siege: dodge by moving")
	c.end_plan()
	check(front.hp == 4 and not back.alive, "siege: the unit left in the lane takes 6")

	c = fresh()
	c.debug_place("hollow_geomancer", E, 0, B)
	var s = c.debug_place("ark_sentinel", P, 2, F)
	c._declare_intents()
	c.end_plan()
	check(c.terrain_at(P, F, 2) == "quicksand", "quicksand: the strongest unit's slot sinks")
	check(not c.can_move(s) and c.move_unit(2, F, 3, F) != "", "quicksand: the unit can't move")
	check(c.effective_spd(s) == 1, "quicksand: -1 SPD")

	c = fresh()
	var hydra = c.debug_place("echo_of_hydra", E, 1, F)
	c._deal_damage(hydra, hydra.hp, "effect")
	check(c.unit_at(E, F, 1) != null and c.unit_at(E, F, 1).id == "hydra_head" and c.unit_at(E, F, 0).id == "hydra_head", "hydra: two heads grow back")

	c = fresh()
	c.debug_place("echo_of_circe", E, 1, B)
	var spawn = c.debug_place("void_spawn", E, 0, F)
	var thor = c.debug_place("thor", P, 0, F)
	c.debug_place("ark_sentinel", P, 1, F)
	c._declare_intents()
	check(c.transformed_uid == thor.uid, "circe: targets the highest-cost unit")
	c.end_plan()
	check(spawn.alive and spawn.hp == 3, "circe: the Swine doesn't attack")

	c = Combat.new()
	c.setup(Data.battle("tangled_ruins"), [], [], 1)
	var archer = c.debug_place("echo_archer", P, 1, B)
	check(c._pick_target(archer, 1) != c.unit_at(E, B, 1), "enemy ruins: ranged units can't hit the Weaver in Ruins")


func test_pierce() -> void:
	var c = fresh()
	var ein = c.debug_place("einherjar", P, 0, F)
	var back = c.debug_place("ark_sentinel", P, 0, B)
	c.debug_place("void_charger", E, 0, F)
	c.end_plan()
	check(not ein.alive, "pierce: einherjar dies")
	check(back.hp == 2, "pierce: 2 excess damage reaches the back unit")
	check(back.atk == 4, "pierce: einherjar's on-death buffs its lane")
	check(c.core_hp == 50, "pierce: Core untouched")


func test_valkyrie_reinforce() -> void:
	var c = fresh()
	c.debug_place("einherjar", P, 0, F)
	var valk = c.debug_place("valkyrie", P, 0, B)
	var charger = c.debug_place("void_charger", E, 0, F)
	c.end_plan()
	check(valk.row == F, "reinforce: valkyrie steps forward")
	check(valk.atk == 6, "reinforce: valkyrie gains +2 and the fallen ATK")
	check(valk.hp == 2, "reinforce: pierce still hits valkyrie")
	check(not charger.alive, "reinforce: valkyrie kills the charger")
	check(c.result == "win", "reinforce: fight is won")


func test_revive() -> void:
	var c = fresh()
	var mummy = c.debug_place("mummy_guardian", P, 0, F)
	mummy.hp = 1
	c.debug_place("hollowed_zealot", E, 0, F)
	c.end_plan()
	check(mummy.alive and mummy.hp == 1 and mummy.revive_used, "revive: mummy returns with 1 HP")

	c = fresh(50, false, ["ankh_of_eternity"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	var ein = c.debug_place("einherjar", P, 0, F)
	var behind = c.debug_place("echo_archer", P, 0, B)
	var maiden = c.debug_place("shieldmaiden", P, 2, F)
	var left = c.debug_place("ark_sentinel", P, 1, F)
	var raven = c.debug_place("raven_of_odin", P, 3, B)
	var swarm = c.debug_place("scarab_swarm", P, 1, B)
	c.deck = [c._new_card("ark_sentinel")]
	c.hand = []
	c._deal_damage(ein, 10, "effect")
	check(ein.alive and ein.hp == 1, "revive on-death: einherjar revives")
	check(behind.atk == 4 and ein.atk == 3, "revive on-death: einherjar buffs its lane but not itself")
	c._deal_damage(maiden, 10, "effect")
	check(maiden.alive and left.shield == 3, "revive on-death: shieldmaiden shields her neighbor")
	c._deal_damage(raven, 10, "effect")
	check(raven.alive and c.hand.size() == 1, "revive on-death: raven draws a card")
	c._deal_damage(swarm, 10, "effect")
	var scarab = c.unit_at(P, F, 1)
	check(swarm.alive and swarm.row == B and scarab == left, "revive on-death: swarm keeps its slot")
	c._deal_damage(left, 10, "effect")
	c._deal_damage(left, 10, "effect")
	c._deal_damage(swarm, 10, "effect")
	scarab = c.unit_at(P, B, 1)
	check(not swarm.alive and scarab != null and scarab.id == "scarab", "revive on-death: a dead swarm leaves a Scarab in its slot")

	c = fresh(50, false, ["ankh_of_eternity"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	swarm = c.debug_place("scarab_swarm", P, 2, F)
	c._deal_damage(swarm, 10, "effect")
	scarab = c.unit_at(P, B, 2)
	check(swarm.alive and swarm.row == F and scarab != null and scarab.id == "scarab", "revive on-death: reviving swarm summons its Scarab behind")

	c = fresh(50, false, ["ankh_of_eternity", "mead_of_the_einherjar"])
	var bulwark = c.debug_place("hollowed_bulwark", E, 0, F)
	var sentinel = c.debug_place("ark_sentinel", P, 0, F)
	var berserker = c.debug_place("berserker", P, 3, F)
	c.debug_place("odin", P, 2, B)
	c._deal_damage(sentinel, 10, "effect")
	check(sentinel.alive, "revive watchers: sentinel revives")
	check(berserker.atk == 5, "revive watchers: berserker (+1) and Mead (+1) trigger on revive")
	check(sentinel.atk == 2, "revive watchers: Mead skips the reviving unit")
	check(bulwark.hp == 6, "revive watchers: Odin avenges a reviving ally")
	c._deal_damage(berserker, 10, "effect")
	check(berserker.alive and berserker.atk == 5, "revive watchers: a reviving berserker doesn't feed itself")


func test_achilles() -> void:
	var c = fresh()
	var ach = c.debug_place("achilles", P, 0, F)
	c.debug_place("hollowed_zealot", E, 0, F)
	c.end_plan()
	check(ach.hp == 5, "achilles: immune to melee")
	check(c.result == "win", "achilles: kills the zealot")


func test_timeout_threat() -> void:
	var c = fresh()
	c.debug_place("ark_sentinel", P, 0, F)
	c.debug_place("hollowed_bulwark", E, 3, F)
	for i in 3:
		c.end_plan()
	check(c.result == "timeout", "timeout: fight times out after round 3")
	check(c.core_hp == 46, "timeout: 3 lane hits + 1 Threat")


func test_herald_round() -> void:
	var c = fresh(30, true)
	c.debug_place("void_herald", E, 1, F)
	c._declare_intents()
	c.end_plan()
	check(c.core_hp == 15, "herald: 10 attack + 5 Void Tide")
	check(c.units(E).size() == 2, "herald: summons a Void Spawn")
	check(c.phase == "plan" and c.round_num == 2, "herald: no round limit")


func test_hel() -> void:
	var c = fresh(30, true)
	var hel = c.debug_place("hel", E, 1, B)
	hel.hp = 30
	c.debug_place("ark_sentinel", P, 0, F)
	var archer = c.debug_place("echo_archer", P, 3, B)
	c._declare_intents()
	c.end_plan()
	check(not archer.alive, "hel: harvest kills the lowest-HP unit")
	check(hel.hp == 28, "hel: takes 4 and the Toll heals 2")
	check(c.core_hp == 28, "hel: Toll of the Dead deals 2 to the Core")
	var d1 = c.unit_at(E, F, 1)
	var d2 = c.unit_at(E, F, 2)
	check(d1 != null and d1.id == "draugr" and d2 != null and d2.id == "draugr", "hel: raises Draugr in empty front slots of lanes 2-3")
	check(c.unit_at(E, F, 0) == null and c.unit_at(E, F, 3) == null, "hel: no Draugr in lanes 1 and 4")
	check(hel.atk == 6, "hel: gains +1 ATK each round")

	var mummy = c.debug_place("mummy_guardian", P, 2, F)
	c._deal_damage(mummy, 10, "effect")
	check(mummy.alive and c.core_hp == 28 and hel.hp == 28, "hel: a reviving unit doesn't pay the Toll")

	c._deal_damage(hel, 99, "effect")
	check(c.units(E).is_empty() and c.result == "win", "hel: her Draugr crumble when she falls")


func test_apep() -> void:
	var c = fresh(30, true)
	var apep = c.debug_place("apep", E, 0, B)
	var sentinel = c.debug_place("ark_sentinel", P, 1, F)
	sentinel.shield = 5
	var mummy = c.debug_place("mummy_guardian", P, 1, B)
	mummy.hp = 3
	var archer = c.debug_place("echo_archer", P, 3, F)
	archer.shield = 3
	c._declare_intents()
	check(c.intents[apep.uid]["lanes"] == [1], "apep: constricts the lane with the most units")
	c.end_plan()
	check(not sentinel.alive, "apep: constrict goes through Shield")
	check(not mummy.alive and c.unit_at(P, B, 1) == null, "apep: units it kills can't Revive")
	check(archer.alive and archer.shield == 0, "apep: Devour Light strips Shield at end of round")
	check(apep.hp == 38, "apep: player units hit it from any lane")
	var guarded = c.debug_place("ark_sentinel", P, 2, F)
	guarded.shield = 5
	c._deal_damage(guarded, 2, "melee")
	check(guarded.hp == 2 and guarded.shield == 5, "apep: Shield blocks nothing while Apep lives")
	c._remove(guarded)
	var brood = c.unit_at(E, F, 1)
	check(brood != null and brood.id == "serpent_brood", "apep: a Serpent Brood hatches")
	check(c.core_hp == 27, "apep: Void Tide deals 3")
	check(c.units(E).size() == 2, "apep: only one Brood per round")

	apep.hp = 20
	c.debug_place("ark_sentinel", P, 0, F)
	c._declare_intents()
	check(c.intents[apep.uid]["lanes"].size() == 2, "apep: constricts two lanes at half HP")
	c._deal_damage(apep, 99, "effect")
	check(c.units(E).is_empty() and c.result == "win", "apep: its Brood die with it")

	var seen := {}
	for s in 40:
		var run = Run.new()
		run.setup(s + 1, "myrmidon")
		seen[run.boss_id] = true
		check(run._pick_battle("boss", Run.FLOORS - 1) == run.boss_id, "boss: the map's boss is the one fought")
	check(seen.size() == 3, "boss: runs pick all three bosses")


func test_charger_charges() -> void:
	var c = fresh()
	c.debug_place("ark_sentinel", P, 0, F).hp = 50
	c.debug_place("ark_sentinel", P, 1, F).hp = 50
	var charger = c.debug_place("void_charger", E, 0, F)
	charger.hp = 50
	c._declare_intents()
	c.end_plan()
	check(c.intents[charger.uid]["type"] == "charge", "charger: charges in round 2")
	check(c.intents[charger.uid]["lane"] == 2, "charger: picks the emptiest lane")
	c.end_plan()
	check(charger.lane == 2, "charger: moved to lane 3")


func test_spells() -> void:
	var c = fresh()
	var a = c.debug_place("void_spawn", E, 0, F)
	var b = c.debug_place("hollowed_zealot", E, 1, F)
	c.debug_place("void_spawn", E, 3, F)
	c.hand = [c._new_card("rebuke"), c._new_card("transposition")]
	c.faith = 3
	check(c.play_spell(0, [[E, F, 0]], 1) == "", "rebuke: legal")
	check(a.hp == 0 or not a.alive, "rebuke: collision damages the pushed unit")
	check(b.hp == 2, "rebuke: collision damages the other unit")
	var d = c.unit_at(E, F, 3)
	check(c.play_spell(0, [[E, F, 1], [E, F, 3]]) == "", "transposition: legal")
	check(b.lane == 3 and d.lane == 1, "transposition: units swapped")

	var h = fresh(30, true)
	var herald = h.debug_place("void_herald", E, 1, F)
	var spawn = h.debug_place("void_spawn", E, 0, F)
	h.hand = [h._new_card("rebuke"), h._new_card("transposition")]
	h.faith = 3
	check(not h.valid_targets(0).has([E, F, 1]), "immovable: boss is not a rebuke target")
	check(h.play_spell(0, [[E, F, 1]], 1) != "", "immovable: rebuke on the boss is rejected")
	check(h.play_spell(0, [[E, F, 0]], 1) == "", "immovable: spawn can be pushed into the boss")
	check(herald.hp == herald.max_hp and herald.lane == 1, "immovable: boss takes no collision damage")
	check(not spawn.alive, "immovable: pushed spawn takes the collision damage")
	check(h.valid_targets(0).is_empty(), "immovable: transposition cannot target the boss")


func _hand_index(c, id: String) -> int:
	for i in c.hand.size():
		if c.hand[i]["id"] == id:
			return i
	return -1


func test_raiders() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var raider = c.debug_place("raider", P, 0, F)
	check(c.move_unit(0, F, 1, F) == "", "raider: move")
	check(raider.atk == 3, "raider: +1 ATK when moved")
	check(c.moves_left == 0 and c.move_unit(1, F, 2, F) != "", "raider: only one move per round")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("ark_sentinel"), c._new_card("sandswarm"), c._new_card("raider")]
	c._plan_start = c._capture()
	check(c.play_unit(0, 0, F) == "", "fresh: deploy")
	check(c.move_unit(0, F, 0, B) == "" and c.move_unit(0, B, 2, F) == "" and c.moves_left == 1,
		"fresh: a unit deployed this round moves freely without using a move")
	check(c.unit_at(P, F, 2) != null and c.unit_at(P, F, 0) == null, "fresh: it ends where it was last put")
	check(c.play_spell(0, []) == "", "fresh: sandswarm")
	var scarab = c.unit_at(P, F, 1)
	check(scarab != null and c.move_unit(1, F, 1, B) == "" and c.moves_left == 1, "fresh: tokens summoned this round move freely too")
	check(c.play_unit(0, 3, B) == "", "fresh: deploy raider")
	var fresh_raider = c.unit_at(P, B, 3)
	check(c.move_unit(3, B, 1, F) == "" and fresh_raider.atk == fresh_raider.def["atk"], "fresh: repositioning doesn't trigger Raider")
	c.end_plan()
	if c.result == "":
		check(not c.is_fresh(c.unit_at(P, F, 2)), "fresh: locked in after planning")
		check(c.move_unit(2, F, 2, B) == "" and c.moves_left == 0, "fresh: the next round, moving uses a move")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var z = c.debug_place("hollowed_zealot", E, 1, F)
	c.debug_place("ulfhednar", P, 0, F)
	check(c.move_unit(0, F, 1, F) == "", "ulfhednar: move")
	check(z.hp == 2, "ulfhednar: deals its ATK to the enemy front unit in its new lane")

	c = fresh()
	var front = c.debug_place("void_spawn", E, 2, F)
	var back = c.debug_place("void_wisp", E, 2, B)
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("loki")]
	c.faith = 3
	check(c.play_unit(0, 0, B) == "", "loki: deploy")
	check(c.moves_left == 2, "loki: extra move on the round he's deployed")
	c.debug_place("ark_sentinel", P, 1, F)
	check(c.move_unit(1, F, 2, F) == "", "loki: move")
	check(front.hp == 2 and back.hp == 1, "loki: 1 damage to each enemy in the new lane")
	c.end_plan()
	if c.result == "":
		check(c.moves_left == 2, "loki: 2 moves at the start of each round")

	c = fresh(50, false, ["dragon_prow"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	var s = c.debug_place("ark_sentinel", P, 0, F)
	c.hand = [c._new_card("longship")]
	c.faith = 3
	c._plan_start = c._capture()
	check(c.play_spell(0, []) == "", "longship: cast")
	check(c.moves_left == 3, "longship: 2 extra moves")
	check(c.move_unit(0, F, 1, F) == "", "longship: move")
	check(s.shield == 2, "longship: moved unit gains Shield 2")
	check(c.effective_atk(s) == 4, "dragon prow: moved unit has +2 ATK")
	check(c.restart_plan() == "", "longship: restart")
	s = c.unit_at(P, F, 0)
	check(c.moves_left == 1 and not c.longship_active and s.shield == 0 and c.effective_atk(s) == 2, "longship: restart undoes moves and buffs")


func test_oracle() -> void:
	var c = fresh()
	var z = c.debug_place("hollowed_zealot", E, 0, F)
	c.debug_place("pythia", P, 0, B)
	var ally = c.debug_place("ark_sentinel", P, 1, F)
	c.hand = [c._new_card("divine_favor"), c._new_card("olympian_ichor")]
	c.faith = 1
	check(c.play_spell(0, [[P, F, 1]]) == "", "divine favor: cast")
	check(c.effective_atk(ally) == 4 and ally.atk == 2, "divine favor: +2 ATK this round only")
	check(z.hp == 4, "pythia: 1 damage when a spell is cast")
	ally.hp = 1
	check(c.play_spell(0, [[P, F, 1]]) == "", "ichor: cast")
	check(ally.hp == 4 and ally.atk == 3, "ichor: heals 4 (up to max) and +1 ATK")
	check(z.hp == 3, "pythia: triggers on every spell")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var s = c.debug_place("ark_sentinel", P, 0, F)
	c.hand = [c._new_card("divine_favor")]
	check(c.play_spell(0, [[P, F, 0]]) == "", "divine favor: cast")
	c.end_plan()
	check(c.round_num == 2 and c.effective_atk(s) == 2, "divine favor: expires at the next round")

	c = fresh(50, false, ["oracles_tripod"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	var hermes = c.debug_place("hermes", P, 0, B)
	c.hand = [c._new_card("warding"), c._new_card("warding")]
	c.faith = 1
	check(c.free_spell_active() and c.card_cost(c.hand[0]) == 0, "hermes: first spell is free")
	check(c.play_spell(0, [[P, B, 0]]) == "", "hermes: free warding")
	check(c.faith == 1 and hermes.shield == 5, "hermes: no Faith spent, Shield 4 + 1")
	check(not c.free_spell_active() and c.card_cost(c.hand[0]) == 1, "hermes: second spell costs full")
	check(c.play_spell(0, [[P, B, 0]]) == "", "tripod: second warding")
	check(c.faith == 1, "tripod: +1 Faith on the second spell")


func test_swarm() -> void:
	var c = fresh()
	var bulwark = c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("ark_sentinel", P, 1, F)
	c.hand = [c._new_card("sandswarm"), c._new_card("plague_of_locusts")]
	c.faith = 3
	check(c.play_spell(0, []) == "", "sandswarm: cast")
	check(c.units(P).size() == 4, "sandswarm: Scarabs fill the 3 empty front slots")
	check(c.valid_targets(0).has([E, B, 3]), "plague: can target any enemy")
	check(c.play_spell(0, [[E, B, 3]]) == "", "plague: cast")
	check(bulwark.hp == 4, "plague: damage equals your unit count")

	c = fresh(40)
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("khepri", P, 0, B)
	var scarab = c.debug_place("scarab", P, 1, F)
	check(c.effective_atk(scarab) == 2, "khepri: Scarabs have +1 ATK")
	c.core_hp = 30
	c._deal_damage(scarab, 5, "effect")
	check(c.core_hp == 31, "khepri: a Scarab death heals the Core by 1")
	c.core_hp = 40
	c._deal_damage(c.debug_place("scarab", P, 2, F), 5, "effect")
	check(c.core_hp == 40, "khepri: Core healing is capped at max")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("scarab_queen", P, 1, F)
	c.end_plan()
	var summoned = c.unit_at(P, F, 0)
	check(summoned != null and summoned.id == "scarab", "scarab queen: summons into the nearest empty slot in her row")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0]], "terrain": []}, [], ["sacred_hive"], 1)
	var mine: Array = c.units(P)
	check(mine.size() == 2 and mine.all(func(u): return u.id == "scarab" and u.row == B), "sacred hive: 2 Scarabs in the back row")


func test_divine() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var s = c.debug_place("ark_sentinel", P, 0, F)
	var scarab = c._spawn("scarab", P, 1, F)
	c.deck = [c._new_card("ark_sentinel"), c._new_card("echo_archer")]
	c.hand = [c._new_card("divine_insight"), c._new_card("ambrosia"), c._new_card("aegis_of_olympus"), c._new_card("thread_of_fate")]
	c.faith = 1
	check(c.play_spell(_hand_index(c, "divine_insight"), []) == "", "insight: cast")
	check(c.hand.size() == 5 and c.deck.is_empty(), "insight: draws 2")
	check(c.play_spell(_hand_index(c, "ambrosia"), []) == "", "ambrosia: cast")
	check(c.faith == 3 and c.discard.any(func(card): return card["id"] == "ambrosia"), "ambrosia: +2 Faith, not exhausted")
	check(c.play_spell(_hand_index(c, "aegis_of_olympus"), []) == "", "aegis: cast")
	check(s.shield == 3 and scarab.shield == 3, "aegis: all allies gain Shield 3")
	var thread := _hand_index(c, "thread_of_fate")
	check(not c.valid_targets(thread).has([P, F, 1]), "thread: tokens can't be returned")
	check(c.play_spell(thread, [[P, F, 0]]) == "", "thread: cast")
	check(c.unit_at(P, F, 0) == null and c.hand.any(func(card): return card == s.card), "thread: unit returns to hand")

	var run = Run.new()
	run.setup(7, "myrmidon")
	check(run._card_pool("Divine", [], []).size() == 4, "divine: 4 Divine cards")
	for rarity in ["", "Common", "Uncommon", "Rare"]:
		check(run._card_pool(rarity, [], []).all(func(id): return Data.CARDS[id]["rarity"] != "Divine"), "divine: never in the %s pool" % rarity)
	var rng := RandomNumberGenerator.new()
	for i in 300:
		for id in run._card_choices(Run.ELITE_ODDS, rng):
			check(Data.CARDS[id]["rarity"] != "Divine", "divine: never a card reward")
	run.start_event("hall_of_the_forgotten_god")
	run.gold = 100
	check(run.choose_option(0) == "", "hall: offer life")
	check(run.shrine["pending"] == "choose" and run.shrine["cards"].size() == 2, "hall: choose 1 of 2")
	check(run.shrine["cards"].all(func(id): return Data.CARDS[id]["rarity"] == "Divine"), "hall: offers Divine cards")
	var pick: String = run.shrine["cards"][0]
	run.shrine_take_card(0)
	check(run.deck.has(pick), "hall: Divine card joins the deck")


func test_terrain_cards() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var s = c.debug_place("ark_sentinel", P, 1, F)
	c.terrain[c._key(P, F, 2)] = "ley_line"
	c.terrain[c._key(P, B, 3)] = "ley_line"
	c.hand = [c._new_card("channel_ley_line"), c._new_card("raise_ruins")]
	c._plan_start = c._capture()
	check(c.valid_targets(0) == [[P, F, 0], [P, F, 1], [P, F, 3]], "ley line: front slots without terrain, occupied or not")
	check(c.play_spell(0, [[P, B, 0]]) != "", "ley line: rejected in the back row")
	check(c.play_spell(0, [[P, F, 2]]) != "", "ley line: rejected on a slot with terrain")
	check(c.play_spell(0, [[P, F, 1]]) == "", "ley line: cast under a deployed unit")
	check(c.terrain_at(P, F, 1) == "ley_line" and c.effective_atk(s) == 4, "ley line: the unit there gains +2 ATK")
	check(c.faith == 1, "ley line: costs 2")
	check(c.exhausted.size() == 1 and c.discard.is_empty(), "ley line: exhausts")
	var ruins := _hand_index(c, "raise_ruins")
	check(c.valid_targets(ruins) == [[P, B, 0], [P, B, 1], [P, B, 2]], "ruins: back slots without terrain")
	check(c.play_spell(ruins, [[P, F, 3]]) != "", "ruins: rejected in the front row")
	check(c.play_spell(ruins, [[P, B, 3]]) != "", "ruins: never replaces other terrain")
	check(c.play_spell(ruins, [[P, B, 2]]) == "", "ruins: cast on a back slot")
	check(c.terrain_at(P, B, 2) == "ruins" and c.exhausted.size() == 2, "ruins: created and exhausted")
	check(c.restart_plan() == "", "terrain: restart planning")
	check(c.terrain_at(P, F, 1) == "" and c.terrain_at(P, B, 2) == "" and c.hand.size() == 2, "terrain: restart undoes terrain changes")

	c = fresh()
	c.hand = [c._new_card("channel_ley_line")]
	c.play_spell(0, [[P, F, 0]])
	s = c.debug_place("ark_sentinel", P, 0, F)
	check(c.effective_atk(s) == 4, "ley line: a unit deployed there later gains +2 ATK")

	c = fresh()
	var archer = c.debug_place("hollow_archer", E, 0, B)
	var hidden = c.debug_place("echo_archer", P, 0, B)
	c.hand = [c._new_card("raise_ruins")]
	check(c.play_spell(0, [[P, B, 0]]) == "", "ruins: cast under a deployed unit")
	c.end_plan()
	check(hidden.hp == 2 and c.core_hp == 48, "ruins: ranged enemy can't target the covered unit and hits the Core")
	check(archer.hp == 1, "ruins: the covered unit still attacks")


# ---------------------------------------------------------------- fuzzing

func test_patron_relics() -> void:
	var c = fresh(50, false, ["mead_of_the_einherjar"])
	var weak = c.debug_place("echo_archer", P, 0, F)
	var other = c.debug_place("ark_sentinel", P, 2, F)
	var e = c.debug_place("hollowed_zealot", E, 0, F)
	weak.hp = 1
	c.end_plan()
	check(not weak.alive, "mead: first ally died")
	check(other.atk == 3, "mead: other ally gains +1 ATK")
	check(c.mead_used, "mead: used once")

	c = fresh(50, false, ["spartan_standard"])
	var left = c.debug_place("ark_sentinel", P, 0, F)
	var middle = c.debug_place("ark_sentinel", P, 1, F)
	var right = c.debug_place("ark_sentinel", P, 2, F)
	c.end_plan()
	check(middle.shield == 1, "spartan: unit flanked on both sides gains Shield 1")
	check(left.shield == 0 and right.shield == 0, "spartan: units with one neighbor gain nothing")

	c = fresh(50, false, ["scarab_amulet"])
	var hurt = c.debug_place("ark_sentinel", P, 0, F)
	hurt.hp = 2
	c.end_plan()
	check(hurt.hp == 3, "scarab: ally healed by 1 at end of round")

	for patron in Data.PATRONS:
		var run = Run.new()
		run.setup(1, patron["card"])
		check(run.relics.is_empty(), "patron %s starts without a relic" % patron["card"])
		check(run.power == patron["powers"][0], "patron %s defaults to its first power" % patron["card"])
		for id in patron["powers"]:
			check(Data.GOD_POWERS[id]["pantheon"] == Data.CARDS[patron["card"]]["faction"], "power %s belongs to the patron's pantheon" % id)
	for id in ["mead_of_the_einherjar", "spartan_standard", "scarab_amulet"]:
		check(Data.RELICS[id].get("pool", true), "former patron relic %s is in the relic pool" % id)


func _with_power(c, id: String, nodes: Array = []):
	c.power = {"id": id, "nodes": nodes}
	c.power_uses = 1
	return c


func test_god_powers() -> void:
	for id in Data.GOD_POWERS:
		var power: Dictionary = Data.GOD_POWERS[id]
		check(ResourceLoader.exists("res://art/glyphs/%s.svg" % id), "power %s has a glyph" % id)
		check(power["target"] in ["ally", "enemy", "enemy_front", "empty_ally_slot"], "power %s target" % id)
		var branches := {}
		for n in power["nodes"]:
			var node: Dictionary = power["nodes"][n]
			branches[node["branch"]] = branches.get(node["branch"], 0) + 1
			if node["tier"] > 1:
				check(power["nodes"].values().any(func(o): return o["branch"] == node["branch"] and o["tier"] == node["tier"] - 1), "power %s node %s has a lower tier" % [id, n])
		check(branches.get("Pact", 0) == 1 and branches.size() == 3, "power %s: two branches and a Pact" % id)

	# Tyr's Oath
	var c = _with_power(fresh(), "tyrs_oath")
	c.debug_place("hollowed_bulwark", E, 3, B)
	var victim = c.debug_place("ark_sentinel", P, 0, F)
	var other = c.debug_place("ark_sentinel", P, 1, F)
	check(c.use_power([[P, F, 0]]) == "", "tyr: used")
	check(not victim.alive and c.effective_atk(other) == 3 and other.atk == 2, "tyr: sacrifice, others +1 ATK this round")
	check(c.use_power([[P, F, 1]]) != "", "tyr: only once per fight")
	c = _with_power(fresh(), "tyrs_oath", ["blood_1", "blood_2", "oath_1", "oath_2", "pact"])
	c.core_hp = 40
	c.debug_place("hollowed_bulwark", E, 3, B)
	victim = c.debug_place("ark_sentinel", P, 0, F)
	other = c.debug_place("ark_sentinel", P, 1, F)
	var faith_before: int = c.faith
	c.use_power([[P, F, 0]])
	check(other.atk == 4, "tyr full: +2 ATK for the fight")
	check(c.core_hp == 44, "tyr full: Core healed by the unit's HP")
	check(c.hand.has(victim.card) and not c.discard.has(victim.card), "tyr full: card returns to hand")
	check(c.faith == faith_before + 1, "tyr full: +1 Faith")

	# Thor's Thunderclap
	c = _with_power(fresh(), "thors_thunderclap")
	var z = c.debug_place("hollowed_zealot", E, 1, F)
	c.use_power([[E, F, 1]])
	check(z.hp == 2, "thor: 3 damage")
	c = _with_power(fresh(), "thors_thunderclap", ["storm_1", "storm_2", "hammer_1", "hammer_2", "pact"])
	var front = c.debug_place("void_spawn", E, 1, F)
	var back = c.debug_place("hollow_archer", E, 1, B)
	var left = c.debug_place("hollowed_zealot", E, 0, F)
	var ally = c.debug_place("ark_sentinel", P, 1, F)
	c.use_power([[E, F, 1]])
	check(not front.alive and not back.alive, "thor full: hits both units in the lane")
	check(left.hp == 3, "thor full: shockwave hits the neighbour for 2")
	check(ally.shield == 2, "thor full: Storm Shield")
	check(c.power_uses == 1, "thor full: a kill refunds the power once")
	c.use_power([[E, F, 0]])
	check(c.power_uses == 0, "thor full: refund only once")
	c = _with_power(fresh(), "thors_thunderclap", ["storm_1"])
	c.falls = 5
	z = c.debug_place("hollowed_zealot", E, 1, F)
	z.max_hp = 20
	z.hp = 20
	c.use_power([[E, F, 1]])
	check(z.hp == 14, "thor storm: +1 per fall, capped at +3")

	# Zeus's Lightning Bolt
	c = _with_power(fresh(), "zeus_lightning_bolt")
	var a1 = c.debug_place("hollowed_zealot", E, 0, F)
	var a2 = c.debug_place("hollowed_zealot", E, 2, F)
	c.use_power([[E, F, 0]])
	check(a1.hp == 3 and a2.hp == 4, "zeus: 2 to the target, chain 1")
	c = _with_power(fresh(), "zeus_lightning_bolt", ["chain_1", "chain_2", "sky_1", "sky_2", "pact"])
	var targets: Array = []
	for lane in 4:
		targets.append(c.debug_place("void_spawn", E, lane, F))
	var archer = c.debug_place("echo_archer", P, 0, B)
	faith_before = c.faith
	c.use_power([[E, F, 0]])
	check(not targets[0].alive, "zeus full: 4 damage kills")
	check(targets.slice(1).all(func(t): return t.hp == 1), "zeus full: chains to three more for 2")
	check(c.faith == faith_before + 1, "zeus full: Faith per kill")
	check(c.effective_atk(archer) == 3, "zeus full: Ranged units +1 ATK")

	# Poseidon's Tide
	c = _with_power(fresh(), "poseidons_tide")
	var s = c.debug_place("void_spawn", E, 1, F)
	check(c.use_power([[E, F, 1]], 1) == "" and s.lane == 2 and s.hp == 3, "poseidon: pushed into an empty lane, no damage")
	c = _with_power(fresh(), "poseidons_tide")
	s = c.debug_place("void_spawn", E, 0, F)
	c.use_power([[E, F, 0]], -1)
	check(s.hp == 1, "poseidon: edge impact 2")
	c = _with_power(fresh(), "poseidons_tide", ["wave_1", "wave_2", "undertow_1", "undertow_2"])
	z = c.debug_place("hollowed_zealot", E, 1, F)
	c.debug_place("ark_sentinel", P, 2, F)
	var moves: int = c.moves_left
	c.use_power([[E, F, 1]], 1)
	check(not z.alive, "poseidon full: riptide 4 + ambush 2 kill a 5 HP zealot")
	check(c.moves_left == moves + 1, "poseidon full: +1 move")

	# Osiris's Return
	c = _with_power(fresh(), "osiris_return")
	check(not c.can_use_power(), "osiris: needs a fallen ally")
	var dead = c.debug_place("ark_sentinel", P, 0, F)
	c.debug_place("void_spawn", E, 3, F)
	dead.hp = 0
	c._kill(dead)
	check(c.can_use_power(), "osiris: usable once an ally died")
	c.use_power([[P, B, 2]])
	var back_unit = c.unit_at(P, B, 2)
	check(back_unit != null and back_unit.id == "ark_sentinel" and back_unit.hp == 1, "osiris: returns with 1 HP")
	c = _with_power(fresh(), "osiris_return", ["life_1", "life_2", "wings_1", "wings_2", "pact"])
	c.core_hp = 40
	c.debug_place("hollowed_bulwark", E, 3, B)
	dead = c.debug_place("ark_sentinel", P, 0, F)
	dead.hp = 0
	c._kill(dead)
	c.use_power([[P, F, 1]])
	back_unit = c.unit_at(P, F, 1)
	check(back_unit.hp == 4 and back_unit.shield == 3 and back_unit.atk == 4, "osiris full: full HP, Shield 3, +2 ATK")
	check(back_unit.has_kw("revive") and c.core_hp == 43, "osiris full: Revive and Core healed")
	back_unit.hp = 0
	c._kill(back_unit)
	check(back_unit.alive and back_unit.hp >= 1, "osiris full: the returned unit revives")

	# Sekhmet's Plague
	c = _with_power(fresh(), "sekhmets_plague")
	var p1 = c.debug_place("hollowed_bulwark", E, 1, F)
	var p2 = c.debug_place("hollowed_bulwark", E, 1, B)
	var p3 = c.debug_place("hollowed_bulwark", E, 2, F)
	c.use_power([[E, F, 1]])
	check(p1.poisoned and p2.poisoned and not p3.poisoned, "sekhmet: poisons the lane only")
	c.end_plan()
	check(p1.hp == 7 and p3.hp == 8, "sekhmet: poison ticks 1 on enemies")
	c = _with_power(fresh(), "sekhmets_plague", ["plague_1", "plague_2", "hunt_1", "hunt_2", "pact"])
	c.core_hp = 40
	p1 = c.debug_place("hollowed_bulwark", E, 1, F)
	p3 = c.debug_place("hollowed_bulwark", E, 2, F)
	var weak = c.debug_place("void_spawn", E, 0, F)
	weak.hp = 1
	var hurt = c.debug_place("ark_sentinel", P, 3, B)
	hurt.hp = 2
	c.use_power([[E, F, 1]])
	check(p3.poisoned and not weak.alive, "sekhmet full: adjacent lanes, Lion's Bite kills a 1 HP enemy")
	check(c.core_hp == 42, "sekhmet full: Feast heals 2 on a poisoned death")
	check(hurt.hp == 3, "sekhmet full: Sun's Mercy heals allies")
	check(p1.hp == 7, "sekhmet full: bite 1")
	c.end_plan()
	check(p1.hp <= 5, "sekhmet full: Virulence ticks 2")

	# Undo round restores the power.
	c = _with_power(fresh(), "thors_thunderclap")
	c.debug_place("hollowed_zealot", E, 1, F)
	c._plan_start = c._capture()
	c.use_power([[E, F, 1]])
	check(c.power_uses == 0 and c.can_restart_plan(), "power: counts as a plan action")
	c.restart_plan()
	check(c.power_uses == 1 and c.unit_at(E, F, 1).hp == 5, "power: Undo round restores it")


func test_power_upgrades() -> void:
	var run = Run.new()
	run.setup(1, "myrmidon", "poseidons_tide")
	check(run.power == "poseidons_tide" and run.main_pantheon() == "greek", "upgrades: chosen power")
	check(run.pending_upgrades() == 0, "upgrades: none at start")
	run.add_card("faith_surge")
	run.add_card("hoplite")
	check(run.devotion == 1 and run.foreign == 0, "upgrades: neutral cards don't count")
	run.add_card("hoplite")
	check(run.pending_upgrades() == 1, "upgrades: first threshold reached")
	var options: Array = run.upgrade_options()
	options.sort()
	check(options == ["undertow_1", "wave_1"], "upgrades: only tier 1 at first (%s)" % [options])
	check(run.choose_upgrade("wave_2") != "", "upgrades: tier 2 locked")
	check(run.choose_upgrade("wave_1") == "" and run.pending_upgrades() == 0, "upgrades: picked")
	check(run.choose_upgrade("undertow_1") != "", "upgrades: nothing pending")
	for n in 3:
		run.add_card("einherjar")
	run.add_card("hoplite")
	run.add_card("hoplite")
	check(run.foreign == 3 and run.devotion == 4, "upgrades: counts by pantheon")
	options = run.upgrade_options()
	options.sort()
	check(options == ["pact", "undertow_1", "wave_2"], "upgrades: tier 2 and Pact open (%s)" % [options])
	run.choose_upgrade("pact")
	check(run.power_state()["nodes"] == ["wave_1", "pact"], "upgrades: passed to fights")
	var before: int = run.devotion
	run.deck.append("hoplite")
	check(run.devotion == before, "upgrades: removing or appending outside add_card doesn't count")


func test_round_scaling() -> void:
	var c = Combat.new()
	c.setup({"core": 50, "enemies": [], "terrain": [], "enemy_bonus": {"atk": 1, "hp": 2, "rounds": 2}}, [], ["golden_fleece"], 1)
	check(c.max_rounds == 6, "round scaling: 3 base + 2 floor rounds + 1 Golden Fleece")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0], ["void_spawn", 1, 0], ["void_spawn", 2, 0]], "terrain": [],
		"enemy_bonus": {"atk": 2, "hp": 8, "rounds": 0}}, [], [], 7)
	var empowered: Array = c.units(E).filter(func(u): return u.empowered)
	check(empowered.size() == 1, "empower: exactly one enemy is Empowered")
	check(empowered.size() == 1 and empowered[0].atk == 4 and empowered[0].hp == 11, "empower: +2 ATK / +8 HP applied")
	for u in c.units(E):
		if not u.empowered:
			check(u.atk == 2 and u.hp == 3, "empower: other enemies unchanged")
	var run = Run.new()
	run.setup(1, "shieldmaiden")
	for id in run.nodes.size():
		run.current = id
		var expected: int = run.nodes[id]["floor"] / Data.BALANCE["scaling_every_floors"] * Data.BALANCE["scaling_rounds"]
		if run.nodes[id]["type"] == "boss":
			check(run.enemy_bonus() == {"atk": 0, "hp": 0, "rounds": 0}, "boss fight has no floor scaling")
		else:
			check(run.enemy_bonus()["rounds"] == expected, "round scaling: floor %d bonus" % run.nodes[id]["floor"])


func test_tooltip_wrap() -> void:
	var texts: Array = []
	for table in [Data.CARDS, Data.RELICS, Data.ENEMIES]:
		for id in table:
			texts.append("%s\n%s" % [table[id]["name"], table[id]["text"]])
	for text in texts:
		var wrapped: String = CardWidget.wrap_text(text)
		for line in wrapped.split("\n"):
			check(line.length() <= 60, "wrap: line too long: %s" % line)
		check(wrapped.replace("\n", " ").split(" ", false) == text.replace("\n", " ").split(" ", false), "wrap: words preserved")


func _state_text(c) -> String:
	return str(c.snapshot()) + str(c.deck) + str(c.discard) + str(c.exhausted) + str(c.moves_left) + str(c.spells_this_round) + str(c.rng.state)


## A restart must return the exact starting state, and replaying the same plays
## afterwards must give the same round as never restarting.
func test_restart_plan() -> void:
	var fresh_c = fresh()
	check(not fresh_c.can_restart_plan(), "restart: nothing to undo at start")
	check(fresh_c.restart_plan() != "", "restart: refused with nothing to undo")
	var power_ids: Array = Data.GOD_POWERS.keys()
	for plain in Data.BATTLES:
		for s in range(1, 6):
			var tag := "restart %s seed %d" % [plain["id"], s]
			var deck_ids := Data.deck_cards("sandbox")
			var battle: Dictionary = plain.duplicate()
			var pid: String = power_ids[s % power_ids.size()]
			battle["god_power"] = {"id": pid, "nodes": Data.GOD_POWERS[pid]["nodes"].keys() if s % 2 == 0 else []}
			var a = Combat.new()
			var b = Combat.new()
			a.setup(battle, deck_ids, [], s)
			b.setup(battle, deck_ids, [], s)
			var round_guard := 0
			while a.phase == "plan" and b.phase == "plan" and round_guard < 20:
				round_guard += 1
				var start := _state_text(b)
				var junk := RandomNumberGenerator.new()
				junk.seed = s * 131 + round_guard
				for n in 4:
					if b.phase == "plan" and not b.hand.is_empty():
						_random_play(b, junk.randi_range(0, b.hand.size() - 1), junk)
				if b.phase == "plan":
					_random_power(b, junk)
				if b.phase != "plan":
					break
				if b.can_restart_plan():
					b.restart_plan()
				check(_state_text(b) == start, "%s round %d: restart restores the plan start" % [tag, a.round_num])
				var ra := RandomNumberGenerator.new()
				var rb := RandomNumberGenerator.new()
				ra.seed = s * 977 + round_guard
				rb.seed = s * 977 + round_guard
				for n in 3:
					if a.phase == "plan" and not a.hand.is_empty():
						_random_play(a, ra.randi_range(0, a.hand.size() - 1), ra)
					if b.phase == "plan" and not b.hand.is_empty():
						_random_play(b, rb.randi_range(0, b.hand.size() - 1), rb)
				if a.phase == "plan" and b.phase == "plan" and ra.randf() < 0.3 and rb.randf() < 0.3:
					_random_power(a, ra)
					_random_power(b, rb)
				a.end_plan()
				b.end_plan()
				check(_state_text(a) == _state_text(b), "%s round %d: same result after restart" % [tag, a.round_num])


func fuzz_all_battles() -> void:
	var combat_relics: Array = []
	for id in Data.RELICS:
		if Data.RELICS[id]["combat"]:
			combat_relics.append(id)
	for battle in Data.BATTLES:
		for s in range(1, 21):
			_fuzz_one(battle, Data.deck_cards(battle["deck"]), battle["relics"], s)
		for s in range(21, 31):
			_fuzz_one(battle, Data.deck_cards("sandbox"), combat_relics, s)
		var n := 31
		for id in Data.GOD_POWERS:
			for full in [false, true]:
				var with_power: Dictionary = battle.duplicate()
				with_power["god_power"] = {"id": id, "nodes": Data.GOD_POWERS[id]["nodes"].keys() if full else []}
				_fuzz_one(with_power, Data.deck_cards("sandbox"), combat_relics if full else [], n)
				n += 1


func _fuzz_one(battle: Dictionary, deck_ids: Array, relics: Array, seed_value: int) -> void:
	var c = Combat.new()
	c.setup(battle, deck_ids, relics, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	_autoplay(c, rng, deck_ids.size(), "%s seed %d" % [battle["id"], seed_value])


func _autoplay(c, rng: RandomNumberGenerator, total_cards: int, tag: String) -> void:
	var guard := 0
	while c.phase == "plan" and guard < 40:
		guard += 1
		for attempt in 10:
			if c.hand.is_empty() or c.phase != "plan":
				break
			var i := rng.randi_range(0, c.hand.size() - 1)
			_random_play(c, i, rng)
			_check_invariants(c, total_cards, tag)
		while c.phase == "plan" and rng.randf() < 0.5:
			_random_move(c, rng)
			_check_invariants(c, total_cards, tag)
		if c.phase == "plan" and rng.randf() < 0.5:
			_random_power(c, rng)
			_check_invariants(c, total_cards, tag)
		if c.phase == "plan" and c.can_restart_plan() and rng.randf() < 0.1:
			c.restart_plan()
			_check_invariants(c, total_cards, tag)
		if c.phase == "plan":
			c.end_plan()
		_check_invariants(c, total_cards, tag)
	check(c.phase == "over", "%s: fight ended (round %d)" % [tag, c.round_num])
	check(c.result in ["win", "timeout", "defeat"], "%s: valid result '%s'" % [tag, c.result])


# ---------------------------------------------------------------- runs

func test_maps() -> void:
	for s in range(1, 5001):
		var run = Run.new()
		run.setup(s, "shieldmaiden")
		var tag := "map seed %d" % s
		check(run.floors.size() == Run.FLOORS, "%s: floor count" % tag)
		check(run.floors[Run.FLOORS - 1].size() == 1, "%s: single boss node" % tag)
		for type in Run.GUARANTEED:
			for range_floors in Run.GUARANTEED[type]:
				var found := false
				for f in range_floors:
					for id in run.floors[f]:
						if run.nodes[id]["type"] == type:
							found = true
				check(found, "%s: has a %s on floors %s" % [tag, type, range_floors])
		for node in run.nodes:
			var f: int = node["floor"]
			if f < Run.FLOORS - 1:
				check(not node["edges"].is_empty(), "%s: node %d has no exit" % [tag, node["id"]])
			for e in node["edges"]:
				check(run.nodes[e]["floor"] == f + 1, "%s: edge skips a floor" % tag)
				check(not (node["type"] in Run.SERVICES and run.nodes[e]["type"] == node["type"]),
						"%s: %s leads straight into another %s" % [tag, node["type"], node["type"]])
			if f > 0:
				var incoming := false
				for other in run.nodes:
					if other["edges"].has(node["id"]):
						incoming = true
				check(incoming, "%s: node %d is unreachable" % [tag, node["id"]])
			if f == 0:
				check(node["type"] == "fight", "%s: floor 1 is all fights" % tag)
			if f == Run.FLOORS - 2:
				check(node["type"] == "rest", "%s: pre-boss floor is rest" % tag)
			check(not (node["type"] == "elite" and f < Run.EARLY_FLOORS), "%s: elite too early" % tag)


func test_reward_rule() -> void:
	for s in range(1, 201):
		var run = Run.new()
		run.setup(s, "myrmidon")
		var picks: Array = run._card_choices(Run.NORMAL_ODDS, run.reward_rng)
		var factions: Array = picks.map(func(id): return Data.CARDS[id]["faction"])
		check(picks.size() == 3, "reward: three choices")
		check(factions.has("greek"), "reward: a card from the god power's pantheon (seed %d)" % s)
		check(picks[0] != picks[1] and picks[1] != picks[2] and picks[0] != picks[2], "reward: no duplicates")


func test_no_loss_when_units_die() -> void:
	for boss in [false, true]:
		var c = Combat.new()
		var enemy: String = "void_herald" if boss else "hollowed_zealot"
		c.setup({"core": 50, "enemies": [[enemy, 1, F]], "terrain": [], "boss": boss}, [], [], 1)
		var s = c.debug_place("ark_sentinel", P, 1, F)
		s.hp = 1
		c.end_plan()
		check(not s.alive, "no loss (boss %s): the only unit died" % boss)
		check(c.result == "" and c.phase == "plan", "no loss (boss %s): the fight goes on with no units" % boss)
		var guard := 0
		while c.phase != "over" and guard < 50:
			guard += 1
			c.end_plan()
		check(c.result == ("defeat" if boss else "timeout"), "no loss (boss %s): ends by %s" % [boss, c.result])


func test_curses() -> void:
	var c = fresh(50)
	c.hand = [c._new_card("void_taint"), c._new_card("void_rot"), c._new_card("warding")]
	c.deck = [c._new_card("ark_sentinel"), c._new_card("ark_sentinel"), c._new_card("ark_sentinel")]
	c.discard = []
	check(not c.can_afford(0) and not c.can_afford(1), "curse: can't be afforded")
	check(c.valid_targets(0).is_empty(), "curse: no targets")
	check(c.play_spell(0, []) != "" and c.play_unit(1, 0, F) != "", "curse: play is rejected")
	c._start_round()
	check(c.hand.filter(func(card): return c.card_def(card)["type"] == "curse").is_empty(), "curse: discarded at round start")
	check(c.discard.size() == 2, "curse: moved to the discard pile")
	check(c.core_hp == 48, "curse: Void Rot deals 2 to the Core")
	var d = fresh(50)
	d.core_hp = 1
	d.hand = [d._new_card("void_rot")]
	d._start_round()
	check(d.core_hp == 1 and d.result == "", "curse: Void Rot is never lethal")
	for id in Data.CARDS:
		if Data.CARDS[id]["type"] == "curse":
			var run = Run.new()
			run.setup(1, "myrmidon")
			for n in 50:
				check(not run._card_choices(Run.ELITE_ODDS, run.reward_rng).has(id), "curse: %s never offered as a reward" % id)


func test_status_cards() -> void:
	for pair in [["void_weaver", "void_web"], ["hollow_hexer", "hex"], ["ashen_wraith", "ashes"]]:
		var c = fresh(50)
		c.deck = []
		var e = c.debug_place(pair[0], E, 1, F)
		c._act(e)
		check(c.deck.size() == 1 and c.deck[0]["id"] == pair[1], "status: %s shuffles %s into the draw pile" % pair)
		check(c.core_hp < 50, "status: %s still attacks (hits the empty lane's Core)" % pair[0])

	var h = fresh(50)
	h.deck = [h._new_card("ark_sentinel"), h._new_card("hex")]
	h.hand = []
	h.discard = []
	h._start_round()
	check(h.hand.size() == 2 and h.faith == 2, "status: drawing Hex costs 1 Faith (faith %d)" % h.faith)
	check(not h.can_afford(h.hand.find(h.hand.filter(func(card): return card["id"] == "hex")[0])), "status: Hex is unplayable")
	h.deck = [h._new_card("ark_sentinel"), h._new_card("ark_sentinel")]
	h._start_round()
	check(h.hand.filter(func(card): return card["id"] == "hex").is_empty(), "status: Hex leaves the hand next round")
	check(h.exhausted.size() == 1 and h.discard.is_empty(), "status: Hex is exhausted, not discarded")

	var a = fresh(50)
	a.hand = [a._new_card("ashes")]
	a.deck = [a._new_card("ark_sentinel"), a._new_card("ark_sentinel")]
	a._start_round()
	check(a.core_hp == 49 and a.exhausted.size() == 1, "status: Ashes burns the Core for 1 as it exhausts")
	for id in ["void_web", "hex", "ashes"]:
		var run = Run.new()
		run.setup(1, "myrmidon")
		for n in 30:
			check(not run._card_choices(Run.ELITE_ODDS, run.reward_rng).has(id), "status: %s never offered as a reward" % id)


func test_event_data() -> void:
	var fx_keys := ["gold", "hp", "max_hp", "card", "curse", "relic", "remove", "remove_random", "choose", "goto"]
	for ev_id in Data.EVENTS:
		var ev: Dictionary = Data.EVENTS[ev_id]
		var stages: Array = [ev]
		check(ev.get("weight", Data.EVENT_WEIGHT) > 0, "event %s: weight" % ev_id)
		for s in ev.get("stages", {}):
			stages.append(ev["stages"][s])
		for stage in stages:
			check(stage.has("text") and not stage["options"].is_empty(), "event %s: stage has text and options" % ev_id)
			for option in stage["options"]:
				var outcomes: Array = option.get("outcomes", [option])
				for o in outcomes:
					if option.has("outcomes"):
						check(o.get("weight", 0) > 0, "event %s: outcome weight" % ev_id)
					var fx: Dictionary = o.get("fx", {})
					for k in fx:
						check(k in fx_keys, "event %s: unknown effect %s" % [ev_id, k])
					if fx.has("goto"):
						check(ev.get("stages", {}).has(fx["goto"]), "event %s: goto %s exists" % [ev_id, fx["goto"]])
					if fx.has("curse"):
						check(Data.CARDS.get(fx["curse"], {}).get("type", "") == "curse", "event %s: %s is a curse" % [ev_id, fx["curse"]])
					for key in ["card", "choose"]:
						if fx.has(key):
							check(fx[key] in ["any", "pantheon", "Divine"] or Run.RARITY_ONLY.has(fx[key]), "event %s: %s pool" % [ev_id, key])


## Plays every event many times with random choices and checks the run stays valid.
func fuzz_shrines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for ev_id in Data.EVENTS:
		for s in range(1, 81):
			var run = Run.new()
			run.setup(s, Data.PATRONS[s % 3]["card"])
			run.gold = rng.randi_range(0, 120)
			run.core_hp = rng.randi_range(1, run.max_hp)
			run.state = "shrine"
			run.start_event(ev_id)
			_play_shrine(run, rng, "shrine %s seed %d" % [ev_id, s])
			check(run.core_hp >= 1, "shrine %s: Core HP stays at 1 or more" % ev_id)
			check(run.max_hp >= Run.MIN_MAX_HP, "shrine %s: max HP floor" % ev_id)


func _play_shrine(run, rng: RandomNumberGenerator, tag: String) -> void:
	var guard := 0
	while not run.shrine["done"] and guard < 10:
		guard += 1
		var choices: Array = []
		for i in run.shrine_options().size():
			if run.can_choose(i):
				choices.append(i)
		check(not choices.is_empty(), "%s: shrine has a legal option" % tag)
		if choices.is_empty():
			return
		check(run.choose_option(choices[rng.randi_range(0, choices.size() - 1)]) == "", "%s: shrine option" % tag)
		if run.shrine["pending"] == "remove":
			run.shrine_remove(rng.randi_range(0, run.deck.size() - 1))
		elif run.shrine["pending"] == "choose":
			run.shrine_take_card(rng.randi_range(-1, 2))
		check(run.gold >= 0, "%s: gold went negative" % tag)
		check(run.core_hp <= run.max_hp, "%s: HP above max" % tag)
		check(run.deck.size() >= Run.MIN_DECK, "%s: deck below minimum" % tag)
	check(run.shrine["done"], "%s: shrine resolved" % tag)


func fuzz_runs() -> void:
	var outcomes := {"victory": 0, "defeat": 0}
	for s in range(1, 61):
		var patron: Dictionary = Data.PATRONS[s % 3]
		var run = Run.new()
		run.setup(s, patron["card"], patron["powers"][(s / 3) % 2])
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 104729
		var tag := "run seed %d" % s
		var guard := 0
		while not (run.state in ["victory", "defeat"]) and guard < 200:
			guard += 1
			match run.state:
				"map":
					while run.pending_upgrades() > 0:
						var ups: Array = run.upgrade_options()
						check(not ups.is_empty(), "%s: upgrade pending with no options" % tag)
						if ups.is_empty():
							break
						check(run.choose_upgrade(ups[rng.randi_range(0, ups.size() - 1)]) == "", "%s: choose upgrade" % tag)
					var options: Array = run.available_nodes()
					check(not options.is_empty(), "%s: no available node on the map" % tag)
					if options.is_empty():
						break
					check(run.enter_node(options[rng.randi_range(0, options.size() - 1)]) == "", "%s: enter node" % tag)
				"combat":
					var c = run.make_combat()
					_autoplay(c, rng, run.deck.size(), "%s combat %s" % [tag, run.battle_id])
					run.finish_combat(c)
				"reward":
					run.finish_reward(rng.randi_range(-1, run.reward["cards"].size() - 1))
				"shop":
					for i in run.shop["cards"].size():
						if rng.randf() < 0.5:
							run.buy_card(i)
					for i in run.shop["relics"].size():
						run.buy_relic(i)
					if run.can_buy_remove() and rng.randf() < 0.5:
						check(run.buy_remove(rng.randi_range(0, run.deck.size() - 1)) == "", "%s: remove" % tag)
					if run.can_buy_heal():
						run.buy_heal()
					run.leave_node()
				"shrine":
					_play_shrine(run, rng, tag)
					run.leave_node()
				"rest":
					if rng.randf() < 0.5 or run.deck.size() <= Run.MIN_DECK:
						run.rest_heal()
					else:
						check(run.rest_remove(rng.randi_range(0, run.deck.size() - 1)) == "", "%s: rest remove" % tag)
			check(run.gold >= 0, "%s: gold went negative" % tag)
			check(run.core_hp <= run.max_hp, "%s: HP above max" % tag)
			check(run.deck.size() >= Run.MIN_DECK, "%s: deck below minimum" % tag)
		check(run.state in ["victory", "defeat"], "%s: run finished (state %s)" % [tag, run.state])
		if outcomes.has(run.state):
			outcomes[run.state] += 1
	print("Random-play runs: %d victories, %d defeats" % [outcomes["victory"], outcomes["defeat"]])


func _random_play(c, i: int, rng: RandomNumberGenerator) -> void:
	var targets: Array = c.valid_targets(i)
	var def: Dictionary = c.card_def(c.hand[i])
	if not c.can_afford(i):
		return
	if def["type"] == "unit":
		if targets.is_empty():
			return
		var t: Array = targets[rng.randi_range(0, targets.size() - 1)]
		_expect_ok(c.play_unit(i, t[2], t[1]), def["name"])
		return
	match def["target"]:
		"none":
			_expect_ok(c.play_spell(i, []), def["name"])
		"ally", "ally_card", "ally_slot", "enemy", "empty_ally_slot":
			if not targets.is_empty():
				_expect_ok(c.play_spell(i, [targets[rng.randi_range(0, targets.size() - 1)]]), def["name"])
		"enemy_front":
			if not targets.is_empty():
				var dir := -1 if rng.randf() < 0.5 else 1
				_expect_ok(c.play_spell(i, [targets[rng.randi_range(0, targets.size() - 1)]], dir), def["name"])
		"enemy_pair":
			for a in targets:
				for b in targets:
					if a != b and a[1] == b[1]:
						_expect_ok(c.play_spell(i, [a, b]), def["name"])
						return


func _random_power(c, rng: RandomNumberGenerator) -> void:
	var targets: Array = c.power_targets()
	if targets.is_empty():
		return
	var t: Array = targets[rng.randi_range(0, targets.size() - 1)]
	_expect_ok(c.use_power([t], -1 if rng.randf() < 0.5 else 1), c.power_def()["name"])


func _random_move(c, rng: RandomNumberGenerator) -> void:
	var mine: Array = c.units(P).filter(func(u): return c.can_move(u) and (c.moves_left > 0 or c.is_fresh(u)))
	if mine.is_empty():
		return
	var u = mine[rng.randi_range(0, mine.size() - 1)]
	var empties: Array = []
	for row in 2:
		for lane in 4:
			if c.unit_at(P, row, lane) == null:
				empties.append([row, lane])
	if empties.is_empty():
		return
	var d: Array = empties[rng.randi_range(0, empties.size() - 1)]
	_expect_ok(c.move_unit(u.lane, u.row, d[1], d[0]), "move")


func _expect_ok(err: String, what: String) -> void:
	check(err == "", "legal play rejected (%s): %s" % [what, err])


func _check_invariants(c, total_cards: int, tag: String) -> void:
	var cids := {}
	for side in 2:
		for row in 2:
			for lane in 4:
				var u = c.grid[side][row][lane]
				if u == null:
					continue
				check(u.alive and u.hp > 0, "%s: dead unit on grid (%s)" % [tag, u.id])
				check(u.side == side and u.row == row, "%s: unit position mismatch (%s)" % [tag, u.id])
				check(lane >= u.lane and lane < u.lane + u.width, "%s: unit lane mismatch (%s)" % [tag, u.id])
				if side == P and u.card != null and u.lane == lane:
					cids[u.card["cid"]] = true
	var statuses := 0
	for pile in [c.hand, c.deck, c.discard, c.exhausted]:
		for card in pile:
			check(not cids.has(card["cid"]), "%s: card %s is in two places" % [tag, card["id"]])
			cids[card["cid"]] = true
			if Data.CARDS[card["id"]]["type"] == "status":
				statuses += 1
				check(not c.discard.has(card), "%s: a status card reached the discard pile" % tag)
	check(cids.size() - statuses == total_cards, "%s: card count %d != %d" % [tag, cids.size() - statuses, total_cards])
