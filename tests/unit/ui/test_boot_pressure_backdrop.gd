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
const CHARACTER_OVERLAY_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_character_overlay.gdshader")
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
const BOOT_ICON_BASE_PATH := (
	"res://src/ui/components/boot_icon_base.gd")
const COMMAND_SLOT_SKIN_PATH := (
	"res://src/ui/components/command_sequence_slot_skin.gd")
const COMMAND_CROSS_STAR_SHADER_PATH := (
	"res://assets/shaders/canvas_ui_command_cross_star_ssaa.gdshader")
const BOOT_BUTTON_MOTION_PATH := (
	"res://src/ui/components/boot_menu_button_motion.gd")
const BOOT_FOCUS_MARK_PATH := (
	"res://src/ui/components/boot_menu_focus_mark.gd")
const BOOT_BUTTON_FOCUS_SHADER_PATH := (
	"res://assets/shaders/canvas_ui_boot_menu_focus.gdshader")


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


func test_boot_screen_uses_palette_a_brush_and_stable_gold() -> void:
	var boot := await _instantiate_boot()
	var black_base := boot.get_node("IntroBlackBase") as ColorRect
	var stage := boot.get_node("BackgroundStage") as BattleStage

	assert_not_null(black_base)
	assert_true(black_base.color.is_equal_approx(Color("#c8d3d0")))
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
						Color("#c8d3d0")))
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
						Color(0.325490, 0.423529, 0.474510, 0.42)))
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
						Vector3(0.262745, 0.364706, 0.419608)))
		assert_true(
			Vector3(material.get_shader_parameter(
					&"palette_mid")).is_equal_approx(
						Vector3(0.435294, 0.529412, 0.572549)))
		assert_true(
			Vector3(material.get_shader_parameter(
					&"palette_light")).is_equal_approx(
						Vector3(0.619608, 0.678431, 0.690196)))
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
						Color("#435d6b")))
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


