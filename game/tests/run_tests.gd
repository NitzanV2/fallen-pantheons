extends SceneTree
## Headless rules tests. Run from the game folder:
##   godot --headless --script res://tests/run_tests.gd

const Combat = preload("res://scripts/core/combat.gd")
const Data = preload("res://scripts/core/data.gd")
const Run = preload("res://scripts/core/run.gd")
const RunSave = preload("res://scripts/core/run_save.gd")
const Achievements = preload("res://scripts/core/achievements.gd")
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
	test_plan_adjust()
	test_rally()
	test_oracle()
	test_swarm()
	test_pack()
	test_forge()
	test_sun()
	test_act2_enemies()
	test_act2_elites()
	test_act2_bosses()
	test_act2_relics()
	test_divine()
	test_terrain_cards()
	test_restart_plan()
	test_patron_relics()
	test_god_powers()
	test_power_upgrades()
	test_power_cooldown()
	test_round_scaling()
	test_tooltip_wrap()
	fuzz_all_battles()
	test_maps()
	test_acts()
	test_reward_rule()
	test_no_loss_when_units_die()
	test_curses()
	test_status_cards()
	test_event_data()
	fuzz_shrines()
	fuzz_runs()
	test_continue_run()
	test_economy()
	test_fusion_cards()
	test_amalgam_shrine()
	test_athena()
	test_achievements()
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


## Count rare shrine picks over `trials` independent rolls (seen_events cleared each time).
func _rare_event_hits(seed_value: int, trials: int, relics: Array) -> int:
	var run = Run.new()
	run.setup(seed_value, "myrmidon")
	run.relics = relics.duplicate()
	var hits := 0
	for n in trials:
		run.seen_events.clear()
		run._pick_event()
		if Data.EVENTS[run.shrine["event"]].get("weight", Data.EVENT_WEIGHT) < Data.EVENT_WEIGHT:
			hits += 1
	return hits


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
	check(not c.intents.values()[0].has("lane"), "siege: the target lane is hidden while loading")
	c.end_plan()
	check(front.hp == 4 and back.hp == 4, "siege: nothing fires in the loading round")
	check(c.move_unit(2, F, 1, F) == "", "siege: move a unit away")
	check(not c.intents.values()[0].has("lane"), "siege: the target lane is hidden when firing")
	c.end_plan()
	check(not front.alive and back.hp == 4, "siege: picks the most crowded lane as it fires, so moving doesn't dodge it")

	c = fresh()
	var engine = c.debug_place("siege_engine", E, 1, B)
	engine.max_hp = 50
	engine.hp = 50
	var pair_front = c.debug_place("ark_sentinel", P, 3, F)
	var pair_back = c.debug_place("ark_sentinel", P, 3, B)
	var lone = c.debug_place("ark_sentinel", P, 0, F)
	c._declare_intents()
	c.end_plan()
	c.end_plan()
	check(not pair_front.alive and not pair_back.alive and lone.hp == 4, "siege: hits both slots of the lane with the most units")

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

	c = fresh()
	var lone = c.debug_place("echo_archer", P, 0, F)
	c.debug_place("void_charger", E, 0, F)
	c._declare_intents()
	c.end_plan()
	check(not lone.alive and c.core_hp == 50, "pierce: an enemy's excess damage stops at your last unit, not the Core")


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

	# Valkyrie gains the fallen ally's current ATK, including permanent buffs, not its base ATK.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var buffed = c.debug_place("ark_sentinel", P, 1, F)
	buffed.atk += 3
	valk = c.debug_place("valkyrie", P, 1, B)
	c._deal_damage(buffed, 99, "effect")
	check(valk.row == F and valk.atk == 1 + 5, "reinforce: gains the fallen ally's buffed ATK (2 base + 3)")

	# Ulfr Hunter Reinforces behind a Wolf (and Gjallarhorn shields it), without Valkyrie's ATK gain.
	c = fresh(50, false, ["gjallarhorn"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	var lead = c.debug_place("wolf", P, 2, F)
	var hunter = c.debug_place("ulfr_hunter", P, 2, B)
	c._deal_damage(lead, 99, "effect")
	check(hunter.row == F and hunter.lane == 2, "reinforce: Ulfr Hunter steps forward")
	check(hunter.atk == 2 and hunter.shield == 4, "reinforce: Gjallarhorn shields Ulfr Hunter, no ATK gain")

	# The reinforce swing is bonus: they can still attack again in resolve.
	c = fresh()
	c.phase = "resolve"
	var foe = c.debug_place("hollowed_zealot", E, 0, F)
	c.debug_place("ark_sentinel", P, 0, F)
	valk = c.debug_place("valkyrie", P, 0, B)
	c._deal_damage(c.unit_at(P, F, 0), 99, "effect")
	check(valk.row == F and foe.hp == 2, "reinforce: the step attacks for the fallen ally's ATK")
	check(valk.attacked_round == 0 and valk.reinforced_round == c.round_num, "reinforce: resolve swing does not spend the normal attack")
	var hp_after: int = foe.hp
	c._act(valk)
	check(foe.hp < hp_after and valk.attacked_round == c.round_num, "reinforce: they still attack during the attacking phase")

	c = fresh()
	c.phase = "resolve"
	foe = c.debug_place("hollowed_zealot", E, 0, F)
	c.debug_place("ark_sentinel", P, 0, F)
	valk = c.debug_place("valkyrie", P, 0, B)
	valk.attacked_round = c.round_num
	c._deal_damage(c.unit_at(P, F, 0), 99, "effect")
	check(valk.row == F and valk.atk == 3 and foe.hp == 5, "reinforce: no reinforce swing if it already attacked")

	# Tyr's Oath can trigger Reinforce during planning; the swing locks free move / FREE icon.
	c = _with_power(fresh(), "tyrs_oath")
	foe = c.debug_place("hollowed_zealot", E, 0, F)
	c.debug_place("ark_sentinel", P, 0, F)
	valk = c.debug_place("valkyrie", P, 0, B)
	valk.from_hand = true
	valk.deployed_round = c.round_num
	c.debug_place("hollowed_bulwark", E, 3, B)
	check(c.can_reposition(valk), "reinforce+tyr: FREE before the oath")
	check(c.use_power([[P, F, 0]]) == "", "reinforce+tyr: oath used")
	check(valk.row == F and valk.attacked_round == c.round_num and foe.hp < 5, "reinforce+tyr: steps forward and attacks in planning")
	check(not c.can_reposition(valk) and not c.can_move(valk), "reinforce+tyr: FREE gone and locked after the planning attack")
	check(c.move_unit(0, F, 1, F) != "" and valk.lane == 0, "reinforce+tyr: can't spend a move after attacking")

	c = fresh()
	var front_foe = c.debug_place("hollowed_bulwark", E, 0, F)
	var back_foe = c.debug_place("hollowed_bulwark", E, 0, B)
	var body = c.debug_place("berserker", P, 0, F)
	body.atk += 2
	body.hp = 1
	c.hand = [c._new_card("ragnarok")]
	c.faith = 5
	check(c.play_spell(0, [[P, F, 0]]) == "", "ragnarok: casts")
	check(front_foe.hp == 3 and back_foe.hp == 3, "ragnarok: blasts the lane for ATK, not remaining HP")
	check(c.unit_at(P, F, 0) == null, "ragnarok: the ally is destroyed")


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

	c = fresh()
	mummy = c.debug_place("mummy_guardian", P, 0, F)
	c._deal_damage(mummy, 20, "effect")
	check(mummy.alive and mummy.hp == 1 and c.core_hp == 50, "revive: keyword Revive does not damage the Core")

	c = fresh(50, false, ["ankh_of_eternity"])
	mummy = c.debug_place("mummy_guardian", P, 0, F)
	var plain = c.debug_place("ark_sentinel", P, 1, F)
	c._deal_damage(mummy, 20, "effect")
	check(mummy.alive and mummy.hp == 1 and c.core_hp == 48, "ankh: a keyword Revive damages the Core once")
	c._deal_damage(mummy, 20, "effect")
	check(not mummy.alive and c.core_hp == 48, "ankh: the second death does not Revive or damage the Core")
	c._deal_damage(plain, 20, "effect")
	check(plain.alive and plain.hp == 1 and c.core_hp == 46, "ankh: a unit without the keyword Revives and the Core takes 2")
	c._deal_damage(plain, 20, "effect")
	check(not plain.alive and c.core_hp == 46, "ankh: that unit's second death stays dead")

	c = fresh(50, false, ["ankh_of_eternity"])
	scarab = c._spawn("scarab", P, 0, F)
	var wolf = c._spawn("wolf", P, 1, F)
	check(c.snapshot()["grid"][P][F][0]["revive"], "ankh: a Scarab shows Revive ready")
	c._deal_damage(scarab, 5, "effect")
	check(scarab.alive and scarab.hp == 1 and scarab.revive_used and c.core_hp == 48, "ankh: a Scarab Revives and the Core takes 2")
	check(not c.snapshot()["grid"][P][F][0]["revive"], "ankh: a spent Revive is no longer shown")
	c._deal_damage(scarab, 5, "effect")
	check(not scarab.alive and c.core_hp == 48 and c.last_dead_ally == null, "ankh: a Scarab's second death stays dead and is not a Book target")
	c._deal_damage(wolf, 5, "effect")
	check(wolf.alive and wolf.hp == 1 and c.core_hp == 46, "ankh: a Wolf token Revives and the Core takes 2")

	c = fresh(50, false, ["ankh_of_eternity"])
	swarm = c.debug_place("scarab_swarm", P, 0, F)
	c._deal_damage(swarm, 10, "effect")
	scarab = c.unit_at(P, B, 0)
	check(swarm.alive and swarm.hp == 1 and scarab != null and scarab.id == "scarab" and c.core_hp == 48,
		"ankh: a Swarm Revives, leaves a Scarab, and the Core takes 2")
	c._deal_damage(scarab, 5, "effect")
	check(scarab.alive and scarab.hp == 1 and c.core_hp == 46, "ankh: the Swarm's Scarab Revives and the Core takes 2")
	c._deal_damage(scarab, 5, "effect")
	check(not scarab.alive and c.core_hp == 46, "ankh: that Scarab then stays dead")

	c = fresh(50, false, ["ankh_of_eternity"])
	c.debug_place("khepri", P, 1, F)
	scarab = c._spawn("scarab", P, 0, F)
	c.core_hp = 40
	c._deal_damage(scarab, 5, "effect")
	check(scarab.alive and c.core_hp == 39, "ankh: Khepri heals 1 and the Ankh still deals 2")

	c = fresh(50, false, ["ankh_of_eternity"])
	c.terrain[c._key(P, F, 0)] = "flooded"
	var sunk = c.debug_place("ark_sentinel", P, 0, F)
	c._deal_damage(sunk, 20, "effect")
	check(not sunk.alive and c.core_hp == 50, "ankh: Flooded blocks Revive and the Core is not damaged")

	c = fresh(50, false, ["ankh_of_eternity", "charons_lantern"])
	c.terrain[c._key(P, F, 0)] = "flooded"
	sunk = c.debug_place("ark_sentinel", P, 0, F)
	c._deal_damage(sunk, 20, "effect")
	check(sunk.alive and sunk.hp == 1 and c.core_hp == 48, "ankh: Charon's Lantern lets the Revive happen, and the Core takes 2")

	c = fresh(50, false, ["ankh_of_eternity"])
	var unmade = c.debug_place("mummy_guardian", P, 0, F)
	c._unmaking = true
	c._deal_damage(unmade, 20, "effect")
	check(not unmade.alive and c.core_hp == 50, "ankh: Apep's unmaking blocks Revive and the Core is not damaged")

	c = fresh(50, false, ["ankh_of_eternity", "aegis_fragment"])
	var saved = c.debug_place("ark_sentinel", P, 0, F)
	c._deal_damage(saved, 20, "effect")
	check(saved.alive and saved.hp == 1 and not saved.revive_used and c.core_hp == 50, "ankh: Aegis is not a Revive, so the Core is untouched")
	c._deal_damage(saved, 20, "effect")
	check(saved.alive and saved.revive_used and c.core_hp == 48, "ankh: the next death Revives and the Core takes 2")
	c._deal_damage(saved, 20, "effect")
	check(not saved.alive and c.core_hp == 48, "ankh: after Revive is spent, the Core is not damaged again")

	c = fresh(50, false, ["ankh_of_eternity"])
	c.debug_place("osiris", P, 3, B)
	var risen = c.debug_place("ark_sentinel", P, 0, F)
	c._deal_damage(risen, 20, "effect")
	check(risen.alive and risen.hp == risen.max_hp and risen.atk == 4 and c.core_hp == 48, "ankh: Osiris returns it at full HP and the Core still takes 2")

	c = fresh(50, false, ["ankh_of_eternity", "styx_water"])
	wolf = c._spawn("wolf", P, 0, F)
	c._deal_damage(wolf, 5, "effect")
	check(wolf.alive and wolf.hp == 1 and not wolf.has_kw("incorporeal") and not c.styx_used and c.core_hp == 48,
		"ankh: a token Revives through the Ankh, and Styx Water stays unused")

	c = fresh(2, false, ["ankh_of_eternity"])
	var doomed = c.debug_place("ark_sentinel", P, 0, F)
	c._deal_damage(doomed, 20, "effect")
	check(doomed.alive and doomed.hp == 1 and c.core_hp == 0 and c.result == "defeat", "ankh: Core damage from a Revive can lose the fight")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var anubis = c.debug_place("anubis", P, 0, F)
	c._deal_damage(c.debug_place("ark_sentinel", P, 1, F), 20, "effect")
	check(anubis.atk == 4 and anubis.max_hp == 6, "book: Anubis keeps the +1/+1 from a death")
	anubis.temp_atk = 3
	c._attach(anubis, c._new_card("bronze_spear"))
	check(c.effective_atk(anubis) == 9, "book: spear ATK and temp ATK apply while it lives")
	c._attach(anubis, c._new_card("golden_cuirass"))
	check(anubis.max_hp == 10 and anubis.armaments.size() == 1 and anubis.armaments[0]["id"] == "golden_cuirass",
		"book: the cuirass adds HP and replaces the spear")
	c._deal_damage(anubis, 99, "effect")
	var kept = c.last_dead_ally
	check(kept["id"] == "anubis" and kept["kept_atk"] == 4 and kept["kept_max_hp"] == 6, "book: the saved body excludes Armament HP and temp ATK")
	check(c.deck.any(func(card): return card["id"] == "golden_cuirass"), "book: the cuirass returns to the deck")
	c.hand = [c._new_card("book_of_the_dead")]
	c.faith = 3
	check(c.play_spell(0, [[P, F, 2]]) == "", "book: cast")
	risen = c.unit_at(P, F, 2)
	check(risen != null and risen.id == "anubis" and risen.atk == 4 and risen.max_hp == 6 and risen.hp == 6,
		"book: Anubis returns at full gained HP and ATK")
	check(risen.temp_atk == 0 and risen.armaments.is_empty(), "book: temp ATK and Armaments are not returned")
	check(not c.is_fresh(risen) and c.move_unit(2, F, 3, F) != "", "book: the returned unit can't move this round")

	c = fresh()
	var sphinx = c.debug_place("sphinx", P, 0, F)
	sphinx.atk = 5
	sphinx.max_hp = 8
	sphinx.hp = 3
	c._attach(sphinx, c._new_card("golden_cuirass"))
	c._deal_damage(sphinx, 99, "effect")
	c.hand = [c._new_card("book_of_the_dead")]
	c.faith = 3
	check(c.play_spell(0, [[P, B, 1]]) == "", "book: return the sphinx")
	risen = c.unit_at(P, B, 1)
	check(risen.atk == 5 and risen.max_hp == 8 and risen.hp == 8 and risen.armaments.is_empty(),
		"book: Sphinx growth returns at full HP, without the cuirass")

	c = _with_power(fresh(), "osiris_return")
	var dead = c.debug_place("anubis", P, 0, F)
	dead.atk = 6
	dead.max_hp = 9
	dead.hp = 9
	c._attach(dead, c._new_card("bronze_spear"))
	c._deal_damage(dead, 99, "effect")
	check(c.use_power([[P, B, 2]]) == "", "osiris: return the buffed body")
	risen = c.unit_at(P, B, 2)
	check(risen.atk == 6 and risen.max_hp == 9 and risen.hp == 1 and risen.armaments.is_empty(),
		"osiris: keeps gained ATK and max HP, still at 1 HP, without the spear")
	c = _with_power(fresh(), "osiris_return", ["life_1"])
	dead = c.debug_place("sphinx", P, 0, F)
	dead.atk = 5
	dead.max_hp = 8
	dead.hp = 8
	c._deal_damage(dead, 99, "effect")
	c.use_power([[P, F, 1]])
	risen = c.unit_at(P, F, 1)
	check(risen.atk == 5 and risen.max_hp == 8 and risen.hp == 8, "osiris: Breath of Life returns the grown body at full HP")


func test_plan_adjust() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("pythia"), c._new_card("divine_favor"), c._new_card("ark_sentinel")]
	c.faith = 3
	c._plan_start = c._capture()
	check(c.play_unit(0, 0, B) == "", "plan: deploy Pythia")
	var pythia = c.unit_at(P, B, 0)
	check(c.move_unit(0, B, 1, B) == "" and c.moves_left == 1, "plan: Pythia can move before her effect, for free")
	check(c.play_spell(0, [[P, B, 1]]) == "", "plan: a spell with no enemy in her lane")
	check(pythia.effect_used and c.move_unit(1, B, 2, B) != "" and c.recall_unit(B, 1) != "",
		"plan: Pythia locks after a spell, even when there was nothing to hit")
	check(c.unit_at(P, B, 1) == pythia, "plan: locked Pythia stays put")
	check(c.play_unit(0, 0, F) == "", "plan: deploy a sentinel beside her")
	var sentinel = c.unit_at(P, F, 0)
	check(c.move_unit(0, F, 1, B) != "" and sentinel.lane == 0, "plan: a fresh unit can't swap onto a locked one")
	check(c.move_unit(0, F, 2, F) == "" and not sentinel.effect_used, "plan: being the spell's target does not lock the sentinel")
	check(c.restart_plan() == "" and c.units(P).is_empty() and c.faith == 3 and c.hand.size() == 3,
		"plan: restart undoes the locked Pythia and refunds nothing extra")

	c = fresh()
	c.hand = [c._new_card("ark_sentinel")]
	c.faith = 2
	c._plan_start = c._capture()
	check(c.play_unit(0, 0, F) == "", "plan: deploy")
	check(c.move_unit(0, F, 2, B) == "", "plan: reposition")
	check(c.recall_unit(B, 2) == "", "plan: drag back to hand")
	check(c.faith == 2 and c.units(P).is_empty() and c.hand.size() == 1 and c.hand[0]["id"] == "ark_sentinel",
		"plan: the card and its Faith are returned")
	check(c.play_unit(0, 3, F) == "" and c.faith == 1 and c.unit_at(P, F, 3) != null, "plan: the refunded card can be played again")
	check(c.restart_plan() == "" and c.faith == 2 and c.units(P).is_empty() and c.hand.size() == 1,
		"plan: restart still restores the start of planning")

	c = fresh()
	c.hand = [c._new_card("ark_sentinel")]
	for _i in 6:
		c.hand.append(c._new_card("warding"))
	c.faith = 3
	check(c.play_unit(0, 0, F) == "", "plan: deploy with a crowded hand")
	c.hand.append(c._new_card("warding"))
	check(c.hand.size() == 7 and c.recall_unit(F, 0) != "" and c.unit_at(P, F, 0) != null and c.faith == 2,
		"plan: a full hand refuses the return")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("ark_sentinel"), c._new_card("bronze_spear"), c._new_card("raider")]
	c.faith = 5
	check(c.play_unit(0, 0, F) == "" and c.play_spell(0, [[P, F, 0]]) == "" and c.play_unit(0, 3, F) == "", "plan: arm one of two fresh units")
	var armed = c.unit_at(P, F, 0)
	var raider = c.unit_at(P, F, 3)
	check(c.move_unit(0, F, 3, F) == "" and armed.lane == 3 and raider.lane == 0 and raider.atk == 2 and c.moves_left == 1,
		"plan: two fresh units swap, and the swap is not a Raider move")
	check(c.recall_unit(F, 3) != "" and armed.lane == 3 and c.faith == 2, "plan: an armed unit can't return to hand")
	check(c.recall_unit(F, 0) == "" and c.faith == 3 and c.unit_at(P, F, 0) == null, "plan: the unarmed one can")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("ark_sentinel"), c._new_card("sandswarm")]
	c.faith = 3
	check(c.play_unit(0, 0, B) == "" and c.play_spell(0, []) == "", "plan: deploy, then summon Scarabs")
	var scarab_lane = c.unit_at(P, F, 1)
	check(scarab_lane != null and scarab_lane.id == "scarab" and c.move_unit(0, B, 1, F) != "" and c.unit_at(P, B, 0) != null,
		"plan: a fresh unit can't swap with a Scarab summoned this round")

	c = fresh()
	c.hand = [c._new_card("loki")]
	c.faith = 3
	check(c.play_unit(0, 0, B) == "", "plan: deploy Loki")
	check(c.moves_left == 2 and c.recall_unit(B, 0) != "" and c.faith == 0 and c.unit_at(P, B, 0) != null,
		"plan: Loki's extra move locks him, and recalling him can't grant it again")

	c = fresh()
	c.hand = [c._new_card("cyclops_smith")]
	c.faith = 3
	check(c.play_unit(0, 0, F) == "", "plan: deploy the Cyclops")
	check(c.hand.size() == 1 and c.hand[0].get("forged", false) and c.recall_unit(F, 0) != "" and c.hand.size() == 1,
		"plan: the forge locks the Cyclops, so he can't be replayed for a second Armament")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("hermes"), c._new_card("warding"), c._new_card("ark_sentinel")]
	c.faith = 6
	check(c.play_unit(0, 0, B) == "" and c.recall_unit(B, 0) == "" and c.faith == 6 and c.units(P).is_empty(),
		"plan: Hermes can be returned before a spell is cast")
	var hermes_index := 0
	for i in c.hand.size():
		if c.hand[i]["id"] == "hermes":
			hermes_index = i
	check(c.play_unit(hermes_index, 0, B) == "", "plan: deploy Hermes again")
	var hermes = c.unit_at(P, B, 0)
	var sentinel_index := 0
	for i in c.hand.size():
		if c.hand[i]["id"] == "ark_sentinel":
			sentinel_index = i
	check(c.play_unit(sentinel_index, 1, F) == "", "plan: deploy a sentinel")
	check(c.play_spell(0, [[P, F, 1]]) == "" and c.faith == 2, "plan: the free Warding is cast on the sentinel")
	check(hermes.effect_used and hermes.shield == 1 and c.move_block(hermes) == "Its effect has already triggered" and c.recall_unit(B, 0) != "",
		"plan: the shield trigger locks Hermes")
	check(c.move_unit(1, F, 2, F) == "" and not c.unit_at(P, F, 2).effect_used, "plan: the unit Warding was cast on is not locked")

	c = fresh()
	var foe = c.debug_place("hollowed_zealot", E, 1, F)
	c.hand = [c._new_card("loki"), c._new_card("ark_sentinel"), c._new_card("raider")]
	c.faith = 6
	check(c.play_unit(0, 0, B) == "" and c.play_unit(0, 0, F) == "" and c.play_unit(0, 2, F) == "", "plan: Loki plus two fresh units")
	var zealot_hp: int = foe.hp
	check(c.move_unit(0, F, 2, F) == "" and foe.hp == zealot_hp, "plan: swapping two fresh units does not trigger Loki")


