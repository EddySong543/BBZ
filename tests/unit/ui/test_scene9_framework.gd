extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const BATTLE9_PATH := "res://src/ui/battle_screen9.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const GENERIC_CHARACTER_SHADER_PATH := "res://assets/shaders/character_light.gdshader"
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"
const PLATFORM_PATH := "res://assets/scenes/scene9/scene9_battle_platform.png"
const FOREGROUND_LEFT_PATH := (
		"res://assets/scenes/scene9/scene9_foreground_left.png")
const FOREGROUND_RIGHT_PATH := (
		"res://assets/scenes/scene9/scene9_foreground_right.png")
const GRASS_PATHS: Array[String] = [
	"res://assets/scenes/scene9/scene9_grass_01.png",
	"res://assets/scenes/scene9/scene9_grass_02.png",
	"res://assets/scenes/scene9/scene9_grass_03.png",
]
const GRASSLAND_SCRIPT_PATH := (
		"res://src/ui/components/scene9_silver_grassland.gd")
const GROUND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_silver_ground.gdshader")
const GRASS_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_silver_grass.gdshader")


func test_scene9_resources_exist_without_premature_environment_assets() -> void:
	assert_true(ResourceLoader.exists(SCENE9_PATH))
	assert_true(ResourceLoader.exists(BATTLE9_PATH))
	assert_true(ResourceLoader.exists(PLATFORM_PATH))
	assert_true(ResourceLoader.exists(FOREGROUND_LEFT_PATH))
	assert_true(ResourceLoader.exists(FOREGROUND_RIGHT_PATH))
	var stage_source := FileAccess.get_file_as_string(SCENE9_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE9_PATH)
	for grass_path: String in GRASS_PATHS:
		assert_true(ResourceLoader.exists(grass_path))
	assert_true(ResourceLoader.exists(GRASSLAND_SCRIPT_PATH))
	assert_true(ResourceLoader.exists(GROUND_SHADER_PATH))
	assert_true(ResourceLoader.exists(GRASS_SHADER_PATH))
	assert_false(stage_source.contains("res://assets/import/"))
	assert_false(stage_source.contains("res://assets/scenes/scene8/"))
	assert_false(battle_source.contains("scene8"))
	assert_false(battle_source.contains("canvas_env_scene8"))


func test_scene9_framework_is_a_direct_editable_stage() -> void:
	if not ResourceLoader.exists(SCENE9_PATH):
		return
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_not_null(stage)
	if stage == null:
		return
	assert_eq((stage.get_script() as Script).resource_path,
			"res://src/ui/components/battle_stage.gd")
	assert_eq(stage.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(stage.anchor_right, 1.0)
	assert_eq(stage.anchor_bottom, 1.0)
	var backdrop := stage.get_node_or_null("FrameworkBackdrop") as ColorRect
	assert_not_null(backdrop)
	if backdrop != null:
		assert_eq(backdrop.get_parent(), stage)
		assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(float(backdrop.get_meta("parallax_factor")), 0.0)
		assert_eq(float(backdrop.get_meta("pointer_parallax_factor")), 0.0)
		assert_eq(String(backdrop.get_meta("composition_role")),
				"temporary_framework_backdrop")
	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"),
				"Scene9 framework must keep later art directly editable")


