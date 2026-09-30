extends SceneTree
## Captures run-screen screenshots for a quick visual check (needs a window, not --headless):
##   godot --path . --script res://tests/screenshot_run.gd -- <output_folder>


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OS.get_user_data_dir()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.seed_box.value = 7
	main._start_run("myrmidon")
	var view = main.run_view
	var run = view.run
	await _frames(5)
	_save(out_dir + "/run_map_start.png")

	view._on_node_pressed(run.available_nodes()[0])
	await _frames(5)
	_save(out_dir + "/run_combat.png")

	view.battle_view.map_requested.emit()
	await _frames(5)
	_save(out_dir + "/run_combat_map.png")
	view.battle_view.deck_requested.emit()
	await _frames(5)
	_save(out_dir + "/run_combat_deck.png")
	view._close_overlay()

	var c = view.battle_view.combat
	c.result = "win"
	c.phase = "over"
	view._on_combat_finished(c)
	await _frames(5)
	_save(out_dir + "/run_reward.png")

	view._take_reward(0)
	view._on_node_pressed(run.available_nodes()[0])
	if run.state == "combat":
		var c2 = view.battle_view.combat
		c2.result = "win"
		c2.phase = "over"
		view._on_combat_finished(c2)
		view._take_reward(-1)
	await _frames(5)
	_save(out_dir + "/run_map_progress.png")

	run.gold = 120
	run._generate_shop()
	run.state = "shop"
	view._show()
	await _frames(5)
	_save(out_dir + "/run_shop.png")

	run._pick_event()
	run.state = "shrine"
	view._show()
	await _frames(5)
	_save(out_dir + "/run_shrine.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