func test_rally() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var hoplite = c.debug_place("hoplite", P, 1, F)
	var neutral = c.debug_place("ark_sentinel", P, 0, F)
	var greek = c.debug_place("peltast", P, 2, F)
	c.end_plan()
	check(greek.atk == 3 and neutral.atk == 2 and hoplite.atk == 2, "rally: Hoplite buffs the Greek neighbour only")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("hoplite", P, 0, F)
	var scarab = c._spawn("scarab", P, 1, F)
	c.end_plan()
	check(scarab.atk == 1, "rally: a summoned Scarab is not Greek, so it is skipped")

	c = fresh(50, false, ["laurel_wreath"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("hoplite", P, 1, F)
	greek = c.debug_place("peltast", P, 2, F)
	neutral = c.debug_place("ark_sentinel", P, 0, F)
	c.end_plan()
	check(greek.atk == 4 and neutral.atk == 2, "rally: Laurel Wreath doubles the Greek buff and still skips other factions")


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

	c = fresh(100, true)
	var herald = c.debug_place("void_herald", E, 1, F)
	c.end_plan()
	c.end_plan()
	var ids: Array = c.units(E).map(func(u): return u.id)
	check(ids.count("void_spawn") == 2 and ids.count("void_wisp") == 1, "herald: a Spawn every round, a Wisp every second round (%s)" % [ids])
	check(c.units(E).filter(func(u): return u.id == "void_wisp")[0].row == B, "herald: the Wisp joins the back row")
	herald.hp = herald.max_hp / 2
	var before: int = c.units(E).size()
	c.end_plan()
	c.end_plan()
	check(c.units(E).size() <= before, "herald: no summons in phase 2")


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
	c = fresh()
	var front = c.debug_place("void_spawn", E, 0, F)
	var back = c.debug_place("hollowed_zealot", E, 2, B)
	c.hand = [c._new_card("transposition")]
	c.faith = 1
	check(c.play_spell(0, [[E, F, 0], [E, B, 2]]) == "", "transposition: cross-row is legal")
	check(front.row == B and front.lane == 2 and back.row == F and back.lane == 0, "transposition: swaps front and back")

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
	check(scarab != null and c.move_unit(1, F, 1, B) != "" and c.unit_at(P, F, 1) == scarab and c.moves_left == 1,
		"fresh: units summoned by an effect can't move the round they arrive")
	check(not c.can_move(scarab) and c.snapshot()["grid"][P][F][1]["move_block"] != "", "fresh: the hover explains why")
	check(c.play_unit(0, 3, B) == "", "fresh: deploy raider")
	var fresh_raider = c.unit_at(P, B, 3)
	check(c.move_unit(3, B, 0, B) == "" and fresh_raider.atk == fresh_raider.def["atk"], "fresh: repositioning doesn't trigger Raider")
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

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.deck = [c._new_card("warding"), c._new_card("rebuke"), c._new_card("ark_sentinel")]
	c.hand = [c._new_card("augury")]
	c.faith = 1
	check(c.play_spell(0, []) == "" and c.faith == 0, "augury: costs 1")
	check(c.hand.size() == 2 and c.deck.size() == 1 and c.discard.size() == 1 and c.discard[0]["id"] == "augury",
		"augury: draws 2, then goes to the discard")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.deck = [c._new_card("warding"), c._new_card("rebuke"), c._new_card("ark_sentinel")]
	c.hand = [c._new_card("augury")]
	for n in 6:
		c.hand.append(c._new_card("warding"))
	c.faith = 1
	check(c.hand.size() == 7 and c.play_spell(0, []) == "", "augury: cast from a full hand")
	check(c.hand.size() == 7 and c.deck.size() == 2, "augury: a full hand draws only until 7")

	c = fresh(50, false, ["oracles_tripod"])
	c.debug_place("hollowed_bulwark", E, 3, B)
	var pythia = c.debug_place("pythia", P, 0, B)
	hermes = c.debug_place("hermes", P, 1, B)
	var zealot = c.debug_place("hollowed_zealot", E, 0, F)
	c.deck = [c._new_card("ark_sentinel"), c._new_card("ark_sentinel"), c._new_card("rebuke"), c._new_card("rebuke")]
	c.hand = [c._new_card("augury"), c._new_card("warding")]
	c.faith = 1
	check(c.card_cost(c.hand[0]) == 0 and c.play_spell(0, []) == "", "augury: Hermes makes the first one free")
	check(c.faith == 1 and zealot.hp == 4 and hermes.shield == 1 and pythia.effect_used, "augury: Pythia pings and Hermes gains Shield")
	check(c.hand.size() == 3, "augury: the free cast still draws 2")
	var warding := 0
	for i in c.hand.size():
		if c.hand[i]["id"] == "warding":
			warding = i
	check(c.play_spell(warding, [[P, B, 0]]) == "" and c.faith == 1, "augury: the Tripod refunds the spell cast after it")

	var run = Run.new()
	run.setup(1, "myrmidon")
	check(run._card_pool("Common", ["neutral"], []).has("augury"), "augury: a neutral Common")
	check(not run._card_pool("Common", ["greek"], []).has("augury"), "augury: the Greek reward slot does not include it")
	check(run._card_pool("Common", [], []).has("augury"), "augury: shops and off-pantheon rewards can offer it")


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


func test_pack() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var hunter = c.debug_place("ulfr_hunter", P, 0, F)
	check(c.effective_atk(hunter) == 2, "pack: no bonus alone")
	c.debug_place("wolf", P, 1, F)
	c.debug_place("wolf", P, 2, F)
	check(c.effective_atk(hunter) == 4, "pack: +1 ATK per other Wolf")
	c.debug_place("wolf", P, 3, F)
	c.debug_place("wolf", P, 1, B)
	c.debug_place("wolf", P, 0, B)
	check(c.effective_atk(hunter) == 2 + c.PACK_MAX, "pack: capped at PACK_MAX")
	c.debug_place("ark_sentinel", P, 2, B)
	check(c.effective_atk(hunter) == 2 + c.PACK_MAX, "pack: non-Wolves don't count")

	# Flank: Freki behind a front Wolf hits the same target right after it.
	c = fresh()
	var zealot = c.debug_place("hollowed_zealot", E, 0, F)
	zealot.hp = 30
	zealot.max_hp = 30
	c.debug_place("hollowed_bulwark", E, 3, B)
	var front = c.debug_place("ulfr_hunter", P, 0, F)
	var freki = c.debug_place("freki", P, 0, B)
	check(c.effective_atk(front) == 3 and c.effective_atk(freki) == 3, "flank: both Wolves get Pack +1")
	c.end_plan()
	check(freki.attacked_round == 1, "flank: Freki attacked from the back row")
	check(zealot.hp <= 30 - 6, "flank: the target took both Wolves' hits")
	var summoned := 0
	for u in c.units(P):
		if u.id == "wolf":
			summoned += 1
	check(summoned == 1, "freki: summons a Wolf at end of round after attacking")

	# No Flank without a Wolf in front, and plain Wolves don't Flank without Skoll and Hati.
	c = fresh()
	zealot = c.debug_place("hollowed_zealot", E, 1, F)
	zealot.hp = 30
	c.debug_place("ark_sentinel", P, 1, F)
	freki = c.debug_place("freki", P, 1, B)
	c.end_plan()
	check(freki.attacked_round == 0, "flank: needs a Wolf in front")
	c = fresh()
	zealot = c.debug_place("hollowed_zealot", E, 1, F)
	zealot.hp = 30
	c.debug_place("ulfr_hunter", P, 1, F)
	var back_wolf = c.debug_place("ulfr_hunter", P, 1, B)
	check(not c.has_flank(back_wolf), "flank: plain Wolves lack it")
	c.debug_place("skoll_and_hati", P, 3, F)
	check(c.has_flank(back_wolf), "skoll and hati: your Wolves have Flank")
	c.end_plan()
	check(back_wolf.attacked_round == 1, "skoll and hati: granted Flank attacks")

	# Skoll and Hati summon while you have fewer than 3 Wolves.
	c = fresh(50, true)
	var wall = c.debug_place("hollowed_bulwark", E, 3, B)
	wall.hp = 999
	wall.max_hp = 999
	c.debug_place("skoll_and_hati", P, 0, F)
	c.end_plan()
	check(c._wolf_count(P) == 2, "skoll and hati: summons a Wolf at start of round")
	for i in 4:
		c.end_plan()
	check(c._wolf_count(P) == c.SKOLL_WOLVES, "skoll and hati: stops at SKOLL_WOLVES Wolves")

	# Geri grows when another Wolf dies.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var geri = c.debug_place("geri", P, 0, F)
	var w = c.debug_place("wolf", P, 1, F)
	c._deal_damage(w, 10, "effect")
	check(geri.atk == 4 and geri.max_hp == 5, "geri: +1/+1 when another Wolf dies")
	c._deal_damage(c.debug_place("ark_sentinel", P, 2, F), 10, "effect")
	check(geri.atk == 4, "geri: ignores non-Wolf deaths")

	# Call of the Pack fills a lane pair; Blood Scent hits once per Wolf.
	c = fresh()
	var target = c.debug_place("hollowed_bulwark", E, 3, B)
	c.hand = [c._new_card("call_of_the_pack"), c._new_card("blood_scent")]
	c.faith = 3
	check(c.valid_targets(0).size() == 8, "call of the pack: any empty slot, no fallen ally needed")
	check(c.play_spell(0, [[P, B, 2]]) == "", "call of the pack: cast")
	check(c.unit_at(P, B, 2) != null and c.unit_at(P, F, 2) != null, "call of the pack: Wolves in both slots of the lane")
	check(c.move_unit(2, B, 0, B) != "" and c.unit_at(P, B, 2) != null and c.moves_left == 1, "call of the pack: the Wolves can't move this round")
	check(c.play_spell(0, [[E, B, 3]]) == "", "blood scent: cast")
	check(target.hp == 4, "blood scent: each Wolf deals its ATK (1 + Pack 1)")
	check("flank" in CardWidget.glossary_icons(Data.CARDS["skoll_and_hati"], "skoll_and_hati"), "glossary: Skoll and Hati explain Flank")
	check("pack" in CardWidget.glossary_icons(Data.CARDS["blood_scent"], "blood_scent"), "glossary: Wolf cards explain Wolves")
	check("revive" in CardWidget.glossary_icons(Data.CARDS["osiris"], "osiris"), "glossary: mentioned keywords are explained")
	check(not "taunt" in CardWidget.glossary_icons(Data.CARDS["thor"], "thor"), "glossary: unmentioned keywords stay out")
	check(not "toll" in CardWidget.glossary_icons(CardWidget.enemy_def("hel"), "hel"), "glossary: Hel's Toll of the Dead isn't the Toll keyword")
	check("toll" in CardWidget.glossary_icons(CardWidget.enemy_def("obol_collector"), "obol_collector"), "glossary: the Obol Collector explains Toll")
	check(not CardWidget.bold_keywords(Data.ENEMIES["hel"]["text"]).contains("[b]Toll[/b]"), "glossary: Toll of the Dead isn't bolded as Toll")
	c = fresh()
	c.debug_place("ark_sentinel", P, 0, F)
	c.hand = [c._new_card("book_of_the_dead")]
	c.faith = 3
	check(c.valid_targets(0).is_empty(), "book of the dead: still needs a fallen ally")


func test_act2_enemies() -> void:
	# Incorporeal halves melee (min 1); ranged hits in full.
	var c = fresh()
	var shade = c.debug_place("shade", E, 0, F)
	var sentinel = c.debug_place("ark_sentinel", P, 0, F)
	c._attack(sentinel, shade, 3)
	check(shade.hp == 3, "incorporeal: melee 3 deals 1")
	c._attack(sentinel, shade, 1)
	check(shade.hp == 2, "incorporeal: minimum 1")
	var archer = c.debug_place("echo_archer", P, 0, B)
	c._attack(archer, shade, 2)
	check(not shade.alive, "incorporeal: ranged deals full damage")

	# Drown floods your front slot in its lane; Flooded is -1 ATK and blocks Revive.
	c = fresh()
	var thrall = c.debug_place("drowned_thrall", E, 1, F)
	c.debug_place("hollowed_bulwark", E, 3, F)
	var mummy = c.debug_place("mummy_guardian", P, 1, F)
	var atk_before: int = c.effective_atk(mummy)
	c._deal_damage(thrall, 99, "effect")
	check(c.terrain_at(P, F, 1) == "flooded", "drown: floods your front slot in its lane")
	check(c.effective_atk(mummy) == atk_before - 1, "flooded: -1 ATK")
	c._deal_damage(mummy, 99, "effect")
	check(not mummy.alive, "flooded: no Revive")
	c = fresh()
	c.terrain[c._key(P, F, 2)] = "sunlit"
	var t2 = c.debug_place("drowned_thrall", E, 2, F)
	c.debug_place("hollowed_bulwark", E, 3, F)
	c._deal_damage(t2, 99, "effect")
	check(c.terrain_at(P, F, 2) == "sunlit", "drown: existing terrain stays")

	# Drag pulls the back unit forward when the front is empty.
	c = fresh()
	var lamprey = c.debug_place("styx_lamprey", E, 1, F)
	var back = c.debug_place("echo_archer", P, 1, B)
	back.max_hp = 6
	back.hp = 6
	c._act(lamprey)
	check(c.unit_at(P, F, 1) == back and c.unit_at(P, B, 1) == null, "drag: back unit pulled to the front")
	check(back.hp < back.max_hp, "drag: then attacked")

	# Devour: heals 3 and +1 ATK when its kill stays dead.
	c = fresh()
	var eater = c.debug_place("soul_eater", E, 0, F)
	eater.hp = 2
	var victim = c.debug_place("echo_archer", P, 0, F)
	victim.hp = 1
	c.actor = eater
	c._act(eater)
	c.actor = null
	check(not victim.alive and eater.atk == 4 and eater.hp == 5, "devour: +1 ATK and heals 3")

	# Toll: takes 1 Faith, else the Core takes 2.
	c = fresh()
	c.debug_place("obol_collector", E, 3, B)
	c.debug_place("null_idol", E, 0, F)
	check(c.toll_count() == 1 and c.snapshot()["toll"] == 1, "toll: counted and shown")
	c.faith = 0
	var core: int = c.core_hp
	c.end_plan()
	check(c.core_hp <= core - 2, "toll: no Faith, the Core takes 2")
	c = fresh()
	c.debug_place("obol_collector", E, 3, B)
	c.debug_place("null_idol", E, 0, F)
	c.faith = 1
	core = c.core_hp
	c.end_plan()
	check(c.core_hp == core, "toll: a spare Faith pays it (%d -> %d)" % [core, c.core_hp])

	# Judgement: the last killer is judged next round and attacked anywhere.
	c = fresh()
	var assessor = c.debug_place("assessor_of_maat", E, 3, B)
	c.debug_place("hollowed_bulwark", E, 3, F)
	var weak = c.debug_place("void_spawn", E, 0, F)
	weak.hp = 1
	var killer = c.debug_place("ark_sentinel", P, 0, F)
	c.actor = killer
	c._attack(killer, weak, 3)
	c.actor = null
	c._declare_intents()
	check(c.judged_uid == killer.uid and c.intents[assessor.uid]["text"].begins_with("JUDGE"), "judgement: the killer is judged")
	check(c._unit_snapshot(killer)["judged"], "judgement: shown on the unit")
	var hp_before: int = killer.hp
	c._act(assessor)
	check(killer.hp < hp_before, "judgement: the Assessor hits the judged unit in another lane")
	c._declare_intents()
	check(c.judged_uid == -1, "judgement: only the previous round's killer")

	# Hel-Hound: +2 against Flooded or wounded units.
	c = fresh()
	var hound = c.debug_place("hel_hound", E, 0, F)
	var tank = c.debug_place("mummy_guardian", P, 0, F)
	c._attack(hound, tank, 3)
	check(tank.hp == 2, "hel-hound: normal damage at full HP")
	tank.hp = 5
	tank.max_hp = 20
	c._attack(hound, tank, 3)
	check(tank.hp == 0 or not tank.alive or tank.revive_used, "hel-hound: +2 below half HP")

	# Drowned status: a random lane gets -1 ATK this round.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, F)
	var units_atk := {}
	for lane in 4:
		units_atk[lane] = c.debug_place("ark_sentinel", P, lane, F)
	c.deck = [c._new_card("drowned")]
	c._draw(1)
	check(c.drowned_lanes.size() == 1, "drowned: a lane is chosen")
	var lane_hit: int = c.drowned_lanes[0]
	check(c.effective_atk(units_atk[lane_hit]) == units_atk[lane_hit].atk - 1, "drowned: -1 ATK in that lane")
	check(c.effective_atk(units_atk[(lane_hit + 1) % 4]) == units_atk[(lane_hit + 1) % 4].atk, "drowned: other lanes unaffected")

	# Waves arrive at the start of their round; the fight isn't won while some are pending.
	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0]], "terrain": [], "waves": [[2, "shade", 0, 0]]}, [], [], 1)
	check(c.pending_waves().size() == 1 and c.snapshot()["waves"][0]["name"] == "Shade", "waves: shown from the start")
	c._deal_damage(c.unit_at(E, F, 0), 99, "effect")
	check(c.result == "", "waves: not won while an arrival is pending")
	c.end_plan()
	check(c.round_num == 2 and c.unit_at(E, F, 0) != null and c.unit_at(E, F, 0).id == "shade", "waves: the Shade arrives in round 2")
	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0]], "terrain": [], "waves": [[5, "shade", 0, 0]]}, [], [], 1)
	c._deal_damage(c.unit_at(E, F, 0), 99, "effect")
	check(c.result == "win", "waves: arrivals after the round limit don't count")
	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0], ["void_spawn", 1, 0]], "terrain": [], "waves": [[2, "shade", 0, 0]]}, [], [], 1)
	c.end_plan()
	var arrived = null
	for e in c.units(E):
		if e.id == "shade":
			arrived = e
	check(arrived != null and arrived.lane == 2 and arrived.row == F, "waves: an occupied slot sends it to the nearest empty one")
	# Full front row: a ferry spill waits in the back, then advances when a front slot frees.
	c = Combat.new()
	c.setup({"core": 50, "enemies": [
		["void_spawn", 0, 0], ["void_spawn", 1, 0], ["void_spawn", 2, 0], ["void_spawn", 3, 0],
	], "terrain": [], "waves": [[2, "shade", 0, 0]], "max_rounds": 4}, [], [], 1)
	c.end_plan()
	var waiter = null
	for e in c.units(E):
		if e.id == "shade":
			waiter = e
	check(waiter != null and waiter.row == B, "waves: a full front puts the ferry arrival in the back")
	check(c.intents.get(waiter.uid, {}).get("type", "") == "wait", "waves: a back-row melee arrival Waits")
	c._deal_damage(c.unit_at(E, F, 1), 99, "effect")
	c.end_plan()
	check(waiter.alive and waiter.row == F and waiter.lane == 1, "waves: a Waiting enemy advances into a freed front slot")
	check(c.intents.get(waiter.uid, {}).get("type", "") == "attack", "waves: after advancing it intends to attack")

	# Every Act 2 battle is valid and pooled.
	for b in Data.BATTLES:
		if b.get("act", 1) != 2:
			continue
		check(Data.BATTLE_POOLS.has(b["id"]) and Data.BATTLE_POOLS[b["id"]].begins_with("act2_"), "act 2 battle %s is pooled" % b["id"])
		for e in b["enemies"] + b.get("waves", []).map(func(w): return [w[1]]):
			check(Data.ENEMIES.has(e[0]), "act 2 battle %s: enemy %s exists" % [b["id"], e[0]])
	check(Data.ACTS[1]["pools"]["early"] == "act2_early" and Data.ACTS[1]["pools"]["late"] == "act2_late", "act 2 uses its own fights")