func test_boot_title_uses_white_gold_palette_on_bright_stage() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn")
	assert_true(title_column.visible)
	var contracts: Array[Array] = [
		["BoTopShadow", "BoTop", false],
		["BoMiddleShadow", "BoMiddle", false],
		["ZanBottomShadow", "ZanBottom", false],
		["ChuanShadow", "Chuan", false],
		["ShuoShadow", "Shuo", false],
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
		assert_almost_eq(
			float(shadow_material.get_shader_parameter(
				&"perspective_strength")),
			0.10,
			0.001)
		assert_almost_eq(
			float(shadow_material.get_shader_parameter(&"edge_padding")),
			0.04,
			0.001)
		assert_almost_eq(
			float(shadow_material.get_shader_parameter(
				&"structure_tint_strength")),
			0.0,
			0.001)

		var face_material := face.material as ShaderMaterial
		assert_eq(
			bool(face_material.get_shader_parameter(&"flow_enabled")),
			bool(contract[2]))
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
		assert_almost_eq(
			float(face_material.get_shader_parameter(
				&"perspective_strength")),
			0.10,
			0.001)
		assert_almost_eq(
			float(face_material.get_shader_parameter(&"edge_padding")),
			0.04,
			0.001)
		assert_almost_eq(
			float(face_material.get_shader_parameter(
				&"structure_tint_strength")),
			0.42,
			0.001)
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


func test_boot_title_has_no_plus_badges() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn") as Control
	for node_name: String in [
		"ChinesePlus",
		"ChinesePlusShadow",
		"EnglishPlus",
		"EnglishPlusShadow",
	]:
		assert_null(title_column.get_node_or_null(node_name),
				"Boot 中英文标题不再保留加号节点")

func test_boot_title_uses_one_horizontal_perspective_field() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn") as Control
	assert_true(title_column.position.is_equal_approx(Vector2(37.0, 263.0)))
	assert_true(title_column.size.is_equal_approx(Vector2(1017.0, 340.0)))
	assert_eq(title_column.rotation, 0.0)

	var contracts: Array[Array] = [
		[
			"BoTopShadow",
			"BoTop",
			Vector2(93.0, -67.0),
			0.0,
			270.0 / 726.0,
			Vector2.ONE,
		],
		[
			"BoMiddleShadow",
			"BoMiddle",
			Vector2(321.0, -62.0),
			228.0 / 726.0,
			498.0 / 726.0,
			Vector2.ONE,
		],
		[
			"ZanBottomShadow",
			"ZanBottom",
			Vector2(549.0, -65.0),
			456.0 / 726.0,
			1.0,
			Vector2.ONE,
		],
		[
			"ChuanShadow",
			"Chuan",
			Vector2(551.0, 174.0),
			327.0 / 726.0,
			543.0 / 726.0,
			Vector2(0.75, 0.75),
		],
		[
			"ShuoShadow",
			"Shuo",
			Vector2(723.0, 179.0),
			510.0 / 726.0,
			1.0,
			Vector2(0.75, 0.75),
		],
	]
	for contract: Array in contracts:
		var shadow := title_column.get_node(contract[0]) as TextureRect
		var face := title_column.get_node(contract[1]) as TextureRect
		assert_eq(face.position, contract[2])
		assert_eq(shadow.position - face.position, Vector2(6.0, 7.0))
		assert_true(face.size.is_equal_approx(Vector2(270.0, 270.0)))
		assert_true(shadow.size.is_equal_approx(Vector2(270.0, 270.0)))
		assert_eq(face.scale, contract[5])
		assert_eq(shadow.scale, contract[5])
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
	var chuan := title_column.get_node("Chuan") as TextureRect
	var shuo := title_column.get_node("Shuo") as TextureRect
	assert_eq(chuan.texture.resource_path,
		"res://assets/ui/boot/title_chuan.png")
	assert_eq(shuo.texture.resource_path,
		"res://assets/ui/boot/title_shuo.png")
	var chuan_image := chuan.texture.get_image()
	var shuo_image := shuo.texture.get_image()
	var source_energy := Color8(221, 86, 57, 255)
	var source_face := Color8(245, 232, 209, 255)
	var source_structure := Color8(15, 27, 38, 255)
	for image: Image in [chuan_image, shuo_image]:
		assert_eq(image.get_size(), Vector2i(252, 252))
		assert_eq(image.get_used_rect().size, Vector2i(216, 216))
		var palette_counts := {
			source_energy: 0,
			source_face: 0,
			source_structure: 0,
		}
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel := image.get_pixel(x, y)
				if palette_counts.has(pixel):
					palette_counts[pixel] += 1
		assert_gt(int(palette_counts[source_face]), 15000)
		assert_gt(int(palette_counts[source_structure]), 500)
		assert_gt(int(palette_counts[source_energy]), 300)

	# User-marked micro corrections remain local: two protruding 传 caps stay
	# clear, while the isolated lower-left 说 counter is closed by one face cell.
	for cell: Vector2i in [
		Vector2i(5, 3),
		Vector2i(5, 4),
		Vector2i(19, 21),
		Vector2i(21, 22),
	]:
		var sample := cell * 9 + Vector2i(4, 4)
		assert_ne(chuan_image.get_pixelv(sample), source_face)
	assert_eq(
		shuo_image.get_pixelv(Vector2i(9, 21) * 9 + Vector2i(4, 4)),
		source_face)


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


func test_boot_character_pointer_response_turns_character_around_chest() -> void:
	var boot := await _instantiate_boot()
	var character := boot.get_node("Character") as BootCharacterIdle
	var base := character.get_node("Rig/Base") as Sprite2D
	var base_material := base.material as ShaderMaterial
	var star := character.get_node(
		"Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	var glow := character.get_node(
		"Rig/RearHandEnergyAnchor/RearHandGlow") as ColorRect
	var star_material := star.material as ShaderMaterial
	var glow_material := glow.material as ShaderMaterial
	var animation_player := character.get_node(
		"AnimationPlayer") as AnimationPlayer
	var waist_animation_player := character.get_node(
		"WaistAnimationPlayer") as AnimationPlayer
	var idle := animation_player.get_animation(&"idle")
	var waist_idle := waist_animation_player.get_animation(&"waist_idle")

	assert_almost_eq(float(character.get("loop_duration")), 6.4, 0.001)
	assert_almost_eq(
		float(character.get("waist_loop_duration")),
		9.0,
		0.001)
	assert_almost_eq(
		float(character.get("pointer_dead_zone")),
		0.08,
		0.001)
	assert_almost_eq(
		float(character.get("pointer_energy_smooth")),
		5.0,
		0.001)
	assert_almost_eq(
		float(character.get("pointer_character_yaw_degrees")),
		3.0,
		0.001)
	assert_almost_eq(
		float(character.get("pointer_character_pitch_degrees")),
		1.2,
		0.001)
	assert_almost_eq(
		float(character.get("pointer_character_smooth")),
		4.2,
		0.001)
	assert_not_null(base_material)
	assert_not_null(star_material)
	assert_not_null(glow_material)
	character.call(&"preview_pointer_response", Vector2.ZERO)
	assert_eq(
		Vector2(star_material.get_shader_parameter(&"pointer_tilt")),
		Vector2.ZERO)
	assert_eq(
		Vector2(glow_material.get_shader_parameter(&"pointer_tilt")),
		Vector2.ZERO)
	assert_eq(
		Vector2(base_material.get_shader_parameter(&"pointer_tilt")),
		Vector2.ZERO)
	assert_true(Vector2(base_material.get_shader_parameter(
		&"perspective_pivot")).is_equal_approx(Vector2(0.56, 0.50)))
	assert_almost_eq(
		float(base_material.get_shader_parameter(&"front_hand_depth_boost")),
		1.25,
		0.001)
	assert_true(base_material.shader.code.contains("perspective_source_uv"))
	assert_almost_eq(
		float(base_material.get_shader_parameter(
			&"energy_transfer_strength")),
		0.045,
		0.001)
	assert_true(star_material.shader.code.contains(
		"horizontal_pointer_length"))
	assert_true(star_material.shader.code.contains("highlight_center"))
	assert_true(star_material.shader.code.contains("ring_point"))
	assert_almost_eq(
		float(star_material.get_shader_parameter(
			&"pointer_near_extension")),
		0.25,
		0.001)
	assert_almost_eq(
		float(star_material.get_shader_parameter(
			&"pointer_far_reduction")),
		0.15,
		0.001)
	assert_almost_eq(
		float(star_material.get_shader_parameter(
			&"pointer_rotation_degrees")),
		6.0,
		0.001)
	assert_true(star.size.is_equal_approx(Vector2(75.35, 75.35)))
	assert_true(_animation_has_track(
		idle,
		NodePath("Rig/FurRightTips:position")))
	assert_almost_eq(idle.length, 6.4, 0.001)
	assert_almost_eq(waist_idle.length, 9.0, 0.001)

	character.call(&"preview_pointer_response", Vector2(1.0, -1.0))
	var expected_response := Vector2(1.0, -1.0).normalized()
	assert_true(
		Vector2(character.call(&"current_pointer_response"))
			.is_equal_approx(expected_response))
	assert_true(
		Vector2(star_material.get_shader_parameter(&"pointer_tilt"))
			.is_equal_approx(expected_response))
	assert_true(
		Vector2(glow_material.get_shader_parameter(&"pointer_tilt"))
			.is_equal_approx(expected_response))
	assert_true(
		Vector2(character.call(&"current_character_pointer_response"))
			.is_equal_approx(expected_response))
	assert_true(
		Vector2(base_material.get_shader_parameter(&"pointer_tilt"))
			.is_equal_approx(expected_response))
	var hair_left := character.get_node("Rig/HairLeftTips") as Sprite2D
	var fur_right := character.get_node("Rig/FurRightTips") as Sprite2D
	var shadow := character.get_node("Rig/Base/Shadow") as Sprite2D
	var hair_material := hair_left.material as ShaderMaterial
	var shadow_material := shadow.material as ShaderMaterial
	assert_not_null(hair_material)
	assert_not_null(shadow_material)
	assert_eq(
		hair_material.shader.resource_path,
		CHARACTER_OVERLAY_SHADER_PATH)
	assert_true(
		Vector2(hair_material.get_shader_parameter(&"pointer_tilt"))
			.is_equal_approx(expected_response))
	assert_true(
		Vector2(shadow_material.get_shader_parameter(&"pointer_tilt"))
			.is_equal_approx(expected_response))
	assert_eq(hair_left.offset, Vector2.ZERO)
	assert_eq(fur_right.offset, Vector2.ZERO)
	assert_ne(
		character.get_node("Rig/RearHandEnergyAnchor").position,
		Vector2(112.68, 47.125))

	character.call(&"preview_pointer_response", Vector2(0.04, 0.04))
	assert_eq(
		Vector2(character.call(&"current_pointer_response")),
		Vector2.ZERO)
	assert_eq(
		Vector2(star_material.get_shader_parameter(&"pointer_tilt")),
		Vector2.ZERO)
	assert_eq(
		Vector2(base_material.get_shader_parameter(&"pointer_tilt")),
		Vector2.ZERO)
	assert_eq(
		character.get_node("Rig/RearHandEnergyAnchor").position,
		Vector2(112.68, 47.125))
	assert_eq(hair_left.offset, Vector2.ZERO)


func _animation_has_track(animation: Animation, path: NodePath) -> bool:
	if animation == null:
		return false
	for track_index: int in animation.get_track_count():
		if animation.track_get_path(track_index) == path:
			return true
	return false


func test_boot_menu_replaces_click_anywhere_with_explicit_actions() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var main_buttons := menu.get_node("MainButtons") as VBoxContainer
	var small_buttons := menu.get_node("SmallButtons") as Control
	var expected_main: Array[String] = [
		"开始游戏", "读取存档", "加入愿望单", "退出游戏",
	]
	var expected_small_paths: Array[String] = [
		"res://assets/ui/boot/menu_icons/steam.png",
		"res://assets/ui/boot/menu_icons/discord.png",
		"res://assets/ui/boot/menu_icons/qq.png",
		"res://assets/ui/boot/menu_icons/feedback.png",
	]
	var expected_small_names: Array[String] = [
		"Steam", "Discord", "QQ", "Feedback",
	]

	assert_null(boot.get_node_or_null("EnterPrompt"))
	assert_true(menu.visible)
	assert_true(menu.is_interaction_enabled())
	assert_gt(menu.size.x, 0.0)
	assert_gt(menu.size.y, 0.0)
	assert_gte(menu.position.x, 0.0)
	assert_gte(menu.position.y, 0.0)
	assert_lte(menu.position.x + menu.size.x, 1920.0)
	assert_lte(menu.position.y + menu.size.y, 1080.0)
	assert_eq(main_buttons.get_child_count(), 4)
	assert_eq(small_buttons.get_child_count(), 4)
	assert_null(small_buttons.get_node_or_null("Settings"))
	assert_false(small_buttons is Container)
	assert_null(menu.get_node_or_null("IconDock"))
	for index: int in expected_main.size():
		var button := main_buttons.get_child(index) as Button
		assert_eq(button.text, expected_main[index])
		assert_false(button.disabled)
		assert_null(button.get_node_or_null("Plate"))
		assert_eq(button.theme_type_variation, &"BootMainButton")
		assert_true(
			button.get_theme_color(&"font_color").is_equal_approx(
				Color(0.12549, 0.188235, 0.227451, 0.96)))
		var motion := button.get_node("Motion") as BootMenuButtonMotion
		assert_not_null(motion)
		assert_eq(motion.get_script().resource_path, BOOT_BUTTON_MOTION_PATH)
		assert_eq(motion.focus_mark_path, NodePath("../FocusMark"))
		var focus_mark := button.get_node_or_null("FocusMark") as Control
		assert_not_null(focus_mark)
		if focus_mark != null:
			assert_eq(focus_mark.get_script().resource_path, BOOT_FOCUS_MARK_PATH)
			assert_eq(focus_mark.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_almost_eq(focus_mark.anchor_right, 1.0, 0.001)
			assert_almost_eq(focus_mark.anchor_bottom, 1.0, 0.001)
		assert_null(button.get_node_or_null("ButtonJuice"))
	for index: int in expected_small_paths.size():
		var button := small_buttons.get_child(index) as Button
		assert_eq(button.name, expected_small_names[index])
		assert_eq(button.text, "")
		assert_eq(button.icon.resource_path, expected_small_paths[index])
		assert_true(button.expand_icon)
		assert_false(button.disabled)
		assert_null(button.get_node_or_null("Plate"))
		assert_eq(button.theme_type_variation, &"BootIconButton")
		var icon_base := button.get_node("Base") as BootIconBase
		assert_not_null(icon_base)
		assert_true(icon_base is Control)
		assert_eq(icon_base.get_script().resource_path, BOOT_ICON_BASE_PATH)
		assert_true(icon_base.show_behind_parent)
		assert_true(icon_base.size.is_equal_approx(Vector2(66.0, 66.0)))
		assert_almost_eq(icon_base.anchor_left, 0.5, 0.001)
		assert_almost_eq(icon_base.anchor_right, 0.5, 0.001)
		assert_almost_eq(icon_base.anchor_top, 1.0, 0.001)
		assert_almost_eq(icon_base.anchor_bottom, 1.0, 0.001)
		assert_true(icon_base.material is ShaderMaterial)
		assert_eq(
			(icon_base.material as ShaderMaterial).shader.resource_path,
			COMMAND_CROSS_STAR_SHADER_PATH)
		var geometry: Dictionary = icon_base.debug_geometry()
		assert_eq(geometry["star_center"], Vector2(33.5, 64.5))
		assert_eq(geometry["star_radii"], Vector2(14.0, 13.0))
		assert_almost_eq(float(geometry["profile_power"]), 5.0, 0.001)
		assert_eq(geometry["bottom_shadow_offset"], Vector2(1.0, 2.0))
		assert_almost_eq(float(geometry["bottom_shadow_expand"]), 1.0, 0.001)
		assert_eq(String(geometry["render_path"]), "analytic_ssaa_9x9")
		var motion := button.get_node("Motion") as BootMenuButtonMotion
		assert_not_null(motion)
		assert_eq(motion.icon_base_path, NodePath("../Base"))
		assert_null(button.get_node_or_null("ButtonJuice"))
	var feedback_button := small_buttons.get_node("Feedback") as Button
	assert_eq(feedback_button.get_theme_constant(&"icon_max_width"), 48)
	var status := menu.get_node("StatusLabel") as Label
	assert_eq(status.theme_type_variation, &"BootStatusLabel")


func test_boot_menu_small_buttons_are_individually_inspector_adjustable() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var small_buttons := menu.get_node("SmallButtons") as Control
	var names: Array[String] = [
		"Steam", "Discord", "QQ", "Feedback",
	]
	for index: int in names.size():
		var button := small_buttons.get_node(names[index]) as Button
		var icon_base := button.get_node("Base") as BootIconBase
		var original_offsets := Vector4(
			icon_base.offset_left,
			icon_base.offset_top,
			icon_base.offset_right,
			icon_base.offset_bottom)
		var test_position := Vector2(7.0 + index * 59.0, 3.0 + index)
		var test_size := Vector2(42.0 + index, 44.0 + index)
		button.position = test_position
		button.size = test_size
		await get_tree().process_frame
		assert_true(button.position.is_equal_approx(test_position), names[index])
		assert_true(button.size.is_equal_approx(test_size), names[index])
		assert_eq(Vector4(
			icon_base.offset_left,
			icon_base.offset_top,
			icon_base.offset_right,
			icon_base.offset_bottom), original_offsets)
		assert_true(icon_base.size.is_equal_approx(Vector2(66.0, 66.0)))


func test_boot_menu_focus_motion_is_clear_without_changing_layout_rects() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var start_button := menu.get_node("MainButtons/StartGame") as Button
	var start_motion := (
		start_button.get_node("Motion") as BootMenuButtonMotion)
	var start_mark := start_button.get_node_or_null("FocusMark") as Control
	assert_not_null(start_mark)
	if start_mark == null:
		return
	var discord := menu.get_node("SmallButtons/Discord") as Button
	var discord_base := discord.get_node("Base") as BootIconBase
	var discord_motion := discord.get_node("Motion") as BootMenuButtonMotion
	var start_position := start_button.position
	var discord_position := discord.position

	await get_tree().create_timer(0.15).timeout
	var start_state := start_motion.debug_state()
	assert_almost_eq(float(start_state["focus_strength"]), 0.0, 0.001)
	assert_true(
		Vector2(start_state["visual_offset"]).is_equal_approx(Vector2.ZERO))
	assert_true(Vector2(start_state["scale"]).is_equal_approx(Vector2.ONE))
	var start_mark_state: Dictionary = start_mark.call(&"debug_state")
	assert_false(bool(start_mark_state["active"]))

	start_button.grab_focus()
	await get_tree().create_timer(0.15).timeout
	start_state = start_motion.debug_state()
	assert_gt(float(start_state["focus_strength"]), 0.98)
	assert_true(
		Vector2(start_state["visual_offset"]).is_equal_approx(
			Vector2(4.0, 0.0)))
	assert_true(Vector2(start_state["scale"]).is_equal_approx(
		Vector2(1.03, 1.03)))
	assert_eq(start_button.position, start_position)
	var start_material := start_button.material as ShaderMaterial
	assert_not_null(start_material)
	assert_eq(start_material.shader.resource_path, BOOT_BUTTON_FOCUS_SHADER_PATH)
	assert_almost_eq(
		float(start_material.get_shader_parameter(&"focus_tint_strength")),
		0.0,
		0.001)
	start_mark_state = start_mark.call(&"debug_state")
	assert_true(bool(start_mark_state["active"]))
	assert_almost_eq(float(start_mark_state["blade_height"]), 18.0, 0.001)
	assert_true(
		Color(start_mark_state["blade_color"]).is_equal_approx(
			Color("eda63a")))
	assert_true(
		Color(start_mark_state["separator_color"]).is_equal_approx(
			Color("0f1b26")))
	assert_eq(bool(start_state["sweep_enabled"]), false)

	discord.grab_focus()
	await get_tree().create_timer(0.15).timeout
	var discord_state := discord_motion.debug_state()
	var base_state := discord_base.debug_state()
	assert_gt(float(discord_state["focus_strength"]), 0.98)
	assert_true(
		Vector2(discord_state["visual_offset"]).is_equal_approx(
			Vector2(0.0, -4.0)))
	assert_true(Vector2(discord_state["scale"]).is_equal_approx(
		Vector2.ONE))
	assert_gt(float(base_state["focus_strength"]), 0.98)
	assert_true(bool(base_state["hot"]))
	assert_almost_eq(float(base_state["base_alpha"]), 1.0, 0.001)
	assert_eq(String(base_state["render_path"]), "analytic_ssaa_9x9")
	var focused_star_color: Color = base_state["star_color"]
	assert_gt(focused_star_color.r, 0.98)
	assert_gt(focused_star_color.g, 0.85)
	assert_gt(focused_star_color.b, 0.53)
	assert_eq(discord.position, discord_position)
	assert_eq(bool(discord_state["sweep_enabled"]), false)
	assert_true(
		Color(discord_state["focus_color"]).is_equal_approx(
			Color(1.0, 0.86, 0.54, 1.0)))
	assert_almost_eq(float(discord_state["focus_tint_strength"]), 0.14, 0.001)

	discord.button_down.emit()
	await get_tree().create_timer(0.06).timeout
	discord_state = discord_motion.debug_state()
	base_state = discord_base.debug_state()
	assert_gt(float(discord_state["press_strength"]), 0.98)
	assert_true(Vector2(discord_state["scale"]).is_equal_approx(
		Vector2.ONE))
	assert_true(
		Vector2(discord_state["visual_offset"]).is_equal_approx(
			Vector2.ZERO))
	assert_gt(float(base_state["press_strength"]), 0.98)
	assert_lt(float(base_state["base_alpha"]), 0.84)
	discord.button_up.emit()


func test_boot_menu_icons_preserve_internal_white_and_clear_only_exterior() -> void:
	var icon_contracts: Array[Array] = [
		["steam", Vector2i(88, 88), 183],
		["discord", Vector2i(48, 48), 459],
		["qq", Vector2i(80, 96), 1239],
	]
	for contract: Array in icon_contracts:
		var path := (
			"res://assets/ui/boot/menu_icons/%s.png" % String(contract[0]))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image, path)
		if image == null:
			continue
		assert_eq(image.get_size(), contract[1])
		for corner: Vector2i in [
			Vector2i.ZERO,
			Vector2i(image.get_width() - 1, 0),
			Vector2i(0, image.get_height() - 1),
			image.get_size() - Vector2i.ONE,
		]:
			assert_almost_eq(image.get_pixelv(corner).a, 0.0, 0.001)
		var preserved_white := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel := image.get_pixel(x, y)
				if (
					pixel.a > 0.99
					and pixel.r >= 237.0 / 255.0
					and pixel.g >= 237.0 / 255.0
					and pixel.b >= 237.0 / 255.0
				):
					preserved_white += 1
		assert_eq(preserved_white, int(contract[2]))
		if String(contract[0]) == "discord":
			assert_eq(image.get_used_rect().size, Vector2i(44, 40))

	var feedback_path := "res://assets/ui/boot/menu_icons/feedback.png"
	var feedback := Image.load_from_file(
		ProjectSettings.globalize_path(feedback_path))
	assert_not_null(feedback, feedback_path)
	if feedback != null:
		assert_eq(feedback.get_size(), Vector2i(48, 48))
		assert_eq(feedback.get_used_rect().size, Vector2i(44, 26))


func test_boot_menu_cross_star_base_reuses_the_sequence_slot_geometry() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var small_buttons := menu.get_node("SmallButtons") as Control
	var sequence_script := load(COMMAND_SLOT_SKIN_PATH) as Script
	for button_name: String in ["Steam", "Discord", "QQ", "Feedback"]:
		var base := small_buttons.get_node("%s/Base" % button_name) as BootIconBase
		assert_not_null(base, button_name)
		assert_true(base.get_script().get_base_script() == sequence_script, button_name)
		var geometry: Dictionary = base.debug_geometry()
		assert_true(bool(geometry["smooth_vector_rendering"]), button_name)
		assert_true(bool(geometry["analytic_antialiasing"]), button_name)
		assert_false(bool(geometry["geometry_antialiasing"]), button_name)
	assert_false(FileAccess.file_exists(
		"res://assets/ui/boot/menu_frames/icon_frame_idle.png"))
	assert_false(FileAccess.file_exists(
		"res://assets/ui/boot/menu_frames/icon_frame_focus.png"))


func test_boot_menu_placeholders_report_unconfigured_actions() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var status := menu.get_node("StatusLabel") as Label
	var load_button := menu.get_node("MainButtons/LoadGame") as Button
	var steam_button := menu.get_node("SmallButtons/Steam") as Button

	load_button.pressed.emit()
	assert_eq(status.text, "读取存档功能待接入")
	steam_button.pressed.emit()
	assert_eq(status.text, "Steam链接待配置")
	assert_null(menu.get_node_or_null("SmallButtons/Settings"))
	assert_true(menu.is_interaction_enabled())


func test_boot_menu_starts_unselected_and_keeps_keyboard_neighbors() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var start_button := menu.get_node("MainButtons/StartGame") as Button
	var load_button := menu.get_node("MainButtons/LoadGame") as Button
	var quit_button := menu.get_node("MainButtons/QuitGame") as Button
	var steam_button := menu.get_node("SmallButtons/Steam") as Button
	var qq_button := menu.get_node("SmallButtons/QQ") as Button
	var feedback_button := menu.get_node("SmallButtons/Feedback") as Button

	assert_eq(start_button.focus_neighbor_bottom, start_button.get_path_to(load_button))
	assert_eq(quit_button.focus_neighbor_bottom, quit_button.get_path_to(steam_button))
	assert_eq(qq_button.focus_neighbor_right, qq_button.get_path_to(feedback_button))
	assert_eq(feedback_button.focus_neighbor_left, feedback_button.get_path_to(qq_button))
	assert_null(get_viewport().gui_get_focus_owner())
	start_button.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), start_button)


