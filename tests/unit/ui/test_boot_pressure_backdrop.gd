extends GutTest

const BOOT_SCREEN_PATH := "res://src/ui/boot_screen.tscn"
const SOURCE_SIZE := Vector2(1672.0, 941.0)
const PAPER_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_paper.gdshader")
const BLUE_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_blue_layer.gdshader")
const BLUE_MOTION_SCRIPT_PATH := (
	"res://src/ui/components/boot_blue_flow_motion.gd")
const MOTION_SCRIPT_PATH := (
	"res://src/ui/components/boot_pressure_motion.gd")
const GOLD_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_gold_energy.gdshader")
const PRESSURE_CONTOUR_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_pressure_contours.gdshader")
const FOREGROUND_BRUSH_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_foreground_brush.gdshader")
const TITLE_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_title_perspective.gdshader")
const CHARACTER_DEPTH_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_character_depth.gdshader")
const BLUE_LAYER_PATHS: Array[String] = [
	"res://assets/ui/boot/boot_pressure_blue_base.png",
	"res://assets/ui/boot/boot_pressure_blue_mid.png",
	"res://assets/ui/boot/boot_pressure_blue_light.png",
]
const BLUE_FOREGROUND_PATH := (
	"res://assets/ui/boot/boot_pressure_blue_foreground.png")
const GOLD_COMBINED_PATH := (
	"res://assets/ui/boot/boot_pressure_gold_combined.png")
const GOLD_FLOW_PATH := (
	"res://assets/ui/boot/boot_pressure_gold_flow.png")
const BLUE_INTRO_PATH := (
	"res://assets/ui/boot/boot_pressure_blue_intro_path.png")


func test_boot_pressure_assets_are_transparent_full_size_layers() -> void:
	for resource_path: String in (
			BLUE_LAYER_PATHS
			+ [BLUE_FOREGROUND_PATH, GOLD_COMBINED_PATH]
	):
		var exists := ResourceLoader.exists(resource_path)
		assert_true(exists, resource_path)
		if not exists:
			continue
		var texture := load(resource_path) as Texture2D
		assert_not_null(texture)
		assert_eq(texture.get_size(), SOURCE_SIZE)
		var image := texture.get_image()
		assert_almost_eq(
			image.get_pixel(0, 0).a,
			0.0,
			0.001)
	assert_true(ResourceLoader.exists(GOLD_FLOW_PATH), GOLD_FLOW_PATH)
	var gold_texture := load(GOLD_COMBINED_PATH) as Texture2D
	var gold_image := gold_texture.get_image()
	for filled_hole_center: Vector2i in [
		Vector2i(702, 277),
		Vector2i(743, 304),
		Vector2i(718, 343),
		Vector2i(776, 368),
	]:
		assert_gt(
			gold_image.get_pixelv(filled_hole_center).a,
			0.95,
			"Confirmed hand-left gold hole must be filled.")
	if ResourceLoader.exists(GOLD_FLOW_PATH):
		var flow_texture := load(GOLD_FLOW_PATH) as Texture2D
		assert_not_null(flow_texture)
		assert_eq(flow_texture.get_size(), SOURCE_SIZE)
		var flow_image := flow_texture.get_image()
		var phase_one := flow_image.get_pixel(650, 120)
		var phase_two := flow_image.get_pixel(650, 128)
		assert_almost_eq(phase_one.b, 1.0, 0.01)
		assert_almost_eq(phase_two.b, 1.0, 0.01)
		assert_gt(phase_one.r, 0.5)
		assert_lt(phase_one.g, 0.5)
		assert_gt(absf(phase_one.a - phase_two.a), 0.005)
	assert_true(ResourceLoader.exists(BLUE_INTRO_PATH), BLUE_INTRO_PATH)
	var intro_texture := load(BLUE_INTRO_PATH) as Texture2D
	assert_not_null(intro_texture)
	if intro_texture != null:
		var intro_image := intro_texture.get_image()
		var diagonal_values: Array[float] = []
		for point: Vector2i in [
			Vector2i(900, 500),
			Vector2i(1000, 550),
			Vector2i(1100, 600),
			Vector2i(1200, 650),
			Vector2i(1300, 700),
			Vector2i(1400, 750),
			Vector2i(1500, 800),
		]:
			diagonal_values.append(intro_image.get_pixelv(point).r)
		assert_lt(
			diagonal_values.max() - diagonal_values.min(),
			0.08,
			"The lower-right brush center must reveal as one stroke.")