func test_act2_bosses() -> void:
	# Hades claims your costliest playable card when you end planning; 8 damage in one round frees it.
	var c = fresh(80, true)
	var h = c.debug_place("hades", E, 1, B)
	c._declare_intents()
	c.hand = [c._new_card("ark_sentinel"), c._new_card("thor"), c._new_card("shieldmaiden")]
	var thor: Dictionary = c.hand[1]
	check(c.claim_preview() == [1] and c.snapshot()["claim_next"] == [1], "hades: previews the costliest card")
	c.end_plan()
	check(thor in c.claimed and not thor in c.hand and c.hand.size() == 2, "hades: claims it when you end planning")
	check(c.snapshot()["claimed"] == ["Thor"], "hades: the claimed card is listed")
	check(c.core_hp == 80 - 4 - 1, "hades: Dominion of the Dead costs 1 per claimed card")
	check(c.pending_waves().size() == 1 and c.pending_waves()[0][1] == "shade", "hades: a Shade is on its way")
	c._deal_damage(h, 5, "effect")
	check(c.claimed.size() == 1, "hades: under 8 damage keeps the claim")
	c._deal_damage(h, 3, "effect")
	check(c.claimed.is_empty() and thor in c.hand, "hades: 8 damage in a round frees the card")
	c.end_plan()
	check(c.round_num == 3 and c.helm_active(h) and c._unit_snapshot(h)["helm"], "hades: Helm of Darkness on round 3")
	var hp_before: int = h.hp
	c._deal_damage(h, 10, "effect")
	check(h.hp == hp_before, "hades: the Helm blocks damage")
	check(not [E, B, 1] in c._targets_for({}, "enemy"), "hades: the Helm blocks spell targeting")
	h.hp = 30
	c.end_plan()
	check(c.pending_waves().size() == 2 and c.pending_waves().all(func(w): return w[1] == "shade"), "hades: phase 2 ferries two Shades")
	c.hand = [c._new_card("ark_sentinel"), c._new_card("thor"), c._new_card("odin")]
	check(c.claim_preview().size() == 2, "hades: phase 2 claims two cards")
	c._deal_damage(h, 99, "effect")
	check(not h.alive and c.pending_waves().is_empty(), "hades: his death cancels the Shades")

	# Ammit weighs lanes 1-2 against 3-4; the heavier side's front units take the difference x2.
	c = fresh(50, true)
	var am = c.debug_place("ammit", E, 1, B)
	var l1 = c.debug_place("ark_sentinel", P, 0, F)
	c.debug_place("echo_archer", P, 1, B)
	var r1 = c.debug_place("ark_sentinel", P, 2, F)
	l1.max_hp = 10
	l1.hp = 10
	check(c.weighing() == {"left": 4, "right": 2, "mult": 2}, "ammit: weighs both sides")
	c._ammit_weigh(am)
	check(l1.hp == 6 and r1.hp == 4, "ammit: the heavier side's front takes the difference x2")
	var l2 = c.debug_place("ark_sentinel", P, 1, F)
	l1.hp = 10
	l2.max_hp = 10
	l2.hp = 10
	c._ammit_weigh(am)
	check(l1.hp == 6 and l2.hp == 6, "ammit: the damage is split across the front units")
	c = fresh(50, true)
	am = c.debug_place("ammit", E, 1, B)
	c.debug_place("echo_archer", P, 3, B)
	c._ammit_weigh(am)
	check(c.core_hp == 46, "ammit: no front units on the heavy side means the Core takes it")
	c = fresh(50, true)
	am = c.debug_place("ammit", E, 1, B)
	var victim = c.debug_place("ark_sentinel", P, 0, F)
	victim.hp = 1
	am.hp = 30
	c._ammit_weigh(am)
	check(not victim.alive and am.hp == 34, "ammit: phase 2 devours the units the Weighing kills")
	c = fresh(50, true)
	am = c.debug_place("ammit", E, 1, B)
	var even = c.debug_place("ark_sentinel", P, 0, F)
	c.debug_place("ark_sentinel", P, 3, F)
	c._ammit_weigh(am)
	check(even.hp == 4 and c.core_hp == 50, "ammit: balanced scales do nothing")

	# Nidhogg rots the slot of your highest-ATK unit; the unit flees or takes 4.
	c = fresh(50, true)
	var n = c.debug_place("nidhogg", E, 1, B)
	var big = c.debug_place("thor", P, 1, F)
	var small = c.debug_place("ark_sentinel", P, 0, F)
	c._declare_intents()
	check(c._rot_slot() == [F, 1] and "0:1" in c.snapshot()["rot_targets"], "nidhogg: gnaws the highest-ATK unit's slot")
	c._nidhogg_gnaw(n)
	check(c.terrain_at(P, F, 1) == "rotted", "nidhogg: the slot becomes Rotted")
	check(big.alive and big.row == F and big.lane == 2 and big.hp == big.max_hp, "nidhogg: the unit flees to an adjacent free slot")
	check(not c.slot_open(P, F, 1) and c.move_unit(0, F, 1, F) != "" and small.lane == 0, "rotted: units can't move in")
	c.hand = [c._new_card("ark_sentinel")]
	c.faith = 3
	check(not [P, F, 1] in c.valid_targets(0) and c.play_unit(0, 1, F) != "", "rotted: units can't be deployed there")
	var trapped = c.debug_place("ark_sentinel", P, 0, B)
	c.debug_place("ark_sentinel", P, 1, B)
	c.intents[n.uid] = {"type": "attack", "rot": [B, 0]}
	c._nidhogg_gnaw(n)
	check(trapped.hp == 0 or not trapped.alive, "nidhogg: a trapped unit takes 4")
	c.intents[n.uid] = {"type": "breath", "lane": 2}
	c._nidhogg_breath(n)
	check(big.poisoned and big.hp == big.max_hp - 3, "nidhogg: poison breath poisons and deals 3")
	for lane in 4:
		c.terrain[c._key(P, F, lane)] = "rotted"
	check(c._rot_slot().is_empty(), "nidhogg: stops rotting at 4 Rotted slots")
	c.intents[n.uid] = {"type": "attack", "rot": []}
	var core_before: int = c.core_hp
	c._nidhogg_gnaw(n)
	check(c.core_hp == core_before - 2, "nidhogg: then gnaws the Core")


