extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const MESH_SCRIPT_PATH := "res://src/ui/components/scene5_wheat_mesh.gd"
const MOUNTAIN_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_far_mountain_wind.gdshader")
const PLATFORM_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_platform_interlock.gdshader")
const GRASS_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_distant_grass_interlock.gdshader")


func test_scene9_far_mountains_use_local_ridge_wind_without_moving_composition() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var left := stage.get_node("DistantLeftMountain") as Control
	var right := stage.get_node("DistantRightMountain") as Control

	_assert_rect(left, Rect2(184.0, 59.0, 288.0, 216.0), Vector2(4.0, 4.0))
	_assert_rect(right, Rect2(381.0, -36.0, 408.0, 144.0), Vector2(6.0, 6.0))
	assert_not_null(left.get_script())
	assert_not_null(right.get_script())
	if left.get_script() == null or right.get_script() == null:
		return
	assert_eq((left.get_script() as Script).resource_path, MESH_SCRIPT_PATH)
	assert_eq((right.get_script() as Script).resource_path, MESH_SCRIPT_PATH)
	assert_eq(int(left.get("mesh_columns")), 48)
	assert_eq(int(right.get("mesh_columns")), 56)
	assert_eq(int(left.get("mesh_rows")), 18)
	assert_eq(int(right.get("mesh_rows")), 18)

	var left_material := left.material as ShaderMaterial
	var right_material := right.material as ShaderMaterial
	assert_not_null(left_material)
	assert_not_null(right_material)
	assert_not_same(left_material, right_material)
	for material: ShaderMaterial in [left_material, right_material]:
		assert_true(material.resource_local_to_scene)
		assert_eq(material.shader.resource_path, MOUNTAIN_SHADER_PATH)
		assert_eq(material.get_shader_parameter(&"motion_strength"), 1.0)
		assert_gte(float(material.get_shader_parameter(&"cycle_sec")), 18.0)
		assert_lte(float(material.get_shader_parameter(&"sway_px")), 1.0)
		assert_lte(float(material.get_shader_parameter(&"ridge_band")), 0.06)
		assert_lte(float(material.get_shader_parameter(&"field_wave_speed")), 0.014)
	assert_ne(left_material.get_shader_parameter(&"phase_seed"),
			right_material.get_shader_parameter(&"phase_seed"))
	assert_not_null(left.get("texture"))
	assert_not_null(right.get("texture"))
	assert_gt(_count_opaque_ridge_pixels(left, left_material), 60,
			"The left ridge curve must cross real authored grass pixels")
	assert_gt(_count_opaque_ridge_pixels(right, right_material), 90,
			"The right ridge curve must cross real authored snow-grass pixels")

	var shader_source := FileAccess.get_file_as_string(MOUNTAIN_SHADER_PATH)
	assert_true(shader_source.contains("ridge_weight"))
	assert_true(shader_source.contains("world_x"))
	assert_true(shader_source.contains("field_wave"))
	assert_false(shader_source.contains("hint_screen_texture"))