func test_boot_menu_isolated_canvas_stays_outside_scene_modulation_chain() -> void:
	var boot := await _instantiate_boot()
	var interface_layer := boot.get_node("InterfaceLayer") as CanvasLayer
	var menu := interface_layer.get_node("BootMenu") as BootMenuController
	assert_not_null(interface_layer)
	assert_gt(interface_layer.layer, 0)
	assert_eq(menu.get_parent(), interface_layer)
	assert_false(menu.use_parent_material)
	assert_true(menu.modulate.is_equal_approx(Color.WHITE))
	var menu_origin := menu.get_global_transform_with_canvas().origin
	boot.position += Vector2(83.0, 47.0)
	boot.modulate = Color(0.2, 0.3, 0.4, 0.5)
	await get_tree().process_frame
	assert_true(
		menu.get_global_transform_with_canvas().origin.is_equal_approx(menu_origin),
		"独立 UI 画布不得继承场景根节点的波动位移")
	assert_true(menu.modulate.is_equal_approx(Color.WHITE))


func test_boot_menu_intro_locks_input_without_using_gray_disabled_state() -> void:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	var boot := packed.instantiate() as Control
	add_child_autofree(boot)
	await get_tree().process_frame
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	menu.prepare_intro()
	for button: Button in menu.find_children("*", "Button", true, false):
		assert_false(button.disabled, button.name)
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE, button.name)
		assert_eq(button.focus_mode, Control.FOCUS_NONE, button.name)
		if button.theme_type_variation == &"BootIconButton":
			assert_eq(
				button.get_theme_color(&"icon_disabled_color"),
				button.get_theme_color(&"icon_normal_color"),
				button.name)
		elif button.theme_type_variation == &"BootMainButton":
			assert_eq(
				button.get_theme_color(&"font_disabled_color"),
				button.get_theme_color(&"font_color"),
				button.name)
	menu.set_intro_reveal(0.5)
	assert_true(menu.visible)
	menu.finish_intro()
	for button: Button in menu.find_children("*", "Button", true, false):
		assert_false(button.disabled, button.name)
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP, button.name)
		assert_eq(button.focus_mode, Control.FOCUS_ALL, button.name)


func test_boot_menu_focus_shader_has_no_sweep_path() -> void:
	var file := FileAccess.open(BOOT_BUTTON_FOCUS_SHADER_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var source := file.get_as_text()
	assert_false(source.contains("glint"))
	assert_false(source.contains("glint_band"))
	assert_false(source.contains("glint_progress"))
	var motion_file := FileAccess.open(BOOT_BUTTON_MOTION_PATH, FileAccess.READ)
	assert_not_null(motion_file)
	if motion_file != null:
		assert_false(motion_file.get_as_text().contains("glint"))


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