func test_act2_elites() -> void:
	# Charon ferries your lowest-HP back unit at the end of the round: no death, card to the discard pile.
	var c = fresh()
	c.debug_place("charon", E, 3, F)
	var strong = c.debug_place("ark_sentinel", P, 0, B)
	var weak = c.debug_place("echo_archer", P, 1, B)
	var front = c.debug_place("mummy_guardian", P, 1, F)
	check(c.ferry_target() == weak and c._unit_snapshot(weak)["ferried"], "charon: the weakest back unit is marked")
	check(not c._unit_snapshot(front)["ferried"], "charon: front units are safe")
	c.faith = 1
	var falls_before: int = c.falls
	var weak_card: Dictionary = weak.card
	c.end_plan()
	check(not weak.alive and c.unit_at(P, B, 1) == null, "charon: the passenger leaves the board")
	check(weak_card in c.discard + c.deck + c.hand, "charon: its card goes back into your piles")
	check(c.falls == falls_before, "charon: a ferry isn't a death")
	check(strong.alive, "charon: one unit per round")

	# Cerberus: a fallen Head enrages the others; all three alive heal 2 at the end of the round.
	c = fresh()
	var h1 = c.debug_place("cerberus_head", E, 1, F)
	var h2 = c.debug_place("cerberus_head", E, 2, F)
	var h3 = c.debug_place("cerberus_head", E, 3, F)
	h1.hp = 3
	h2.hp = 3
	c.end_plan()
	check(h1.hp == 5 and h2.hp == 5 and h3.hp == 7, "cerberus: all three alive heal 2")
	c._deal_damage(h1, 99, "effect")
	check(h2.atk == 4 and h3.atk == 4, "cerberus: survivors gain +2 ATK")
	h2.hp = 3
	c.end_plan()
	check(h2.hp <= 3, "cerberus: no heal once a Head is gone")

	# Hraesvelgr: Wingbeat shifts your units; blocked ones stay and take 2.
	c = fresh()
	c.debug_place("hraesvelgr", E, 1, B)
	c.debug_place("null_idol", E, 0, F)
	var a = c.debug_place("ark_sentinel", P, 0, F)
	var b2 = c.debug_place("ark_sentinel", P, 2, F)
	var edge = c.debug_place("ark_sentinel", P, 3, F)
	c.wingbeat_dir = 1
	check(c.snapshot()["wingbeat"] == 1, "wingbeat: shown in the snapshot")
	c._wingbeat(1)
	check(c.unit_at(P, F, 1) == a, "wingbeat: a unit with room shifts one lane")
	check(c.unit_at(P, F, 3) == edge and edge.hp == edge.max_hp - 2, "wingbeat: the edge unit stays and takes 2")
	check(c.unit_at(P, F, 2) == b2 and b2.hp == b2.max_hp - 2, "wingbeat: a blocked unit stays and takes 2")
	c._wingbeat(-1)
	check(c.unit_at(P, F, 0) == a and a.hp == a.max_hp, "wingbeat: shifts back left")
	c = fresh()
	c.debug_place("hraesvelgr", E, 1, B)
	c._declare_intents()
	check(c.wingbeat_dir in [-1, 1], "wingbeat: a direction is declared")

	# Erinyes: the unit that dealt the most damage last round is hunted.
	c = fresh()
	var fury = c.debug_place("erinyes_fury", E, 0, F)
	var t1 = c.debug_place("void_spawn", E, 2, F)
	t1.max_hp = 30
	t1.hp = 30
	var small = c.debug_place("echo_archer", P, 0, F)
	var big = c.debug_place("ark_sentinel", P, 2, F)
	big.atk = 5
	c.actor = small
	c._deal_damage(t1, 2, "ranged")
	c.actor = big
	c._deal_damage(t1, 5, "melee")
	c.actor = null
	c._declare_intents()
	check(c.vengeance_uid == big.uid and c.intents[fury.uid]["type"] == "vengeance", "erinyes: the top damage dealer is hunted")
	check(c._unit_snapshot(big)["hunted"], "erinyes: shown on the unit")
	var hp_before: int = big.hp
	c._act(fury)
	check(big.hp < hp_before and small.hp == small.max_hp, "erinyes: the Fury attacks the hunted unit in another lane")
	c._declare_intents()
	check(c.vengeance_uid == -1, "erinyes: only last round's damage counts")

	# Erinyes: only one Fury is Airborne each round; they rotate by lane.
	c = fresh()
	var f0 = c.debug_place("erinyes_fury", E, 0, F)
	var f2 = c.debug_place("erinyes_fury", E, 2, F)
	var f3 = c.debug_place("erinyes_fury", E, 3, F)
	c.round_num = 1
	c._declare_intents()
	check(f0.has_kw("airborne") and not f2.has_kw("airborne") and not f3.has_kw("airborne"), "erinyes: round 1 leftmost Fury is Airborne")
	check(c._unit_snapshot(f0)["airborne"] and not c._unit_snapshot(f2)["airborne"], "erinyes: airborne shown only on the flying Fury")
	var melee = c.debug_place("ark_sentinel", P, 2, F)
	check(c._can_target(melee, f2) and not c._can_target(melee, f0), "erinyes: melee hits grounded, not airborne")
	c.round_num = 2
	c._declare_intents()
	check(not f0.has_kw("airborne") and f2.has_kw("airborne") and not f3.has_kw("airborne"), "erinyes: round 2 next lane is Airborne")
	c._deal_damage(f2, f2.hp, "effect")
	check(not f2.alive, "erinyes: airborne Fury can die")
	c.round_num = 3
	c._declare_intents()
	var flying := 0
	for f in [f0, f3]:
		if f.alive and f.has_kw("airborne"):
			flying += 1
	## Survivors lanes 0 then 3; round 3 → index (3-1)%2 = 0 → lane 0.
	check(flying == 1 and f0.has_kw("airborne") and not f3.has_kw("airborne"), "erinyes: after a death, exactly one survivor is Airborne")

	# Keeper: seals a lane until it takes 6 damage this round; Guardians return two rounds later.
	c = fresh()
	var keeper = c.debug_place("keeper_of_the_gate", E, 1, B)
	var guard = c.debug_place("gate_guardian", E, 1, F)
	var sealed_unit = c.debug_place("ark_sentinel", P, 2, F)
	c._declare_intents()
	check(c.sealed_lane == 2 and c.snapshot()["sealed_lane"] == 2, "keeper: round 1 seals lane 3")
	check(c.is_sealed(sealed_unit), "keeper: your unit in the lane is sealed")
	c._deal_damage(keeper, 6, "effect")
	check(not c.is_sealed(sealed_unit) and c.snapshot()["seal_broken"], "keeper: 6 damage breaks the Seal")
	c.gate_damage = 0
	var guard_hp: int = guard.hp
	c._act(sealed_unit)
	check(guard.hp == guard_hp and keeper.hp == keeper.max_hp - 6, "keeper: a sealed unit doesn't attack")
	c._deal_damage(guard, 99, "effect")
	check(c.pending_waves().size() == 1 and c.snapshot()["waves"][0]["returning"], "keeper: the Guardian is due back")
	check(c.result == "", "keeper: not won while the Keeper lives")
	c.end_plan()
	c.end_plan()
	check(c.round_num == 3 and c.unit_at(E, F, 1) != null and c.unit_at(E, F, 1).id == "gate_guardian", "keeper: the Guardian returns two rounds later")
	c = fresh()
	keeper = c.debug_place("keeper_of_the_gate", E, 1, B)
	guard = c.debug_place("gate_guardian", E, 1, F)
	c._deal_damage(guard, 99, "effect")
	c._deal_damage(keeper, 99, "effect")
	check(c.result == "win" and c.pending_waves().is_empty(), "keeper: killing the Keeper stops the Guardians")

	for id in ["charon", "cerberus", "hraesvelgr", "erinyes", "twelfth_gate"]:
		check(Data.BATTLE_POOLS.get(id, "") == "act2_elite", "act 2 elite %s is pooled" % id)
	check(Data.ACTS[1]["pools"]["elite"] == "act2_elite", "act 2 uses its own elites")


