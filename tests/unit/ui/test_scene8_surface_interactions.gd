extends GutTest

const SCENE8_PATH := "res://src/ui/scenes/scene8.tscn"
const BATTLE_SCREEN8_PATH := "res://src/ui/battle_screen8.tscn"
const CONTROLLER_PATH := (
		"res://src/ui/components/scene8_surface_interaction_controller.gd")
const WATER_INCLUDE_PATH := (
		"res://assets/shaders/canvas_env_scene8_shared_water_wave.gdshaderinc")
const LAKE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_open_lake.gdshader")
const REFLECTION_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_aurora_reflection.gdshader")
const PLATFORM_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_platform_float.gdshader")


func test_scene8_surface_controller_listens_before_gui_without_consuming_input() -> void:
	var source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	assert_true(source.contains("class IceChipBurst"))
	assert_false(source.contains("class PlatformCrackLayer"),
			"Rejected small surface cracks must be removed, not hidden")
	assert_true(source.contains("func _input"))
	assert_true(source.contains("set_process_input(true)"))
	assert_false(source.contains("func _unhandled_input"),
			"BattleScreenBase is a fullscreen MOUSE_FILTER_STOP Control")
	assert_false(source.contains("set_input_as_handled"))
	assert_false(source.contains("GPUParticles2D"),
			"Small deterministic chips need procedural pixel geometry, not a generic emitter")

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node_or_null("SurfaceInteractionController")
	assert_not_null(controller)
	assert_true(controller.is_processing_input())
	assert_false(controller.is_processing_unhandled_input())
	assert_eq(String(controller.get("lake_path")), "../MirrorLake")
	assert_eq(String(controller.get("platform_path")), "../BattlePlatform")
	var lake_position := Vector2(controller.call("find_lake_position_for_testing"))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = lake_position
	event.pressed = true
	controller.call("_input", event)
	assert_eq(int(controller.call("left_click_input_count_for_testing")), 1)
	assert_eq(int(controller.call("active_lake_ripple_count_for_testing")), 1)


func test_platform_idle_state_has_no_central_black_fissure_seed() -> void:
	var shader_source := FileAccess.get_file_as_string(PLATFORM_SHADER_PATH)
	assert_eq(shader_source.count("if (platform_break_amount > 0.001)"), 2,
			"The central fissure must be completely gated while the easter egg is idle")
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var material := platform.material as ShaderMaterial
	assert_almost_eq(float(material.get_shader_parameter(
			&"platform_break_amount")), 0.0, 0.0001,
			"A fresh Scene8 instance must not retain any fissure reveal state")
	var image := platform.texture.get_image()
	var center_x := image.get_width() / 2
	var minimum_luma := 1.0
	var isolated_alpha_holes := 0
	for y: int in range(90, 104):
		for x: int in range(center_x - 4, center_x + 5):
			var color := image.get_pixel(x, y)
			if color.a >= 0.8:
				minimum_luma = minf(
						minimum_luma,
						color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722)
			elif color.a < 0.12:
				var opaque_neighbors := 0
				for offset_y: int in range(-1, 2):
					for offset_x: int in range(-1, 2):
						if offset_x == 0 and offset_y == 0:
							continue
						if image.get_pixel(
								x + offset_x, y + offset_y).a >= 0.8:
							opaque_neighbors += 1
				if opaque_neighbors >= 6:
					isolated_alpha_holes += 1
	assert_eq(isolated_alpha_holes, 0,
			"The intact central platform may not contain an isolated alpha pinhole")
	assert_gt(minimum_luma, 0.45,
			"The intact central platform source may not contain a black seed pixel")


