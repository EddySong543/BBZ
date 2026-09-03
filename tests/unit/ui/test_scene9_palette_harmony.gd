extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const STATIC_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_static_depth.gdshader")
const PIXEL_CLOUD_MOTION_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_pixel_cloud_motion.gdshader")
const FOREGROUND_WIND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_foreground_wind.gdshader")
const FAR_GRASS_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_distant_grass_wind.gdshader")
const FAR_GRASS_INTERLOCK_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_distant_grass_interlock.gdshader")
const FAR_MOUNTAIN_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_far_mountain_wind.gdshader")
const PLATFORM_INTERLOCK_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_platform_interlock.gdshader")
const REF49_PATH := "res://ref/ref49.png"


func test_scene9_ref49_palette_is_global_and_preserves_manual_composition() -> void:
	assert_true(FileAccess.file_exists(REF49_PATH))
	var static_source := FileAccess.get_file_as_string(STATIC_SHADER_PATH)
	var far_source := FileAccess.get_file_as_string(FAR_GRASS_SHADER_PATH)
	assert_true(static_source.contains("palette_remap_strength"))
	assert_true(static_source.contains("palette_shadow_color"))
	assert_true(far_source.contains("ground_harmony_strength"))
	assert_true(far_source.contains("ground_harmony_start"))

	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	stage.idle_drift = false
	stage.pointer_parallax = false

	_assert_rect(stage, "DistantPixelCloudBank",
			Rect2(-504.0, 107.0, 2368.0, 544.0), Vector2(1.4, 1.4))
	_assert_rect(stage, "ForegroundMid",
			Rect2(253.0, 746.0, 408.0, 136.0), Vector2(4.0, 4.0))
	_assert_rect(stage, "ForegroundLeft",
			Rect2(-96.0, 749.0, 332.0, 188.0), Vector2(3.0, 3.0))
	_assert_rect(stage, "ForegroundRight",
			Rect2(1420.0, 701.0, 288.0, 216.0), Vector2(3.0, 3.0))
	_assert_rect(stage, "BattlePlatformNew",
			Rect2(-17.0, 490.0, 408.0, 136.0), Vector2(6.0, 6.0))
	_assert_rect(stage, "DistantLeft",
			Rect2(-263.0, 477.0, 332.0, 188.0), Vector2(6.0, 5.0))
	_assert_rect(stage, "DistantLeft2",
			Rect2(1060.0001, 485.0, 332.0, 188.0), Vector2(5.0, 5.0))
	_assert_rect(stage, "DistantRight",
			Rect2(-1486.0, 433.99997, 408.0, 136.0), Vector2(6.0, 5.0))
	_assert_rect(stage, "DistantRight2",
			Rect2(-108.0, 426.0, 408.0, 136.0), Vector2(6.0, 5.0))
	_assert_rect(stage, "DistantLeftMountain",
			Rect2(184.0, 59.0, 288.0, 216.0), Vector2(4.0, 4.0))
	_assert_rect(stage, "DistantRightMountain",
			Rect2(381.0, -36.0, 408.0, 144.0), Vector2(6.0, 6.0))

	var materials: Array[ShaderMaterial] = []
	for node_name: String in ["SceneSky", "DistantPixelCloudBank", "ForegroundMid", "ForegroundLeft",
			"ForegroundRight", "BattlePlatformNew", "DistantLeftMountain",
			"DistantRightMountain", "DistantLeft", "DistantRight"]:
		var material := (stage.get_node(node_name) as CanvasItem).material \
				as ShaderMaterial
		assert_not_null(material, "%s needs an isolated Scene9 grade" % node_name)
		if material != null:
			materials.append(material)
	if materials.size() != 10:
		return
	for material: ShaderMaterial in materials:
		assert_true(material.resource_local_to_scene,
				"Scene9 grading must not leak into any other scene")

	var sky := materials[0]
	var cloud := materials[1]
	var mid := materials[2]
	var near_left := materials[3]
	var near_right := materials[4]
	var platform := materials[5]
	var mountain_left := materials[6]
	var mountain_right := materials[7]
	var far_left := materials[8]
	var far_right := materials[9]
	assert_not_same(near_left, near_right,
			"Different alpha roots require isolated foreground wind profiles")
	assert_not_same(mid, near_left)
	assert_not_same(platform, mid)
	assert_not_same(mountain_left, mountain_right)

	assert_eq(sky.shader.resource_path, STATIC_SHADER_PATH)
	_assert_palette(sky, "64a4e4", "84c4f4", "c4e4fc")
	assert_eq(cloud.shader.resource_path, PIXEL_CLOUD_MOTION_SHADER_PATH)
	_assert_palette(cloud, "84c4f4", "c4e4fc", "f4fcfc")
	assert_gte(float(cloud.get_shader_parameter(&"saturation")), 0.75)
	assert_lte(float(cloud.get_shader_parameter(
			&"palette_remap_strength")), 0.35)

	for material: ShaderMaterial in [mid, near_left, near_right]:
		assert_eq(material.shader.resource_path, FOREGROUND_WIND_SHADER_PATH)
	assert_lte(float(mid.get_shader_parameter(&"saturation")), 0.45)
	_assert_palette(mid, "9cb4d4", "c4d4fc", "ecf4f4")
	_assert_palette(near_left, "3c4c34", "9cacc4", "b4c4ec")

	assert_eq(far_left.shader.resource_path, FAR_GRASS_INTERLOCK_SHADER_PATH)
	assert_eq(far_right.shader.resource_path, FAR_GRASS_SHADER_PATH)
	for material: ShaderMaterial in [far_left, far_right]:
		assert_gte(float(material.get_shader_parameter(&"saturation")), 0.65)
		assert_lte(float(material.get_shader_parameter(
				&"palette_remap_strength")), 0.45)
		assert_lte(float(material.get_shader_parameter(
				&"ground_harmony_strength")), 0.45)
		_assert_palette(material, "9cb4d4", "c4d4fc", "ecf4f4")

	assert_eq(platform.shader.resource_path, PLATFORM_INTERLOCK_SHADER_PATH)
	_assert_palette(platform, "143c44", "546c84", "acc4ec")
	for material: ShaderMaterial in [mountain_left, mountain_right]:
		assert_eq(material.shader.resource_path, FAR_MOUNTAIN_SHADER_PATH)
		assert_gte(float(material.get_shader_parameter(&"saturation")), 0.65)
		_assert_palette(material, "748cb4", "9cb4d4", "ecf4f4")
	assert_lt(_color_distance(
			cloud.get_shader_parameter(&"palette_highlight_color") as Color,
			mid.get_shader_parameter(&"palette_highlight_color") as Color), 0.08,
			"Cloud and grass whites must belong to the same ref49 light family")