func test_sun() -> void:
	var c = fresh()
	var bulwark = c.debug_place("hollowed_bulwark", E, 1, F)
	bulwark.max_hp = 30
	bulwark.hp = 30
	var archer = c.debug_place("echo_archer", P, 1, B)
	var base_atk: int = c.effective_atk(archer)
	c.hand = [c._new_card("dawn_ritual"), c._new_card("eye_of_ra"), c._new_card("noon_blaze")]
	c.faith = 10
	check(c.valid_targets(0).size() == 8, "dawn ritual: any of your slots without terrain, either row")
	check(c.valid_targets(1).is_empty(), "eye of ra: needs a Burning enemy")
	check(c.play_spell(0, [[P, B, 1]]) == "", "dawn ritual: cast")
	check(c.terrain_at(P, B, 1) == "sunlit" and c.exhausted.size() == 1, "dawn ritual: Sunlit for the fight, Exhaust")
	check(c.effective_atk(archer) == base_atk + 1, "sunlit: +1 ATK")
	c._attack(archer, bulwark, c.effective_atk(archer))
	check(bulwark.burn == 1, "sunlit: attacks apply Burn 1")
	check(c.play_spell(0, [[E, F, 1]]) == "" and bulwark.burn == 2, "eye of ra: doubles Burn")
	check(c.play_spell(0, []) == "" and bulwark.burn == 5, "noon blaze: Burn 3 in a lane with a Sunlit slot")
	var hp: int = bulwark.hp
	c._tick_burn()
	check(bulwark.hp == hp - 5 and bulwark.burn == 4, "burn: deals X, then drops by 1")
	var far = c.debug_place("hollowed_bulwark", E, 3, F)
	c.hand = [c._new_card("noon_blaze")]
	c.play_spell(0, [])
	check(far.burn == 0, "noon blaze: lanes without a Sunlit slot are spared")
	check(not c.is_sunlit(E, F, 1), "sunlit: your side only")

	# Priestess of Aten adds her own Burn to the Sunlit one.
	var priestess = c.debug_place("priestess_of_aten", P, 1, F)
	c.terrain[c._key(P, F, 1)] = "sunlit"
	c._attack(priestess, far, 1)
	check(far.burn == 3, "priestess of aten: Burn 2, +1 on a Sunlit slot")

	# Benben Stone lights its row neighbours, never attacks; Solar Barque shields when Sunlit.
	c = fresh()
	var target = c.debug_place("hollowed_bulwark", E, 1, F)
	var stone = c.debug_place("benben_stone", P, 1, F)
	var barque = c.debug_place("solar_barque", P, 2, F)
	var left = c.debug_place("ark_sentinel", P, 3, F)
	check(c.is_sunlit(P, F, 0) and c.is_sunlit(P, F, 2) and not c.is_sunlit(P, F, 3) and not c.is_sunlit(P, B, 1),
		"benben stone: its slot and the slots left and right are Sunlit")
	check(c.snapshot()["sunlit"].size() == 3, "benben stone: the snapshot lists Sunlit slots")
	var hp_before: int = target.hp
	c._act(stone)
	check(target.hp == hp_before, "benben stone: doesn't attack")
	c._start_of_round(barque)
	check(stone.shield == 2 and left.shield == 2, "solar barque: Sunlit, so its neighbours gain Shield 2")
	c._deal_damage(stone, 99, "effect")
	check(not c.is_sunlit(P, F, 2), "benben stone: the light ends when it dies")
	var shield_before: int = left.shield
	c._start_of_round(barque)
	check(left.shield == shield_before, "solar barque: nothing when not Sunlit")

	# Horus: +2 against Burning enemies, and Faith next round when one dies.
	c = fresh()
	var horus = c.debug_place("horus", P, 0, B)
	var a = c.debug_place("hollowed_bulwark", E, 0, F)
	var b = c.debug_place("hollowed_bulwark", E, 2, F)
	check(horus.has_kw("airborne") and horus.has_kw("ranged"), "horus: Ranged and Airborne")
	c._attack(horus, a, 3)
	check(a.hp == 5, "horus: normal damage without Burn")
	a.burn = 1
	c._attack(horus, a, 3)
	check(a.hp == 0 or not a.alive, "horus: +2 damage against a Burning enemy")
	check(c.faith_next == 1, "horus: a Burning enemy died, +1 Faith next round")
	b.burn = 2
	c._deal_damage(b, 99, "effect")
	check(c.faith_next == 1, "horus: once per round")
	c.debug_place("hollowed_bulwark", E, 3, F)
	var faith_before: int = 3
	c._start_round()
	check(c.faith == faith_before + 1 and c.faith_next == 0, "horus: the Faith arrives at the start of the next round")

	# Revive clears Burn.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, F)
	var mummy = c.debug_place("mummy_guardian", P, 0, F)
	mummy.burn = 4
	c._deal_damage(mummy, 99, "effect")
	check(mummy.alive and mummy.burn == 0, "burn: Revive clears it")
	check("burn" in CardWidget.glossary_icons(Data.CARDS["horus"], "horus"), "glossary: Burning explains Burn")
	check("sunlit" in CardWidget.glossary_icons(Data.CARDS["solar_barque"], "solar_barque"), "glossary: Sunlit is explained")


func test_forge() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var hop = c.debug_place("ark_sentinel", P, 0, F)
	c.hand = [c._new_card("bronze_spear"), c._new_card("golden_cuirass"), c._new_card("harpe"), c._new_card("pythia")]
	c.faith = 10
	check(c.valid_targets(0) == [[P, F, 0]], "armament: targets your units")
	check(c.play_spell(0, [[P, F, 0]]) == "", "armament: attach Bronze Spear")
	check(c.effective_atk(hop) == 4 and c.spells_this_round == 0, "bronze spear: +2 ATK, and an Armament is not a spell")
	check(c.play_spell(0, [[P, F, 0]]) == "", "armament: attach Golden Cuirass")
	check(hop.armaments.size() == 1 and c.effective_atk(hop) == 2, "armament: a new one replaces the old")
	check(c.discard.size() == 1 and c.discard[0]["id"] == "bronze_spear", "armament: the replaced card goes to the discard pile")
	check(hop.max_hp == 8 and hop.hp == 8 and hop.has_kw("taunt"), "golden cuirass: +4 HP and Taunt")
	check(c.play_spell(0, [[P, F, 0]]) == "", "armament: attach Harpe")
	check(hop.max_hp == 4 and hop.hp == 4 and not hop.has_kw("taunt"), "armament: removing the Cuirass takes its HP and Taunt")
	check(hop.has_kw("cleave") and c.effective_atk(hop) == 3, "harpe: +1 ATK and Cleave")
	var deck_before: int = c.deck.size()
	c._deal_damage(hop, 99, "effect")
	check(c.deck.size() == deck_before + 1 and c.deck.any(func(card): return card["id"] == "harpe"), "armament: shuffles into the draw pile when its unit dies")

	# Revive keeps the Armament; Thread of Fate sends it to the discard pile.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var mummy = c.debug_place("mummy_guardian", P, 1, F)
	c._attach(mummy, c._new_card("hoplon"))
	c._deal_damage(mummy, 99, "effect")
	check(mummy.alive and mummy.armaments.size() == 1, "armament: stays on a unit that Revives")
	c.hand = [c._new_card("thread_of_fate")]
	c.faith = 3
	c.play_spell(0, [[P, F, 1]])
	check(c.discard.any(func(card): return card["id"] == "hoplon"), "armament: Thread of Fate discards it")

	# Hoplon shields at start of round; Talos holds several, each +1 ATK more.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var talos = c.debug_place("talos", P, 2, F)
	c._attach(talos, c._new_card("hoplon"))
	c._attach(talos, c._new_card("bronze_spear"))
	check(talos.armaments.size() == 2 and c.effective_atk(talos) == 3 + 2 + 2, "talos: holds any number, +1 ATK each")
	c.end_plan()
	check(talos.shield == 2, "hoplon: Shield 2 at start of round")
	deck_before = c.deck.size()
	c._deal_damage(talos, 99, "effect")
	check(c.deck.size() == deck_before + 2, "talos: all his Armaments shuffle back")

	# Forge Apprentice discounts the first Armament each round; Cyclops forges a free Common one.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("forge_apprentice", P, 0, F)
	c.hand = [c._new_card("golden_cuirass"), c._new_card("golden_cuirass"), c._new_card("cyclops_smith")]
	c.faith = 10
	check(c.card_cost(c.hand[0]) == 1, "forge apprentice: first Armament costs 1 less")
	c.play_spell(0, [[P, F, 0]])
	check(c.card_cost(c.hand[0]) == 2, "forge apprentice: only the first each round")
	check(c.play_unit(1, 1, F) == "", "cyclops: deploy")
	var forged: Dictionary = c.hand[c.hand.size() - 1]
	check(Data.CARDS[forged["id"]]["type"] == "armament" and Data.CARDS[forged["id"]]["rarity"] == "Common", "cyclops: adds a Common Armament")
	check(c.card_cost(forged) == 0, "cyclops: it costs 0 this round")
	c._deal_damage(c.unit_at(P, F, 0), 99, "effect")
	c.end_plan()
	check(c.card_cost(forged) > 0 or not c.hand.has(forged), "cyclops: the discount lasts only this round")

	# Undo restores Armaments.
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("ark_sentinel", P, 0, F)
	c.hand = [c._new_card("golden_cuirass")]
	c.faith = 5
	c._plan_start = c._capture()
	c.play_spell(0, [[P, F, 0]])
	c.restart_plan()
	var restored = c.unit_at(P, F, 0)
	check(restored.armaments.is_empty() and restored.max_hp == 4 and c.hand.size() == 1, "armament: undo takes it back")


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
		for id in run._card_choices(Data.ACTS[0]["elite_odds"], rng):
			check(Data.CARDS[id]["rarity"] != "Divine", "divine: never a card reward")
	run.start_event("hall_of_the_forgotten_god")
	run.gold = 100
	check(run.choose_option(0) == "", "hall: offer life")
	check(run.shrine["pending"] == "choose" and run.shrine["cards"].size() == 2, "hall: choose 1 of 2")
	check(run.shrine["cards"].all(func(id): return Data.CARDS[id]["rarity"] == "Divine"), "hall: offers Divine cards")
	var pick: String = run.shrine["cards"][0]
	run.shrine_take_card(0)
	check(run.deck.has(pick), "hall: Divine card joins the deck")


func test_amalgam_shrine() -> void:
	var ids: Array = []
	for id in Data.CARDS:
		if Data.CARDS[id].get("amalgam", false):
			ids.append(id)
	check(ids.size() == 20, "amalgam: 20 keyword trios")
	var seen_kw := {}
	for id in ids:
		var words: Array = Data.CARDS[id]["keywords"]
		check(words.size() == 4 and words[0] == "chimera", "amalgam: %s has Chimera plus three rolled keywords" % id)
		for word in words:
			seen_kw[word] = true
	seen_kw.erase("chimera")
	check(seen_kw.size() == 6, "amalgam: the roll pool is Frenzy, Revive, Cleave, Taunt, Ranged and Pierce")
	var run = Run.new()
	run.setup(3, "myrmidon")
	for id in ids:
		check(not run._card_pool("Rare", [], []).has(id), "amalgam: %s is not a reward or shop card" % id)
	var before: int = run.max_hp
	var deck_before: int = run.deck.size()
	run.start_event("shrine_of_the_amalgam")
	check(run.choose_option(0) == "", "amalgam: offer vitality")
	check(run.max_hp == before - 10, "amalgam: vitality costs 10 max Core HP")
	check(run.shrine["done"] and run.shrine["pending"] == "", "amalgam: the shrine ends without a draft")
	check(run.deck.size() == deck_before + 1, "amalgam: one card joins the deck")
	var pick: String = run.deck[run.deck.size() - 1]
	check(Data.CARDS[pick].get("amalgam", false) and run.devotion == 0 and run.foreign == 0, "amalgam: it joins the deck and counts for no pantheon")
	var seen := {}
	for i in 40:
		var other = Run.new()
		other.setup(i + 11, "myrmidon")
		other.start_event("shrine_of_the_amalgam")
		other.choose_option(0)
		seen[other.deck[other.deck.size() - 1]] = true
	check(seen.size() > 1, "amalgam: different visits roll different beasts")
	var c = fresh()
	var beast = c.debug_place("amalgam_cleave_frenzy_pierce", P, 1, F)
	check(c.is_wolf(beast) and c.is_scarab(beast), "chimera: an Amalgam counts as Wolf and Scarab")
	c.debug_place("wolf", P, 0, F)
	var pack_wolf = c.debug_place("ulfr_hunter", P, 2, F)
	check(c.effective_atk(pack_wolf) == Data.CARDS["ulfr_hunter"]["atk"] + 2, "chimera: Pack counts the Amalgam as a Wolf")
	c.debug_place("khepri", P, 3, B)
	check(c.effective_atk(beast) == Data.CARDS["amalgam_cleave_frenzy_pierce"]["atk"] + 1, "chimera: Khepri buffs the Amalgam as a Scarab")
	c.core_hp = 30
	c._deal_damage(beast, 99, "effect")
	check(c.core_hp == 31, "chimera: Khepri heals when the Amalgam dies")