func test_scene9_builds_a_continuous_perspective_silver_grassland() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var field := stage.get_node_or_null("SilverGrassland") as Node2D
	assert_not_null(field)
	if field == null:
		return
	assert_eq(field.get_parent(), stage)
	assert_lt(field.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_eq((field.get_script() as Script).resource_path, GRASSLAND_SCRIPT_PATH)
	var ground := field.get_node_or_null("PerspectiveGround") as Polygon2D
	assert_not_null(ground)
	if ground != null:
		assert_eq(ground.polygon.size(), 4)
		assert_lte(ground.polygon[0].x, -100.0,
				"The horizon ground edge must begin offscreen")
		assert_gte(ground.polygon[1].x, 2020.0,
				"The horizon ground edge must end offscreen")
		assert_gt(ground.polygon[2].x - ground.polygon[3].x,
				ground.polygon[1].x - ground.polygon[0].x,
				"The continuous ground must widen from horizon to foreground")
		var ground_material := ground.material as ShaderMaterial
		assert_not_null(ground_material)
		if ground_material != null:
			assert_true(ground_material.resource_local_to_scene)
			assert_eq(ground_material.shader.resource_path, GROUND_SHADER_PATH)
	assert_eq(String(field.get_meta("composition_role")),
			"procedural_silver_field_with_accent_clumps")
	assert_eq(float(field.get_meta("parallax_factor")), 0.72)
	assert_true(field.has_method("distribution_mode_for_testing"))
	if field.has_method("distribution_mode_for_testing"):
		assert_eq(String(field.call("distribution_mode_for_testing")),
				"procedural_field_with_stratified_accent_clumps")


func test_scene9_distributes_three_silver_grass_variants_with_one_wind_field() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var field := stage.get_node("SilverGrassland") as Node2D
	var expected_counts: Dictionary[String, int] = {
		"FarGrass": 4,
		"MidGrass": 3,
		"NearGrass": 2,
	}
	var total_instances := 0
	var shared_shader: Shader = null
	var shared_grass_material: ShaderMaterial = null
	for band_name: String in expected_counts:
		var band := field.get_node_or_null(band_name) as Node2D
		assert_not_null(band)
		if band == null:
			continue
		assert_eq(band.get_child_count(), 3)
		for variant_index: int in 3:
			var instances := band.get_child(variant_index) as MultiMeshInstance2D
			assert_not_null(instances)
			if instances == null:
				continue
			assert_eq(instances.texture.resource_path, GRASS_PATHS[variant_index])
			assert_eq(instances.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
			assert_not_null(instances.multimesh)
			assert_eq(instances.multimesh.transform_format,
					MultiMesh.TRANSFORM_2D)
			assert_true(instances.multimesh.use_custom_data)
			assert_eq(instances.multimesh.instance_count,
					expected_counts[band_name])
			total_instances += instances.multimesh.instance_count
			var grass_material := instances.material as ShaderMaterial
			assert_not_null(grass_material)
			if grass_material == null:
				continue
			assert_true(grass_material.resource_local_to_scene)
			assert_eq(grass_material.shader.resource_path, GRASS_SHADER_PATH)
			if shared_shader == null:
				shared_shader = grass_material.shader
				shared_grass_material = grass_material
			else:
				assert_eq(grass_material.shader, shared_shader,
						"All depth bands must use the same wind-field shader")
	assert_eq(total_instances, 27)
	var ground_material := (field.get_node("PerspectiveGround") as Polygon2D).material \
			as ShaderMaterial
	assert_not_null(ground_material)
	assert_not_null(shared_grass_material)
	if ground_material != null and shared_grass_material != null:
		assert_eq(ground_material.get_shader_parameter("wind_direction"),
				shared_grass_material.get_shader_parameter("wind_direction"))
		assert_eq(float(ground_material.get_shader_parameter("wind_speed")),
				float(shared_grass_material.get_shader_parameter("wind_speed")))
		var root_shadow := shared_grass_material.get_shader_parameter(
				"root_shadow") as Color
		assert_gte(root_shadow.get_luminance(), 0.40,
				"Grass roots must blend into the silver field instead of reading as black blocks")
		assert_lte(float(shared_grass_material.get_shader_parameter(
				"original_color_influence")), 0.05)
		assert_gte(float(shared_grass_material.get_shader_parameter(
				"root_fade_start")), 0.94,
				"Grass roots must stay visible long enough to join the ground surface")


func test_scene9_connects_the_named_platform_and_foregrounds_as_complete_images() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var expected_assets: Dictionary[String, String] = {
		"BattlePlatform": PLATFORM_PATH,
		"ForegroundLeft": FOREGROUND_LEFT_PATH,
		"ForegroundRight": FOREGROUND_RIGHT_PATH,
	}
	var expected_scales: Dictionary[String, Vector2] = {
		"BattlePlatform": Vector2(6.0, 6.0),
		"ForegroundLeft": Vector2(3.0, 3.0),
		"ForegroundRight": Vector2(3.0, 3.0),
	}
	var protected_manual_rects: Dictionary[String, Rect2] = {
		"BattlePlatform": Rect2(-182.0, 166.0, 387.0, 207.0),
		"ForegroundLeft": Rect2(-126.0, 667.0, 278.33334, 167.6666),
		"ForegroundRight": Rect2(1244.0, 680.0, 236.0, 154.0),
	}
	for node_name: String in expected_assets:
		var layer := stage.get_node_or_null(node_name) as TextureRect
		assert_not_null(layer)
		if layer == null:
			continue
		assert_eq(layer.get_parent(), stage)
		assert_not_null(layer.texture)
		assert_eq(layer.texture.resource_path, expected_assets[node_name])
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(layer.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
				"Scene9 art must show the complete source without slicing or tiling")
		assert_eq(layer.scale, expected_scales[node_name])
		assert_almost_eq(layer.scale.x, layer.scale.y, 0.0001,
				"Scene9 art may only use uniform overall scaling")
		var protected_rect := protected_manual_rects[node_name]
		assert_almost_eq(layer.position.x, protected_rect.position.x, 0.001)
		assert_almost_eq(layer.position.y, protected_rect.position.y, 0.001)
		assert_almost_eq(layer.size.x, protected_rect.size.x, 0.001)
		assert_almost_eq(layer.size.y, protected_rect.size.y, 0.001)
	assert_lt(stage.get_node("BattlePlatform").get_index(),
			stage.get_node("ForegroundLeft").get_index())
	assert_lt(stage.get_node("BattlePlatform").get_index(),
			stage.get_node("ForegroundRight").get_index())
	assert_eq(float(stage.get_node("BattlePlatform").get_meta(
			"parallax_factor")), 1.0)
	assert_gt(float(stage.get_node("ForegroundLeft").get_meta(
			"parallax_factor")), 1.0)
	assert_gt(float(stage.get_node("ForegroundRight").get_meta(
			"parallax_factor")), 1.0)


func test_scene9_imported_alpha_footprints_anchor_to_the_battle_frame() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform_rect := _displayed_used_rect(
			stage.get_node("BattlePlatform") as TextureRect)
	var left_rect := _displayed_used_rect(
			stage.get_node("ForegroundLeft") as TextureRect)
	var right_rect := _displayed_used_rect(
			stage.get_node("ForegroundRight") as TextureRect)
	assert_lte(platform_rect.position.x, 0.0)
	assert_gte(platform_rect.end.x, 1700.0,
			"The protected manual platform must span the central battle frame")
	assert_lte(platform_rect.position.y, 748.0,
			"The platform silhouette must reach the mature fighter baseline")
	assert_gt(platform_rect.end.y, 1080.0,
			"The complete platform underside may continue below the viewport")
	assert_lte(left_rect.position.x, 0.0)
	assert_gte(left_rect.end.y, 1080.0)
	assert_gte(right_rect.end.x, 1920.0)
	assert_gte(right_rect.end.y, 1080.0)


func test_scene9_guides_preserve_mature_character_geometry() -> void:
	if not ResourceLoader.exists(SCENE9_PATH):
		return
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_eq((stage.get_node("CompositionGuides/P1Baseline") as Marker2D).position,
			Vector2(480.0, 748.0))
	assert_eq((stage.get_node("CompositionGuides/P2Baseline") as Marker2D).position,
			Vector2(1440.0, 748.0))
	assert_eq((stage.get_node(
			"CompositionGuides/PlatformBaseline") as Marker2D).position,
			Vector2(960.0, 748.0))


func test_scene9_entry_reuses_shared_ui_characters_input_and_parallax() -> void:
	if not ResourceLoader.exists(BATTLE9_PATH):
		return
	BattleSetup.reset()
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE9_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE9_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_false(screen.character_reflections_enabled)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p1_char_display.position,
			(base.get_node("P1CharDisplay") as CharacterDisplay).position)
	assert_eq(screen.p2_char_display.position,
			(base.get_node("P2CharDisplay") as CharacterDisplay).position)
	assert_eq(screen.p1_char_display.size,
			(base.get_node("P1CharDisplay") as CharacterDisplay).size)
	assert_eq(screen.p2_char_display.size,
			(base.get_node("P2CharDisplay") as CharacterDisplay).size)
	assert_not_null(screen.p1_char_display.get_render_texture())
	assert_not_null(screen.p2_char_display.get_render_texture())
	for node_path: String in [
		"P1Hud",
		"P2Hud",
		"TimerLabel",
		"Buttons",
		"DeathSwitchOverlay",
	]:
		assert_true(screen.has_node(node_path))
	base.free()
	BattleSetup.reset()


func test_scene9_disables_unowned_environment_effects_and_keeps_characters_neutral() -> void:
	if not ResourceLoader.exists(BATTLE9_PATH):
		return
	BattleSetup.reset()
	var screen := (load(BATTLE9_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for shadow: TextureRect in [screen.p1_shadow, screen.p2_shadow]:
		assert_not_null(shadow)
		assert_false(shadow.visible)
	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)
	var character_materials: Array[ShaderMaterial] = []
	for display: CharacterDisplay in [
		screen.p1_char_display,
		screen.p2_char_display,
	]:
		assert_eq(display.rim_strength, 0.0)
		assert_eq(display.backlight, 0.0)
		assert_eq(display.warmth_amount, 0.0)
		assert_eq(display.fill_amount, 0.0)
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") \
				as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		character_materials.append(material)
		assert_eq(material.shader.resource_path, GENERIC_CHARACTER_SHADER_PATH)
		assert_eq(float(material.get_shader_parameter("rim_strength")), 0.0)
		assert_eq(float(material.get_shader_parameter("backlight")), 0.0)
		assert_eq(float(material.get_shader_parameter("warmth_amount")), 0.0)
		assert_eq(float(material.get_shader_parameter("fill_amount")), 0.0)
	assert_eq(character_materials.size(), 2)
	if character_materials.size() == 2:
		assert_ne(character_materials[0], character_materials[1],
				"P1/P2 runtime character materials must stay isolated")
	BattleSetup.reset()


func test_scene9_uses_a_local_neutral_post_process() -> void:
	if not ResourceLoader.exists(BATTLE9_PATH):
		return
	var screen := (load(BATTLE9_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var material := (screen.get_node("PostFX") as ColorRect).material \
			as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_true(material.resource_local_to_scene)
	assert_eq(material.shader.resource_path, POSTFX_SHADER_PATH)
	assert_eq(float(material.get_shader_parameter("barrel_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("edge_blur_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("brightness")), 1.0)
	assert_eq(float(material.get_shader_parameter("contrast")), 1.0)
	assert_eq(float(material.get_shader_parameter("saturation")), 1.0)
	assert_eq(float(material.get_shader_parameter("tint_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("split_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("vignette_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("grain_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("heat_haze_strength")), 0.0)


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.03)
	var local_rect := Rect2(Vector2(used_rect.position), Vector2(used_rect.size))
	var layer_transform := Transform2D(
			layer.rotation, layer.scale, 0.0, layer.position)
	var corners: Array[Vector2] = [
		layer_transform * local_rect.position,
		layer_transform * Vector2(local_rect.end.x, local_rect.position.y),
		layer_transform * local_rect.end,
		layer_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _alpha_used_rect(image: Image, threshold: float) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