func test_scene9_ref49_grass_stays_blue_violet_across_every_depth() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var mid := stage.get_node("ForegroundMid") as Control
	var near_left := stage.get_node("ForegroundLeft") as Control
	var near_right := stage.get_node("ForegroundRight") as Control
	var far_left := stage.get_node("DistantLeft") as Control
	var far_right := stage.get_node("DistantRight") as Control
	var platform := stage.get_node("BattlePlatformNew") as Control
	var mountain_left := stage.get_node("DistantLeftMountain") as Control
	var mountain_right := stage.get_node("DistantRightMountain") as Control

	var mid_grade := _average_color(mid, false, 0.0)
	var near_left_grade := _average_color(near_left, false, 0.0)
	var near_right_grade := _average_color(near_right, false, 0.0)
	var far_left_grade := _average_color(far_left, true, 0.0)
	var far_right_grade := _average_color(far_right, true, 0.0)
	var far_left_roots := _average_color(far_left, true, 0.64)
	var far_right_roots := _average_color(far_right, true, 0.69)
	var platform_grade := _average_color(platform, false, 0.0)
	var mountain_left_grade := _average_color(mountain_left, false, 0.0)
	var mountain_right_grade := _average_color(mountain_right, false, 0.0)

	for distant_silver: Color in [mid_grade, far_left_grade, far_right_grade]:
		assert_gte(_color_chroma(distant_silver), 0.09,
				"Ref49 silver grass must retain a readable blue-violet hue")
		assert_gt(distant_silver.b, distant_silver.g)
		assert_gt(distant_silver.g, distant_silver.r)
	for near_silver: Color in [near_left_grade, near_right_grade]:
		assert_gte(_color_chroma(near_silver), 0.08,
				"Foreground must keep ref49's darker olive/slate depth")
	assert_gte(_luma(far_left_grade), 0.70)
	assert_gte(_luma(far_right_grade), 0.72)
	assert_lt(_color_distance(far_left_roots, platform_grade),
			_color_distance(_source_average(far_left, 0.64),
			_source_average(platform, 0.0)) * 0.8,
			"The left grass roots must converge toward the platform palette")
	assert_lt(_color_distance(far_right_roots, platform_grade),
			_color_distance(_source_average(far_right, 0.69),
			_source_average(platform, 0.0)) * 0.8,
			"The right grass roots must converge toward the platform palette")
	assert_lte(_color_chroma(mountain_left_grade), 0.16)
	assert_lte(_color_chroma(mountain_right_grade), 0.16)
	assert_lt(_color_distance(mountain_left_grade, mountain_right_grade),
			_color_distance(_source_average(mountain_left, 0.0),
			_source_average(mountain_right, 0.0)),
			"Both far mountains must converge without sharing one brightness value")