func test_achievements() -> void:
	check(Data.ACHIEVEMENTS.has("untouched_boss") and Data.ACHIEVEMENTS.has("gold_200"), "badges: achievement defs exist")
	var c = fresh(40)
	c._damage_core(5, "Void Charger", true)
	c._damage_core(3, "The Void Tide", false)
	check(c.core_damage_taken == 8 and c.core_direct_damage == 5, "badges: combat splits direct Core damage")
	var run = Run.new()
	run.setup(7, "myrmidon", "zeus_lightning_bolt")
	run.state = "victory"
	run.gold = 160
	run.core_hp = run.max_hp
	run.bosses_beaten = Data.ACTS.size()
	run.bosses_untouched = Data.ACTS.size()
	run.relics = ["pilgrims_pouch", "healing_ampoule", "obol", "wardens_plate", "eye_of_horus"]
	var badges: Array = run.earned_badges()
	for id in ["untouched_boss", "untouched_all", "gold_100", "gold_150", "full_core", "relic_hoard"]:
		check(id in badges, "badges: victory earns %s" % id)
	check(not ("gold_200" in badges), "badges: 160 gold does not earn Dragon's Hoard")
	run.gold = 50
	run.bosses_untouched = 0
	run.relics = []
	run.core_hp = run.max_hp - 1
	check(run.earned_badges().is_empty(), "badges: a plain victory earns none")
	var saved_path := Achievements.path
	Achievements.path = "user://achievements_test.save"
	Achievements.clear()
	check(Achievements.unlock(["gold_100", "gold_100"]) == ["gold_100"], "badges: unlock records a badge once")
	check(Achievements.is_unlocked("gold_100") and Achievements.unlock(["gold_100"]).is_empty(), "badges: a second unlock is a no-op")
	Achievements.clear()
	Achievements.path = saved_path
	run = Run.new()
	run.setup(8, "shieldmaiden", "tyrs_oath")
	run.enter_node(run.available_nodes()[0])
	run.nodes[run.current]["type"] = "boss"
	c = run.make_combat()
	c.result = "win"
	run.finish_combat(c)
	check(run.bosses_beaten == 1 and run.bosses_untouched == 1, "badges: a clean boss clear is counted")
	run = Run.new()
	run.setup(10, "mummy_guardian", "osiris_return")
	run.enter_node(run.available_nodes()[0])
	run.nodes[run.current]["type"] = "boss"
	var boss_fight = run.make_combat()
	boss_fight._damage_core(4, "Boss", true)
	boss_fight.result = "win"
	run.finish_combat(boss_fight)
	check(run.bosses_beaten == 1 and run.bosses_untouched == 0, "badges: direct Core damage denies Untouched")


func test_athena() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var left = c.debug_place("ark_sentinel", P, 0, F)
	var athena = c.debug_place("athena", P, 1, F)
	var right = c.debug_place("ark_sentinel", P, 2, F)
	var behind = c.debug_place("ark_sentinel", P, 1, B)
	c.end_plan()
	check(left.shield == 2 and right.shield == 2, "athena: the allies beside her gain Shield 2")
	check(athena.shield == 0 and behind.shield == 0, "athena: she and the ally behind her gain nothing")
	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var front = c.debug_place("ark_sentinel", P, 1, F)
	var side = c.debug_place("ark_sentinel", P, 0, B)
	c.debug_place("athena", P, 1, B)
	c.end_plan()
	check(front.shield == 0 and side.shield == 0, "athena: the back row grants no shield")


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

func test_act2_relics() -> void:
	var c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 3, 0]], "terrain": []}, [], ["gleipnir_fragment"], 1)
	var wolf = c._spawn("wolf", P, 0, F)
	check(wolf.max_hp == Data.CARDS["wolf"]["hp"] + 1 and wolf.hp == wolf.max_hp, "relic: Gleipnir gives Wolves +1 HP")
	var other = c._spawn("ark_sentinel", P, 1, F)
	check(other.max_hp == Data.CARDS["ark_sentinel"]["hp"], "relic: Gleipnir skips non-Wolves")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 3, 0]], "terrain": []}, ["bronze_spear", "bronze_spear"], ["anvil_of_lemnos"], 1)
	var holder = c.debug_place("ark_sentinel", P, 0, F)
	var spears: Array = c.hand.filter(func(k): return k["id"] == "bronze_spear")
	check(spears.size() == 2 and c.card_cost(spears[0]) == 0, "relic: Anvil makes the first Armament free")
	c.faith = 0
	check(c.play_spell(c.hand.find(spears[0]), [[P, F, 0]]) == "", "relic: free Armament played with 0 Faith")
	check(c.card_cost(spears[1]) == Data.CARDS["bronze_spear"]["cost"], "relic: Anvil only once per fight")
	check(holder.armaments.size() == 1, "relic: Armament attached")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 3, 0]], "terrain": []}, [], ["sun_disk"], 3)
	check(c.terrain.values().count("sunlit") == 1, "relic: Sun Disk lights one slot")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["obol_collector", 3, 0], ["obol_collector", 2, 0]], "terrain": []}, [], ["obol"], 1)
	c.faith = 0
	var core: int = c.core_hp
	c._pay_toll()
	check(c.core_hp == core - 2, "relic: Obol pays one Toll, the other still costs 2")
	core = c.core_hp
	c._pay_toll()
	check(c.core_hp == core - 4, "relic: Obol once per fight")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 3, 0]], "terrain": [["flooded", P, 0, F]]}, [], ["charons_lantern"], 1)
	var reviver = c.debug_place("ark_sentinel", P, 0, F)
	reviver.bonus_kw.append("revive")
	reviver.hp = 0
	c._kill(reviver)
	check(reviver.alive, "relic: Charon's Lantern lets Revive work on Flooded slots")

	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 3, 0]], "terrain": []}, [], ["styx_water"], 1)
	var first = c.debug_place("ark_sentinel", P, 0, F)
	var second = c.debug_place("ark_sentinel", P, 1, F)
	var token = c._spawn("wolf", P, 2, F)
	token.hp = 0
	c._kill(token)
	check(not token.alive, "relic: Styx Water skips tokens")
	first.hp = 0
	c._kill(first)
	check(first.alive and first.hp == 1 and first.has_kw("incorporeal"), "relic: Styx Water returns the first ally with 1 HP, Incorporeal")
	second.hp = 0
	c._kill(second)
	check(not second.alive, "relic: Styx Water once per fight")

	var run = Run.new()
	run.setup(5, "myrmidon")
	run.act = 1
	for i in 40:
		var r: String = run._random_relic(run.reward_rng)
		check(Data.RELICS[r].get("act", 1) <= 1, "relic: Act 2 relics never drop in Act 1 (%s)" % r)
	run.act = 2
	var seen := {}
	for i in 200:
		seen[run._random_relic(run.reward_rng)] = true
	check(seen.has("obol") and seen.has("charons_lantern"), "relic: Act 2 relics drop in Act 2")
	for id in Data.RELICS:
		check(ResourceLoader.exists("res://art/relics/%s.png" % id), "relic %s has art" % id)


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

	_test_power_tier3()

	# Undo round restores the power.
	c = _with_power(fresh(), "thors_thunderclap")
	c.debug_place("hollowed_zealot", E, 1, F)
	c._plan_start = c._capture()
	c.use_power([[E, F, 1]])
	check(c.power_uses == 0 and c.can_restart_plan(), "power: counts as a plan action")
	c.restart_plan()
	check(c.power_uses == 1 and c.unit_at(E, F, 1).hp == 5, "power: Undo round restores it")


func _test_power_tier3() -> void:
	for id in Data.GOD_POWERS:
		var nodes: Dictionary = Data.GOD_POWERS[id]["nodes"]
		check(nodes.values().filter(func(n): return n["tier"] == 3).size() == 2, "tier 3: %s has one per branch" % id)

	var c = _with_power(fresh(), "tyrs_oath", ["blood_1", "blood_2", "blood_3", "oath_1", "oath_2", "oath_3"])
	var foe = c.debug_place("hollowed_bulwark", E, 0, B)
	var victim = c.debug_place("hoplite", P, 0, F)
	var faith_before: int = c.faith
	var foe_hp: int = foe.hp
	var victim_atk: int = c.effective_atk(victim)
	c.use_power([[P, F, 0]])
	check(foe.hp == foe_hp - victim_atk, "tier 3: Blood Eagle hits the lane's enemy for the unit's ATK")
	check(c.faith == faith_before + Data.CARDS["hoplite"]["cost"], "tier 3: Oath Kept refunds the unit's cost as Faith")

	c = _with_power(fresh(), "thors_thunderclap", ["storm_1", "storm_2", "storm_3", "hammer_1", "hammer_2", "hammer_3"])
	var weak: Array = []
	for lane in 3:
		var w = c.debug_place("void_spawn", E, lane, F)
		w.hp = 1
		weak.append(w)
	var tough = c.debug_place("hollowed_zealot", E, 3, F)
	tough.max_hp = 30
	tough.hp = 30
	var atk_before: int = tough.atk
	c.use_power([[E, F, 0]])
	check(c.power_uses == 1, "tier 3: Ragnarok refunds after the first kill")
	c.use_power([[E, F, 2]])
	check(c.power_uses == 1, "tier 3: Ragnarok refunds again")
	check(tough.atk == atk_before - 1, "tier 3: Thunder Rolls takes 1 ATK from a survivor")
	c.use_power([[E, F, 3]])
	check(c.power_uses == 0 and tough.atk == atk_before - 2, "tier 3: no kill, no refund; Thunder Rolls stacks")

	c = _with_power(fresh(), "zeus_lightning_bolt", ["chain_1", "chain_2", "chain_3", "sky_1", "sky_2", "sky_3"])
	var big = c.debug_place("hollowed_bulwark", E, 0, F)
	big.max_hp = 20
	big.hp = 20
	var rest: Array = []
	for lane in [1, 2, 3]:
		for row in 2:
			rest.append(c.debug_place("hollowed_bulwark", E, lane, row))
	var rest_hp: int = rest[0].hp
	c.use_power([[E, F, 0]])
	check(big.hp == 13, "tier 3: Keraunos first hit deals 7")
	check(rest.all(func(r): return r.hp == rest_hp - 2), "tier 3: Wrath of Olympus chains to every enemy")

	c = _with_power(fresh(), "poseidons_tide", ["wave_1", "wave_2", "wave_3", "undertow_1", "undertow_2", "undertow_3"])
	var pushed = c.debug_place("hollowed_bulwark", E, 1, F)
	pushed.max_hp = 40
	pushed.hp = 40
	var behind = c.debug_place("hollowed_bulwark", E, 1, B)
	var behind_hp: int = behind.hp
	var s1 = c.debug_place("hoplite", P, 1, F)
	var s2 = c.debug_place("hoplite", P, 3, F)
	c.use_power([[E, F, 1]], 1)
	check(behind.hp == behind_hp - 4, "tier 3: Tsunami hits the enemy behind for the impact")
	check(pushed.hp == 40 - 4 - c.effective_atk(s1) - c.effective_atk(s2), "tier 3: Encircling Current, both neighbours strike")

	c = _with_power(fresh(), "osiris_return", ["life_1", "life_2", "life_3", "wings_1", "wings_2", "wings_3"])
	var dead = c.debug_place("ark_sentinel", P, 0, F)
	var hurt = c.debug_place("ark_sentinel", P, 3, B)
	hurt.hp = 1
	foe = c.debug_place("hollowed_bulwark", E, 1, F)
	foe_hp = foe.hp
	dead.hp = 0
	c._kill(dead)
	c.use_power([[P, F, 1]])
	var back_unit = c.unit_at(P, F, 1)
	check(hurt.hp == hurt.max_hp, "tier 3: Field of Reeds heals the others to full")
	check(foe.hp == foe_hp - c.effective_atk(back_unit), "tier 3: Avenging Ba strikes the lane's enemy")

	c = _with_power(fresh(), "sekhmets_plague", ["plague_1", "plague_2", "plague_3", "hunt_1", "hunt_2", "hunt_3"])
	var p = c.debug_place("hollowed_bulwark", E, 1, F)
	var p_hp: int = p.hp
	var p_atk: int = c.effective_atk(p)
	c.use_power([[E, F, 1]])
	check(p.hp == p_hp - 3, "tier 3: Pride of the Lioness bites for 3")
	check(c.effective_atk(p) == maxi(0, p_atk - 1), "tier 3: Pestilence, Poisoned enemies -1 ATK")


func test_power_cooldown() -> void:
	var run = Run.new()
	run.setup(5, "myrmidon", "zeus_lightning_bolt")
	var by_floor := {}
	for i in run.nodes.size():
		if run.nodes[i]["type"] in ["fight", "elite"] and not by_floor.has(run.nodes[i]["floor"]):
			by_floor[run.nodes[i]["floor"]] = i
	var first: int = by_floor.keys().min()
	run.current = by_floor[first]
	run.battle_id = "swarm"
	run.state = "combat"
	var c = run.make_combat()
	check(c.power_uses == 1, "cooldown: charged in the first fight")
	c.power_invoked = true
	c.result = "win"
	run.finish_combat(c)
	var used_on: int = first + 1
	check(run.power_ready_floor == used_on + Data.POWER_COOLDOWN_FLOORS + 1, "cooldown: ready %d floors later" % Data.POWER_COOLDOWN_FLOORS)
	for f in by_floor:
		run.current = by_floor[f]
		var fight = run.make_combat()
		var floor_num: int = f + 1
		if floor_num <= used_on:
			continue
		var expect_ready: bool = floor_num > used_on + Data.POWER_COOLDOWN_FLOORS
		check((fight.power_uses == 1) == expect_ready, "cooldown: floor %d charged = %s" % [floor_num, expect_ready])
		if not expect_ready:
			check(fight.power_targets().is_empty() and fight.use_power([[E, F, 0]]).begins_with("Your god power is recharging"), "cooldown: can't use while recharging")
	run.current = by_floor[first]
	c = run.make_combat()
	c.power_invoked = false
	run.power_ready_floor = 0
	c.result = "win"
	run.finish_combat(c)
	check(run.power_ready_floor == 0, "cooldown: an unused power stays charged")


