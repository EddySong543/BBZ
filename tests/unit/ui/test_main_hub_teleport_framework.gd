extends GutTest

const TELEPORT_SCENE_PATH := "res://src/ui/main_hub/main_hub_teleport.tscn"


func test_teleport_scene_reuses_the_mature_pointer_parallax_contract() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as MainHubTeleportStage
	add_child_autofree(stage)
	await get_tree().process_frame

	assert_true(stage is BattleStage)
	assert_true(stage.pointer_parallax)
	assert_false(stage.demo_click_shake)
	assert_false(stage.idle_drift)
	assert_eq(stage.get_layer_contract(), {
		"Backdrop": 0.0,
		"FarEnvironment": 0.14,
		"MidEnvironment": 0.48,
		"GroundEnvironment": 1.0,
		"PortalLayer": 1.0,
		"CharacterLayer": 1.0,
		"ForegroundEnvironment": 1.18,
	})


func test_teleport_scene_exposes_empty_editable_environment_layers() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as MainHubTeleportStage
	add_child_autofree(stage)
	await get_tree().process_frame

	for layer_name: String in [
		"FarEnvironment",
		"MidEnvironment",
		"GroundEnvironment",
		"ForegroundEnvironment",
	]:
		var layer := stage.get_node(layer_name) as Control
		assert_not_null(layer)
		assert_eq(layer.get_child_count(), 0,
				"环境层必须保持空白，等待 Eddy 提供并指定素材")
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_null(stage.get_node_or_null("Guild"), "公会是后期可选区，本轮不得搭空壳")


func test_teleport_scene_declares_only_the_approved_adjacent_districts() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as MainHubTeleportStage
	add_child_autofree(stage)
	await get_tree().process_frame

	assert_eq(stage.district_id, &"teleport")
	assert_eq(stage.get_exit_contract(), {
		&"left": &"team_prep",
		&"right": &"shop",
	})
	watch_signals(stage)
	assert_true(stage.request_exit(&"left"))
	assert_signal_emitted_with_parameters(stage, &"exit_requested",
			[&"left", &"team_prep"])
	assert_false(stage.request_exit(&"guild"))


func test_teleport_scene_reuses_profile_character_and_existing_portal_assets() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as MainHubTeleportStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var character := stage.get_node("CharacterLayer/PlayerCharacter") as CharacterDisplay
	assert_not_null(character)
	assert_false(character.sprite_frames_path.is_empty())
	assert_true(ResourceLoader.exists(character.sprite_frames_path))
	var portal_rig := stage.get_node("PortalLayer/PortalRig") as MainHubPortalRig
	assert_not_null(portal_rig)
	assert_eq(portal_rig.get_stones().size(), 4)
	for stone: TextureRect in portal_rig.get_stones():
		assert_not_null(stone.texture)
		assert_eq(stone.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(stone.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_pointer_response_moves_depth_layers_without_splitting_actor_and_ground() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as MainHubTeleportStage
	add_child_autofree(stage)
	await get_tree().process_frame

	stage.pointer_parallax = false
	stage.pointer_zoom = 0.0
	stage.set("_pnx", 1.0)
	stage._process(0.0)
	var far := stage.get_node("FarEnvironment") as Control
	var ground := stage.get_node("GroundEnvironment") as Control
	var portal := stage.get_node("PortalLayer") as Control
	var character := stage.get_node("CharacterLayer") as Control
	var foreground := stage.get_node("ForegroundEnvironment") as Control

	assert_almost_eq(far.position.x, -stage.pointer_strength * 0.14, 0.001)
	assert_almost_eq(ground.position.x, -stage.pointer_strength, 0.001)
	assert_almost_eq(portal.position.x, ground.position.x, 0.001)
	assert_almost_eq(character.position.x, ground.position.x, 0.001)
	assert_almost_eq(foreground.position.x,
			-stage.pointer_strength * 1.18, 0.001)
	assert_lt(foreground.position.x, ground.position.x)
	assert_lt(ground.position.x, far.position.x)


func test_portal_stones_float_and_accept_search_energy() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as MainHubTeleportStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var portal_rig := stage.get_node("PortalLayer/PortalRig") as MainHubPortalRig
	var stones: Array[TextureRect] = portal_rig.get_stones()
	var initial_positions: PackedVector2Array = PackedVector2Array()
	for stone: TextureRect in stones:
		initial_positions.append(stone.position)

	portal_rig._process(MainHubPortalRig.PORTAL_FLOAT_PERIOD * 0.125)
	var moved_count: int = 0
	for index: int in stones.size():
		if not stones[index].position.is_equal_approx(initial_positions[index]):
			moved_count += 1
	assert_eq(moved_count, stones.size())

	portal_rig.begin_search(Color("48A8FF"))
	await get_tree().create_timer(MainHubPortalRig.ENERGY_TWEEN_DURATION + 0.05).timeout
	assert_almost_eq(portal_rig.get_energy_level(),
			MainHubPortalRig.SEARCH_ENERGY_LEVEL, 0.01)