func test_lake_click_creates_pixel_perspective_ripples() -> void:
	var include_source := FileAccess.get_file_as_string(WATER_INCLUDE_PATH)
	var lake_source := FileAccess.get_file_as_string(LAKE_SHADER_PATH)
	var reflection_source := FileAccess.get_file_as_string(REFLECTION_SHADER_PATH)
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	assert_true(include_source.contains("scene8_click_ripple"))
	assert_true(include_source.contains("click_ripple_events"))
	assert_true(include_source.contains("click_ripple_count"))
	assert_true(include_source.contains("texelFetch"))
	assert_false(include_source.contains("uniform vec4 click_ripple_a"))
	assert_false(include_source.contains("uniform vec4 click_ripple_b"))
	assert_false(include_source.contains("uniform vec4 click_ripple_c"))
	assert_false(controller_source.contains("LAKE_SLOT_COUNT"),
			"Lake ripples must not have an application-level count limit")
	assert_true(controller_source.contains("ImageTexture.create_from_image"))
	assert_true(include_source.contains("primary_ring"))
	assert_true(include_source.contains("secondary_ring"))
	assert_true(include_source.contains("floor(screen_uv * pixel_grid)"),
			"Ripple geometry must snap to the shared 320x180 pixel grid")
	assert_false(include_source.contains("oblique_band"))
	assert_false(include_source.contains("scene8_click_refraction"))
	assert_true(lake_source.contains("click_ripple"))
	assert_true(reflection_source.contains("click_ripple"))
	assert_true(reflection_source.contains("screen_sample_uv.x"),
			"Ripple crests must refract the existing sampled aurora reflection")

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SurfaceInteractionController")
	var lake_position := Vector2(controller.call("find_lake_position_for_testing"))
	assert_gte(lake_position.x, 0.0)
	assert_eq(String(controller.call(
			"hit_kind_at_viewport_position_for_testing", lake_position)), "lake")
	assert_true(bool(controller.call(
			"trigger_lake_at_viewport_position", lake_position)))
	assert_eq(int(controller.call("active_lake_ripple_count_for_testing")), 1)
	var contract := Dictionary(controller.call("lake_uniform_contract_for_testing"))
	assert_eq(String(contract.effect_kind), "pixel_perspective_ripple")
	assert_eq(String(contract.storage_kind), "dynamic_event_texture")
	assert_eq(int(contract.application_limit), -1)
	assert_eq(int(contract.event_count), 1)
	assert_between(float(contract.duration_sec), 1.45, 1.8)
	assert_between(float(contract.minimum_width_px), 95.0, 125.0)
	assert_between(float(contract.maximum_width_px), 160.0, 190.0)
	assert_between(float(contract.vertical_compression), 0.30, 0.48)
	assert_gte(float(contract.immediate_strength_floor), 0.5,
			"A click must be visible on its first rendered frame")
	assert_true(bool(contract.shared_by_water_and_reflection))


func test_lake_ripples_accumulate_without_a_fixed_count_limit() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SurfaceInteractionController")
	var lake_position := Vector2(controller.call("find_lake_position_for_testing"))
	assert_true(bool(controller.call(
			"trigger_lake_at_viewport_position", lake_position)))
	controller.call("_process", 0.50)
	for ripple_index: int in range(1, 12):
		assert_true(bool(controller.call(
				"trigger_lake_at_viewport_position", lake_position)),
				"Every valid click must append ripple %d" % ripple_index)
	assert_eq(int(controller.call("active_lake_ripple_count_for_testing")), 12,
			"The old three-ripple ceiling must be removed")
	var ripples := Array(controller.get("_lake_ripples"))
	assert_almost_eq(float((ripples[0] as Dictionary).age), 0.50, 0.001,
			"New clicks must not refresh the first ripple")
	assert_eq(float((ripples[11] as Dictionary).age), 0.0)
	var contract := Dictionary(controller.call("lake_uniform_contract_for_testing"))
	assert_eq(int(contract.event_count), 12)
	assert_gte(int(contract.texture_capacity), 12)