func test_power_upgrades() -> void:
	var run = Run.new()
	run.setup(1, "myrmidon", "poseidons_tide")
	check(run.power == "poseidons_tide" and run.main_pantheon() == "greek", "upgrades: chosen power")
	check(run.pending_upgrades() == 0, "upgrades: none at start")
	run.add_card("faith_surge")
	run.add_card("hoplite")
	check(run.devotion == 1 and run.foreign == 0, "upgrades: neutral cards don't count")
	var first: int = Data.POWER_THRESHOLDS[0]
	var second: int = Data.POWER_THRESHOLDS[1]
	while run.devotion < first - 1:
		run.add_card("hoplite")
	check(run.pending_upgrades() == 0, "upgrades: nothing one card short of the first threshold")
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
	check(run.pending_upgrades() == 0, "upgrades: other pantheons don't count toward devotion")
	while run.devotion < second:
		run.add_card("hoplite")
	check(run.foreign == 3 and run.devotion == second and run.pending_upgrades() == 1, "upgrades: counts by pantheon")
	options = run.upgrade_options()
	options.sort()
	check(options == ["pact", "undertow_1", "wave_2"], "upgrades: tier 2 and Pact open (%s)" % [options])
	run.choose_upgrade("pact")
	check(run.power_state()["nodes"] == ["wave_1", "pact"], "upgrades: passed to fights")
	run.power_nodes = ["wave_1", "wave_2", "pact"]
	run.devotion = Data.TIER3_DEVOTION - 1
	check(not run.upgrade_options().has("wave_3"), "upgrades: tier 3 locked below the devotion gate")
	run.devotion = Data.TIER3_DEVOTION
	check(run.upgrade_options().has("wave_3"), "upgrades: tier 3 opens at the devotion gate")
	run.power_nodes = ["wave_1", "pact"]
	run.devotion = second
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
	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0], ["void_spawn", 1, 0], ["void_spawn", 2, 0]], "terrain": [],
		"enemy_bonus": {"atk": 2, "hp": 6, "count": 2, "rounds": 0}}, [], [], 7)
	empowered = c.units(E).filter(func(u): return u.empowered)
	check(empowered.size() == 2 and empowered.all(func(u): return u.atk == 4 and u.hp == 9), "empower: count 2 empowers two different enemies")
	c = Combat.new()
	c.setup({"core": 50, "enemies": [["void_spawn", 0, 0]], "terrain": [],
		"enemy_bonus": {"atk": 2, "hp": 6, "count": 3, "rounds": 0}}, [], [], 7)
	check(c.units(E)[0].atk == 4, "empower: count above the enemy count buffs each enemy once")
	var run = Run.new()
	run.setup(1, "shieldmaiden")
	for id in run.nodes.size():
		run.current = id
		var expected: int = run.nodes[id]["floor"] / Data.BALANCE["scaling_every_floors"] * Data.BALANCE["scaling_rounds"]
		if run.nodes[id]["type"] == "boss":
			check(run.enemy_bonus()["count"] == 0 and run.enemy_bonus()["rounds"] == 0, "boss fight has no floor scaling")
		else:
			var steps: int = run.nodes[id]["floor"] / Data.BALANCE["scaling_every_floors"]
			check(run.enemy_bonus()["rounds"] == expected, "round scaling: floor %d bonus" % run.nodes[id]["floor"])
			check(run.enemy_bonus()["count"] == steps * Data.BALANCE["empowered_per_step"], "empower count: floor %d" % run.nodes[id]["floor"])


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
		_check_map_path_caps(run, tag)


func _check_map_path_caps(run, tag: String) -> void:
	for start in run.floors[0]:
		_dfs_check_path_caps(run, start, {}, tag)


func _dfs_check_path_caps(run, id: int, counts: Dictionary, tag: String) -> void:
	var type: String = run.nodes[id]["type"]
	var next: Dictionary = counts.duplicate()
	if Run.PATH_CAPS.has(type):
		next[type] = int(next.get(type, 0)) + 1
	if run.nodes[id]["edges"].is_empty():
		for capped in Run.PATH_CAPS:
			check(int(next.get(capped, 0)) <= Run.PATH_CAPS[capped],
					"%s: path has %d %ss (max %d)" % [tag, int(next.get(capped, 0)), capped, Run.PATH_CAPS[capped]])
		return
	for e in run.nodes[id]["edges"]:
		_dfs_check_path_caps(run, e, next, tag)


func test_reward_rule() -> void:
	for s in range(1, 201):
		var run = Run.new()
		run.setup(s, "myrmidon")
		var picks: Array = run._card_choices(Data.ACTS[0]["normal_odds"], run.reward_rng)
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
				check(not run._card_choices(Data.ACTS[0]["elite_odds"], run.reward_rng).has(id), "curse: %s never offered as a reward" % id)


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
			check(not run._card_choices(Data.ACTS[0]["elite_odds"], run.reward_rng).has(id), "status: %s never offered as a reward" % id)


func test_event_data() -> void:
	var fx_keys := ["gold", "hp", "max_hp", "card", "curse", "relic", "remove", "remove_random", "choose", "goto", "lose_relic"]
	var act2_events: Array = Data.EVENTS.keys().filter(func(id): return Data.EVENTS[id].get("act", 1) == 2)
	check(act2_events.size() >= 4, "events: Act 2 has its own events")
	var run = Run.new()
	run.setup(3, "myrmidon")
	for n in 60:
		run._pick_event()
		check(Data.EVENTS[run.shrine["event"]].get("act", 1) <= 1, "events: no Act 2 event in Act 1 (%s)" % run.shrine["event"])
	run.act = 2
	run.seen_events.clear()
	var seen := {}
	for n in Data.EVENTS.size():
		run._pick_event()
		seen[run.shrine["event"]] = true
	check(seen.size() == Data.EVENTS.size(), "events: Act 2 cycles through every event before repeating")
	run.relics = ["obol", "sun_disk"]
	run.start_event("lethes_spring")
	var notes: Array = run._apply_fx({"lose_relic": true})
	check(run.relics.size() == 1 and notes.size() == 1, "events: lose_relic removes one relic")
	# Omens Tablet triples rare-event weights (weight < EVENT_WEIGHT).
	check(Data.RELICS.has("omens_tablet") and Data.RELICS["omens_tablet"].get("pool", true), "events: Omens Tablet is in the relic pool")
	check(ResourceLoader.exists("res://art/relics/omens_tablet.png"), "events: Omens Tablet has art")
	var rare_ids: Array = Data.EVENTS.keys().filter(func(id): return Data.EVENTS[id].get("weight", Data.EVENT_WEIGHT) < Data.EVENT_WEIGHT)
	check(rare_ids.size() >= 2, "events: at least two rare-weight events exist")
	var trials := 400
	var without := _rare_event_hits(42, trials, [])
	var with_tablet := _rare_event_hits(42, trials, ["omens_tablet"])
	check(with_tablet >= without * 2, "events: Omens Tablet at least doubles rare picks (%d vs %d / %d)" % [with_tablet, without, trials])
	for ev_id in Data.EVENTS:
		var ev: Dictionary = Data.EVENTS[ev_id]
		if ev_id != "pantheon_shrine":
			check(ResourceLoader.exists("res://art/events/%s.jpg" % ev_id), "event %s has art" % ev_id)
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
							check(fx[key] in ["any", "pantheon", "Divine", "amalgam"] or Run.RARITY_ONLY.has(fx[key]), "event %s: %s pool" % [ev_id, key])


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


## Beating an act boss heals half the missing HP, grants a free upgrade and opens a fresh map with
## a different boss; the last act's boss ends the run.
func test_acts() -> void:
	for s in range(1, 21):
		var run = Run.new()
		run.setup(s, "shieldmaiden", "tyrs_oath")
		check(run.act == 1 and run.boss_ids.size() == Data.ACTS.size(), "acts: one boss per act")
		check(run.boss_ids.size() == Data.ACTS.size() and run.boss_ids[0] != run.boss_ids[1], "acts: no boss repeats")
		check(run.boss_id == run.boss_ids[0], "acts: act 1 boss first")
		var boss_node: int = run.floors[Run.FLOORS - 1][0]
		run.current = boss_node
		run.battle_id = run._pick_battle("boss", Run.FLOORS - 1)
		run.state = "combat"
		run.core_hp = 21
		run.power_ready_floor = 99
		var c = run.make_combat()
		check(not c.battle.has("boss_bonus") or c.battle["boss_bonus"].is_empty(), "acts: act 1 boss has no bonus")
		c.result = "win"
		c.core_hp = 21
		run.finish_combat(c)
		check(run.state == "act_complete", "acts: act 1 boss leads to the act-complete screen")
		check(run.core_hp == 21 + ceili((run.max_hp - 21) * Data.ACT_HEAL), "acts: heals half the missing HP")
		check(run.pending_upgrades() == 1, "acts: a free upgrade is pending")
		run.start_next_act()
		check(run.act == 2 and run.state == "map" and run.current == -1 and run.path.is_empty(), "acts: act 2 starts fresh")
		check(run.boss_id == run.boss_ids[1], "acts: act 2 boss")
		check(run.power_charged(1), "acts: power recharged")
		check(run.nodes.size() > 0 and run.floors.size() == Run.FLOORS, "acts: act 2 map generated")
		run.enter_node(run.available_nodes()[0])
		if run.state == "combat":
			check(run.enemy_bonus()["count"] >= Data.ACTS[1]["empower_steps"], "acts: act 2 floor 1 is Empowered")
			check(Data.BATTLE_POOLS[run.battle_id] == Data.ACTS[1]["pools"][run.battle_pool], "acts: act 2 draws from its pool")
		run.current = run.floors[Run.FLOORS - 1][0]
		run.battle_id = run._pick_battle("boss", Run.FLOORS - 1)
		run.state = "combat"
		c = run.make_combat()
		var boss_unit = c.units(E).filter(func(u): return Data.unit_def(u.id).get("kind", "") == "boss")[0]
		var base: Dictionary = Data.ENEMIES[boss_unit.id]
		check(boss_unit.max_hp == base["hp"] + Data.ACTS[1]["boss_bonus"].get("hp", 0), "acts: act 2 boss gets its act's bonus HP")
		check(Data.BATTLE_POOLS[run.boss_id] == "act2_boss" and base.get("act", 1) == 2, "acts: act 2 has its own bosses")
		check(c.units(E).filter(func(u): return Data.unit_def(u.id).get("kind", "") != "boss").all(func(u): return u.max_hp == Data.ENEMIES[u.id]["hp"]), "acts: boss minions get no bonus")
		c.result = "win"
		run.finish_combat(c)
		check(run.state == "victory", "acts: the last act's boss wins the run")


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
				"act_complete":
					check(not run.is_final_act(), "%s: act complete only before the last act" % tag)
					run.start_next_act()
					check(run.state == "map" and run.current == -1, "%s: next act starts on a fresh map" % tag)
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
		"ally", "ally_card", "ally_slot", "enemy", "enemy_burning", "empty_ally_slot":
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
			if c.slot_open(P, row, lane):
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
				if side == P and u.lane == lane:
					check(u.id == "talos" or u.armaments.size() <= 1, "%s: %s holds %d Armaments" % [tag, u.id, u.armaments.size()])
	var statuses := 0
	var armed: Array = []
	for u in c.units(P):
		armed.append_array(u.armaments)
	for pile in [c.hand, c.deck, c.discard, c.exhausted, c.claimed, armed]:
		for card in pile:
			check(not cids.has(card["cid"]), "%s: card %s is in two places" % [tag, card["id"]])
			cids[card["cid"]] = true
			if card.get("forged", false):
				statuses += 1
			elif Data.CARDS[card["id"]]["type"] == "status":
				statuses += 1
				check(not c.discard.has(card), "%s: a status card reached the discard pile" % tag)
	check(cids.size() - statuses == total_cards, "%s: card count %d != %d" % [tag, cids.size() - statuses, total_cards])


