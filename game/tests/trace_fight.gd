extends SceneTree
## Prints the full log of the balance bot playing one battle.
##   godot --headless --path . --script res://tests/trace_fight.gd -- <battle_id> [seed] [floor_steps]

const Data = preload("res://scripts/core/data.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Sim = preload("res://tests/balance_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var battle_id: String = args[0] if args.size() > 0 else "fenrir"
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var steps := int(args[2]) if args.size() > 2 else 1
	var battle: Dictionary = {}
	for b in Data.BATTLES:
		if b["id"] == battle_id:
			battle = b.duplicate(true)
	battle["core"] = 40
	battle["enemy_bonus"] = {"atk": Data.BALANCE["empower_atk"] if steps > 0 else 0, "hp": Data.BALANCE["empower_hp"] if steps > 0 else 0,
		"count": steps * Data.BALANCE["empowered_per_step"], "rounds": steps * Data.BALANCE["scaling_rounds"]}
	var deck: Array = Data.STARTER + ["shieldmaiden", "einherjar", "hoplite"]
	var c = Combat.new()
	c.setup(battle, deck, [], seed_value)
	var bot = Sim.new()
	var guard := 0
	while c.phase == "plan" and guard < 20:
		guard += 1
		print("== Plan round %d: faith %d, hand %s" % [c.round_num, c.faith, c.hand.map(func(card): return card["id"])])
		for step in 10:
			if c.phase != "plan":
				break
			var before: int = c.hand.size()
			if not bot._play_best_card(c):
				break
			for ev in c.events:
				print("   " + ev["text"])
			if c.hand.size() == before and c.phase == "plan":
				break
		if c.phase == "plan":
			for ev in c.end_plan():
				print(ev["text"])
	print("RESULT: %s, core %d" % [c.result, c.core_hp])
	bot.free()
	quit()
