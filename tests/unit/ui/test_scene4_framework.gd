extends GutTest

const SCENE4_PATH := "res://src/ui/scenes/scene4.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE4_PATH := "res://src/ui/battle_screen4.tscn"
const SKY_TEXTURE_PATH := "res://assets/scenes/scene4/scene4_sky.png"
const FAR_FOREST_PATH := "res://assets/scenes/scene4/scene4_far_forest.png"
const BACKGROUND_TOP_LEAVES_PATH := "res://assets/scenes/scene4/scene4_background_top_leaves.png"
const BACKGROUND_TREE_PATH := "res://assets/scenes/scene4/scene4_background_tree.png"
const BACKGROUND_TREE_2_PATH := "res://assets/scenes/scene4/scene4_background_tree_2.png"
const BATTLE_PLATFORM_PATH := "res://assets/scenes/scene4/scene4_battle_platform.png"
const LEFT_TREE_2_PATH := "res://assets/scenes/scene4/scene4_foreground_left_tree_2.png"
const RIGHT_TREE_2_PATH := "res://assets/scenes/scene4/scene4_foreground_right_tree_2.png"
const RUIN_STONE_1_PATH := "res://assets/scenes/scene4/scene4_midground_ruin_stone_1.png"
const RUIN_STONE_2_PATH := "res://assets/scenes/scene4/scene4_midground_ruin_stone_2.png"
const SKY_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_sky_grade.gdshader"
const DEPTH_GRADE_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_depth_grade.gdshader"
const RELIC_GLOW_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_relic_glow.gdshader"
const CANOPY_SHAFTS_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_canopy_shafts.gdshader"
const MIDGROUND_MIST_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_midground_mist.gdshader"
const MOTE_SYNC_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_mote_sync.gdshader"
const FOREGROUND_FOG_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_foreground_fog.gdshader"
const CHARACTER_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_character_light.gdshader"
const SHADOW_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_root_contact_shadow.gdshader"
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"
const ACHIEVEMENT_SPIRIT_SCRIPT_PATH := (
		"res://src/ui/components/scene4_leaf_spirit_swarm.gd")


