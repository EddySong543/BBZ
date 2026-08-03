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
const CHARACTER_DEPTH_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_character_depth.gdshader")
const PROMPT_PERSPECTIVE_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_prompt_perspective.gdshader")

const BLUE_LAYER_PATHS: Array[String] = [
	"res://assets/ui/boot/boot_pressure_blue_base.png",
	"res://assets/ui/boot/boot_pressure_blue_mid.png",
	"res://assets/ui/boot/boot_pressure_blue_light.png",
]
const GOLD_COMBINED_PATH := (
	"res://assets/ui/boot/boot_pressure_gold_combined.png")
const GOLD_FLOW_PATH := (
	"res://assets/ui/boot/boot_pressure_gold_flow.png")


func test_boot_pressure_assets_are_transparent_full_size_layers() -> void:
	for resource_path: String in BLUE_LAYER_PATHS + [GOLD_COMBINED_PATH]:
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


func test_boot_screen_uses_actual_blue_and_gold_layers() -> void:
	var boot := await _instantiate_boot()
	var stage := boot.get_node("BackgroundStage") as BattleStage

	assert_not_null(stage)
	assert_true(stage.idle_drift)
	assert_true(stage.pointer_parallax)
	assert_false(stage.demo_click_shake)
	assert_eq(stage.get_index(), 0)
	assert_lt(stage.get_index(), boot.get_node("TitleColumn").get_index())
	assert_lt(stage.get_index(), boot.get_node("Character").get_index())

	for removed_name: String in [
		"PressurePlate",
		"BlueDeepFlow",
		"BlueMidFlow",
		"BlueLightFlow",
		"GoldenHalo",
		"EnergyFragments",
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
						Color("#1b2a41")))
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
			0.18,
			0.001)
		var contour_material := (
			pressure_contours.material as ShaderMaterial)
		assert_not_null(contour_material)
		assert_eq(
			contour_material.shader.resource_path,
			PRESSURE_CONTOUR_SHADER_PATH)
		assert_true(
			Color(contour_material.get_shader_parameter(
					&"navy_color")).is_equal_approx(
						Color(0.196078, 0.290196, 0.372549, 0.08)))
		assert_true(
			Color(contour_material.get_shader_parameter(
					&"gold_color")).is_equal_approx(
						Color(0.784314, 0.572549, 0.039216, 0.026)))

	var blue_contracts: Array[Array] = [
		["BlueBase", BLUE_LAYER_PATHS[0], 0.0, 7.4, 0.0, 0.0, 0.25],
		["BlueMid", BLUE_LAYER_PATHS[1], 28.0, 5.0, 2.0, 0.10, 0.45],
		["BlueLight", BLUE_LAYER_PATHS[2], 56.0, 3.6, 3.2, 0.18, 0.65],
	]
	for contract: Array in blue_contracts:
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
		var flow_contrast_value: Variant = material.get_shader_parameter(
				&"flow_contrast")
		assert_not_null(flow_contrast_value)
		if flow_contrast_value != null:
			assert_almost_eq(
				float(flow_contrast_value),
				float(contract[5]),
				0.001)
		assert_true(
			Vector2(material.get_shader_parameter(
					&"motion_direction")).is_equal_approx(
						Vector2(-1.0, 0.55)))

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

	var foreground_brush := (
		stage.get_node_or_null("ForegroundBrush") as TextureRect)
	assert_not_null(foreground_brush)
	if foreground_brush != null:
		assert_gt(
			foreground_brush.get_index(),
			stage.get_node("GoldEnergy").get_index())
		assert_eq(
			foreground_brush.texture.resource_path,
			BLUE_LAYER_PATHS[1])
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
						Color("#24364f")))
		assert_almost_eq(
			float(foreground_material.get_shader_parameter(
					&"opacity")),
			0.18,
			0.001)
		assert_almost_eq(
			float(foreground_material.get_shader_parameter(
					&"fringe_cleanup")),
			0.14,
			0.001)

	var controller := stage.get_node_or_null("PressureMotion")
	assert_not_null(controller)
	if controller != null:
		assert_eq(controller.get_script().resource_path, MOTION_SCRIPT_PATH)
		assert_almost_eq(controller.flow_period, 5.2, 0.001)

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