func test_boot_screen_uses_black_stage_graphite_brush_and_stable_gold() -> void:
	var boot := await _instantiate_boot()
	var black_base := boot.get_node("IntroBlackBase") as ColorRect
	var stage := boot.get_node("BackgroundStage") as BattleStage

	assert_not_null(black_base)
	assert_eq(black_base.color, Color.BLACK)
	assert_eq(black_base.get_index(), 0)
	assert_not_null(stage)
	assert_true(stage.idle_drift)
	assert_true(stage.pointer_parallax)
	assert_false(stage.demo_click_shake)
	assert_eq(stage.get_index(), 1)
	assert_lt(stage.get_index(), boot.get_node("TitleColumn").get_index())
	assert_lt(stage.get_index(), boot.get_node("Character").get_index())

	for removed_name: String in [
		"PressurePlate",
		"BlueDeepFlow",
		"BlueMidFlow",
		"BlueLightFlow",
		"GoldenHalo",
		"EnergyFragments",
		"LeftForeground",
	]:
		assert_null(stage.get_node_or_null(removed_name))

	var paper := stage.get_node_or_null("PaperBase") as ColorRect
	assert_not_null(paper)
	if paper != null:
		var paper_material := paper.material as ShaderMaterial
		assert_not_null(paper_material)
		assert_eq(
			paper_material.shader.resource_path,
			PAPER_SHADER_PATH)
		assert_true(
			Color(paper_material.get_shader_parameter(
					&"paper_color")).is_equal_approx(
						Color("#080a0f")))
		assert_almost_eq(
			float(paper_material.get_shader_parameter(
					&"fine_grain_strength")),
			0.01,
			0.001)

	var pressure_contours := (
		stage.get_node_or_null("PressureContours") as ColorRect)
	assert_not_null(pressure_contours)
	if pressure_contours != null:
		assert_lt(
			pressure_contours.get_index(),
			stage.get_node("BlueBase").get_index())
		assert_almost_eq(
			float(pressure_contours.get_meta("parallax_factor")),
			0.14,
			0.001)
		var contour_material := (
			pressure_contours.material as ShaderMaterial)
		assert_not_null(contour_material)
		assert_eq(
			contour_material.shader.resource_path,
			PRESSURE_CONTOUR_SHADER_PATH)
		assert_true(
			Color(contour_material.get_shader_parameter(
					&"wave_color")).is_equal_approx(
						Color(0.105882, 0.149020, 0.192157, 0.42)))
		assert_true(
			Vector2(contour_material.get_shader_parameter(
					&"virtual_resolution")).is_equal_approx(
						Vector2(320.0, 180.0)))
		assert_almost_eq(
			float(contour_material.get_shader_parameter(
					&"wave_spacing")),
			0.225,
			0.001)
		assert_almost_eq(
			float(contour_material.get_shader_parameter(
					&"wave_half_width")),
			0.018,
			0.001)
		assert_almost_eq(
			float(contour_material.get_shader_parameter(
					&"wave_period")),
			44.0,
			0.001)
		assert_true(
			Vector2(contour_material.get_shader_parameter(
					&"flow_direction")).is_equal_approx(
						Vector2(-1.0, 0.55)))
		assert_almost_eq(
			float(contour_material.get_shader_parameter(
					&"direction_spread")),
			0.70,
			0.001)

	var graphite_contracts: Array[Array] = [
		["BlueBase", BLUE_LAYER_PATHS[0], 0.0, 7.4, 0.0, 0.0, 0.25],
		["BlueMid", BLUE_LAYER_PATHS[1], 28.0, 5.0, 2.0, 0.10, 0.45],
		["BlueLight", BLUE_LAYER_PATHS[2], 56.0, 3.6, 3.2, 0.18, 0.65],
	]
	for contract: Array in graphite_contracts:
		var layer := stage.get_node_or_null(contract[0]) as TextureRect
		assert_not_null(layer)
		if layer == null:
			continue
		assert_eq(layer.texture.resource_path, contract[1])
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(
			float(layer.get_meta("parallax_factor")),
			float(contract[6]))
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, BLUE_SHADER_PATH)
		assert_almost_eq(
			float(material.get_shader_parameter(&"motion_pixels")),
			float(contract[2]),
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"motion_period")),
			float(contract[3]),
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"bend_pixels")),
			float(contract[4]),
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"flow_contrast")),
			float(contract[5]),
			0.001)
		assert_true(
			Vector2(material.get_shader_parameter(
					&"motion_direction")).is_equal_approx(
						Vector2(-1.0, 0.55)))
		assert_true(
			Vector3(material.get_shader_parameter(
					&"palette_shadow")).is_equal_approx(
						Vector3(0.203922, 0.227451, 0.250980)))
		assert_true(
			Vector3(material.get_shader_parameter(
					&"palette_mid")).is_equal_approx(
						Vector3(0.349020, 0.388235, 0.431373)))
		assert_true(
			Vector3(material.get_shader_parameter(
					&"palette_light")).is_equal_approx(
						Vector3(0.666667, 0.705882, 0.745098)))
		assert_almost_eq(
			float(material.get_shader_parameter(&"palette_strength")),
			1.0,
			0.001)

	var blue_controller := stage.get_node_or_null("BlueFlowMotion")
	assert_not_null(blue_controller)
	if blue_controller != null:
		assert_eq(
			blue_controller.get_script().resource_path,
			BLUE_MOTION_SCRIPT_PATH)
		var first_blue_time := float(
			blue_controller.call(&"animation_time"))
		await get_tree().create_timer(0.08).timeout
		var last_blue_time := float(
			blue_controller.call(&"animation_time"))
		assert_gt(last_blue_time, first_blue_time)
		for layer_name: String in ["BlueBase", "BlueMid", "BlueLight"]:
			var layer := stage.get_node(layer_name) as TextureRect
			var material := layer.material as ShaderMaterial
			assert_gt(
				float(material.get_shader_parameter(&"motion_time")),
				first_blue_time)

	for removed_gold_name: String in [
		"GoldInner",
		"GoldMid",
		"GoldOuter",
	]:
		assert_null(stage.get_node_or_null(removed_gold_name))

	var gold_energy := stage.get_node_or_null("GoldEnergy") as TextureRect
	assert_not_null(gold_energy)
	if gold_energy != null:
		assert_eq(gold_energy.texture.resource_path, GOLD_COMBINED_PATH)
		assert_eq(
			gold_energy.texture_filter,
			CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_almost_eq(
			float(gold_energy.get_meta("parallax_factor")),
			0.82,
			0.001)
		assert_almost_eq(gold_energy.rotation, 0.0, 0.0001)
		var material := gold_energy.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, GOLD_SHADER_PATH)
		var flow_texture := material.get_shader_parameter(
				&"flow_texture") as Texture2D
		assert_not_null(flow_texture)
		if flow_texture != null:
			assert_eq(flow_texture.resource_path, GOLD_FLOW_PATH)
		assert_almost_eq(
			float(material.get_shader_parameter(&"hand_flow_pixels")),
			2.5,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"escape_flow_pixels")),
			4.0,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"flow_period")),
			5.2,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(
					&"minimum_source_alpha")),
			0.72,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(
					&"hand_motion_strength")),
			0.16,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(
					&"escape_motion_strength")),
			0.38,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(
					&"escape_highlight_strength")),
			0.52,
			0.001)
		assert_true(
			Vector3(material.get_shader_parameter(
					&"escape_highlight_color")).is_equal_approx(
						Vector3(1.0, 0.86, 0.54)))

	var foreground_brush := (
		stage.get_node_or_null("ForegroundBrush") as TextureRect)
	assert_not_null(foreground_brush)
	if foreground_brush != null:
		assert_gt(
			foreground_brush.get_index(),
			stage.get_node("GoldEnergy").get_index())
		assert_eq(
			foreground_brush.texture.resource_path,
			BLUE_FOREGROUND_PATH)
		assert_eq(
			foreground_brush.texture_filter,
			CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_almost_eq(
			float(foreground_brush.get_meta("parallax_factor")),
			1.08,
			0.001)
		var foreground_material := (
			foreground_brush.material as ShaderMaterial)
		assert_not_null(foreground_material)
		assert_eq(
			foreground_material.shader.resource_path,
			FOREGROUND_BRUSH_SHADER_PATH)
		assert_true(
			Color(foreground_material.get_shader_parameter(
					&"tint_color")).is_equal_approx(
						Color("#3a4148")))
		assert_almost_eq(
			float(foreground_material.get_shader_parameter(
					&"opacity")),
			0.16,
			0.001)
		assert_almost_eq(
			float(foreground_material.get_shader_parameter(
					&"tint_strength")),
			0.9,
			0.001)

	var controller := stage.get_node_or_null("PressureMotion")
	assert_not_null(controller)
	if controller != null:
		assert_eq(controller.get_script().resource_path, MOTION_SCRIPT_PATH)
		assert_almost_eq(controller.flow_period, 5.2, 0.001)
		assert_almost_eq(controller.contour_period, 44.0, 0.001)

	assert_null(boot.get_node_or_null("Background"))
	assert_null(boot.get_node_or_null("TitleColumn/TitleBoard"))


func test_boot_gold_assets_stay_anchored_while_local_energy_advances() -> void:
	var boot := await _instantiate_boot()
	var stage := boot.get_node("BackgroundStage")
	var controller := stage.get_node_or_null("PressureMotion")
	assert_not_null(controller)
	if controller == null:
		return

	var gold_energy := stage.get_node_or_null("GoldEnergy") as TextureRect
	assert_not_null(gold_energy)
	if gold_energy == null:
		return
	var first_time := float(controller.call(&"animation_time"))
	var first_shader_time: float = float(
		(gold_energy.material as ShaderMaterial)
		.get_shader_parameter(&"motion_time"))
	await get_tree().create_timer(0.08).timeout
	var last_time := float(controller.call(&"animation_time"))
	assert_gt(last_time, first_time)
	assert_almost_eq(gold_energy.rotation, 0.0, 0.0001)
	var material := gold_energy.material as ShaderMaterial
	assert_gt(
		float(material.get_shader_parameter(&"motion_time")),
		first_shader_time)


func test_boot_pressure_contours_advance_outward_without_reverse() -> void:
	var boot := await _instantiate_boot()
	var stage := boot.get_node("BackgroundStage")
	var controller := stage.get_node_or_null("PressureMotion")
	var contours := stage.get_node_or_null("PressureContours") as ColorRect
	assert_not_null(controller)
	assert_not_null(contours)
	if controller == null or contours == null:
		return

	var material := contours.material as ShaderMaterial
	var first_time := float(
		material.get_shader_parameter(&"motion_time"))
	await get_tree().create_timer(0.08).timeout
	var last_time := float(
		material.get_shader_parameter(&"motion_time"))
	assert_gt(last_time, first_time)

	var file := FileAccess.open(
		PRESSURE_CONTOUR_SHADER_PATH,
		FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var source := file.get_as_text()
	assert_true(source.contains("uniform float motion_time"))
	assert_true(source.contains("outward_phase"))
	assert_true(source.contains("shifted_radius"))
	assert_true(source.contains("fract("))
	assert_true(source.contains("pixel_edge"))
	assert_true(source.contains("pixelated_mask"))
	assert_true(source.contains("floor(UV * safe_resolution)"))
	assert_true(source.contains("flow_direction"))
	assert_true(source.contains("direction_alignment"))
	assert_false(source.contains("diagonal_arc_window"))
	assert_false(source.contains("horizontal_arc_window"))
	assert_false(source.contains("TIME"))
	assert_false(source.contains("sin("))
	assert_false(source.contains("cos("))


func test_boot_gold_shader_advects_upper_right_without_breathing() -> void:
	var file := FileAccess.open(GOLD_SHADER_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var source := file.get_as_text()
	assert_true(source.contains("uniform sampler2D flow_texture"))
	assert_true(source.contains("flow_region"))
	assert_true(source.contains("minimum_source_alpha"))
	assert_true(source.contains("hand_motion_strength"))
	assert_true(source.contains("escape_motion_strength"))
	assert_true(source.contains("escape_highlight_strength"))
	assert_true(source.contains("circular_phase_distance"))
	assert_true(source.contains("UV - flow_offset"))
	assert_true(source.contains("flow.a"))
	assert_true(source.contains("energy.a = max"))
	assert_true(source.contains("source.a * clamp(minimum_source_alpha"))
	assert_true(source.contains("transported_coverage"))
	assert_true(source.contains("escape_highlight_color"))
	assert_true(source.contains("outer_wave"))
	assert_false(source.contains("sin("))
	assert_false(source.contains("phase_a"))
	assert_false(source.contains("phase_b"))
	assert_false(source.contains("hand_value_strength"))
	assert_false(source.contains("escape_value_strength"))
	assert_false(source.contains("escape_wave"))
	assert_false(source.contains("fragments +="))
	assert_false(source.contains("fragment_a"))
	assert_false(source.contains("fragment_b"))
	assert_false(source.contains("fragment_c"))
	assert_false(source.contains("max(base.rgb"))
	assert_false(source.contains("escape_progress"))
	assert_false(source.contains("escape_fade"))
	assert_false(source.contains("energy.a *="))


func test_boot_title_uses_white_gold_palette_on_black_stage() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn")
	assert_true(title_column.visible)
	var contracts: Array[Array] = [
		["BoTopShadow", "BoTop"],
		["BoMiddleShadow", "BoMiddle"],
		["ZanBottomShadow", "ZanBottom"],
		["EnglishSubtitleShadow", "EnglishSubtitle"],
	]
	for contract: Array in contracts:
		var shadow := title_column.get_node(contract[0]) as TextureRect
		var face := title_column.get_node(contract[1]) as TextureRect
		assert_not_null(shadow)
		assert_eq(shadow.texture, face.texture)
		assert_eq(shadow.position - face.position, Vector2(6.0, 7.0))
		assert_lt(shadow.get_index(), face.get_index())
		assert_eq(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE)

		var shadow_material := shadow.material as ShaderMaterial
		assert_true(
			Color(shadow_material.get_shader_parameter(
					&"structure_color")).is_equal_approx(
						Color(0.031373, 0.070588, 0.164706, 0.28)))
		assert_eq(
			shadow_material.get_shader_parameter(&"outline_strength"),
			0.0)

		var face_material := face.material as ShaderMaterial
		assert_true(
			Color(face_material.get_shader_parameter(
					&"structure_color")).is_equal_approx(
						Color("#0f1b26")))
		assert_true(
			Color(face_material.get_shader_parameter(
					&"face_color")).is_equal_approx(
						Color("#f4f6f8")))
		assert_true(
			Color(face_material.get_shader_parameter(
					&"energy_color")).is_equal_approx(
						Color("#eda63a")))
		assert_true(
			Color(face_material.get_shader_parameter(
					&"energy_peak_color")).is_equal_approx(
						Color("#ffd773")))
		assert_gt(
			float(face_material.get_shader_parameter(
				&"flow_start_uv_x")),
			float(face_material.get_shader_parameter(
				&"flow_end_uv_x")))
		assert_eq(
			face_material.get_shader_parameter(
				&"flow_pixel_step_texels"),
			4.0)
		assert_eq(
			face_material.get_shader_parameter(
				&"flow_value_steps"),
			3.0)
		assert_eq(
			face_material.get_shader_parameter(&"outline_strength"),
			1.0)
		assert_eq(
			face_material.get_shader_parameter(&"outline_width_texels"),
			1.0)
		var outline_color: Color = face_material.get_shader_parameter(
				&"outline_color")
		assert_true(
			outline_color.is_equal_approx(
				Color("#0f1b26")))
	assert_almost_eq(
		float(title_column.get("flow_period_seconds")),
		8.4,
		0.001)
	assert_almost_eq(
		float(title_column.get("flow_duration_seconds")),
		3.6,
		0.001)

	var shader_file := FileAccess.open(TITLE_SHADER_PATH, FileAccess.READ)
	assert_not_null(shader_file)
	if shader_file != null:
		var shader_source := shader_file.get_as_text()
		assert_true(shader_source.contains("float source_cell = floor"))
		assert_true(shader_source.contains("continuous_head_cell"))
		assert_true(shader_source.contains("cell_blend"))
		assert_true(shader_source.contains("lower_intensity"))
		assert_true(shader_source.contains("upper_intensity"))
		assert_true(shader_source.contains("stepped_trail"))
		assert_true(shader_source.contains("block_pattern"))
		assert_false(shader_source.contains("head_pixel_x = ("))
		assert_false(shader_source.contains("fragment_strength"))
		assert_false(shader_source.contains("square_fragment"))


func test_boot_title_uses_one_horizontal_perspective_field() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn") as Control
	assert_true(title_column.position.is_equal_approx(Vector2(37.0, 263.0)))
	assert_true(title_column.size.is_equal_approx(Vector2(806.4, 340.0)))
	assert_eq(title_column.rotation, 0.0)

	var contracts: Array[Array] = [
		[
			"BoTopShadow",
			"BoTop",
			Vector2(93.0, -67.0),
			0.0,
			270.0 / 726.0,
		],
		[
			"BoMiddleShadow",
			"BoMiddle",
			Vector2(321.0, -62.0),
			228.0 / 726.0,
			498.0 / 726.0,
		],
		[
			"ZanBottomShadow",
			"ZanBottom",
			Vector2(546.0, -62.0),
			456.0 / 726.0,
			1.0,
		],
	]
	for contract: Array in contracts:
		var shadow := title_column.get_node(contract[0]) as TextureRect
		var face := title_column.get_node(contract[1]) as TextureRect
		assert_eq(face.position, contract[2])
		assert_eq(shadow.position - face.position, Vector2(6.0, 7.0))
		assert_true(face.size.is_equal_approx(Vector2(270.0, 270.0)))
		assert_true(shadow.size.is_equal_approx(Vector2(270.0, 270.0)))
		assert_eq(face.scale, Vector2.ONE)
		assert_eq(shadow.scale, Vector2.ONE)
		assert_eq(face.rotation, 0.0)
		assert_eq(shadow.rotation, 0.0)

		for title_node: TextureRect in [shadow, face]:
			var material := title_node.material as ShaderMaterial
			assert_true(is_equal_approx(
				float(material.get_shader_parameter(
					&"perspective_strength")),
				0.10))
			var group_x_min: Variant = material.get_shader_parameter(
				&"group_x_min")
			var group_x_max: Variant = material.get_shader_parameter(
				&"group_x_max")
			assert_not_null(group_x_min)
			assert_not_null(group_x_max)
			if group_x_min == null or group_x_max == null:
				continue
			assert_true(is_equal_approx(
				float(group_x_min),
				float(contract[3])))
			assert_true(is_equal_approx(
				float(group_x_max),
				float(contract[4])))

	var english := title_column.get_node("EnglishSubtitle") as TextureRect
	var english_shadow := title_column.get_node(
		"EnglishSubtitleShadow") as TextureRect
	assert_eq(english.position, Vector2(520.0, 191.0))
	assert_true(english.size.is_equal_approx(Vector2(396.0, 90.0)))
	assert_eq(
		english_shadow.position - english.position,
		Vector2(6.0, 7.0))
	assert_true(
		english_shadow.size.is_equal_approx(Vector2(396.0, 90.0)))
	assert_eq(english.scale, Vector2.ONE)
	assert_eq(english_shadow.scale, Vector2.ONE)
	assert_eq(
		english.texture.resource_path,
		"res://assets/ui/boot/title_bobozan.png")
	var english_image := english.texture.get_image()
	var source_energy := Color8(221, 86, 57, 255)
	var source_face := Color8(245, 232, 209, 255)
	assert_eq(
		english_image.get_pixel(43, 46),
		source_energy)
	assert_eq(
		english_image.get_pixel(91, 46),
		source_energy)
	assert_eq(english_image.get_pixel(48, 28), source_face)
	assert_eq(english_image.get_pixel(16, 33), source_face)
	assert_gt(english_image.get_pixel(43, 46).a, 0.99)
	assert_gt(english_image.get_pixel(91, 46).a, 0.99)
	assert_almost_eq(
		float((english.material as ShaderMaterial).get_shader_parameter(
			&"perspective_strength")),
		0.04,
		0.001)


func test_boot_character_uses_size_driven_presentation() -> void:
	var boot := await _instantiate_boot()
	var character := boot.get_node("Character") as Control
	var rig := character.get_node("Rig") as Node2D

	assert_eq(character.scale, Vector2.ONE)
	assert_true(character.position.is_equal_approx(Vector2(528.0, 96.00001)))
	assert_true(character.size.is_equal_approx(
		Vector2(1510.1462, 912.978)))
	assert_true(rig.position.is_equal_approx(Vector2(0.0, 51.732)))
	assert_true(rig.scale.is_equal_approx(Vector2(4.734, 4.734)))


func test_boot_character_reuses_star_phase_for_warm_energy_light() -> void:
	var boot := await _instantiate_boot()
	var character := boot.get_node("Character") as Control
	var base := character.get_node("Rig/Base") as Sprite2D
	var material := base.material as ShaderMaterial

	assert_not_null(material)
	assert_eq(material.shader.resource_path, CHARACTER_DEPTH_SHADER_PATH)
	assert_true(
		Vector2(material.get_shader_parameter(
				&"rear_energy_center")).is_equal_approx(
					Vector2(0.3532, 0.2756)))
	assert_almost_eq(
		float(material.get_shader_parameter(&"rear_light_strength")),
		0.14,
		0.001)
	var first_phase := float(
		material.get_shader_parameter(&"energy_phase"))
	await get_tree().create_timer(0.08).timeout
	var last_phase := float(
		material.get_shader_parameter(&"energy_phase"))
	assert_gt(last_phase, first_phase)


func test_boot_enter_prompt_matches_click_anywhere_behavior() -> void:
	var boot := await _instantiate_boot()
	var prompt := boot.get_node("EnterPrompt") as Control
	var label := prompt.get_node("Label") as Label
	var left_line := prompt.get_node("LineLeft") as ColorRect
	var right_line := prompt.get_node("LineRight") as ColorRect

	assert_not_null(prompt)
	assert_true(prompt.visible)
	assert_eq(prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(label.text, "点击进入游戏")
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(
		label.get_theme_color("font_color").is_equal_approx(
			Color("#f4f6f8")))
	assert_true(left_line.color.is_equal_approx(Color("#f4f6f8")))
	assert_true(right_line.color.is_equal_approx(Color("#f4f6f8")))
	assert_null(left_line.material)
	assert_null(label.material)
	assert_null(right_line.material)
	assert_true(prompt.position.is_equal_approx(Vector2(300.0, 610.0)))
	assert_true(prompt.size.is_equal_approx(Vector2(420.0, 58.0)))
	assert_true(label.position.is_equal_approx(Vector2(63.0, -27.0)))
	assert_true(label.size.is_equal_approx(Vector2(272.0, 58.0)))
	assert_eq(label.get_theme_font_size("font_size"), 28)
	assert_true(left_line.position.is_equal_approx(Vector2(-11.0, 1.0)))
	assert_true(left_line.size.is_equal_approx(Vector2(64.0, 3.0)))
	assert_true(right_line.position.is_equal_approx(Vector2(345.0, 1.0)))
	assert_true(right_line.size.is_equal_approx(Vector2(64.0, 3.0)))
	assert_eq(prompt.scale, Vector2.ONE)
	assert_eq(label.scale, Vector2.ONE)
	assert_eq(left_line.scale, Vector2.ONE)
	assert_eq(right_line.scale, Vector2.ONE)
	assert_almost_eq(left_line.rotation, 0.0, 0.0001)
	assert_almost_eq(right_line.rotation, 0.0, 0.0001)
	assert_almost_eq(prompt.rotation, 0.0, 0.0001)
	assert_true(float(prompt.get("fade_duration")) >= 1.8)
	assert_true(float(prompt.get("minimum_alpha")) >= 0.84)


func test_boot_enter_prompt_peaks_after_title_flow_finishes() -> void:
	var boot := await _instantiate_boot()
	var title := boot.get_node("TitleColumn") as Control
	var prompt := boot.get_node("EnterPrompt") as Control

	assert_true(bool(prompt.call(&"is_title_synchronized")))
	var flow_end_seconds := float(
		title.call(&"final_flow_release_seconds"))
	var flow_period_seconds := float(title.get("flow_period_seconds"))
	var peak_delay_seconds := float(
		prompt.get("title_peak_delay_seconds"))
	var expected_peak_phase := (
		(flow_end_seconds + peak_delay_seconds)
		/ flow_period_seconds)
	assert_almost_eq(flow_end_seconds, 5.40, 0.001)
	assert_almost_eq(
		float(prompt.call(&"synced_peak_phase")),
		expected_peak_phase,
		0.001)

	title.call(
		&"_set_flow_phase",
		flow_end_seconds / flow_period_seconds)
	assert_almost_eq(prompt.modulate.a, prompt.minimum_alpha, 0.001)
	title.call(&"_set_flow_phase", expected_peak_phase)
	assert_almost_eq(prompt.modulate.a, 1.0, 0.001)


func test_boot_enter_prompt_click_feedback_brightens_and_tightens_once() -> void:
	var boot := await _instantiate_boot()
	var prompt := boot.get_node("EnterPrompt") as Control

	prompt.call(&"play_enter_feedback")
	assert_true(bool(prompt.call(&"is_enter_feedback_active")))
	assert_almost_eq(prompt.modulate.a, 1.0, 0.001)
	await get_tree().create_timer(0.12).timeout
	assert_true(
		prompt.scale.is_equal_approx(
			Vector2.ONE * float(prompt.get("enter_feedback_scale"))))
	assert_almost_eq(prompt.modulate.a, 1.0, 0.001)


func _instantiate_boot() -> Control:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	var boot := packed.instantiate() as Control
	add_child_autofree(boot)
	await get_tree().process_frame
	var intro := boot.get_node_or_null("IntroController")
	if intro != null:
		intro.call(&"finish_immediately")
		await get_tree().process_frame
	return boot


func _luminance(color: Color) -> float:
	return (
		color.r * 0.299
		+ color.g * 0.587
		+ color.b * 0.114)