func test_scene4_has_an_independent_shared_battle_entry() -> void:
	BattleSetup.reset()
	var battle_source := FileAccess.get_file_as_string(BATTLE4_PATH)
	var screen := (load(BATTLE4_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(ResourceLoader.exists(SCENE4_PATH))
	assert_true(ResourceLoader.exists(BATTLE4_PATH))
	assert_true(battle_source.contains(BATTLE_BASE_PATH))
	assert_false(battle_source.contains('parent="StageSlot/Stage"'))
	assert_false(battle_source.contains('[editable path="StageSlot/Stage"]'))
	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE4_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_not_null(screen.get_node_or_null("WorldGroup"))
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	assert_true(screen.has_node("P1Hud"))
	assert_true(screen.has_node("P2Hud"))
	assert_true(screen.has_node("Buttons"))
	assert_true(screen.has_node("DeathSwitchOverlay"))
	assert_false(screen.character_reflections_enabled)
	assert_true(screen.character_reflection_receiver_path.is_empty())
	BattleSetup.reset()


func test_scene4_shares_one_pool_between_ambient_and_achievement_spirits() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame

	assert_false(stage.has_node("LeafSpirits"))
	var spirits := stage.get_node_or_null("AchievementLeafSpirits")
	assert_not_null(spirits)
	if spirits != null:
		assert_eq(spirits.get_script().resource_path,
				ACHIEVEMENT_SPIRIT_SCRIPT_PATH)
		assert_eq(int(spirits.call("get_pool_size")), 24)
		assert_eq(int(spirits.call("get_active_spirit_count")), 0)
		assert_true(bool(spirits.auto_ambient))
		assert_eq(float(spirits.initial_delay_sec), 8.0)
		assert_eq(float(spirits.interval_min_sec), 22.0)
		assert_eq(float(spirits.interval_max_sec), 38.0)
		assert_eq(int(spirits.ambient_spirit_count_min), 2)
		assert_eq(int(spirits.ambient_spirit_count_max), 3)
		assert_eq(float(spirits.ambient_flight_duration_min), 3.4)
		assert_eq(float(spirits.ambient_flight_duration_max), 4.5)
		assert_eq(float(spirits.ambient_spirit_scale_min), 2.3)
		assert_eq(float(spirits.ambient_spirit_scale_max), 2.9)
		assert_true(bool(spirits.call("is_ambient_timer_running")))
	var top_leaves := stage.get_node("BackgroundTopLeaves2") as TextureRect
	assert_null(top_leaves.get_script())
	assert_eq(top_leaves.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_scene4_ambient_spirits_return_and_achievement_swarm_preempts_them() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var spirits := stage.get_node("AchievementLeafSpirits")

	assert_true(bool(spirits.call("trigger_ambient_swarm")))
	assert_between(int(spirits.call("get_active_spirit_count")), 2, 3)
	assert_eq(String(spirits.call("get_active_swarm_kind")), "ambient")
	assert_true(bool(spirits.call("trigger_achievement_swarm")))
	assert_between(int(spirits.call("get_active_spirit_count")), 18, 24)
	assert_eq(String(spirits.call("get_active_swarm_kind")), "achievement")


func test_scene4_connects_formal_tree_assets_to_expected_layers() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var expected_assets: Dictionary[String, String] = {
		"Sky": SKY_TEXTURE_PATH,
		"FarForest": FAR_FOREST_PATH,
		"BackgroundBottomLeaves": BACKGROUND_TOP_LEAVES_PATH,
		"BackgroundTopLeaves2": BACKGROUND_TOP_LEAVES_PATH,
		"BackgroundTree": BACKGROUND_TREE_PATH,
		"BackgroundTree2": BACKGROUND_TREE_2_PATH,
		"BattlePlatform": BATTLE_PLATFORM_PATH,
		"LeftTree2": LEFT_TREE_2_PATH,
		"RightTree2": RIGHT_TREE_2_PATH,
		"RuinStone1": RUIN_STONE_1_PATH,
		"RuinStone2": RUIN_STONE_2_PATH,
		"RuinStone3": RUIN_STONE_1_PATH,
		"RuinStone4": RUIN_STONE_1_PATH,
	}
	var replacement_dimensions: Dictionary[String, Vector2] = {
		"FarForest": Vector2(248.0, 140.0),
		"BattlePlatform": Vector2(308.0, 96.0),
		"LeftTree2": Vector2(217.0, 217.0),
		"RightTree2": Vector2(157.0, 244.0),
	}
	for node_path: String in expected_assets:
		var art := stage.get_node(node_path) as TextureRect
		assert_not_null(art)
		assert_not_null(art.texture)
		assert_eq(art.texture.resource_path, expected_assets[node_path])
		assert_eq(art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		if node_path in [
			"RuinStone1",
			"RuinStone2",
			"RuinStone3",
			"RuinStone4",
		]:
			assert_eq(art.mouse_filter, Control.MOUSE_FILTER_PASS)
		else:
			assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		if node_path in replacement_dimensions:
			assert_eq(
					art.texture.get_size(),
					replacement_dimensions[node_path],
					"%s 使用 2026-08-09 导入的替换素材" % node_path)

	assert_eq(
			(stage.get_node("FarForest") as TextureRect).stretch_mode,
			TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var far_forest := stage.get_node("FarForest") as TextureRect
	assert_eq(far_forest.anchor_right, 1.0)
	assert_eq(far_forest.anchor_bottom, 1.0)
	var far_forest_factor := float(far_forest.get_meta("parallax_factor"))
	var bottom_leaves := stage.get_node("BackgroundBottomLeaves") as TextureRect
	assert_true(bottom_leaves.flip_v)
	assert_eq(bottom_leaves.anchor_right, 1.0)
	assert_eq(bottom_leaves.anchor_bottom, 1.0)
	assert_almost_eq(bottom_leaves.rotation, PI, 0.0001,
			"保留 Eddy 取消底部垂直反转后的手动构图")
	var bottom_leaves_factor := float(bottom_leaves.get_meta("parallax_factor"))
	assert_lt(far_forest_factor, bottom_leaves_factor)
	assert_lt(bottom_leaves_factor, 1.0)
	assert_eq((stage.get_node("BattlePlatform") as Control).scale,
			Vector2(6.0, 6.0))


func test_scene4_separates_platform_from_bottom_canopy_without_moving_authored_art() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var bottom_leaves := stage.get_node("BackgroundBottomLeaves") as TextureRect
	var bottom_material := bottom_leaves.material as ShaderMaterial
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var platform_material := platform.material as ShaderMaterial
	var depth_shadow := stage.get_node_or_null("BattlePlatformDepthShadow") as TextureRect

	assert_not_null(depth_shadow)
	if depth_shadow == null:
		return
	assert_eq(depth_shadow.texture.resource_path, BATTLE_PLATFORM_PATH)
	assert_eq(depth_shadow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(depth_shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(depth_shadow.position.x, platform.position.x)
	assert_almost_eq(depth_shadow.position.y - platform.position.y, 1.0, 0.001)
	assert_eq(depth_shadow.size, platform.size)
	assert_eq(depth_shadow.scale, platform.scale)
	assert_eq(depth_shadow.get_index() + 1, platform.get_index())
	assert_eq(float(depth_shadow.get_meta("parallax_factor")), 1.0)
	assert_between(depth_shadow.modulate.a, 0.38, 0.48)
	var shadow_material := depth_shadow.material as ShaderMaterial
	assert_not_null(shadow_material)
	assert_eq(shadow_material.shader.resource_path, DEPTH_GRADE_SHADER_PATH)
	assert_between(float(shadow_material.get_shader_parameter("brightness")), 0.4, 0.44)
	assert_between(float(shadow_material.get_shader_parameter("palette_strength")), 0.82, 0.86)

	assert_gte(bottom_leaves.modulate.a, 0.99)
	assert_between(float(bottom_material.get_shader_parameter("brightness")), 0.67, 0.71)
	assert_between(float(bottom_material.get_shader_parameter("saturation")), 0.72, 0.76)
	assert_between(float(bottom_material.get_shader_parameter("contrast")), 1.08, 1.12)
	assert_between(float(bottom_material.get_shader_parameter("haze_strength")), 0.1, 0.14)
	var bottom_mid := bottom_material.get_shader_parameter("palette_mid") as Color
	var platform_mid := platform_material.get_shader_parameter("palette_mid") as Color
	assert_lt(bottom_mid.g - bottom_mid.b, platform_mid.g - platform_mid.b)
	assert_between(float(platform_material.get_shader_parameter("brightness")), 0.94, 0.98)
	assert_between(float(platform_material.get_shader_parameter("contrast")), 1.16, 1.2)
	var platform_light := platform_material.get_shader_parameter("palette_light") as Color
	assert_gt(platform_light.g, platform_light.r)
	assert_gt(platform_light.r, platform_light.b)


func test_scene4_grades_every_environment_asset_by_depth_role() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var depth_layers: Array[String] = [
		"FarForest",
		"BackgroundBottomLeaves",
		"BackgroundTopLeaves2",
		"BackgroundTree",
		"BackgroundTree2",
		"BattlePlatform",
		"LeftTree2",
		"RightTree2",
	]
	for node_name: String in depth_layers:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		assert_not_null(material.shader)
		assert_eq(material.shader.resource_path, DEPTH_GRADE_SHADER_PATH)
		assert_lte(float(material.get_shader_parameter("brightness")), 0.98)
		assert_lte(float(material.get_shader_parameter("saturation")), 0.82)
		assert_gte(float(material.get_shader_parameter("palette_strength")), 0.72)
		var palette_mid := material.get_shader_parameter("palette_mid") as Color
		assert_gt(palette_mid.g, palette_mid.b)
		if node_name == "BattlePlatform":
			assert_gt(palette_mid.r, palette_mid.b)
		else:
			assert_gt(palette_mid.b, palette_mid.r)

	var far_forest_material := (
			stage.get_node("FarForest") as TextureRect
	).material as ShaderMaterial
	assert_between(
			float(far_forest_material.get_shader_parameter("brightness")),
			0.72,
			0.76)
	assert_between(
			float(far_forest_material.get_shader_parameter("saturation")),
			0.72,
			0.76)
	assert_between(
			float(far_forest_material.get_shader_parameter("contrast")),
			1.08,
			1.12)
	assert_between(
			float(far_forest_material.get_shader_parameter("haze_strength")),
			0.1,
			0.14)
	var far_mid := far_forest_material.get_shader_parameter("palette_mid") as Color
	assert_between(far_mid.g - far_mid.b, 0.04, 0.07)
	assert_true(bool(far_forest_material.get_shader_parameter(
			"lower_alpha_fade_enabled")))
	assert_between(
			float(far_forest_material.get_shader_parameter(
					"lower_alpha_fade_start")),
			0.64,
			0.68)
	assert_between(
			float(far_forest_material.get_shader_parameter(
					"lower_alpha_fade_end")),
			0.86,
			0.9)
	assert_eq(float(far_forest_material.get_shader_parameter(
			"lower_alpha_floor")), 0.0)
	assert_true(far_forest_material.shader.code.contains("lower_alpha_fade"))

	var tree2_material := (
			stage.get_node("BackgroundTree2") as TextureRect
	).material as ShaderMaterial
	var tree1_material := (
			stage.get_node("BackgroundTree") as TextureRect
	).material as ShaderMaterial
	assert_between(
			float(tree2_material.get_shader_parameter("brightness")),
			0.69,
			0.73)
	assert_between(
			float(tree2_material.get_shader_parameter("saturation")),
			0.72,
			0.76)
	assert_between(
			float(tree2_material.get_shader_parameter("contrast")),
			1.08,
			1.12)
	assert_between(
			float(tree2_material.get_shader_parameter("tint_strength")),
			0.27,
			0.31)
	assert_between(
			float(tree2_material.get_shader_parameter("haze_strength")),
			0.03,
			0.05)
	assert_lt(
			float(tree2_material.get_shader_parameter("brightness")),
			float(tree1_material.get_shader_parameter("brightness")))
	assert_lte(
			float(tree2_material.get_shader_parameter("contrast")),
			float(tree1_material.get_shader_parameter("contrast")))
	assert_eq(
			float(tree2_material.get_shader_parameter("haze_strength")),
			float(tree1_material.get_shader_parameter("haze_strength")))
	for palette_parameter: String in [
		"palette_shadow",
		"palette_mid",
		"palette_light",
	]:
		assert_eq(
				tree2_material.get_shader_parameter(palette_parameter),
				tree1_material.get_shader_parameter(palette_parameter))

	var relief_contracts := {
		"FarForest": {
			"strength": 0.12,
			"height": 0.9,
			"palette_strength": 0.74,
			"parallax_factor": 0.03,
		},
		"BackgroundTree2": {
			"strength": 0.16,
			"height": 1.2,
			"palette_strength": 0.76,
			"parallax_factor": 0.14,
		},
		"BackgroundTree": {
			"strength": 0.2,
			"height": 1.4,
			"palette_strength": 0.78,
			"parallax_factor": 0.3,
		},
	}
	assert_true(far_forest_material.shader.code.contains("pixel_relief_strength"))
	assert_true(far_forest_material.shader.code.contains("TEXTURE_PIXEL_SIZE"))
	assert_true(far_forest_material.shader.code.contains(
			"uniform float pixel_relief_strength : hint_range(0.0, 0.4, 0.01) = 0.0;"))
	for node_name: String in relief_contracts:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		var contract: Dictionary = relief_contracts[node_name]
		assert_almost_eq(
				float(material.get_shader_parameter("pixel_relief_strength")),
				float(contract["strength"]),
				0.001)
		assert_almost_eq(
				float(material.get_shader_parameter("pixel_relief_height")),
				float(contract["height"]),
				0.001)
		assert_almost_eq(
				float(material.get_shader_parameter("palette_strength")),
				float(contract["palette_strength"]),
				0.001)
		assert_almost_eq(
				float(layer.get_meta("parallax_factor")),
				float(contract["parallax_factor"]),
				0.001)
	var far_forest := stage.get_node("FarForest") as TextureRect
	assert_eq(far_forest.modulate.a, 1.0)
	assert_lt(
			float(far_forest.get_meta("parallax_factor")),
			float((stage.get_node("BackgroundTree2") as TextureRect).get_meta(
					"parallax_factor")))
	assert_lt(
			float((stage.get_node("BackgroundTree2") as TextureRect).get_meta(
					"parallax_factor")),
			float((stage.get_node("BackgroundTree") as TextureRect).get_meta(
					"parallax_factor")))
	for static_grade_name: String in [
		"BackgroundBottomLeaves",
		"BackgroundTopLeaves2",
		"BattlePlatform",
		"LeftTree2",
		"RightTree2",
	]:
		var static_material := (
				stage.get_node(static_grade_name) as TextureRect
		).material as ShaderMaterial
		var relief_override: Variant = static_material.get_shader_parameter(
				"pixel_relief_strength")
		assert_true(
				relief_override == null or is_zero_approx(float(relief_override)),
				"%s 不得继承远景浮雕" % static_grade_name)

	var sky_material := (
			stage.get_node("Sky") as TextureRect
	).material as ShaderMaterial
	var sky_mid := sky_material.get_shader_parameter("mid_color") as Color
	var sky_light := sky_material.get_shader_parameter("light_color") as Color
	assert_gt(sky_mid.g, sky_mid.r)
	assert_gt(sky_mid.g, sky_mid.b)
	assert_gt(sky_light.get_luminance(), sky_mid.get_luminance())

	var shared_relic_energy_color := Color(0.62, 0.79, 0.94, 1)
	for stone_name: String in [
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]:
		var stone := stage.get_node(stone_name) as TextureRect
		var stone_material := stone.material as ShaderMaterial
		assert_not_null(stone_material)
		assert_eq(stone_material.shader.resource_path, RELIC_GLOW_SHADER_PATH)
		assert_between(
				float(stone_material.get_shader_parameter("glow_strength")),
				0.64,
				0.7)
		assert_between(
				float(stone_material.get_shader_parameter("exposure")),
				0.83,
				0.88)
		assert_between(
				float(stone_material.get_shader_parameter("palette_strength")),
				0.89,
				0.93)
		assert_eq(
				stone_material.get_shader_parameter("rune_color"),
				shared_relic_energy_color)
		assert_almost_eq(stone.modulate.a, 1.0, 0.001,
				"石碑实体必须保持不透明，仅纹理外轮廓使用源 alpha")
		assert_lte(
				float(stone_material.get_shader_parameter("rune_threshold")),
				0.07)
		assert_lte(
				float(stone_material.get_shader_parameter("pulse_speed")),
				0.11)
		assert_between(
				float(stone_material.get_shader_parameter("circuit_width_px")),
				0.1,
				0.15)
		assert_between(
				float(stone_material.get_shader_parameter("circuit_tail")),
				0.19,
				0.25)
		assert_between(
				float(stone_material.get_shader_parameter("base_charge")),
				0.12,
				0.16)
		assert_eq(
				float(stone_material.get_shader_parameter(
						"energy_pixel_size_px")),
				1.0)
		assert_between(
				float(stone_material.get_shader_parameter("motion_feather")),
				0.04,
				0.051)
		assert_true(stone_material.shader.code.contains("hash11"))
		assert_true(stone_material.shader.code.contains("vertical_segment"))
		assert_true(stone_material.shader.code.contains("horizontal_segment"))
		assert_true(stone_material.shader.code.contains("snapped_x"))
		assert_true(stone_material.shader.code.contains("snapped_y"))
		assert_true(stone_material.shader.code.contains("path_a_progress"))
		assert_true(stone_material.shader.code.contains("energy_pixel_size"))
		assert_true(stone_material.shader.code.contains("drift_a"))
		assert_true(stone_material.shader.code.contains("interaction_flash"))
		assert_false(stone_material.shader.code.contains("interaction_energy"))
		assert_false(stone_material.shader.code.contains("synchronized_head"),
				"彩蛋不得把原本爬行中的能量头强制刷新到统一进度")
		assert_false(stone_material.shader.code.contains(
				"achievement_energy = carved_track"),
				"彩蛋不得直接显现完整休眠回路")
		assert_true(stone_material.shader.code.contains(
				"achievement_energy = embedded_energy"),
				"彩蛋只能增强当前正在爬行的能量")
		assert_true(stone_material.shader.code.contains(
				"achievement_head_energy = head_core_energy"),
				"彩蛋高亮必须继续跟随当前能量头")
		assert_true(stone_material.shader.code.contains(
				"achievement_extension = smoothstep"),
				"彩蛋回路必须从当前能量头平滑延展")
		assert_true(stone_material.shader.code.contains(
				"active_tail_a = mix(circuit_tail"),
				"A 路径必须通过增长当前尾迹显现")
		assert_true(stone_material.shader.code.contains(
				"active_tail_b = mix("))
		assert_true(stone_material.shader.code.contains(
				"circuit_tail * 0.78"),
				"B 路径必须通过增长当前尾迹显现")
		assert_true(stone_material.shader.code.contains("front_fade_a"))
		assert_true(stone_material.shader.code.contains("interior_gate"))
		assert_true(stone_material.shader.code.contains("groove_color"))
		assert_false(stone_material.shader.code.contains("color +="))
		assert_false(stone_material.shader.code.contains("vertical_filament"))

	var shafts := stage.get_node("CanopyLightShafts") as ColorRect
	var shafts_material := shafts.material as ShaderMaterial
	assert_not_null(shafts_material)
	assert_eq(shafts_material.shader.resource_path, CANOPY_SHAFTS_SHADER_PATH)
	assert_between(
			float(shafts_material.get_shader_parameter("beam_strength")),
			0.16,
			0.22)
	assert_true(shafts_material.shader.code.contains("slow_gate"))

	assert_false(stage.has_node("RuinStone2BranchOccluder"))

	var background_top_leaves := (
			stage.get_node("BackgroundTopLeaves2") as TextureRect
	)
	var background_bottom_leaves := (
			stage.get_node("BackgroundBottomLeaves") as TextureRect
	)
	var background_top_material := (
			background_top_leaves.material as ShaderMaterial
	)
	var background_bottom_material := (
			background_bottom_leaves.material as ShaderMaterial
	)
	assert_ne(background_top_material, background_bottom_material)
	assert_between(
			float(background_top_material.get_shader_parameter(
					"sway_strength_px")),
			1.5,
			1.7)
	assert_between(
			float(background_top_material.get_shader_parameter("sway_speed")),
			0.3,
			0.34)
	assert_between(
			float(background_top_material.get_shader_parameter(
					"sway_spatial_phase")),
			1.3,
			1.5)
	assert_between(
			float(background_top_material.get_shader_parameter(
					"sway_secondary_ratio")),
			0.39,
			0.43)
	assert_between(
			float(background_top_material.get_shader_parameter(
					"sway_secondary_strength")),
			0.1,
			0.14)
	assert_between(
			float(background_top_material.get_shader_parameter(
					"sway_blend_strength")),
			0.6,
			0.7)
	assert_true(background_top_material.shader.code.contains(
			"sway_spatial_phase"))
	assert_eq(float(background_bottom_material.get_shader_parameter(
			"sway_strength_px")), 0.0)
	assert_eq(float(background_bottom_material.get_shader_parameter(
			"sway_speed")), 0.0)
	assert_eq(float(background_bottom_material.get_shader_parameter(
			"sway_secondary_strength")), 0.0)
	assert_gte(background_bottom_leaves.modulate.a, 0.99)
	assert_between(
			float(background_bottom_material.get_shader_parameter("brightness")),
			0.67,
			0.71)
	assert_between(
			float(background_bottom_material.get_shader_parameter("saturation")),
			0.72,
			0.76)
	assert_between(
			float(background_bottom_material.get_shader_parameter("contrast")),
			1.08,
			1.12)
	assert_between(
			float(background_bottom_material.get_shader_parameter("haze_strength")),
			0.1,
			0.14)
	assert_between(
			float(background_bottom_material.get_shader_parameter(
					"alpha_cleanup_threshold")),
			0.07,
			0.09)
	assert_between(
			float(background_bottom_material.get_shader_parameter(
					"alpha_cleanup_softness")),
			0.05,
			0.07)

	var foreground_tree_contracts: Dictionary[String, Dictionary] = {
		"LeftTree2": {
			"brightness": 0.60,
			"strength": 2.4,
			"speed": 0.87,
			"period": 7.22,
			"phase": 0.35,
			"x_min": 0.36,
			"x_max": 0.63,
			"y_min": 0.08,
			"y_max": 0.72,
		},
		"RightTree2": {
			"brightness": 0.62,
			"strength": 2.1,
			"speed": 0.58,
			"period": 10.83,
			"phase": 3.4,
			"x_min": 0.25,
			"x_max": 0.51,
			"y_min": 0.10,
			"y_max": 0.70,
		},
	}
	for tree_name: String in foreground_tree_contracts:
		var contract: Dictionary = foreground_tree_contracts[tree_name]
		var tree := stage.get_node(tree_name) as TextureRect
		var tree_material := tree.material as ShaderMaterial
		assert_true(tree.visible)
		assert_false(tree_material.shader.code.contains("stepped_time"))
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_strength_px")),
				float(contract["strength"]),
				0.001,
				"%s 仅摆动挑选出的垂藤" % tree_name)
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_speed")),
				float(contract["speed"]),
				0.001)
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_phase")),
				float(contract["phase"]),
				0.001)
		assert_almost_eq(
				TAU / float(tree_material.get_shader_parameter("sway_speed")),
				float(contract["period"]),
				0.05,
				"%s 使用明确且可读的独立主周期" % tree_name)
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_x_min")),
				float(contract["x_min"]),
				0.001)
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_x_max")),
				float(contract["x_max"]),
				0.001)
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_y_start")),
				float(contract["y_min"]),
				0.001)
		assert_almost_eq(
				float(tree_material.get_shader_parameter("sway_y_end")),
				float(contract["y_max"]),
				0.001)
		assert_between(
				float(contract["x_max"]) - float(contract["x_min"]),
				0.24,
				0.28,
				"扩展藤蔓数量时仍不得覆盖树干主体")
		assert_almost_eq(
				float(tree_material.get_shader_parameter("brightness")),
				float(contract["brightness"]),
				0.001,
				"%s 使用独立的近景压暗值" % tree_name)
	var left_tree_material := (
			(stage.get_node("LeftTree2") as TextureRect).material as ShaderMaterial
	)
	var right_tree_material := (
			(stage.get_node("RightTree2") as TextureRect).material as ShaderMaterial
	)
	assert_ne(
			float(left_tree_material.get_shader_parameter("sway_speed")),
			float(right_tree_material.get_shader_parameter("sway_speed")),
			"左右藤蔓不能使用相同节奏")
	assert_gt(
			absf(
					TAU / float(left_tree_material.get_shader_parameter("sway_speed"))
					- TAU / float(right_tree_material.get_shader_parameter("sway_speed"))),
			3.0,
			"左右主周期至少拉开 3 秒，避免短时间内看成同步摆动")

	var platform_material := (
			(stage.get_node("BattlePlatform") as TextureRect).material
			as ShaderMaterial
	)
	assert_between(float(platform_material.get_shader_parameter("brightness")), 0.94, 0.98)
	assert_between(float(platform_material.get_shader_parameter("saturation")), 0.8, 0.84)
	assert_between(float(platform_material.get_shader_parameter("contrast")), 1.16, 1.2)
	assert_between(float(platform_material.get_shader_parameter("haze_strength")), 0.03, 0.06)


func test_scene4_guides_keep_the_mature_character_baseline() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)

	assert_eq((stage.get_node("CompositionGuides/P1Baseline") as Marker2D).position,
			Vector2(480.0, 748.0))
	assert_eq((stage.get_node("CompositionGuides/P2Baseline") as Marker2D).position,
			Vector2(1440.0, 748.0))
	assert_eq((stage.get_node("CompositionGuides/PlatformBaseline") as Marker2D).position,
			Vector2(960.0, 748.0))
	assert_eq(float(stage.get_node("BattlePlatform").get_meta("parallax_factor")), 1.0)