func test_continue_run() -> void:
	var saved_path := RunSave.path
	RunSave.path = "user://run_save_test.save"
	RunSave.clear()
	var run = Run.new()
	run.setup(42, "myrmidon", "zeus_lightning_bolt")
	RunSave.write(run)
	var loaded = RunSave.read()
	check(loaded != null and RunSave.describe(loaded) == "Greek · Act 1 · The Reliquary", "continue: a new run resumes at the Reliquary")
	check(typeof(loaded.nodes[0]["id"]) == TYPE_INT, "continue: node ids stay integers")
	check(_map_sig(loaded) == _map_sig(run), "continue: the map is unchanged")
	var roll_state: int = run.reward_rng.state
	var expected_roll := int(run.reward_rng.randi())
	run.reward_rng.state = roll_state
	RunSave.write(run)
	loaded = RunSave.read()
	check(loaded.reward_rng.randi() == expected_roll, "continue: reward rolls resume where they stopped")
	check(run.enter_node(run.available_nodes()[0]) == "" and run.state == "combat", "continue: the first node is a fight")
	RunSave.write(run)
	loaded = RunSave.read()
	check(loaded.state == "combat" and loaded.battle_id == run.battle_id and loaded.current == run.current, "continue: a fight saves its battle")
	check(RunSave.describe(loaded).ends_with("battle restarts"), "continue: a saved fight says the battle restarts")
	check(_board_sig(run.make_combat()) == _board_sig(loaded.make_combat()), "continue: the battle is rebuilt the same way")
	var c = run.make_combat()
	c.result = "win"
	c.round_num = c.max_rounds
	run.finish_combat(c)
	check(run.state == "reward" and run.reward["cards"].size() == 3, "continue: a win opens a card reward")
	var pre_deck: Array = run.deck.duplicate()
	var pre_devotion: int = run.devotion
	var picked: String = run.reward["cards"][0]
	run.finish_reward(0)
	check(run.state == "map" and run.deck.has(picked) and not run.reward_checkpoint.is_empty(), "continue: picking a card reaches the map with a reward checkpoint")
	RunSave.write(run)
	loaded = RunSave.read()
	check(loaded.state == "reward" and loaded.deck == pre_deck and loaded.devotion == pre_devotion, "continue: saving from the map after a reward rewinds to that reward")
	check(loaded.reward["cards"] == run.reward_checkpoint["reward"]["cards"], "continue: the rewound reward keeps the same card choices")
	check(run.enter_node(run.available_nodes()[0]) == "", "continue: entering a node after a reward commits the pick")
	check(run.reward_checkpoint.is_empty() and run.deck.has(picked), "continue: the checkpoint clears once a node is entered")
	RunSave.write(run)
	loaded = RunSave.read()
	check(loaded.state == run.state and loaded.deck.has(picked), "continue: after entering a node the picked card stays saved")
	var shop_run = Run.new()
	shop_run.setup(9, "shieldmaiden", "tyrs_oath")
	shop_run.gold = 200
	shop_run.core_hp = 40
	shop_run._generate_shop()
	shop_run.state = "shop"
	check(shop_run.buy_card(0) == "", "continue: the shop sale is legal")
	var shop_state: int = shop_run.shop_rng.state
	var shop_roll := int(shop_run.shop_rng.randi())
	shop_run.shop_rng.state = shop_state
	RunSave.write(shop_run)
	loaded = RunSave.read()
	check(loaded.gold == shop_run.gold and loaded.deck == shop_run.deck and loaded.devotion == shop_run.devotion, "continue: a shop purchase is kept")
	check(loaded.shop["cards"][0]["sold"] and loaded.core_hp == 40, "continue: sold stock and Core HP are kept")
	check(loaded.shop_rng.randi() == shop_roll, "continue: shop rolls resume where they stopped")
	var shrine_run = Run.new()
	shrine_run.setup(11, "mummy_guardian", "osiris_return")
	shrine_run._pick_event()
	shrine_run.state = "shrine"
	RunSave.write(shrine_run)
	loaded = RunSave.read()
	check(loaded.shrine["event"] == shrine_run.shrine["event"] and loaded.seen_events == shrine_run.seen_events, "continue: the shrine event is kept")
	var bad: Dictionary = run.to_save()
	bad["deck"] = ["not_a_card"]
	var f := FileAccess.open(RunSave.path, FileAccess.WRITE)
	f.store_var(bad)
	f.close()
	check(RunSave.read() == null, "continue: an unknown card rejects the save")
	f = FileAccess.open(RunSave.path, FileAccess.WRITE)
	f.store_var({"version": 9})
	f.close()
	check(RunSave.read() == null, "continue: a future save version is ignored")
	f = FileAccess.open(RunSave.path, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	check(RunSave.read() == null, "continue: a damaged file is ignored")
	RunSave.clear()
	check(RunSave.read() == null, "continue: clearing the save removes it")
	RunSave.path = saved_path


func test_economy() -> void:
	var run = Run.new()
	run.setup(3, "myrmidon", "zeus_lightning_bolt")
	check(run.enter_node(run.available_nodes()[0]) == "", "economy: the first node is a fight")
	var c = run.make_combat()
	c.result = "win"
	c.round_num = 1
	c.max_rounds = 3
	run.finish_combat(c)
	check(run.reward["gold"] == 25, "economy: a round-1 win pays 15 plus 5 for each of 2 spare rounds")
	run = Run.new()
	run.setup(4, "shieldmaiden", "tyrs_oath")
	run.enter_node(run.available_nodes()[0])
	run.nodes[run.current]["type"] = "elite"
	c = run.make_combat()
	c.result = "win"
	c.round_num = 2
	c.max_rounds = 4
	run.finish_combat(c)
	check(run.reward["gold"] == 40, "economy: an elite finished with 2 rounds spare pays 30 plus 10")
	run = Run.new()
	run.setup(5, "mummy_guardian", "osiris_return")
	run.enter_node(run.available_nodes()[0])
	c = run.make_combat()
	c.result = "timeout"
	c.round_num = 3
	c.max_rounds = 3
	run.finish_combat(c)
	check(run.reward["gold"] == 0, "economy: a timeout pays nothing")
	run = Run.new()
	run.setup(6, "myrmidon", "zeus_lightning_bolt")
	run.gold = 400
	run.core_hp = 20
	run.act = 2
	check(run.card_price("augury") == 29 and run.card_price("athena") == 46 and run.card_price("thor") == 69, "economy: Act 2 card prices follow rarity")
	check(run.relic_price("pilgrims_pouch") == 57 and run.relic_price("laurel_wreath") == 81 and run.relic_price("golden_fleece") == 115, "economy: Act 2 relic prices follow rarity")
	run.act = 1
	run._generate_shop()
	run.state = "shop"
	check(run.card_price("augury") == 25 and run.relic_price("golden_fleece") == 100, "economy: Act 1 keeps the base rarity prices")
	for id in ["shield_raid", "olympian_ichor", "sphinx", "eye_of_ra", "broodwarden"]:
		check(run.card_price(id) == 25, "economy: %s is priced as a Common" % Data.CARDS[id]["name"])
	check(run.card_price("harpe") == 40, "economy: Harpe stays an Uncommon")
	check(run.remove_price() == 50 and run.buy_remove(0) == "" and run.remove_price() == 75, "economy: removal costs 25 more each time")
	check(run.heal_price() == 40 and run.buy_heal() == "" and run.core_hp == 30 and run.heal_price() == 60, "economy: healing costs 20 more each time")
	check(run.can_buy_remove() and run.can_buy_heal(), "economy: both services stay available")


func test_fusion_cards() -> void:
	var c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("line_captain", P, 1, F)
	var left = c.debug_place("peltast", P, 0, F)
	var right = c.debug_place("peltast", P, 2, F)
	c.end_plan()
	check(left.atk == 4 and right.atk == 4, "fusion: Line Captain rallies Greek neighbours for 2")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var bearer = c.debug_place("ark_sentinel", P, 1, F)
	var kin = c.debug_place("ark_sentinel", P, 2, F)
	var outsider = c.debug_place("peltast", P, 0, F)
	c.hand = [c._new_card("ash_spear")]
	c.faith = 5
	check(c.play_spell(0, [[P, F, 1]]) == "", "fusion: Ash Spear attaches")
	c.end_plan()
	check(kin.atk == 3 and outsider.atk == 2 and bearer.atk == 2, "fusion: Ash Spear gives the bearer Rally 1 for its own faction")
	check(c.effective_atk(bearer) == 4, "fusion: Ash Spear still grants +2 ATK")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.deck = [c._new_card("ark_sentinel"), c._new_card("ark_sentinel")]
	c.hand = [c._new_card("sybil"), c._new_card("warding"), c._new_card("divine_favor")]
	c.discard = []
	c.faith = 5
	check(c.play_unit(0, 0, B) == "", "fusion: Sybil deploys")
	var sybil = c.unit_at(P, B, 0)
	check(c.play_spell(0, [[P, B, 0]]) == "" and c.hand.size() == 2, "fusion: Sybil draws on the first spell")
	check(sybil.effect_used and not c.can_reposition(sybil), "fusion: Sybil's draw locks a fresh deployment")
	check(c.hand[0]["id"] == "divine_favor" and c.play_spell(0, [[P, B, 0]]) == "" and c.hand.size() == 1, "fusion: Sybil draws only once each round")

	c = fresh()
	var foe = c.debug_place("hollowed_zealot", E, 1, F)
	c.debug_place("daedalus", P, 1, B)
	c.hand = [c._new_card("divine_favor"), c._new_card("bronze_spear")]
	c.faith = 5
	check(c.card_cost(c.hand[1]) == 0, "fusion: Daedalus discounts the first Armament")
	check(c.play_spell(0, [[P, B, 1]]) == "" and foe.hp == 4, "fusion: Daedalus strikes the first enemy in his lane")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	var chorus = c.debug_place("chorus_of_delphi", P, 1, B)
	var singer = c.debug_place("peltast", P, 2, B)
	var norse = c.debug_place("berserker", P, 0, B)
	c.hand = [c._new_card("divine_favor")]
	c.faith = 5
	check(c.play_spell(0, [[P, B, 0]]) == "", "fusion: Chorus hears a spell")
	check(chorus.temp_atk == 1 and singer.temp_atk == 1 and norse.temp_atk == 2, "fusion: Chorus buffs Greek allies in its row this round")

	c = fresh()
	c.deck = [c._new_card("ark_sentinel"), c._new_card("ark_sentinel"), c._new_card("ark_sentinel")]
	c.hand = [c._new_card("death_rite")]
	c.discard = []
	c.faith = 5
	c.debug_place("raven_of_odin", P, 0, F)
	check(c.play_spell(0, [[P, F, 0]]) == "" and c.hand.size() == 3, "fusion: Death Rite draws 2 when the ally has On-Death")
	c = fresh()
	c.deck = [c._new_card("ark_sentinel"), c._new_card("ark_sentinel")]
	c.hand = [c._new_card("death_rite")]
	c.discard = []
	c.faith = 5
	c.debug_place("ark_sentinel", P, 0, F)
	check(c.play_spell(0, [[P, F, 0]]) == "" and c.hand.size() == 1, "fusion: Death Rite draws 1 otherwise")

	c = fresh()
	var raid = c.debug_place("shield_raid", P, 0, F)
	check(c.move_unit(0, F, 1, F) == "" and raid.shield == 2, "fusion: Shieldthane gains Shield 2 when it moves")

	c = fresh()
	var charge = c.debug_place("reckless_charge", P, 0, F)
	check(c.move_unit(0, F, 1, F) == "" and charge.hp == 3, "fusion: Doomrunner takes 1 when it moves")
	var front_foe = c.debug_place("hollowed_bulwark", E, 1, F)
	var back_foe = c.debug_place("hollowed_bulwark", E, 1, B)
	c._deal_damage(charge, 99, "effect")
	check(front_foe.hp == 5 and back_foe.hp == 5, "fusion: Doomrunner blasts its lane for its ATK")

	c = fresh()
	var wolf = c.debug_place("wolf", P, 0, F)
	var carrion = c.debug_place("carrion_wolf", P, 1, F)
	c._deal_damage(carrion, 99, "effect")
	check(wolf.atk == 2, "fusion: Carrion Wolf gives other Wolves +1 ATK")

	c = fresh()
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("wolf", P, 1, F)
	var runner = c.debug_place("packrunner", P, 0, F)
	c.moves_left = 2
	check(c.move_unit(0, F, 1, B) == "" and runner.has_kw("flank"), "fusion: Packrunner gains Flank behind a Wolf")
	check(c.move_unit(1, B, 2, B) == "" and runner.bonus_kw.size() == 1, "fusion: Packrunner gains Flank only once")

	c = fresh()
	var hunted = c.debug_place("hollowed_zealot", E, 0, F)
	hunted.hp = 30
	hunted.max_hp = 30
	c.debug_place("hollowed_bulwark", E, 3, B)
	c.debug_place("wolf", P, 0, F)
	var back_wolf = c.debug_place("wolf", P, 0, B)
	c.hand = [c._new_card("hunting_cry")]
	c.faith = 5
	check(c.play_spell(0, []) == "", "fusion: Hunting Cry resolves")
	c.end_plan()
	check(back_wolf.attacked_round == 1 and hunted.hp == 24, "fusion: Hunting Cry gives Wolves Flank and +1 ATK")

	c = fresh()
	var named = c.debug_place("mummy_guardian", P, 0, F)
	c.debug_place("namesake", P, 2, F)
	c._deal_damage(named, 99, "effect")
	check(named.alive and named.hp == 1 and named.atk == 3, "fusion: Namesake gives +1 ATK on Revive")

	c = fresh()
	c.debug_place("broodwarden", P, 0, B)
	var bug = c._spawn("scarab", P, 1, F)
	check(bug.shield == 2, "fusion: Broodwarden gives a summoned Scarab Shield 2")

	c = fresh()
	c.terrain[c._key(P, F, 0)] = "sunlit"
	var sunner = c.debug_place("ark_sentinel", P, 0, F)
	var shaded = c.debug_place("ark_sentinel", P, 1, F)
	c.debug_place("high_noon", P, 2, B)
	check(c.effective_atk(sunner) == 4 and c.effective_atk(shaded) == 2, "fusion: Noon Sentinel adds ATK on Sunlit slots")

	c = fresh()
	var host = c.debug_place("undying_host", P, 0, F)
	c._deal_damage(host, 99, "effect")
	var hatched = c.unit_at(P, B, 0)
	check(host.alive and host.hp == 1 and hatched != null and hatched.id == "scarab", "fusion: Undying Host revives and leaves a Scarab behind")

	c = fresh()
	var mummy = c.debug_place("mummy_of_aten", P, 0, F)
	var burned = c.debug_place("hollowed_bulwark", E, 0, F)
	c._attack(mummy, burned, 3)
	check(burned.burn == 0, "fusion: Mummy of Aten does not Burn off Sunlit")
	c.terrain[c._key(P, F, 0)] = "sunlit"
	var burned2 = c.debug_place("hollowed_bulwark", E, 1, F)
	c._attack(mummy, burned2, 3)
	check(burned2.burn == 2, "fusion: Mummy of Aten applies Burn 2 while Sunlit")

	c = fresh()
	c.terrain[c._key(P, F, 3)] = "sunlit"
	c.debug_place("solar_scarab", P, 1, F)
	var scarab = c.debug_place("scarab", P, 0, F)
	var target = c.debug_place("hollowed_bulwark", E, 0, F)
	c._attack(scarab, target, 1)
	check(target.burn == 1, "fusion: Solar Scarab makes Scarabs Burn while a slot is Sunlit")
	var body = c.unit_at(P, F, 1)
	c._deal_damage(body, 99, "effect")
	check(c.unit_at(P, F, 1) != null and c.unit_at(P, F, 1).id == "scarab", "fusion: Solar Scarab summons a Scarab when it dies")

	c = fresh()
	var armed = c.debug_place("ark_sentinel", P, 0, F)
	c.hand = [c._new_card("whetstone")]
	c.deck = []
	c.discard = []
	c.faith = 5
	check(c.play_spell(0, [[P, F, 0]]) == "", "fusion: Whetstone attaches")
	c._deal_damage(armed, 99, "effect")
	check(c.hand.size() == 1 and c.hand[0]["id"] == "whetstone" and c.deck.is_empty(), "fusion: Whetstone returns to hand")
	c = fresh()
	armed = c.debug_place("ark_sentinel", P, 0, F)
	armed.armaments.append(c._new_card("whetstone"))
	c.hand = []
	for i in 7:
		c.hand.append(c._new_card("ark_sentinel"))
	c.deck = []
	c._deal_damage(armed, 99, "effect")
	check(c.hand.size() == 7 and c.deck.size() == 1 and c.deck[0]["id"] == "whetstone", "fusion: a full hand sends Whetstone to the draw pile")

	var run = Run.new()
	run.setup(1, "shieldmaiden")
	check(run._card_pool("Rare", ["norse"], []).has("packrunner"), "fusion: the new cards are in the draft")
	check("flank" in CardWidget.glossary_icons(Data.CARDS["hunting_cry"], "hunting_cry"), "fusion: Hunting Cry explains Flank")
	check("rally" in CardWidget.glossary_icons(Data.CARDS["ash_spear"], "ash_spear"), "fusion: Ash Spear explains Rally")


func _map_sig(run) -> String:
	var parts: PackedStringArray = []
	for n in run.nodes:
		var edges := ""
		for e in n["edges"]:
			edges += str(e) + ","
		parts.append("%s:%s" % [n["type"], edges])
	return "|".join(parts)


func _board_sig(c) -> String:
	var parts: PackedStringArray = []
	for side in 2:
		for row in 2:
			for lane in 4:
				var u = c.grid[side][row][lane]
				parts.append("-" if u == null else "%s%d" % [u.id, u.hp])
	return "|".join(parts)
