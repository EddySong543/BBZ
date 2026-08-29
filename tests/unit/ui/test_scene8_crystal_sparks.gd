extends GutTest

const SCENE8_PATH := "res://src/ui/scenes/scene8.tscn"
const FOREGROUND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_foreground_grade.gdshader")
const CONTROLLER_PATH := (
		"res://src/ui/components/scene8_crystal_spark_controller.gd")
const EXPECTED_CONNECTED_CRYSTAL_PIXELS: Array[int] = [1274, 1673, 312, 137, 2913, 1154]
const EXPECTED_REJECTED_PALETTE_PIXELS: Array[int] = [377, 924, 39, 0, 453, 236]
const EXPECTED_ANNOTATION_EXCLUDED_PIXELS: Array[int] = [374, 692, 0, 0, 112, 219]
const EXPECTED_RIGHT2_EDGE_EXCLUDED_PIXELS: Array[int] = [0, 0, 0, 0, 40, 0]


func test_foreground_sweep_is_removed_and_crystal_refraction_is_click_only() -> void:
	var shader_source := FileAccess.get_file_as_string(FOREGROUND_SHADER_PATH)
	assert_true(shader_source.contains("COLOR = vec4(color, source.a)"))
	assert_true(shader_source.contains("TEXTURE_PIXEL_SIZE"))
	assert_false(shader_source.contains("glint"),
			"The foreground shader must no longer contain any moving sweep")
	assert_false(shader_source.contains("cluster_ellipse"))

	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	assert_true(controller_source.contains("_is_crystal_pixel"),
			"Click hit testing must inspect the authored source pixel")
	assert_true(controller_source.contains("class CrystalFacetResponse"))
	assert_true(controller_source.contains("queue_redraw()"))
	assert_true(controller_source.contains("draw_rect("),
			"The response must use crisp procedural pixel primitives")
	assert_false(controller_source.contains("GPUParticles2D.new()"),
			"The rejected radial particle burst must be removed")
	assert_false(controller_source.contains("spread = 180.0"))
	assert_false(controller_source.contains("auto_interval"),
			"Crystal sparks must never play automatically")
	assert_false(controller_source.contains("RandomNumberGenerator"))
	assert_false(controller_source.contains("set_input_as_handled"),
			"Crystal feedback must not consume mature battle input")

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_null(stage.get_node_or_null("CrystalGlintController"))
	var controller := stage.get_node("CrystalSparkController")
	assert_not_null(controller)
	assert_eq(int(controller.call("crystal_count")), 6)
	controller.call("_process", 20.0)
	assert_null(stage.get_node_or_null("Scene8CrystalFacetResponse"),
			"Waiting must not create an automatic crystal effect")


func test_all_six_crystals_use_source_pixel_hit_testing() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	var rejected_visible_samples := 0
	for crystal_id: int in 6:
		var hit_position := Vector2(controller.call(
				"find_interactive_position_for_testing", crystal_id))
		assert_gte(hit_position.x, 0.0,
				"Every authored crystal cluster needs at least one interactive pixel")
		assert_eq(int(controller.call(
				"crystal_id_at_viewport_position_for_testing", hit_position)),
				crystal_id)
		var rejected_position := Vector2(controller.call(
				"find_visible_non_crystal_position_for_testing", crystal_id))
		if rejected_position.x >= 0.0:
			rejected_visible_samples += 1
			assert_eq(int(controller.call(
					"crystal_id_at_viewport_position_for_testing", rejected_position)), -1)
	assert_gte(rejected_visible_samples, 4,
			"The coarse circles must reject visible snow or rock samples")
	assert_eq(int(controller.call(
			"crystal_id_at_viewport_position_for_testing", Vector2(960.0, 540.0))),
			-1, "The lake and snow outside the crystals must not respond")


func test_disconnected_blue_rock_and_snow_pixels_are_rejected_exactly() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	var visible_rejected_samples := 0
	for crystal_id: int in 6:
		assert_eq(int(controller.call(
				"interactive_pixel_count_for_testing", crystal_id)),
				EXPECTED_CONNECTED_CRYSTAL_PIXELS[crystal_id],
				"Only the final approved source-pixel mask may respond")
		var rejected_count := int(controller.call(
				"rejected_palette_pixel_count_for_testing", crystal_id))
		assert_eq(rejected_count, EXPECTED_REJECTED_PALETTE_PIXELS[crystal_id])
		var rejected_position := Vector2(controller.call(
				"find_rejected_palette_position_for_testing", crystal_id))
		if rejected_position.x < 0.0:
			continue
		visible_rejected_samples += 1
		assert_eq(int(controller.call(
				"crystal_id_at_viewport_position_for_testing", rejected_position)), -1,
				"Disconnected blue rock or snow pixels must not trigger a response")
	assert_gte(visible_rejected_samples, 3,
			"The regression must cover multiple visible rejected rock/snow islands")