func test_scene4_owns_authored_sky_grade_and_forest_motes() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var sky := stage.get_node("Sky") as TextureRect
	var sky_material := sky.material as ShaderMaterial
	assert_not_null(sky_material)
	assert_eq(sky_material.shader.resource_path, SKY_SHADER_PATH)
	assert_eq(sky.texture.resource_path, SKY_TEXTURE_PATH)

	var motes := stage.get_node("CanopyMotes") as GPUParticles2D
	var mote_process := motes.process_material as ParticleProcessMaterial
	var mote_sync := motes.material as ShaderMaterial
	assert_not_null(motes)
	assert_true(motes.emitting)
	assert_between(motes.amount, 26, 34)
	assert_gte(motes.randomness, 0.75)
	assert_eq(motes.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_not_null(mote_process)
	assert_not_null(mote_sync)
	assert_eq(mote_sync.shader.resource_path, MOTE_SYNC_SHADER_PATH)
	assert_gte(
			float(mote_sync.get_shader_parameter("shaft_response")),
			0.75)
	assert_eq(
			float(mote_sync.get_shader_parameter("relic_response")),
			0.0)
	assert_lt(mote_process.color.b, mote_process.color.g)
	assert_gte(mote_process.color.a, 0.57)

	var mist := stage.get_node("MidgroundMist") as ColorRect
	var mist_material := mist.material as ShaderMaterial
	assert_not_null(mist_material)
	assert_eq(mist_material.shader.resource_path, MIDGROUND_MIST_SHADER_PATH)
	assert_between(
			float(mist_material.get_shader_parameter("mist_strength")),
			0.1,
			0.12)
	assert_between(
			float(mist_material.get_shader_parameter("band_center")),
			0.79,
			0.81)
	assert_between(
			float(mist_material.get_shader_parameter("band_half_width")),
			0.09,
			0.11)
	var mist_color := mist_material.get_shader_parameter("mist_color") as Color
	assert_lte(absf(mist_color.g - mist_color.b), 0.03)
	assert_true(mist_material.shader.code.contains("value_noise"))
	assert_true(mist_material.shader.code.contains("pixel_grid"))

	for ruin_mote_name: String in [
		"RuinMotes1",
		"RuinMotes2",
		"RuinMotes3",
		"RuinMotes4",
	]:
		var ruin_motes := stage.get_node(ruin_mote_name) as GPUParticles2D
		var ruin_sync := ruin_motes.material as ShaderMaterial
		var ruin_process := (
				ruin_motes.process_material as ParticleProcessMaterial
		)
		assert_true(ruin_motes.emitting)
		assert_between(ruin_motes.amount, 5, 7)
		assert_eq(ruin_sync.shader.resource_path, MOTE_SYNC_SHADER_PATH)
		assert_eq(
				float(ruin_sync.get_shader_parameter("relic_response")),
				1.0)
		assert_gte(
				float(ruin_sync.get_shader_parameter("shaft_response")),
				0.6)
		assert_eq(
				ruin_sync.get_shader_parameter("mote_tint"),
				Color(0.604, 0.682, 0.725, 0.9))
		assert_lte(ruin_process.scale_max, 1.0)
		assert_true(ruin_sync.shader.code.contains("relic_active"))

	var foreground_fog := stage.get_node("ForegroundFog") as ColorRect
	var foreground_fog_material := foreground_fog.material as ShaderMaterial
	assert_not_null(foreground_fog_material)
	assert_true(foreground_fog.visible,
			"极薄前景雾只负责融合平台下缘与底部叶幕")
	assert_eq(
			foreground_fog_material.shader.resource_path,
			FOREGROUND_FOG_SHADER_PATH)
	assert_between(
			float(foreground_fog_material.get_shader_parameter("alpha_max")),
			0.04,
			0.08)
	assert_between(
			float(foreground_fog_material.get_shader_parameter("drift_speed")),
			0.02,
			0.03)
	assert_gte(
			float(foreground_fog_material.get_shader_parameter("scale_x")),
			2.3)
	var foreground_fog_color := (
			foreground_fog_material.get_shader_parameter("fog_color") as Color
	)
	assert_gt(foreground_fog_color.g, foreground_fog_color.r)
	assert_gt(foreground_fog_color.g, foreground_fog_color.b)
	assert_gte(foreground_fog.offset_top, 810.0)
	assert_lte(foreground_fog.offset_top, 830.0)
	assert_gte(foreground_fog.offset_bottom, 1020.0)
	assert_lte(foreground_fog.offset_bottom, 1060.0)
	assert_true(foreground_fog_material.shader.code.contains("pixel_grid"))
	assert_true(foreground_fog_material.shader.code.contains("crest_band"))

	assert_false(stage.has_node("LeafDrift"))
	var foreground_motes := stage.get_node("ForegroundMotes") as GPUParticles2D
	var foreground_process := (
			foreground_motes.process_material as ParticleProcessMaterial
	)
	var foreground_blend := (
			foreground_motes.material as CanvasItemMaterial
	)
	assert_true(foreground_motes.emitting)
	assert_between(foreground_motes.amount, 10, 18)
	assert_eq(
			foreground_blend.blend_mode,
			CanvasItemMaterial.BLEND_MODE_ADD)
	assert_gte(foreground_process.scale_min, 1.5)
	assert_lte(foreground_process.color.b, foreground_process.color.g)

	for removed_foreground: String in ["NearCenter", "NearLeft", "NearRight"]:
		assert_false(stage.has_node(removed_foreground))


func test_scene4_reuses_character_geometry_but_owns_environment_materials() -> void:
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE4_PATH) as PackedScene).instantiate()
	for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var base_node := base.get_node(node_name) as Control
		var scene4_node := screen.get_node(node_name) as Control
		assert_eq(scene4_node.position, base_node.position)
		assert_eq(scene4_node.size, base_node.size)

	var light_directions: Array[Vector2] = []
	var scene_exposures: Array[float] = []
	var flash_peaks: Array[float] = []
	var rim_peaks: Array[float] = []
	for side: String in ["P1", "P2"]:
		var sprite_path := "%sCharDisplay/SubViewport/AnimatedSprite2D" % side
		var scene4_sprite := screen.get_node(sprite_path) as AnimatedSprite2D
		var material := scene4_sprite.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, CHARACTER_SHADER_PATH)
		assert_lte(float(material.get_shader_parameter("rim_strength")), 0.1)
		assert_lte(float(material.get_shader_parameter("fill_amount")), 0.04)
		assert_gte(float(material.get_shader_parameter("backlight")), 0.25)
		assert_between(
				float(material.get_shader_parameter("forest_ambient_amount")),
				0.36,
				0.45)
		assert_between(
				float(material.get_shader_parameter("scene_exposure")),
				0.84,
				0.86)
		assert_lte(float(material.get_shader_parameter("flash_peak_strength")), 0.3)
		assert_lte(float(material.get_shader_parameter("flash_dark_response")), 0.5)
		assert_lte(float(material.get_shader_parameter("rim_peak_strength")), 0.25)
		var flash_color := material.get_shader_parameter("flash_color") as Color
		assert_lte(maxf(flash_color.r, maxf(flash_color.g, flash_color.b)), 0.85)
		var forest_color := material.get_shader_parameter("forest_ambient_color") as Color
		assert_gt(forest_color.g, forest_color.r)
		assert_gt(forest_color.g, forest_color.b)
		var rim_color := material.get_shader_parameter("rim_color") as Color
		assert_gt(rim_color.b, rim_color.g)
		assert_gt(rim_color.g, rim_color.r)
		light_directions.append(material.get_shader_parameter("light_dir") as Vector2)
		scene_exposures.append(
				float(material.get_shader_parameter("scene_exposure")))
		flash_peaks.append(
				float(material.get_shader_parameter("flash_peak_strength")))
		rim_peaks.append(
				float(material.get_shader_parameter("rim_peak_strength")))

	assert_gt(light_directions[0].x, 0.0)
	assert_lt(light_directions[1].x, 0.0)
	assert_eq(scene_exposures[0], scene_exposures[1])
	assert_eq(flash_peaks[0], flash_peaks[1])
	assert_eq(rim_peaks[0], rim_peaks[1])

	for shadow_name: String in ["P1Shadow", "P2Shadow"]:
		var shadow := screen.get_node(shadow_name) as TextureRect
		var shadow_material := shadow.material as ShaderMaterial
		assert_not_null(shadow_material)
		assert_eq(shadow_material.shader.resource_path, SHADOW_SHADER_PATH)
		assert_eq(shadow.rotation, 0.0)

	var post_fx := screen.get_node("PostFX") as ColorRect
	var post_material := post_fx.material as ShaderMaterial
	assert_not_null(post_material)
	assert_eq(post_material.shader.resource_path, POSTFX_SHADER_PATH)
	assert_almost_eq(float(post_material.get_shader_parameter("brightness")), 0.99, 0.001)
	assert_almost_eq(float(post_material.get_shader_parameter("contrast")), 1.14, 0.001)
	assert_almost_eq(float(post_material.get_shader_parameter("saturation")), 1.0, 0.001)
	assert_almost_eq(float(post_material.get_shader_parameter("tint_strength")), 0.04, 0.001)
	assert_almost_eq(float(post_material.get_shader_parameter("split_strength")), 0.11, 0.001)
	assert_eq(float(post_material.get_shader_parameter("grain_amount")), 0.0)

	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)
	base.free()
	screen.free()