func test_boot_gold_shader_advects_upper_right_without_breathing() -> void:
	var file := FileAccess.open(GOLD_SHADER_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var source := file.get_as_text()
	assert_true(source.contains("uniform sampler2D flow_texture"))
	assert_true(source.contains("flow_region"))
	assert_true(source.contains("phase_weight"))
	assert_true(source.contains("phase_a"))
	assert_true(source.contains("phase_b"))
	assert_true(source.contains("UV - offset_a"))
	assert_true(source.contains("UV - offset_b"))
	assert_true(source.contains("flow.a"))
	assert_true(source.contains("transported_alpha"))
	assert_false(source.contains("sin("))
	assert_false(source.contains("energy.rgb *="))
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


func test_boot_title_uses_cream_red_palette_on_ink_navy_stage() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn")
	assert_true(title_column.visible)
	var contracts: Array[Array] = [
		["BoTopShadow", "BoTop"],
		["BoMiddleShadow", "BoMiddle"],
		["ZanBottomShadow", "ZanBottom"],
	]
	for contract: Array in contracts:
		var shadow := title_column.get_node(contract[0]) as TextureRect
		var face := title_column.get_node(contract[1]) as TextureRect
		assert_not_null(shadow)
		assert_eq(shadow.texture, face.texture)
		assert_eq(shadow.position - face.position, Vector2(5.0, 9.0))
		assert_lt(shadow.get_index(), face.get_index())
		assert_eq(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE)

		var shadow_material := shadow.material as ShaderMaterial
		assert_true(
			Color(shadow_material.get_shader_parameter(
					&"structure_color")).is_equal_approx(
						Color(0.031373, 0.070588, 0.164706, 0.28)))
		assert_eq(
			shadow_material.get_shader_parameter(&"fragment_strength"),
			0.0)
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
						Color("#f5e8d1")))
		assert_true(
			Color(face_material.get_shader_parameter(
					&"energy_color")).is_equal_approx(
						Color("#e25d49")))
		assert_true(
			Color(face_material.get_shader_parameter(
					&"energy_peak_color")).is_equal_approx(
						Color("#f5e8d1")))
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


func test_boot_title_uses_one_horizontal_perspective_field() -> void:
	var boot := await _instantiate_boot()
	var title_column := boot.get_node("TitleColumn") as Control
	assert_true(title_column.position.is_equal_approx(Vector2(37.0, 263.0)))
	assert_true(title_column.size.is_equal_approx(Vector2(806.4, 318.4)))
	assert_eq(title_column.rotation, 0.0)

	var contracts: Array[Array] = [
		[
			"BoTopShadow",
			"BoTop",
			Vector2.ZERO,
			0.0,
			302.4 / 801.4,
		],
		[
			"BoMiddleShadow",
			"BoMiddle",
			Vector2(256.0, 15.0),
			250.0 / 801.4,
			552.4 / 801.4,
		],
		[
			"ZanBottomShadow",
			"ZanBottom",
			Vector2(507.0, 23.0),
			499.0 / 801.4,
			1.0,
		],
	]
	for contract: Array in contracts:
		var shadow := title_column.get_node(contract[0]) as TextureRect
		var face := title_column.get_node(contract[1]) as TextureRect
		assert_eq(face.position, contract[2])
		assert_eq(shadow.position - face.position, Vector2(5.0, 9.0))
		assert_true(face.size.is_equal_approx(Vector2(302.4, 302.4)))
		assert_true(shadow.size.is_equal_approx(Vector2(302.4, 302.4)))
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
			Color("#f5e8d1")))
	assert_true(left_line.color.is_equal_approx(Color("#f5e8d1")))
	assert_true(right_line.color.is_equal_approx(Color("#f5e8d1")))
	assert_almost_eq(prompt.rotation, 0.0, 0.0001)
	var perspective_contracts: Array[Array] = [
		[left_line, Vector2(0.0, 19.0)],
		[label, Vector2(48.0, 0.0)],
		[right_line, Vector2(252.0, 19.0)],
	]
	for contract: Array in perspective_contracts:
		var item := contract[0] as CanvasItem
		var material := item.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(
			material.shader.resource_path,
			PROMPT_PERSPECTIVE_SHADER_PATH)
		assert_true(
			Vector2(material.get_shader_parameter(
					&"node_offset")).is_equal_approx(contract[1]))
		assert_almost_eq(
			float(material.get_shader_parameter(
					&"perspective_strength")),
			0.10,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"slope_pixels")),
			2.5,
			0.001)
	assert_true(float(prompt.get("fade_duration")) >= 1.8)
	assert_true(float(prompt.get("minimum_alpha")) >= 0.84)


func _instantiate_boot() -> Control:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	var boot := packed.instantiate() as Control
	add_child_autofree(boot)
	await get_tree().process_frame
	return boot