func _assert_palette(
		material: ShaderMaterial,
		shadow_hex: String,
		mid_hex: String,
		highlight_hex: String) -> void:
	assert_true((material.get_shader_parameter(&"palette_shadow_color") as Color)
			.is_equal_approx(Color(shadow_hex)))
	assert_true((material.get_shader_parameter(&"palette_mid_color") as Color)
			.is_equal_approx(Color(mid_hex)))
	assert_true((material.get_shader_parameter(&"palette_highlight_color") as Color)
			.is_equal_approx(Color(highlight_hex)))


func _assert_rect(
		stage: Node,
		node_name: String,
		expected: Rect2,
		expected_scale: Vector2) -> void:
	var layer := stage.get_node(node_name) as Control
	assert_not_null(layer)
	assert_true(layer.position.is_equal_approx(expected.position),
			"Do not move Eddy's manually composed %s" % node_name)
	assert_true(layer.size.is_equal_approx(expected.size),
			"Do not resize Eddy's manually composed %s" % node_name)
	assert_true(layer.scale.is_equal_approx(expected_scale),
			"Do not rescale Eddy's manually composed %s" % node_name)
	assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func _color_chroma(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) \
			- minf(color.r, minf(color.g, color.b))


func _average_color(layer: Control, far_grass: bool, min_uv_y: float) -> Color:
	var image := (layer.get("texture") as Texture2D).get_image()
	var material := layer.material as ShaderMaterial
	var sum := Vector3.ZERO
	var count := 0
	var first_y := floori(float(image.get_height()) * min_uv_y)
	for y in range(first_y, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var source := image.get_pixel(x, y)
			if source.a <= 0.03:
				continue
			var graded := _grade_pixel(
					source, material, float(y) / float(image.get_height()), far_grass)
			sum += Vector3(graded.r, graded.g, graded.b)
			count += 1
	assert_gt(count, 0)
	return Color(sum.x / count, sum.y / count, sum.z / count, 1.0)


func _source_average(layer: Control, min_uv_y: float) -> Color:
	var image := (layer.get("texture") as Texture2D).get_image()
	var sum := Vector3.ZERO
	var count := 0
	var first_y := floori(float(image.get_height()) * min_uv_y)
	for y in range(first_y, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var source := image.get_pixel(x, y)
			if source.a <= 0.03:
				continue
			sum += Vector3(source.r, source.g, source.b)
			count += 1
	assert_gt(count, 0)
	return Color(sum.x / count, sum.y / count, sum.z / count, 1.0)


func _grade_pixel(
		source: Color,
		material: ShaderMaterial,
		uv_y: float,
		far_grass: bool) -> Color:
	var weights := Vector3(0.299, 0.587, 0.114) if far_grass \
			else Vector3(0.2126, 0.7152, 0.0722)
	var source_rgb := Vector3(source.r, source.g, source.b)
	var luma := source_rgb.dot(weights)
	var saturation := float(material.get_shader_parameter(&"saturation"))
	var contrast := float(material.get_shader_parameter(&"contrast"))
	var brightness := float(material.get_shader_parameter(&"brightness"))
	var tint := material.get_shader_parameter(&"tint_color") as Color
	var graded := Vector3(luma, luma, luma).lerp(source_rgb, saturation)
	graded = (graded - Vector3(0.5, 0.5, 0.5)) * contrast \
			+ Vector3(0.5, 0.5, 0.5)
	graded *= Vector3(tint.r, tint.g, tint.b) * brightness
	var shadow := material.get_shader_parameter(&"palette_shadow_color") as Color
	var middle := material.get_shader_parameter(&"palette_mid_color") as Color
	var highlight := material.get_shader_parameter(&"palette_highlight_color") as Color
	var shadow_to_mid := Vector3(shadow.r, shadow.g, shadow.b).lerp(
			Vector3(middle.r, middle.g, middle.b), smoothstep(0.08, 0.58, luma))
	var palette_color := shadow_to_mid.lerp(
			Vector3(highlight.r, highlight.g, highlight.b),
			smoothstep(0.52, 0.94, luma))
	graded = graded.lerp(palette_color, float(material.get_shader_parameter(
			&"palette_remap_strength")))
	if far_grass:
		var harmony := smoothstep(
				float(material.get_shader_parameter(&"ground_harmony_start")),
				1.0, uv_y) * float(material.get_shader_parameter(
				&"ground_harmony_strength"))
		var ground := material.get_shader_parameter(&"ground_harmony_color") as Color
		var grounded := Vector3(ground.r, ground.g, ground.b) \
				* lerpf(0.72, 1.08, clampf(luma, 0.0, 1.0))
		graded = graded.lerp(grounded, harmony)
	var steps := maxf(float(material.get_shader_parameter(&"palette_steps")), 1.0)
	graded = Vector3(
			floor(clampf(graded.x, 0.0, 1.0) * steps + 0.5) / steps,
			floor(clampf(graded.y, 0.0, 1.0) * steps + 0.5) / steps,
			floor(clampf(graded.z, 0.0, 1.0) * steps + 0.5) / steps)
	return Color(graded.x, graded.y, graded.z, source.a)


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))
