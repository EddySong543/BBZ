extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const CLOUD_BANK_SCRIPT_PATH := (
		"res://src/ui/components/scene9_distant_pixel_cloud_bank.gd")
const CLOUD_BLUEPRINT_PATH := (
		"res://src/ui/components/scene9_cloud_blueprint.gd")
const CLOUD_REFERENCE_PATH := (
		"res://assets/scenes/scene9/scene9_cloud_layer.png")
const CLOUD_MOTION_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_pixel_cloud_motion.gdshader")
const FOREGROUND_WIND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_foreground_wind.gdshader")
const FOREGROUND_WIND_MESH_PATH := (
		"res://src/ui/components/scene9_foreground_wind_mesh.gd")


func test_scene9_cloud_blueprint_reproduces_the_authored_pixels_and_animates_inside() -> void:
	assert_true(ResourceLoader.exists(CLOUD_BLUEPRINT_PATH))
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	stage.idle_drift = false
	stage.pointer_parallax = false
	var cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	assert_null(stage.get_node_or_null("CloudLayer"),
			"The retired imported cloud node must stay absent")
	assert_true(cloud.visible)
	assert_eq((cloud.get_script() as Script).resource_path,
			CLOUD_BANK_SCRIPT_PATH)
	var cloud_material := cloud.material as ShaderMaterial
	assert_not_null(cloud_material)
	assert_eq(cloud_material.shader.resource_path, CLOUD_MOTION_SHADER_PATH)
	assert_eq(cloud.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_almost_eq(cloud.position.x, -504.0, 0.001)
	assert_almost_eq(cloud.position.y, 107.0, 0.001,
			"The user's current manual cloud placement must remain untouched")
	assert_eq(cloud.size, Vector2(2368.0, 544.0))
	assert_eq(cloud.scale, Vector2(1.4, 1.4))
	assert_eq(float(cloud.get("animation_fps")), 12.0)
	assert_eq(int(cloud.get("loop_frame_count")), 216)
	assert_almost_eq(float(cloud.call("cycle_duration_seconds")), 18.0, 0.001,
			"The authored loop must slow down without dropping temporal samples")
	assert_eq(cloud.call("pixel_source_size"), Vector2i(592, 136))
	assert_eq(int(cloud.call("core_origin_x")), 92)
	assert_gte(cloud.size.x, 1920.0)
	assert_not_null(cloud.texture)
	assert_eq(cloud.texture.get_size(), Vector2(592.0, 136.0))
	assert_eq(cloud.size / Vector2(cloud.texture.get_size()), Vector2(4.0, 4.0))
	assert_eq(cloud.size / Vector2(cloud.texture.get_size()) * cloud.scale,
			Vector2(5.6, 5.6),
			"The user's manual scale must keep every generated pixel square")

	var source := FileAccess.get_file_as_string(CLOUD_BANK_SCRIPT_PATH)
	assert_false(source.contains("scene9_cloud_layer.png"),
			"Runtime cloud code must consume only the generated code blueprint")
	assert_false(source.contains("_runtime_texture.update"),
			"Live cloud animation must never rebuild and upload a CPU image")
	assert_true(source.contains("impact_origin_path"))
	assert_false(source.contains("posmod(x - CORE_ORIGIN_X"),
			"The authored cloud must not be tiled into the side padding")
	assert_false(source.contains("moving_highlight_tint"),
			"Animation must move authored pixels, not paint a highlight overlay")
	assert_false(source.contains("moving_shadow_tint"),
			"Animation must move authored pixels, not paint a shadow overlay")
	assert_false(source.contains("contact_tint"),
			"The rejected bottom color strip must be removed")
	var rear_cloud := stage.get_node("DistantPixelCloudBank2") as TextureRect
	var runtime := cloud.call("runtime_contract_snapshot") as Dictionary
	assert_eq(runtime["animation_backend"], "gpu_canvas_shader")
	assert_eq(int(runtime["recurring_cpu_frame_builds"]), 0)
	assert_eq(int(runtime["recurring_texture_upload_bytes"]), 0)
	assert_true(bool(runtime["base_texture_built_once"]))
	assert_true(bool(runtime["metadata_texture_built_once"]))
	assert_same(cloud.texture, rear_cloud.texture,
			"Both banks must share one immutable cleaned cloud texture")
	assert_not_same(cloud.material, rear_cloud.material,
			"Click ripple uniforms must remain isolated per cloud bank")
	var cloud_shader_source := FileAccess.get_file_as_string(
			CLOUD_MOTION_SHADER_PATH)
	assert_true(cloud_shader_source.contains("metadata_texture"))
	assert_true(cloud_shader_source.contains("source_phase"))
	assert_true(cloud_shader_source.contains("ripple_phase"))
	assert_true(cloud_shader_source.contains("bottom_lock_depth_px"))

	var reference := Image.new()
	assert_eq(reference.load_png_from_buffer(
			FileAccess.get_file_as_bytes(CLOUD_REFERENCE_PATH)), OK)
	if reference.get_format() != Image.FORMAT_RGBA8:
		reference.convert(Image.FORMAT_RGBA8)
	var authored := cloud.call("render_authored_baseline_for_testing") as Image
	var frame_zero := cloud.call("render_frame_for_testing", 0) as Image
	var frame_quarter := cloud.call("render_frame_for_testing", 54) as Image
	var frame_loop := cloud.call("render_frame_for_testing", 216) as Image
	assert_eq(reference.get_size(), Vector2i(408, 136))
	var baseline := cloud.call("baseline_contract_snapshot") as Dictionary
	assert_eq(int(baseline["left_padding_opaque_pixels"]), 0,
			"Left canvas padding must stay transparent instead of tiling the art")
	assert_eq(int(baseline["right_padding_opaque_pixels"]), 0,
			"Right canvas padding must stay transparent instead of tiling the art")
	assert_eq(int(baseline["removed_left_bottom_pixels"]), 71,
			"The isolated lower-left cloud spur must be removed")
	assert_eq(int(baseline["removed_marked_horizon_pixels"]), 190,
			"The exact red-annotated left horizon droop must be removed")
	assert_eq(baseline["marked_horizon_annotation_bounds"],
			Rect2i(37, 112, 44, 6))
	assert_eq(baseline["marked_horizon_cleanup_bounds"],
			Rect2i(37, 113, 44, 5))
	assert_eq(baseline["orange_protected_bounds"],
			Rect2i(37, 82, 46, 20))
	assert_eq(int(baseline["orange_protected_pixel_changes"]), 0,
			"Every source pixel inside the orange annotation must be restored exactly")
	assert_eq(int(baseline["other_source_pixel_changes"]), 0,
			"Cleaning both targeted left spurs must not redraw the remaining cloud")
	assert_eq(_count_source_region_changes(
			authored, reference, Vector2i(92, 0), Rect2i(37, 82, 46, 20)), 0,
			"The orange-circled cloud body must match the untouched source pixel-for-pixel")
	var marked_screen_rect := cloud.call("marked_horizon_screen_rect") as Rect2
	assert_almost_eq(marked_screen_rect.position.x, -11.6, 2.0)
	assert_almost_eq(marked_screen_rect.position.y, 638.2, 2.0)
	assert_almost_eq(marked_screen_rect.end.x, 234.8, 3.0)
	assert_almost_eq(marked_screen_rect.end.y, 671.8, 3.0,
			"The removed source region must map to the user's red annotation above item one")
	var orange_screen_rect := cloud.call("orange_protected_screen_rect") as Rect2
	assert_almost_eq(orange_screen_rect.position.x, -11.6, 2.0)
	assert_almost_eq(orange_screen_rect.position.y, 470.2, 3.0)
	assert_almost_eq(orange_screen_rect.end.x, 246.0, 4.0)
	assert_almost_eq(orange_screen_rect.end.y, 582.2, 4.0,
			"The restored source region must map to the user's orange annotation")
	assert_eq(_count_changed_pixels(frame_zero, frame_loop), 0,
			"The 18-second code animation must close without a frozen reset frame")
	assert_gt(_count_changed_pixels(frame_zero, frame_quarter), 700,
			"The cloud texture and contour must move visibly")
	for frame_index: int in range(216):
		assert_gt(int(cloud.call("count_changed_pixels",
				frame_index, frame_index + 1)), 120,
				"Every subframe transition, including 215 -> 0, must keep moving")
	var motion_metrics := cloud.call("animation_metrics", 0, 54) as Dictionary
	assert_eq(int(motion_metrics["palette_outlier_pixels"]), 0,
			"Every animated RGB value must come from the authored cloud palette")
	assert_gt(int(motion_metrics["dark_region_changes"]), 300,
			"Authored dark pixels themselves must move to new coordinates")
	assert_gt(int(motion_metrics["mid_region_changes"]), 300,
			"Authored midtone pixels themselves must move to new coordinates")
	assert_gt(int(motion_metrics["light_region_changes"]), 300,
			"Authored light pixels themselves must move to new coordinates")
	assert_gt(int(motion_metrics["top_contour_alpha_changes"]), 24,
			"The top and side-facing silhouette must breathe on the pixel grid")
	assert_gte(int(motion_metrics["maximum_top_displacement_px"]), 2,
			"Contour breathing must be visibly larger than one source pixel")
	assert_lte(int(motion_metrics["maximum_top_displacement_px"]), 6,
			"Horizontal texture flow must not tear the authored silhouette")
	assert_eq(int(motion_metrics["bottom_contour_alpha_changes"]), 0,
			"The terrain-facing cloud bottom must remain geometrically fixed")
	assert_gt(int(motion_metrics["left_body_changes"]), 300)
	assert_gt(int(motion_metrics["right_body_changes"]), 300)
	var flow := cloud.call("flow_contract_snapshot") as Dictionary
	assert_eq(String(flow["direction"]), "outward_from_impact")
	assert_eq(int(flow["vertical_phase_weight"]), 0,
			"Cloud motion must not read as a regular downward phase")
	assert_gte(int(flow["maximum_horizontal_displacement_px"]), 2)
	assert_gte(int(flow["maximum_vertical_displacement_px"]), 2)
	assert_eq(int(flow["bottom_lock_depth_px"]), 8)
	assert_almost_eq(float(flow["source_phase_step_per_frame"]),
			1.0 / 4.5, 0.0001,
			"Smoothness must come from subpixel time sampling, not faster travel")

	var start_position := cloud.position
	stage.call("_process", 600.0)
	assert_lte(cloud.position.distance_to(start_position), 0.001,
			"Code cloud animation must never accumulate translation")
	for frame_index: int in [0, 12, 47, 4800]:
		var snapshot := cloud.call("coverage_snapshot", frame_index) as Dictionary
		assert_gte(int(snapshot["bottom_covered_columns"]), 400,
				"The single authored cloud must retain its full readable width")
		assert_eq(int(snapshot["left_padding_opaque_pixels"]), 0)
		assert_eq(int(snapshot["right_padding_opaque_pixels"]), 0)
	assert_null(stage.get_node_or_null("FloatingIsland"),
			"The abandoned island and waterfall must stay retired")
	assert_lt(stage.get_node("SceneSky").get_index(), cloud.get_index())
	for grass_name: String in ["DistantRight2", "DistantRight",
			"DistantLeft2", "DistantLeft"]:
		assert_lt(cloud.get_index(), stage.get_node(grass_name).get_index(),
				"The cloud contact band must stay behind every distant grass bank")


func test_scene9_foreground_uses_distinct_root_locked_readable_wind_profiles() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var expected: Dictionary[String, Dictionary] = {
		"ForegroundMid": {
			"position": Vector2(253.0, 746.0),
			"size": Vector2(408.0, 136.0),
			"scale": Vector2(4.0, 4.0),
			"source_size": Vector2(408.0, 136.0),
			"geometry_y_start": 0.455,
			"root_y": 0.816,
			"columns": 68,
			"rows": 18,
		},
		"ForegroundLeft": {
			"position": Vector2(-96.0, 749.0),
			"size": Vector2(332.0, 188.0),
			"scale": Vector2(3.0, 3.0),
			"source_size": Vector2(332.0, 188.0),
			"geometry_y_start": 0.058,
			"root_y": 0.878,
			"columns": 56,
			"rows": 24,
		},
		"ForegroundRight": {
			"position": Vector2(1420.0, 701.0),
			"size": Vector2(288.0, 216.0),
			"scale": Vector2(3.0, 3.0),
			"source_size": Vector2(288.0, 216.0),
			"geometry_y_start": 0.078,
			"root_y": 0.958,
			"columns": 48,
			"rows": 28,
		},
	}
	var materials: Array[ShaderMaterial] = []
	var tip_displacements: Array[Vector2] = []
	for node_name: String in expected:
		var node := stage.get_node(node_name) as Control
		assert_not_null(node)
		if node == null:
			continue
		assert_eq((node.get_script() as Script).resource_path,
				FOREGROUND_WIND_MESH_PATH)
		assert_eq(node.position, expected[node_name]["position"],
				"Approved manual foreground placement must stay untouched")
		assert_eq(node.size, expected[node_name]["size"])
		assert_eq(node.scale, expected[node_name]["scale"])
		assert_eq(node.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		var contract := node.call("wind_contract_snapshot") as Dictionary
		assert_eq(contract["shader_path"], FOREGROUND_WIND_SHADER_PATH)
		assert_true(bool(contract["resource_local_to_scene"]))
		assert_eq(contract["source_size"], expected[node_name]["source_size"])
		assert_eq(int(contract["mesh_columns"]), expected[node_name]["columns"])
		assert_eq(int(contract["mesh_rows"]), expected[node_name]["rows"])
		assert_almost_eq(float(contract["geometry_y_start"]),
				float(expected[node_name]["geometry_y_start"]), 0.001)
		assert_almost_eq(float(contract["root_y"]),
				float(expected[node_name]["root_y"]), 0.001)
		assert_true(bool(contract["root_locked"]))
		var root_displacement := node.call("displacement_for_testing",
				Vector2(0.5, float(contract["root_y"])), 4.25) as Vector2
		assert_lte(root_displacement.length(), 0.0001,
				"Every asset's real alpha root must remain exactly fixed")
		var max_source_displacement := 0.0
		for time_seconds: float in [0.0, 1.5, 3.0, 4.5, 6.0, 8.0, 10.0, 13.0]:
			for sample_x: float in [0.12, 0.28, 0.46, 0.64, 0.82]:
				var displacement := node.call("displacement_for_testing",
						Vector2(sample_x,
								float(contract["geometry_y_start"]) + 0.02),
						time_seconds) as Vector2
				max_source_displacement = maxf(
						max_source_displacement, absf(displacement.x))
		assert_gt(max_source_displacement * node.scale.x, 5.5,
				"Foreground branch sway must be clearly readable at 1920x1080")
		assert_lt(max_source_displacement * node.scale.x, 13.0,
				"Readable sway must not detach the foreground silhouette")
		materials.append(node.material as ShaderMaterial)
		tip_displacements.append(node.call("displacement_for_testing",
				Vector2(0.42, float(contract["geometry_y_start"]) + 0.02),
				3.0) as Vector2)
	assert_ne(materials[0], materials[1])
	assert_ne(materials[1], materials[2])
	assert_gt(tip_displacements[0].distance_to(tip_displacements[1]), 0.1)
	assert_gt(tip_displacements[1].distance_to(tip_displacements[2]), 0.1,
			"Mid, left and right foreground must not sway in lockstep")
	var shader_source := FileAccess.get_file_as_string(FOREGROUND_WIND_SHADER_PATH)
	assert_true(shader_source.contains("VERTEX.x += horizontal_offset"))
	assert_true(shader_source.contains("root_pin"))
	assert_true(shader_source.contains("cluster_phase"))
	assert_true(shader_source.contains("texture(TEXTURE"))
	assert_false(shader_source.contains("source.a *="),
			"Foreground wind must not introduce opacity breathing")

func _count_changed_pixels(first: Image, second: Image) -> int:
	var count := 0
	for y: int in first.get_height():
		for x: int in first.get_width():
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				count += 1
	return count


func _count_region_differences(
		canvas: Image, reference: Image, canvas_origin: Vector2i) -> int:
	var count := 0
	for y: int in reference.get_height():
		for x: int in reference.get_width():
			if canvas.get_pixelv(canvas_origin + Vector2i(x, y)) \
					!= reference.get_pixel(x, y):
				count += 1
	return count


func _count_source_region_changes(
		canvas: Image, reference: Image, canvas_origin: Vector2i,
		source_rect: Rect2i) -> int:
	var count := 0
	for y: int in range(source_rect.position.y, source_rect.end.y):
		for x: int in range(source_rect.position.x, source_rect.end.x):
			if canvas.get_pixelv(canvas_origin + Vector2i(x, y)) \
					!= reference.get_pixel(x, y):
				count += 1
	return count