func test_platform_click_emits_only_small_readable_ice_chips() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SurfaceInteractionController")
	var platform_position := Vector2(controller.call(
			"find_platform_position_for_testing"))
	assert_gte(platform_position.x, 0.0)
	assert_eq(String(controller.call(
			"hit_kind_at_viewport_position_for_testing", platform_position)),
			"platform")
	assert_true(bool(controller.call(
			"trigger_platform_at_viewport_position", platform_position, false)))
	var contracts := Array(controller.call("active_chip_contracts_for_testing"))
	assert_eq(contracts.size(), 1)
	var chip_contract := contracts[0] as Dictionary
	assert_eq(int(chip_contract.piece_count), 12)
	assert_between(float(chip_contract.minimum_screen_piece_px), 2.5, 4.0)
	assert_lte(float(chip_contract.maximum_screen_piece_px), 5.5,
			"Eddy explicitly requested smaller ice chips")
	assert_between(float(chip_contract.lifetime_sec), 0.9, 1.15)
	assert_eq(int(controller.call(
			"active_platform_contact_flash_count_for_testing")), 1)
	var shake_contract := Dictionary(controller.call(
			"platform_shake_contract_for_testing"))
	assert_eq(String(shake_contract.kind), "tap")
	assert_between(float(shake_contract.duration_sec), 0.14, 0.22)
	assert_between(float(shake_contract.amplitude_px), 3.0, 5.0)
	assert_true(bool(shake_contract.moves_water_contact))
	assert_true(bool(shake_contract.syncs_characters_when_embedded))
	var platform := stage.get_node("BattlePlatform") as Control
	var water_contact := stage.get_node("PlatformWaterContact") as Control
	var platform_before := platform.position
	var contact_before := water_contact.position
	controller.call("_process", 0.025)
	shake_contract = Dictionary(controller.call(
			"platform_shake_contract_for_testing"))
	var shake_offset := Vector2(shake_contract.current_offset_px)
	assert_ne(shake_offset, Vector2.ZERO,
			"A valid click needs an immediately measurable platform displacement")
	assert_eq(platform.position, platform_before + shake_offset)
	assert_eq(water_contact.position, contact_before + shake_offset)
	assert_eq(int(controller.call("permanent_platform_fissure_count_for_testing")), 0)


func test_third_platform_click_can_create_one_persistent_vertical_fissure() -> void:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var platform_shader_source := FileAccess.get_file_as_string(
			PLATFORM_SHADER_PATH)
	assert_false(controller_source.contains("_build_crack_lines"))
	assert_false(controller_source.contains("draw_polyline"))
	assert_false(controller_source.contains("_platform_source_is_center_gap"),
			"A painted fissure must never cut a hole out of platform hit testing")
	assert_true(platform_shader_source.contains("platform_break_amount"))
	assert_true(platform_shader_source.contains("crack_path_offset"))
	assert_true(platform_shader_source.contains("vertical_fissure_core"))
	assert_true(platform_shader_source.contains("fissure_branch"))
	assert_true(platform_shader_source.contains("distance_from_bottom"),
			"The permanent fissure must reveal from the platform bottom upward")
	assert_true(platform_shader_source.contains(
			"authored_row = 13.0 - crack_local_row"),
			"The fissure silhouette itself must be vertically reversed")
	assert_false(platform_shader_source.contains("root_distance"),
			"The previous center-out growth direction must not return")
	assert_false(platform_shader_source.contains("discard"),
			"The vertical fissure must preserve the complete platform raster")
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SurfaceInteractionController")
	var platform_position := Vector2(controller.call(
			"find_platform_position_for_testing"))
	var center_fissure_position := Vector2(controller.call(
			"find_platform_center_fissure_position_for_testing"))
	assert_gte(center_fissure_position.x, 0.0)
	assert_eq(String(controller.call(
			"hit_kind_at_viewport_position_for_testing", center_fissure_position)),
			"platform")
	controller.call("trigger_platform_at_viewport_position", platform_position, false)
	controller.call("trigger_platform_at_viewport_position", platform_position, false)
	assert_eq(int(controller.call("permanent_platform_fissure_count_for_testing")), 0,
			"The first two valid clicks may only shed ice chips")
	assert_true(bool(controller.call(
			"trigger_platform_at_viewport_position", platform_position, true)))
	assert_eq(int(controller.call("platform_click_count_for_testing")), 3)
	assert_eq(int(controller.call("permanent_platform_fissure_count_for_testing")), 1)
	var break_shake := Dictionary(controller.call(
			"platform_shake_contract_for_testing"))
	assert_eq(String(break_shake.kind), "break")
	assert_between(float(break_shake.duration_sec), 0.34, 0.46)
	assert_between(float(break_shake.amplitude_px), 8.0, 12.0)
	controller.call("_process", 0.40)
	var fissure_contract := Dictionary(controller.call(
			"platform_fissure_contract_for_testing"))
	assert_eq(String(fissure_contract.kind), "vertical_pixel_fissure")
	assert_eq(String(fissure_contract.primary_axis), "vertical")
	assert_eq(String(fissure_contract.growth_direction), "bottom_to_top")
	assert_eq(String(fissure_contract.silhouette_direction), "bottom_to_top")
	assert_true(bool(fissure_contract.silhouette_vertical_flip))
	assert_gt(float(fissure_contract.growth_origin_source_row),
			float(fissure_contract.growth_destination_source_row))
	assert_eq(int(fissure_contract.fissure_count), 1)
	assert_true(bool(fissure_contract.connected))
	assert_true(bool(fissure_contract.source_alpha_preserved))
	assert_false(bool(fissure_contract.affects_hit_testing))
	assert_eq(int(fissure_contract.transparent_pixels_removed), 0)
	assert_eq(float(fissure_contract.core_width_source_px), 1.0)
	assert_lte(float(fissure_contract.maximum_node_width_source_px), 2.0)
	assert_eq(int(fissure_contract.branch_count), 3)
	assert_eq(int(fissure_contract.growth_segment_count), 4)
	assert_between(float(fissure_contract.height_screen_px), 78.0, 90.0)
	assert_between(float(fissure_contract.core_width_screen_px), 5.0, 7.0)
	assert_lte(float(fissure_contract.maximum_center_offset_screen_px), 12.0)
	assert_eq(float(fissure_contract.shader_break_amount), 1.0)
	assert_eq(String(controller.call(
			"hit_kind_at_viewport_position_for_testing", center_fissure_position)),
			"platform", "A fissure is surface damage, not exposed lake water")
	controller.call(
			"trigger_platform_at_viewport_position", platform_position, true)
	assert_eq(int(controller.call("permanent_platform_fissure_count_for_testing")), 1,
			"Repeated clicks must never produce extra notches or crack roots")
	controller.call("_process", 5.0)
	assert_eq(int(controller.call("permanent_platform_fissure_count_for_testing")), 1,
			"The single vertical fissure must outlive all transient chip animation")