func test_red_marked_source_pixels_are_excluded_from_all_click_responses() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	for crystal_id: int in 6:
		var excluded_count := int(controller.call(
				"annotation_excluded_pixel_count_for_testing", crystal_id))
		assert_eq(excluded_count, EXPECTED_ANNOTATION_EXCLUDED_PIXELS[crystal_id],
				"The red-outline registration must remain exact at source-pixel level")
		if crystal_id in [0, 1, 4, 5]:
			var excluded_position := Vector2(controller.call(
					"find_annotation_excluded_position_for_testing", crystal_id))
			assert_gte(excluded_position.x, 0.0)
			assert_eq(int(controller.call(
					"crystal_id_at_viewport_position_for_testing", excluded_position)), -1,
					"A pixel inside Eddy's red outline must never trigger refraction")
		assert_true(bool(controller.call(
				"annotation_exclusions_are_noninteractive_for_testing", crystal_id)),
				"Every removed source pixel, including the polygon edge, must reject clicks")


func test_right2_edge_sliver_is_excluded_without_widening_other_clusters() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	for crystal_id: int in 6:
		var excluded_count := int(controller.call(
				"right2_edge_excluded_pixel_count_for_testing", crystal_id))
		assert_eq(excluded_count, EXPECTED_RIGHT2_EDGE_EXCLUDED_PIXELS[crystal_id],
				"right2 must remove exactly its 40 edge pixels and nothing else")
	assert_true(bool(controller.call(
			"right2_edge_exclusions_are_noninteractive_for_testing")),
			"Every source pixel in the right2 sliver must reject clicks")


func test_click_creates_facet_aligned_refraction_and_rejects_active_retrigger() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	var hit_position := Vector2(controller.call(
			"find_interactive_position_for_testing", 2))
	var click := InputEventMouseButton.new()
	click.position = hit_position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	controller.call("_input", click)

	var response := stage.get_node_or_null("Scene8CrystalFacetResponse") as Node2D
	assert_not_null(response)
	if response == null:
		return
	var refraction := response.get_node("FacetRefraction") as Node2D
	assert_not_null(refraction)
	assert_null(response.get_node_or_null("PixelSparks"))
	assert_null(response.get_node_or_null("ContactFlash"))
	var contract := Dictionary(controller.call(
			"active_response_contract_for_testing", response))
	assert_eq(String(contract.primitive), "facet_refraction")
	assert_eq(int(contract.shard_count), 3)
	assert_almost_eq(float(contract.lifetime_sec), 0.64, 0.001)
	assert_between(float(contract.facet_length_px), 18.0, 48.0)
	assert_between(float(contract.contact_footprint_px), 4.0, 6.0)
	assert_between(float(contract.maximum_shard_length_px), 16.0, 20.0)
	assert_gte(float(contract.core_brightness), 0.98)
	var early_state := Dictionary(refraction.call("timeline_state_for_testing", 0.08))
	assert_true(bool(early_state.contact_visible))
	assert_true(bool(early_state.facet_visible))
	var middle_state := Dictionary(refraction.call("timeline_state_for_testing", 0.24))
	assert_false(bool(middle_state.contact_visible))
	assert_true(bool(middle_state.facet_visible))
	assert_eq(int(middle_state.active_shards), 3)
	var late_state := Dictionary(refraction.call("timeline_state_for_testing", 0.58))
	assert_gte(int(late_state.active_shards), 1,
			"The response must fade through its full lifetime, not vanish halfway")

	assert_false(bool(controller.call(
			"trigger_spark_at_viewport_position", hit_position)),
			"A spark still inside its cooldown must ignore repeated clicks")
	var response_count := 0
	for child: Node in stage.get_children():
		if child.name == "Scene8CrystalFacetResponse":
			response_count += 1
	assert_eq(response_count, 1)
	controller.call("_process", 0.63)
	assert_false(bool(controller.call(
			"trigger_spark_at_viewport_position", hit_position)),
			"The crystal stays locked until the full response finishes")
	controller.call("_process", 0.02)
	assert_true(bool(controller.call(
			"trigger_spark_at_viewport_position", hit_position)))


func test_all_six_crystals_have_distinct_readable_facet_directions() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	var directions: Array[Vector2] = []
	for crystal_id: int in 6:
		var direction := Vector2(controller.call(
				"configured_facet_direction_for_testing", crystal_id))
		assert_almost_eq(direction.length(), 1.0, 0.001)
		var metrics := Dictionary(controller.call(
				"facet_segment_metrics_for_testing", crystal_id))
		assert_between(float(metrics.length_px), 18.0, 48.0)
		directions.append(direction)
	for left_index: int in directions.size():
		for right_index: int in range(left_index + 1, directions.size()):
			assert_lt(absf(directions[left_index].dot(directions[right_index])), 0.999,
					"Every cluster needs its own authored facet direction")


func test_interactive_pixels_are_a_conservative_subset_of_each_red_circle() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("CrystalSparkController")
	for crystal_id: int in 6:
		var interactive_pixels := int(controller.call(
				"interactive_pixel_count_for_testing", crystal_id))
		assert_between(interactive_pixels, 20, 4000,
				"Each circle must expose readable crystal facets without widening to snow")