func test_scene9_ground_join_uses_local_contact_shadow_instead_of_interlock() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform := stage.get_node("BattlePlatformNew") as Control
	var left := stage.get_node("DistantLeft") as Control
	var left_two := stage.get_node("DistantLeft2") as Control
	var right := stage.get_node("DistantRight") as Control
	var right_two := stage.get_node("DistantRight2") as Control
	var expected_meshes: Dictionary[String, Vector2i] = {
		"DistantRightMountain": Vector2i(56, 18),
		"DistantLeftMountain": Vector2i(48, 18),
		"DistantRight2": Vector2i(56, 12),
		"DistantRight": Vector2i(56, 12),
		"DistantLeft2": Vector2i(48, 12),
		"DistantLeft": Vector2i(48, 12),
		"ForegroundMid": Vector2i(68, 18),
		"ForegroundLeft": Vector2i(56, 24),
		"ForegroundRight": Vector2i(48, 28),
	}
	var total_quads := 0
	for node_name: String in expected_meshes:
		var mesh_node := stage.get_node(node_name) as Control
		var density := expected_meshes[node_name]
		assert_eq(int(mesh_node.get("mesh_columns")), density.x)
		assert_eq(int(mesh_node.get("mesh_rows")), density.y)
		total_quads += density.x * density.y
	assert_eq(total_quads, 8280)
	assert_lte(total_quads, 10000,
			"Scene9 must not restore the previous 28,729-quad wind field")

	_assert_rect(platform, Rect2(-17.0, 490.0, 408.0, 136.0), Vector2(6.0, 6.0))
	_assert_rect(left, Rect2(-263.0, 477.0, 332.0, 188.0), Vector2(6.0, 5.0))
	_assert_rect(left_two, Rect2(1060.0001, 485.0, 332.0, 188.0), Vector2(5.0, 5.0))
	_assert_rect(right, Rect2(-1486.0, 433.99997, 408.0, 136.0), Vector2(6.0, 5.0))
	_assert_rect(right_two, Rect2(-108.0, 426.0, 408.0, 136.0), Vector2(6.0, 5.0))

	var platform_material := platform.material as ShaderMaterial
	var left_material := left.material as ShaderMaterial
	var left_two_material := left_two.material as ShaderMaterial
	assert_eq(platform_material.shader.resource_path, PLATFORM_SHADER_PATH)
	assert_eq(left_material.shader.resource_path, GRASS_SHADER_PATH)
	assert_eq(left_two_material.shader.resource_path, GRASS_SHADER_PATH)
	assert_not_same(left_material, left_two_material,
			"Each manually placed left bank needs its own authored scene rectangle")
	for material: ShaderMaterial in [platform_material, left_material, left_two_material]:
		assert_true(material.resource_local_to_scene)
		assert_eq(material.get_shader_parameter(&"contact_enabled"), false)
		assert_eq(material.get_shader_parameter(&"contact_shadow_enabled"), true)
		assert_lte(float(material.get_shader_parameter(&"contact_shadow_strength")),
				0.28)
		assert_lte(float(material.get_shader_parameter(&"contact_shadow_radius_px")),
				12.0)
	assert_not_null(platform_material.get_shader_parameter(&"contact_right_texture"))
	assert_not_null(left_material.get_shader_parameter(&"contact_platform_texture"))
	assert_not_null(left_two_material.get_shader_parameter(&"contact_platform_texture"))
	assert_eq(left_material.get_shader_parameter(&"source_trim_enabled"), true)
	assert_eq(left_material.get_shader_parameter(&"source_trim_rect_px"),
			Vector4(0.0, 0.0, 109.0, 80.0))
	var contact_counts := _count_real_contact_claims(
			platform, right, right_two, left, left_two)
	assert_gte(contact_counts.x, 300.0,
			"The local platform shadow must overlap a readable amount of real right grass")
	assert_lte(contact_counts.x, 700.0,
			"The platform shadow must stay within a shallow contact surface")
	assert_gte(contact_counts.y, 8.0,
			"The left grass shadow must meet real platform surface pixels")
	assert_lte(contact_counts.y, 60.0,
			"The left grass shadow must remain local")

	for shader_path: String in [PLATFORM_SHADER_PATH, GRASS_SHADER_PATH]:
		var source := FileAccess.get_file_as_string(shader_path)
		assert_true(source.contains("sample_layer_alpha"))
		assert_true(source.contains("surface_band"))
		assert_true(source.contains("interlock_cluster"))
		assert_true(source.contains("contact_enabled"))
		assert_true(source.contains("contact_shadow_enabled"))
		assert_true(source.contains("soft_contact_alpha"))
		assert_false(source.contains("hint_screen_texture"))
		assert_false(source.contains("filter_linear"))