func test_battle_buttons_and_item_rows_block_scene8_lake_feedback() -> void:
	var battle := (load(BATTLE_SCREEN8_PATH) as PackedScene).instantiate()
	add_child_autofree(battle)
	var controller := battle.find_child(
			"SurfaceInteractionController", true, false)
	assert_not_null(controller)
	var blocker_contract := Dictionary(controller.call(
			"battle_ui_exclusion_contract_for_testing"))
	assert_true(bool(blocker_contract.has_button_bar))
	assert_eq(int(blocker_contract.item_row_count), 2)
	var button_position := Vector2(blocker_contract.button_bar_center)
	assert_true(bool(controller.call(
			"battle_ui_blocks_viewport_position_for_testing", button_position)))
	var item_positions := blocker_contract.item_row_centers as Array
	for position: Vector2 in item_positions:
		assert_true(bool(controller.call(
				"battle_ui_blocks_viewport_position_for_testing", position)))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button_position
	event.pressed = true
	controller.call("_input", event)
	assert_eq(int(controller.call("left_click_input_count_for_testing")), 0,
			"Battle UI clicks must be rejected before Scene8 surface dispatch")
	assert_eq(int(controller.call("active_lake_ripple_count_for_testing")), 0)


func test_platform_break_probability_is_gated_and_capped() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SurfaceInteractionController")
	var platform_position := Vector2(controller.call(
			"find_platform_position_for_testing"))
	assert_eq(float(controller.call(
			"platform_break_probability_for_testing", platform_position)), 0.0)
	controller.call("trigger_platform_at_viewport_position", platform_position, false)
	assert_eq(float(controller.call(
			"platform_break_probability_for_testing", platform_position)), 0.0)
	controller.call("trigger_platform_at_viewport_position", platform_position, false)
	assert_almost_eq(float(controller.call(
			"platform_break_probability_for_testing", platform_position)), 0.22, 0.001,
			"The same-position third click should have a restrained chance")
	for click_index: int in 12:
		controller.call("trigger_platform_at_viewport_position", platform_position, false)
	assert_lte(float(controller.call(
			"platform_break_probability_for_testing", platform_position)), 0.30)


func test_sky_and_foreground_pixels_do_not_trigger_surface_feedback() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SurfaceInteractionController")
	assert_eq(String(controller.call(
			"hit_kind_at_viewport_position_for_testing", Vector2(960.0, 120.0))),
			"none")
	var foreground_position := Vector2(controller.call(
			"find_foreground_blocked_position_for_testing"))
	assert_gte(foreground_position.x, 0.0)
	assert_eq(String(controller.call(
			"hit_kind_at_viewport_position_for_testing", foreground_position)),
			"none")
