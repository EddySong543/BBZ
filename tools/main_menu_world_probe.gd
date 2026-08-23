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
	await create_timer(1.1).timeout
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
	if not bool(contract.get("shared_movement_controller", false)):
		failures.append("main menu is not using shared expedition movement")
	if String(contract.get("movement_controller_script", "")) \
			!= "res://src/expedition/grid_movement_controller.gd":
		failures.append("main menu movement controller path mismatch")
	var view_size := Vector2(contract.get("view_size", Vector2.ZERO))
	var rendered_cell_size := Vector2(
			contract.get("rendered_cell_size", Vector2.ZERO))
	if view_size != Vector2(1920.0, 1080.0):
		failures.append("map viewport does not cover the 1920 by 1080 design frame")
	if not rendered_cell_size.is_equal_approx(Vector2(1920.0 / 19.0, 1080.0 / 11.0)):
		failures.append("rendered cell does not match the 19 by 11 full-screen grid")
	if not (view_size / rendered_cell_size).is_equal_approx(Vector2(19.0, 11.0)):
		failures.append("viewport is not a complete 19 by 11 grid")
	if world.map_view.position != Vector2.ZERO:
		failures.append("map viewport still exposes an outer fallback ring")
	var render_scale := Vector2(contract.get("render_scale", Vector2.ZERO))
	var screen_token_scale: Vector2 = world.player_token.scale * render_scale
	if not is_equal_approx(absf(screen_token_scale.x), absf(screen_token_scale.y)):
		failures.append("character aspect ratio is distorted by rectangular cells")
	var spawn_cell := Vector2i(contract.get("spawn_cell", Vector2i(-1, -1)))
	var hub_center := Vector2i(contract.get("hub_center_cell", Vector2i(-1, -1)))
	if spawn_cell != hub_center or hub_center != Vector2i(16, 9):
		failures.append("spawn is not the unique hub center cell")
	if Vector2i(contract.get("current_cell", Vector2i(-1, -1))) != spawn_cell:
		failures.append("initial cell does not match this load's spawn")
	if not world._view_position_for_cell(hub_center).is_equal_approx(view_size * 0.5):
		failures.append("hub center cell is not at exact screen center")
	if world._cell_from_view_position(Vector2(0.5, 0.5)) != Vector2i(7, 4):
		failures.append("top-left screen edge cuts a grid cell")
	if world._cell_from_view_position(Vector2(1919.5, 1079.5)) != Vector2i(25, 14):
		failures.append("bottom-right screen edge cuts a grid cell")
	if int(contract.get("ground_cell_count", 0)) != 576:
		failures.append("ground cell count mismatch")
	if int(contract.get("hero_frame_count", 0)) <= 0:
		failures.append("hero idle frames missing")
	if int(contract.get("destination_count", -1)) != 0:
		failures.append("obsolete match or expedition destination grid is still drawn")
	if int(contract.get("portal_stone_count", 0)) != 4:
		failures.append("four portal stones are not attached")
	if int(contract.get("portal_stone_shadow_count", 0)) != 4:
		failures.append("four portal stone ground shadows are not attached")
	if contract.get("portal_stone_cells", []) != [
		Vector2i(15, 8), Vector2i(17, 8),
		Vector2i(15, 10), Vector2i(17, 10),
	]:
		failures.append("portal stones are not on the four corner cells")
	var stone_positions: Array[Vector2] = []
	for stone: TextureRect in world.portal_stones:
		stone_positions.append(stone.position)
	await create_timer(0.3).timeout
	var floating_stones: int = 0
	for index: int in world.portal_stones.size():
		if not world.portal_stones[index].position.is_equal_approx(stone_positions[index]):
			floating_stones += 1
	if floating_stones == 0:
		failures.append("portal stone position idle is not running")
	for index: int in world.portal_stones.size():
		var expected_foot: Vector2 = Vector2(MainMenuWorld.PORTAL_STONE_CELLS[index]) \
				* MainMenuWorld.MAP_CELL + MainMenuWorld.TOKEN_CELL_FOOT_POINT
		var actual_foot: Vector2 = world._portal_stone_home_positions[index] \
				+ MainMenuWorld.PORTAL_STONE_FOOT_ANCHORS[index]
		if actual_foot != expected_foot:
			failures.append("portal stone foot anchor mismatch at index %d" % index)
		if world.portal_stones[index].scale != MainMenuWorld.TOKEN_ASPECT_COMPENSATION \
				* MainMenuWorld.PORTAL_STONE_SCALE:
			failures.append("portal stone scale mismatch at index %d" % index)
	world.play_portal_activation(
			MainMenuWorld.PORTAL_ENERGY_GOLD, MainMenuWorld.PORTAL_ACTIVATION_DURATION)
	if not is_zero_approx(float(world.get("_portal_energy_mix"))):
		failures.append("portal activation does not start from the white idle state")
	await create_timer(0.18).timeout
	var ordered_levels: Array[float] = world.get("_portal_energy_levels")
	if ordered_levels[0] <= 0.0 or ordered_levels[1] > 0.0 \
			or ordered_levels[2] > 0.0 or ordered_levels[3] > 0.0:
		failures.append("portal activation is not ordered TL TR BL BR")
	await create_timer(MainMenuWorld.PORTAL_ACTIVATION_DURATION).timeout
	for stone: TextureRect in world.portal_stones:
		var stone_material := stone.material as ShaderMaterial
		if stone_material.get_shader_parameter("energy_color") \
				!= MainMenuWorld.PORTAL_ENERGY_GOLD:
			failures.append("expedition gold energy is not applied")
		if not is_equal_approx(float(stone_material.get_shader_parameter("energy_mix")), 1.0):
			failures.append("portal energy mix is not active")
	world.begin_portal_search(MainMenuWorld.PORTAL_ENERGY_BLUE)
	await create_timer(1.15).timeout
	var search_levels: Array[float] = world.get("_portal_energy_levels")
	if search_levels[0] < 0.99 or search_levels[1] < 0.99 \
			or search_levels[2] < 0.99 or search_levels[3] > 0.0:
		failures.append("match search must reserve the fourth stone for connection success")
	world.complete_portal_connection(MainMenuWorld.PORTAL_ENERGY_BLUE)
	for stone: TextureRect in world.portal_stones:
		if (stone.material as ShaderMaterial).get_shader_parameter("energy_color") \
				!= MainMenuWorld.PORTAL_ENERGY_BLUE:
			failures.append("match blue energy is not applied")
	await world.play_portal_beam(MainMenuWorld.PORTAL_ENERGY_BLUE, 0.12)
	if world.portal_beam == null or not world.portal_beam.visible:
		failures.append("connected portal does not raise the center beam")
	else:
		var beam_rect := Rect2(world.portal_beam.position, world.portal_beam.size)
		var base_rect := Rect2(view_size * 0.5 - rendered_cell_size * 1.5,
				rendered_cell_size * 3.0)
		if not is_zero_approx(beam_rect.position.y) or not beam_rect.encloses(base_rect):
			failures.append("portal beam does not reach screen top from the center nine cells")
	for path: String in ["UI/ModeMatch", "UI/ModeTower"]:
		var entry := menu.get_node_or_null(path) as Button
		if entry == null or not entry.visible or entry.disabled:
			failures.append("entry unavailable: %s" % path)
		elif not entry.size.is_equal_approx(Vector2(108, 108)) \
				or not is_equal_approx(entry.position.y, 916.0):
			failures.append("direct dock entry geometry mismatch: %s pos=%s size=%s" \
					% [path, entry.position, entry.size])
		elif entry.get_node_or_null("Caption") != null \
				or entry.get_node_or_null("Status") != null:
			failures.append("bottom dock entry still contains visible text nodes: %s" % path)
	if menu.get_node_or_null("UI/NavShop") != null:
		failures.append("shop placeholder still exists")
	var backpack_button := menu.get_node_or_null("UI/NavBackpack") as Button
	if backpack_button == null or not backpack_button.size.is_equal_approx(Vector2(108, 108)):
		failures.append("backpack dock entry missing")
	elif (backpack_button.get_node("Icon") as TextureRect).texture.resource_path \
			!= "res://assets/ui/icons/backpack.png":
		failures.append("backpack dock entry does not use imported asset")
	for path: String in ["UI/ModeMatch", "UI/ModeTower", "UI/NavHeroes", "UI/NavBackpack"]:
		var dock_button := menu.get_node(path) as Button
		if dock_button.text != "" or dock_button.get_node_or_null("Caption") != null:
			failures.append("dock button is not icon-only: %s" % path)
	var target: Vector2i = spawn_cell + Vector2i.LEFT * 2
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
	while world._grid_movement.is_moving() and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if world._grid_movement.is_moving():
		failures.append("main menu click route did not visually settle")
	var keyboard_origin: Vector2i = Vector2i(world.get("_current_cell"))
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_W
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await process_frame
	if Vector2i(world.get("_current_cell")) != keyboard_origin:
		failures.append("main menu still accepts WASD movement")
	contract["mouse_only_verified"] = Vector2i(world.get("_current_cell")) == keyboard_origin
	contract["final_cell"] = Vector2i(world.get("_current_cell"))
	if not failures.is_empty():
		push_error("MAIN_MENU_PROBE: %s" % "; ".join(failures))
		quit(1)
		return
	print("MAIN_MENU_PROBE_OK ", JSON.stringify(contract))
	quit(0)