func _assert_rect(layer: Control, expected: Rect2, expected_scale: Vector2) -> void:
	assert_not_null(layer)
	assert_true(layer.position.is_equal_approx(expected.position))
	assert_true(layer.size.is_equal_approx(expected.size))
	assert_true(layer.scale.is_equal_approx(expected_scale))
	assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func _count_opaque_ridge_pixels(layer: Control, material: ShaderMaterial) -> int:
	var image := (layer.get("texture") as Texture2D).get_image()
	var start_x := float(material.get_shader_parameter(&"ridge_start_x"))
	var end_x := float(material.get_shader_parameter(&"ridge_end_x"))
	var start_y := float(material.get_shader_parameter(&"ridge_start_y"))
	var end_y := float(material.get_shader_parameter(&"ridge_end_y"))
	var curve_power := float(material.get_shader_parameter(&"ridge_curve_power"))
	var band := float(material.get_shader_parameter(&"ridge_band"))
	var count := 0
	for x in range(image.get_width()):
		var uv_x := (float(x) + 0.5) / float(image.get_width())
		var progress := clampf((uv_x - start_x) / maxf(end_x - start_x, 0.001),
				0.0, 1.0)
		var ridge_y := lerpf(start_y, end_y, pow(progress, curve_power))
		for y in range(image.get_height()):
			var uv_y := (float(y) + 0.5) / float(image.get_height())
			if absf(uv_y - ridge_y) <= band \
					and image.get_pixel(x, y).a >= 0.5:
				count += 1
	return count


func _count_real_contact_claims(
		platform: Control,
		right: Control,
		right_two: Control,
		left: Control,
		left_two: Control) -> Vector2:
	var platform_image := (platform.get("texture") as Texture2D).get_image()
	var right_image := (right.get("texture") as Texture2D).get_image()
	var left_image := (left.get("texture") as Texture2D).get_image()
	var platform_rect := _scene_rect(platform)
	var right_rects: Array[Rect2] = [_scene_rect(right), _scene_rect(right_two)]
	var left_rects: Array[Rect2] = [_scene_rect(left), _scene_rect(left_two)]
	var platform_claims := 0
	for y in range(platform_image.get_height()):
		for x in range(platform_image.get_width()):
			if not _is_surface_pixel(platform_image, x, y):
				continue
			var scene_position := platform_rect.position + Vector2(
					(float(x) + 0.5) / float(platform_image.get_width()),
					(float(y) + 0.5) / float(platform_image.get_height())) \
					* platform_rect.size
			var grass_alpha := 0.0
			for grass_rect: Rect2 in right_rects:
				grass_alpha = maxf(grass_alpha,
						_sample_scene_alpha(right_image, grass_rect, scene_position))
			if grass_alpha >= 0.5 and _interlock_cluster(scene_position):
				platform_claims += 1

	var left_claims := 0
	for left_rect: Rect2 in left_rects:
		for y in range(left_image.get_height()):
			for x in range(left_image.get_width()):
				if left_image.get_pixel(x, y).a < 0.5:
					continue
				var scene_position := left_rect.position + Vector2(
						(float(x) + 0.5) / float(left_image.get_width()),
						(float(y) + 0.5) / float(left_image.get_height())) \
						* left_rect.size
				var platform_uv := (scene_position - platform_rect.position) \
						/ platform_rect.size
				var platform_x := floori(platform_uv.x * platform_image.get_width())
				var platform_y := floori(platform_uv.y * platform_image.get_height())
				if platform_x < 0 or platform_x >= platform_image.get_width() \
						or platform_y < 0 or platform_y >= platform_image.get_height():
					continue
				if _is_surface_pixel(platform_image, platform_x, platform_y) \
						and not _interlock_cluster(scene_position):
					left_claims += 1
	return Vector2(platform_claims, left_claims)


func _scene_rect(layer: Control) -> Rect2:
	return Rect2(layer.position, layer.size * layer.scale)


func _sample_scene_alpha(image: Image, scene_rect: Rect2, scene_position: Vector2) -> float:
	if not scene_rect.has_point(scene_position):
		return 0.0
	var uv := (scene_position - scene_rect.position) / scene_rect.size
	var x := clampi(floori(uv.x * image.get_width()), 0, image.get_width() - 1)
	var y := clampi(floori(uv.y * image.get_height()), 0, image.get_height() - 1)
	return image.get_pixel(x, y).a


func _is_surface_pixel(image: Image, x: int, y: int) -> bool:
	if image.get_pixel(x, y).a < 0.5:
		return false
	for depth in range(1, 4):
		if y - depth < 0 or image.get_pixel(x, y - depth).a < 0.5:
			return true
	return false


func _interlock_cluster(scene_position: Vector2) -> bool:
	var cell_x := floori(scene_position.x / 18.0)
	var cell_y := floori(scene_position.y / 12.0)
	var cluster_id := posmod(cell_x * 2 + cell_y * 3 + posmod(cell_x, 3), 7)
	return cluster_id < 3
