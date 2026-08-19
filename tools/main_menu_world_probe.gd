extends SceneTree

## 无截图主界面验收：运行时验证世界、完整格、角色脚锚和入口几何。

const ProfileStore := preload("res://src/core/player_profile.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProfileStore.save_enabled = false
	var packed := load("res://src/ui/main_menu.tscn") as PackedScene
	if packed == null:
		push_error("MAIN_MENU_PROBE: scene load failed")
		quit(1)
		return
	var menu := packed.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame
	var world := menu.get_node_or_null("MenuWorld") as MainMenuWorld
	if world == null:
		push_error("MAIN_MENU_PROBE: MenuWorld missing")
		quit(1)
		return
	var contract: Dictionary = world.get_visual_contract()
	var failures: Array[String] = []
	if not bool(contract.get("presentation_only", false)):
		failures.append("world is not presentation-only")
	if not bool(contract.get("uniform_grass_only", false)):
		failures.append("main menu ground is not uniform grass")
	if not bool(contract.get("click_to_move", false)):
		failures.append("main menu click-to-move is not connected")
	if Vector2(contract.get("view_size", Vector2.ZERO)) \
			/ float(contract.get("rendered_cell", 1.0)) != Vector2(13.0, 7.0):
		failures.append("viewport does not end on complete cells")
	if int(contract.get("ground_cell_count", 0)) != 576:
		failures.append("ground cell count mismatch")
	if int(contract.get("hero_frame_count", 0)) <= 0:
		failures.append("hero idle frames missing")
	for path: String in ["UI/ModeMatch", "UI/ModeStory", "UI/ModeTower"]:
		var entry := menu.get_node_or_null(path) as MainMenuEntry
		if entry == null or not entry.visible or entry.disabled:
			failures.append("entry unavailable: %s" % path)
	var target: Vector2i = world.HOME_CELL + Vector2i.LEFT * 2
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world._view_position_for_cell(target)
	world._on_map_view_gui_input(click)
	var movement_deadline: int = Time.get_ticks_msec() + 3000
	while Vector2i(world.get("_current_cell")) != target \
			and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if Vector2i(world.get("_current_cell")) != target:
		failures.append("main menu click route did not reach target")
	var key_target: Vector2i = target + Vector2i.UP * 3
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_W
	key_event.pressed = true
	Input.parse_input_event(key_event)
	for _index: int in 3:
		var echo_event := InputEventKey.new()
		echo_event.keycode = KEY_W
		echo_event.pressed = true
		echo_event.echo = true
		Input.parse_input_event(echo_event)
	movement_deadline = Time.get_ticks_msec() + 3000
	while Vector2i(world.get("_current_cell")) != key_target \
			and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if Vector2i(world.get("_current_cell")) != key_target:
		failures.append("main menu WASD movement did not reach adjacent cell")
	contract["wasd_verified"] = Vector2i(world.get("_current_cell")) == key_target
	contract["held_wasd_steps"] = 3
	contract["final_cell"] = Vector2i(world.get("_current_cell"))
	if not failures.is_empty():
		push_error("MAIN_MENU_PROBE: %s" % "; ".join(failures))
		quit(1)
		return
	print("MAIN_MENU_PROBE_OK ", JSON.stringify(contract))
	quit(0)
