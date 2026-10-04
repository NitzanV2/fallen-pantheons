extends SceneTree
## Captures UI screenshots for a quick visual check (needs a window, not --headless):
##   godot --path . --script res://tests/screenshot.gd -- <output_folder>

const Data = preload("res://scripts/core/data.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OS.get_user_data_dir()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_save(out_dir + "/shot_menu.png")
	main._show_sandbox(true)
	await _frames(3)
	_save(out_dir + "/shot_sandbox.png")

	main._start_battle(Data.BATTLES[1])
	var view = main.battle_view
	view._new_combat(42)
	var c = view.combat
	var lane := 0
	for i in range(c.hand.size() - 1, -1, -1):
		var def: Dictionary = c.card_def(c.hand[i])
		if def["type"] == "unit" and c.can_afford(i) and lane < 3:
			c.play_unit(i, lane, 0)
			lane += 1
	view._refresh()
	for i in c.hand.size():
		if c.can_afford(i):
			view._on_hand_pressed(i)
			break
	await _frames(5)
	_save(out_dir + "/shot_plan.png")

	view._on_cancel_pressed()
	view._on_end_pressed()
	view.skip_animation = true
	await create_timer(1.5).timeout
	await _frames(5)
	_save(out_dir + "/shot_after_round.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
