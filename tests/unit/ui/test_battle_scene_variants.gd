extends GutTest

const SCENE1_PATH := "res://src/ui/scenes/scene1.tscn"
const SCENE2_PATH := "res://src/ui/scenes/scene2.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const BATTLE2_PATH := "res://src/ui/battle_screen2.tscn"


func test_battle_screen_entry_names_replace_legacy_paths() -> void:
	assert_true(ResourceLoader.exists(BATTLE_BASE_PATH))
	assert_true(ResourceLoader.exists(BATTLE1_PATH))
	assert_true(ResourceLoader.exists(BATTLE2_PATH))
	assert_false(ResourceLoader.exists("res://src/ui/battle_screen.tscn"))
	assert_false(ResourceLoader.exists("res://src/ui/battle_screen_scene2.tscn"))


func test_battle_screen1_statically_uses_scene1_and_fullscreen_sky() -> void:
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var stage_slot := screen.get_node("StageSlot") as Control
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var night_sky := stage.get_node("NightSky") as ColorRect
	assert_eq(stage.scene_file_path, SCENE1_PATH,
			"BattleScreen1 必须在场景中静态挂载 Scene1")
	assert_eq(stage_slot.anchor_right, 1.0)
	assert_eq(stage_slot.anchor_bottom, 1.0)
	assert_eq(stage_slot.size, screen.size,
			"共享舞台插槽必须跟随 BattleScreen 的实际画布尺寸")
	assert_gt(stage_slot.size.x, 0.0)
	assert_gt(stage_slot.size.y, 0.0)
	assert_eq(stage.size, stage_slot.size,
			"Scene1 根节点必须从舞台插槽获得完整尺寸")
	var screen_rect: Rect2 = screen.get_global_rect()
	var sky_rect: Rect2 = night_sky.get_global_rect()
	assert_lte(sky_rect.position.x, screen_rect.position.x)
	assert_lte(sky_rect.position.y, screen_rect.position.y)
	assert_gte(sky_rect.end.x, screen_rect.end.x)
	assert_gte(sky_rect.end.y, screen_rect.end.y,
			"Scene1 夜空必须覆盖完整画面，不能被零尺寸 StageSlot 压缩")


func test_battle_screen1_keeps_scene1_as_the_single_visual_source() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE1_PATH)
	assert_false(battle_source.contains('parent="StageSlot/Stage"'),
			"BattleScreen1 must not serialize stale overrides for Scene1 child nodes")
	assert_false(battle_source.contains('[editable path="StageSlot/Stage"]'),
			"Scene1 composition must be edited only in scene1.tscn")

	var standalone_stage := (load(SCENE1_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	var embedded_stage := screen.get_node("StageSlot/Stage")
	for node_name in ["BambooFarLeft", "BambooFarRight", "BambooLeft", "BambooRight"]:
		var standalone_node := standalone_stage.get_node(node_name) as TextureRect
		var embedded_node := embedded_stage.get_node(node_name) as TextureRect
		assert_eq(embedded_node.position, standalone_node.position,
				"%s must use the position saved in Scene1" % node_name)
		assert_eq(embedded_node.size, standalone_node.size,
				"%s must use the size saved in Scene1" % node_name)
		assert_eq(embedded_node.texture.resource_path, standalone_node.texture.resource_path)
	standalone_stage.free()
	screen.free()


func test_battle_screen2_statically_uses_scene2() -> void:
	BattleSetup.reset()
	var battle_source := FileAccess.get_file_as_string(BATTLE2_PATH)
	assert_false(battle_source.contains('parent="StageSlot/Stage"'),
			"BattleScreen2 must not serialize stale overrides for Scene2 child nodes")
	assert_false(battle_source.contains('[editable path="StageSlot/Stage"]'),
			"Scene2 composition must be edited only in scene2.tscn")
	var screen := (load(BATTLE2_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"),
			"BattleScreen2 的 Stage 接口必须绑定静态挂载节点")
	assert_eq(screen.stage.scene_file_path, SCENE2_PATH,
			"独立 Scene2 战斗场景必须加载 Scene2 舞台")
	assert_true(screen.stage.pointer_parallax,
			"Scene2 舞台继续沿用 BattleScreen 的鼠标视差")
	assert_false(screen.stage.demo_click_shake,
			"Scene2 舞台集成后不得启用独立预览点击震屏")
	assert_not_null(screen.get_node_or_null("WorldGroup"),
			"Scene2 变体继续执行成熟的战斗世界归组")
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	BattleSetup.reset()


func test_scene2_variant_keeps_its_authored_character_geometry() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE2_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.p1_char_display.position, Vector2(96, 258))
	assert_eq(screen.p2_char_display.position, Vector2(1056, 258))
	assert_almost_eq(screen.p1_char_display.size.x, 768.0, 0.01)
	assert_almost_eq(screen.p1_char_display.size.y, 768.0, 0.01)
	assert_almost_eq(screen.p2_char_display.size.x, 768.0, 0.01)
	assert_almost_eq(screen.p2_char_display.size.y, 768.0, 0.01)
	assert_eq(screen.p1_char_display.sprite_scale, Vector2(2, 2))
	assert_eq(screen.p2_char_display.sprite_scale, Vector2(2, 2))
	assert_eq(screen.p1_char_display.anim_fps, 12.0)
	assert_eq(screen.p2_char_display.anim_fps, 12.0)
	BattleSetup.reset()


func test_scene2_foreground_grounding_contract() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)

	var bridge := stage.get_node("StoneBridge") as TextureRect
	var distant_water := stage.get_node("DistantWater") as ColorRect
	var river := stage.get_node("River") as ColorRect
	var river_material := river.material as ShaderMaterial

	var bridge_texture_size := bridge.texture.get_size()
	var bridge_scale := bridge.size / bridge_texture_size
	var p1_source := Vector2(bridge.get_meta("p1_support_source"))
	var p2_source := Vector2(bridge.get_meta("p2_support_source"))
	var p1_display_x := bridge_texture_size.x - 1.0 - p1_source.x if bridge.flip_h else p1_source.x
	var p2_display_x := bridge_texture_size.x - 1.0 - p2_source.x if bridge.flip_h else p2_source.x
	var p1_support := bridge.position + Vector2(p1_display_x, p1_source.y) * bridge_scale
	var p2_support := bridge.position + Vector2(p2_display_x, p2_source.y) * bridge_scale
	assert_gt(bridge_scale.x, 0.0)
	assert_gt(bridge_scale.y, 0.0)
	assert_true(bridge.flip_h,
			"The asymmetric bridge is mirrored so its two deck heights match the authored Scene2 stances")
	assert_lt(p1_support.x, p2_support.x)
	assert_true(Rect2(bridge.position, bridge.size).has_point(p1_support))
	assert_true(Rect2(bridge.position, bridge.size).has_point(p2_support))
	assert_lt(bridge.position.y, river.position.y)
	assert_gt(bridge.position.y + bridge.size.y, river.position.y,
			"The bridge must cross the river waterline so its lower body is grounded in water")
	assert_lte(distant_water.position.x, 0.0)
	assert_gte(distant_water.position.x + distant_water.size.x, 1920.0)
	assert_lt(distant_water.position.y, river.position.y)
	assert_gte(distant_water.position.y + distant_water.size.y, river.position.y,
			"Distant water must overlap the foreground river without a seam")
	assert_lte(river.position.x, 0.0)
	assert_gte(river.position.x + river.size.x, 1920.0)
	assert_gte(river.position.y, distant_water.position.y)
	assert_lte(river.position.y, distant_water.position.y + distant_water.size.y,
			"River may be art-directed vertically but must overlap DistantWater without a seam")
	var river_shader_size: Vector2 = river_material.get_shader_parameter("size_px")
	assert_almost_eq(river_shader_size.x, river.size.x, 0.01)
	assert_almost_eq(river_shader_size.y, river.size.y, 0.01)
	assert_gte(river.position.y + river.size.y, 1080.0,
			"Scene2 河面必须越过屏幕底边，不能留下白线")
	assert_false(river_material.shader.code.contains("impact_ring"),
			"Scene2 river must not continuously expand waterfall-impact rings")


func test_scene2_uses_formal_environment_assets_and_depth_layers() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var scene_source := FileAccess.get_file_as_string(SCENE2_PATH)
	var contract := {
		"CloudFar": "res://assets/scenes/scene2/scene2_cloud_bank.png",
		"FarMountain": "res://assets/scenes/scene2/scene2_far_mountain.png",
		"CloudMid": "res://assets/scenes/scene2/scene2_cloud_tower.png",
		"MidMountain": "res://assets/scenes/scene2/scene2_mid_mountain.png",
		"MountainLeft": "res://assets/scenes/scene2/scene2_mountain_left.png",
		"MountainRight": "res://assets/scenes/scene2/scene2_mountain_right.png",
		"BlossomTree": "res://assets/scenes/scene2/scene2_blossom_tree.png",
		"StoneBridge": "res://assets/scenes/scene2/scene2_stone_bridge.png",
	}

	for node_name: String in contract:
		assert_true(stage.has_node(node_name),
				"Scene2 must contain the formal %s layer" % node_name)
		if not stage.has_node(node_name):
			continue
		var node := stage.get_node(node_name) as TextureRect
		var expected_path: String = contract[node_name]
		assert_eq(node.texture.resource_path, expected_path,
				"%s must use the newly imported Scene2 asset" % node_name)
		assert_gt(node.size.x, 0.0)
		assert_gt(node.size.y, 0.0)
		assert_true(node.has_meta("parallax_factor"))
		assert_gte(float(node.get_meta("parallax_factor")), 0.0)
		assert_eq(node.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
				"%s must retain hard pixel edges" % node_name)

	assert_false(stage.has_node("FarMountainBack"))
	assert_false(stage.has_node("FarMountainMid"))
	assert_false(stage.has_node("FarMountainNear"))
	assert_false(stage.has_node("MountainGate"),
			"The new right mountain must replace the retired gate layer")
	assert_false(scene_source.contains("scene2_mountain_gate_px2.png"))
	assert_false(scene_source.contains("scene2_mountain_left_px2.png"))
	assert_lt(stage.get_node("CloudFar").get_index(), stage.get_node("FarMountain").get_index())
	assert_lt(stage.get_node("FarMountain").get_index(), stage.get_node("CloudMid").get_index())
	assert_lt(stage.get_node("CloudMid").get_index(), stage.get_node("MidMountain").get_index())
	if stage.has_node("MountainLeft") and stage.has_node("MountainRight"):
		assert_lt(stage.get_node("WaterfallLeft").get_index(),
				stage.get_node("MountainLeft").get_index(),
				"The left framing mountain must naturally occlude the waterfall edge")
		assert_lt(stage.get_node("WaterfallLeft").get_index(),
				stage.get_node("MountainRight").get_index(),
				"The right framing mountain must naturally occlude the waterfall edge")
		assert_lt(stage.get_node("MountainRight").get_index(),
				stage.get_node("HorizonHaze").get_index(),
				"Both framing mountains must receive the existing horizon atmosphere")
		assert_lt(stage.get_node("MountainLeft").get_index(),
				stage.get_node("HorizonHaze").get_index(),
				"Both framing mountains must receive the existing horizon atmosphere")
	assert_not_null((stage.get_node("CloudFar") as TextureRect).material,
			"The far cloud bank must receive the Scene2 atmospheric grade")
	assert_not_null((stage.get_node("CloudMid") as TextureRect).material,
			"The mid cloud tower must receive the Scene2 atmospheric grade")
	assert_not_null((stage.get_node("FarMountain") as TextureRect).material,
			"The far mountain must receive a non-blurring atmospheric grade")
	assert_not_null((stage.get_node("MidMountain") as TextureRect).material,
			"The mid mountain must receive a non-blurring atmospheric grade")
	if stage.has_node("MountainLeft") and stage.has_node("MountainRight"):
		assert_true((stage.get_node("MountainLeft") as TextureRect).visible)
		assert_true((stage.get_node("MountainRight") as TextureRect).visible)
	assert_null((stage.get_node("BlossomTree") as TextureRect).material,
			"The replacement tree must display its authored palette without the rejected quiet-zone grade")
	assert_null((stage.get_node("StoneBridge") as TextureRect).material,
			"The playable bridge must remain crisp and ungraded")


func test_scene2_p1_depth_grades_follow_relative_atmospheric_hierarchy() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var graded_layers := [
		stage.get_node("CloudFar") as TextureRect,
		stage.get_node("FarMountain") as TextureRect,
		stage.get_node("CloudMid") as TextureRect,
		stage.get_node("MidMountain") as TextureRect,
	]
	for layer: TextureRect in graded_layers:
		var material := layer.material as ShaderMaterial
		assert_not_null(material,
				"%s must have an atmospheric depth material" % layer.name)
		if material == null:
			continue
		assert_eq(material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene2_depth_grade.gdshader")
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
				"Depth grading must not replace nearest-neighbour pixel edges")

	var far_mountain_material := (
			(stage.get_node("FarMountain") as TextureRect).material as ShaderMaterial)
	var mid_mountain_material := (
			(stage.get_node("MidMountain") as TextureRect).material as ShaderMaterial)
	assert_lte(
			float(far_mountain_material.get_shader_parameter("saturation")),
			float(mid_mountain_material.get_shader_parameter("saturation")),
			"Far geometry must be less saturated than mid geometry")
	assert_lte(
			float(far_mountain_material.get_shader_parameter("contrast")),
			float(mid_mountain_material.get_shader_parameter("contrast")),
			"Far geometry must be lower contrast than mid geometry")
	assert_gte(
			float(far_mountain_material.get_shader_parameter("atmosphere_strength")),
			float(mid_mountain_material.get_shader_parameter("atmosphere_strength")),
			"Far geometry must carry more atmospheric wash than mid geometry")


func test_scene2_new_framing_mountains_have_true_alpha() -> void:
	for path: String in [
		"res://assets/scenes/scene2/scene2_mountain_left.png",
		"res://assets/scenes/scene2/scene2_mountain_right.png",
	]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image)
		if image == null:
			continue
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE,
				"The framing mountain must remain a true-alpha replacement asset")


func test_scene2_bridge_replacement_retains_true_alpha() -> void:
	var bridge_path := "res://assets/scenes/scene2/scene2_stone_bridge.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(bridge_path))
	assert_not_null(image)
	if image == null:
		return
	assert_ne(image.detect_alpha(), Image.ALPHA_NONE,
			"The bridge replacement must retain transparent arches and outer background")


func test_scene2_uses_one_full_height_waterfall() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	assert_true(stage.has_node("WaterfallLeft"),
			"Scene2 must expose one editable full-height waterfall node")
	assert_true(stage.has_node("WaterfallImpactLeft"),
			"The waterfall must expose a separate river-surface impact layer")
	if not stage.has_node("WaterfallLeft") or not stage.has_node("WaterfallImpactLeft"):
		return

	var waterfall := stage.get_node("WaterfallLeft") as ColorRect
	var impact := stage.get_node("WaterfallImpactLeft") as ColorRect
	var material := waterfall.material as ShaderMaterial
	var impact_material := impact.material as ShaderMaterial
	var mid_mountain := stage.get_node("MidMountain") as TextureRect
	var bridge := stage.get_node("StoneBridge") as TextureRect
	var river := stage.get_node("River") as ColorRect
	var fog_front := stage.get_node("FogFront") as ColorRect
	var scene_source := FileAccess.get_file_as_string(SCENE2_PATH)
	var shader_source := material.shader.code

	assert_false(stage.has_node("WaterfallUpper"))
	assert_false(stage.has_node("WaterfallMiddle"))
	assert_false(stage.has_node("WaterfallLower"))
	assert_false(scene_source.contains("WaterfallUpperMat"))
	assert_false(scene_source.contains("WaterfallMiddleMat"))
	assert_false(scene_source.contains("WaterfallLowerMat"))
	assert_eq(impact.position, waterfall.position)
	assert_eq(impact.size, waterfall.size)
	assert_true(waterfall.visible)
	assert_lte(waterfall.position.y, 0.0)
	assert_gte(waterfall.position.y + waterfall.size.y, 1080.0)
	assert_eq(float(impact.get_meta("parallax_factor")),
			float(waterfall.get_meta("parallax_factor")))
	assert_gt(waterfall.get_index(), mid_mountain.get_index())
	assert_lt(waterfall.get_index(), bridge.get_index())
	assert_lt(waterfall.get_index(), river.get_index())
	assert_gt(impact.get_index(), river.get_index(),
			"The impact foam and ripples must remain visible over the river")
	assert_lt(impact.get_index(), fog_front.get_index())
	assert_not_null(material)
	assert_not_null(impact_material)
	assert_eq(material.shader.resource_path,
			"res://assets/shaders/canvas_env_pixel_waterfall.gdshader")
	assert_eq(impact_material.shader.resource_path, material.shader.resource_path)
	assert_eq(int(material.get_shader_parameter("render_part")), 0)
	assert_eq(int(impact_material.get_shader_parameter("render_part")), 1)
	assert_eq(material.get_shader_parameter("size_px"), waterfall.size)
	assert_eq(impact_material.get_shader_parameter("size_px"), impact.size)
	assert_gte(float(material.get_shader_parameter("top_y")), 0.07)
	assert_lte(float(material.get_shader_parameter("top_y")), 0.10)
	assert_gte(float(material.get_shader_parameter("bottom_y")), 0.82)
	assert_lte(float(material.get_shader_parameter("bottom_y")), 0.90)
	assert_gte(float(material.get_shader_parameter("section_width_wobble_px")), 12.0,
			"The long fall must vary its silhouette between broad sections")
	assert_lte(float(material.get_shader_parameter("px_size")), 4.0,
			"The waterfall must use a pixel grid close to the 3px river grid")
	assert_lte(float(material.get_shader_parameter("anim_fps")), 6.0,
			"The waterfall cadence must remain calm enough for the bright scene")
	assert_lte(float(material.get_shader_parameter("fall_speed_px")), 105.0)
	assert_lte(float(material.get_shader_parameter("mouth_highlight_density")), 0.40)
	assert_lte(float(material.get_shader_parameter("cross_join_density")), 0.08)
	assert_lte(float(material.get_shader_parameter("flow_highlight_density")), 0.20)
	assert_lte(float(material.get_shader_parameter("edge_drop_density")), 0.04)
	assert_lte(float(material.get_shader_parameter("splash_fps")), 6.0)
	assert_gte(float(material.get_shader_parameter("splash_cycle_a")), 17.0)
	assert_lte(float(material.get_shader_parameter("impact_mist_strength")), 0.16)
	assert_gte(float(material.get_shader_parameter("ripple_period_sec")), 5.0,
			"Impact ripples must move more slowly than the falling water")
	assert_lte(float(material.get_shader_parameter("ripple_segment_density")), 0.35,
			"Only a minority of ripple segments may flash at once")
	assert_lte(float(material.get_shader_parameter("ripple_shadow_strength")), 0.35)
	assert_ne(material.get_shader_parameter("splash_cycle_a"),
			material.get_shader_parameter("splash_cycle_b"),
			"Splash bursts must not land on one unified beat")
	assert_ne(material.get_shader_parameter("splash_cycle_b"),
			material.get_shader_parameter("splash_cycle_c"),
			"Splash bursts must use staggered lifetimes")
	for shared_parameter: String in [
		"top_y",
		"bottom_y",
		"center_x",
		"bend_px",
		"bottom_half_width_px",
		"ripple_period_sec",
		"deep_color",
		"mid_color",
		"light_color",
		"foam_color",
		"core_width_ratio",
	]:
		assert_eq(
				impact_material.get_shader_parameter(shared_parameter),
				material.get_shader_parameter(shared_parameter),
				"Body and surface impact layers must stay spatially synchronized")
	for marker: String in [
		"mouth_vertical",
		"rare_cross_join",
		"top_lip_segments",
		"splash_phase_a",
		"splash_phase_b",
		"splash_phase_c",
		"entry_white",
		"ripple_bright",
		"ripple_shadow",
	]:
		assert_true(shader_source.contains(marker),
				"The waterfall shader must implement %s" % marker)
	assert_false(shader_source.contains("foam_cycle"),
			"The old synchronized foam cycle must be removed")


func test_scene2_waterfall_is_broken_up_by_cloud_veils_and_calm_distant_water() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	for node_name: String in ["WaterfallCloudUpper", "WaterfallCloudLower"]:
		assert_true(stage.has_node(node_name),
				"Scene2 needs an editable cloud veil named %s" % node_name)
	if not stage.has_node("WaterfallCloudUpper") or not stage.has_node("WaterfallCloudLower"):
		return

	var waterfall := stage.get_node("WaterfallLeft") as ColorRect
	var upper_cloud := stage.get_node("WaterfallCloudUpper") as TextureRect
	var lower_cloud := stage.get_node("WaterfallCloudLower") as TextureRect
	var left_mountain := stage.get_node("MountainLeft") as TextureRect
	var right_mountain := stage.get_node("MountainRight") as TextureRect
	var haze := stage.get_node("HorizonHaze") as ColorRect
	var distant_water := stage.get_node("DistantWater") as ColorRect
	var distant_material := distant_water.material as ShaderMaterial

	assert_lt(waterfall.get_index(), upper_cloud.get_index())
	assert_lt(upper_cloud.get_index(), left_mountain.get_index())
	assert_lt(upper_cloud.get_index(), right_mountain.get_index(),
			"The upper veil must interrupt the fall while the framing cliffs stay in front")
	assert_gt(lower_cloud.get_index(), waterfall.get_index(),
			"The lower veil must remain in front of the waterfall body")
	assert_true(
			lower_cloud.get_index() > left_mountain.get_index()
			or lower_cloud.get_index() > right_mountain.get_index(),
			"The lower veil must overlap at least one framing mountain to avoid a flat stack")
	assert_lt(lower_cloud.get_index(), haze.get_index(),
			"The lower veil may interleave with the framing mountains but must receive valley haze")
	for cloud: TextureRect in [upper_cloud, lower_cloud]:
		assert_eq(cloud.texture.resource_path,
				"res://assets/scenes/scene2/scene2_cloud_bank.png")
		assert_eq(cloud.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_gt(cloud.size.x, 0.0)
		assert_gt(cloud.size.y, 0.0)

	assert_true(distant_water.visible)
	assert_not_null(distant_material)
	if distant_material == null:
		return
	assert_eq(distant_material.shader.resource_path,
			"res://assets/shaders/canvas_env_pixel_distant_water.gdshader")
	assert_eq(distant_material.get_shader_parameter("size_px"), distant_water.size)
	assert_lte(float(distant_material.get_shader_parameter("anim_fps")), 5.0)
	assert_lte(absf(float(distant_material.get_shader_parameter("flow_speed_px"))), 10.0)
	assert_lte(float(distant_material.get_shader_parameter("line_density")), 0.22)
	assert_gte(float(distant_material.get_shader_parameter("sky_lane_strength")), 0.20)
	assert_gte(float(distant_material.get_shader_parameter("bank_shadow_strength")), 0.10)
	assert_lt(distant_water.get_index(), stage.get_node("StoneBridge").get_index(),
			"The distant water must be visible only through and behind the bridge")

	var waterfall_material := waterfall.material as ShaderMaterial
	var waterfall_mid: Color = waterfall_material.get_shader_parameter("mid_color")
	var distant_mid: Color = distant_material.get_shader_parameter("mid_color")
	assert_lt(absf(waterfall_mid.b - distant_mid.b), 0.18,
			"Waterfall and distant water must share one cool blue-green family")
	assert_lt(absf(waterfall_mid.g - distant_mid.g), 0.18,
			"Waterfall and distant water must share one cool blue-green family")

	assert_true(stage.has_node("StoneBridge/BridgeBankShade"),
			"Scene2 P1 needs a dedicated pixel-stepped bridge-bank transition")
	if not stage.has_node("StoneBridge/BridgeBankShade"):
		return
	var bridge_bank := stage.get_node("StoneBridge/BridgeBankShade") as ColorRect
	var bridge := stage.get_node("StoneBridge") as TextureRect
	var river := stage.get_node("River") as ColorRect
	var bridge_bank_material := bridge_bank.material as ShaderMaterial
	assert_not_null(bridge_bank_material)
	assert_eq(bridge_bank_material.shader.resource_path,
			"res://assets/shaders/canvas_env_pixel_bridge_bank.gdshader")
	assert_eq(bridge_bank.get_parent(), bridge,
			"The bank transition must follow future manual bridge transforms")
	assert_lt(bridge.get_index(), river.get_index(),
			"The foreground river must remain the nearest continuous water surface")
	assert_gte(bridge_bank.size.x, bridge.size.x * 0.95,
			"The bridge-bank treatment must cover both ends without pinning editor coordinates")


func test_scene2_p2_motion_uses_pixel_cadence_and_petal_flipbook() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var waterfall := stage.get_node("WaterfallLeft") as ColorRect
	var river := stage.get_node("River") as ColorRect
	var waterfall_material := waterfall.material as ShaderMaterial
	var river_material := river.material as ShaderMaterial
	var petal_far := stage.get_node("PetalFar") as GPUParticles2D
	var petal_near := stage.get_node("PetalNear") as GPUParticles2D
	var petal_path := "res://assets/scenes/scene2/scene2_petal_atlas.png"

	assert_eq(float(waterfall_material.get_shader_parameter("anim_fps")), 5.0)
	assert_eq(float(river_material.get_shader_parameter("anim_fps")), 8.0)
	assert_lte(float(river_material.get_shader_parameter("px_size")),
			float(waterfall_material.get_shader_parameter("px_size")),
			"Near water and background fall must stay on compatible hard pixel grids")

	for particles: GPUParticles2D in [petal_far, petal_near]:
		assert_not_null(particles.texture)
		if particles.texture == null:
			continue
		assert_eq(particles.texture.resource_path, petal_path)
		assert_eq(particles.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(particles.fixed_fps, 12)
		assert_false(particles.interpolate,
				"Pixel petals must not smooth movement between 12fps simulation steps")
		assert_false(particles.fract_delta,
				"Pixel petals must not add fractional movement between fixed steps")

		var draw_material := particles.material as CanvasItemMaterial
		var process_material := particles.process_material as ParticleProcessMaterial
		assert_not_null(draw_material)
		assert_not_null(process_material)
		if draw_material == null or process_material == null:
			continue
		assert_true(draw_material.particles_animation)
		assert_eq(draw_material.particles_anim_h_frames, 4)
		assert_eq(draw_material.particles_anim_v_frames, 1)
		assert_true(draw_material.particles_anim_loop)
		assert_gt(process_material.anim_speed_min, 0.0)
		assert_eq(process_material.anim_speed_min, process_material.anim_speed_max)
		assert_gt(process_material.anim_offset_max, process_material.anim_offset_min,
				"Petals must begin on staggered flutter frames")

	var atlas := Image.load_from_file(ProjectSettings.globalize_path(petal_path))
	assert_not_null(atlas)
	if atlas != null:
		assert_eq(atlas.get_size(), Vector2i(64, 16))
		assert_ne(atlas.detect_alpha(), Image.ALPHA_NONE)


func test_scene2_p2_river_uses_restrained_shoreline_foam_clusters() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var river := stage.get_node("River") as ColorRect
	var material := river.material as ShaderMaterial
	var shader_source := material.shader.code

	assert_true(shader_source.contains("shore_cluster"))
	assert_true(shader_source.contains("shore_cluster_life"))
	assert_true(shader_source.contains("shore_cluster_bright"))
	assert_false(shader_source.contains("shore_light_mask"),
			"P2 must replace the continuous bright shoreline with broken foam clusters")
	assert_lte(float(material.get_shader_parameter("shore_cluster_density")), 0.32)
	assert_gte(float(material.get_shader_parameter("shore_cluster_cycle_sec")), 4.0)
	assert_lte(float(material.get_shader_parameter("shore_foam_strength")), 0.55)


func test_scene1_uses_dedicated_far_bamboo_groves_without_reused_copies() -> void:
	var stage := (load(SCENE1_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var contract := {
		"BambooFarLeft": [
			"res://assets/scenes/scene1/scene1_bamboo_far_left.png",
			Vector2(1335, 1178), 0.34],
		"BambooFarRight": [
			"res://assets/scenes/scene1/scene1_bamboo_far_right.png",
			Vector2(1085, 1449), 0.34],
		"BambooLeft": [
			"res://assets/scenes/scene1/scene1_bamboo_left.png",
			Vector2(128, 256), 1.25],
		"BambooRight": [
			"res://assets/scenes/scene1/scene1_bamboo_right.png",
			Vector2(64, 256), 1.25],
	}

	for node_name: String in contract:
		var bamboo := stage.get_node(node_name) as TextureRect
		assert_eq(bamboo.texture.resource_path, contract[node_name][0])
		var source_size := bamboo.texture.get_size()
		assert_eq(source_size, contract[node_name][1])
		assert_gt(bamboo.size.x, 0.0)
		assert_gt(bamboo.size.y, 0.0)
		assert_eq(float(bamboo.get_meta("parallax_factor")), contract[node_name][2])
		assert_not_null(bamboo.material)
		var bamboo_material := bamboo.material as ShaderMaterial
		assert_eq(bamboo_material.shader.resource_path,
				"res://assets/shaders/canvas_env_night_foliage.gdshader")

	for main_name in ["BambooLeft", "BambooRight"]:
		assert_eq((stage.get_node(main_name) as TextureRect).texture_filter,
				CanvasItem.TEXTURE_FILTER_NEAREST)
		var main_material := stage.get_node(main_name).material as ShaderMaterial
		assert_almost_eq(float(main_material.get_shader_parameter("alpha_scale")),
				1.0, 0.001, "Main bamboo must remain fully opaque")

	for far_name in ["BambooFarLeft", "BambooFarRight"]:
		assert_eq((stage.get_node(far_name) as TextureRect).texture_filter,
				CanvasItem.TEXTURE_FILTER_LINEAR,
				"Large dedicated far groves may use linear sampling to avoid downscale shimmer")

	for removed_copy in [
		"BambooFarLeftInner", "BambooFarRightInner",
		"BambooMidLeftInner", "BambooMidLeft",
		"BambooMidRightInner", "BambooMidRight",
	]:
		assert_false(stage.has_node(removed_copy),
				"Dedicated far-grove art must replace reused bamboo copies")

	var mountain_right := stage.get_node("Mountain_right")
	var bamboo_far_left := stage.get_node("BambooFarLeft")
	var bamboo_far_right := stage.get_node("BambooFarRight")
	var horizon_haze := stage.get_node("HorizonHaze")
	var rooftop_left := stage.get_node("RooftopL")
	var bamboo_left := stage.get_node("BambooLeft")
	var bamboo_right := stage.get_node("BambooRight")
	var rooftop_right := stage.get_node("RooftopR")

	assert_lt(mountain_right.get_index(), bamboo_far_left.get_index())
	assert_lt(bamboo_far_left.get_index(), bamboo_far_right.get_index())
	assert_lt(bamboo_far_right.get_index(), horizon_haze.get_index(),
			"Dedicated far groves must receive the existing horizon haze")
	assert_lt(rooftop_left.get_index(), bamboo_left.get_index())
	assert_lt(bamboo_left.get_index(), bamboo_right.get_index())
	assert_lt(bamboo_right.get_index(), rooftop_right.get_index(),
			"Main bamboo must remain grounded behind the right rooftop")

	var scene2 := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(scene2)
	for node_name: String in contract:
		assert_false(scene2.has_node(node_name),
				"Scene1 bamboo assets must never leak into Scene2")


func test_default_battle_screen_keeps_scene1_character_rendering_contract() -> void:
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()

	assert_eq(screen.get("character_reflections_enabled"), false,
			"Scene1 must not opt into the Scene2-only character reflection channel")
	assert_eq(screen.get_node("P1CharDisplay").rim_strength, 1.2)
	assert_eq(screen.get_node("P1CharDisplay").fill_amount, 0.3)
	assert_eq(screen.get_node("P2CharDisplay").rim_strength, 0.72)
	assert_eq(screen.get_node("P2CharDisplay").fill_amount, 0.08)
	assert_eq(screen.get_node("P1Shadow").self_modulate, Color.WHITE)
	assert_eq(screen.get_node("P2Shadow").self_modulate, Color.WHITE)
	screen.free()


func test_scene2_binds_live_character_textures_to_the_river() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE2_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(screen.get("character_reflections_enabled"), true)
	assert_true(screen.p1_char_display.has_method("get_render_texture"),
			"CharacterDisplay must expose its existing SubViewport texture without duplicating actors")
	var river_material := screen.get("_character_reflection_material") as ShaderMaterial
	assert_not_null(river_material,
			"Scene2 must own a per-instance river material for its live character textures")
	if river_material != null:
		assert_not_null(river_material.get_shader_parameter("p1_reflection_tex"))
		assert_not_null(river_material.get_shader_parameter("p2_reflection_tex"))
		var p1_rect: Vector4 = river_material.get_shader_parameter("p1_reflection_rect")
		var p2_rect: Vector4 = river_material.get_shader_parameter("p2_reflection_rect")
		assert_gt(p1_rect.z, 0.0)
		assert_gt(p1_rect.w, 0.0)
		assert_gt(p2_rect.z, 0.0)
		assert_gt(p2_rect.w, 0.0)
		assert_true(river_material.shader.code.contains("p1_reflection_tex"))
		assert_true(river_material.shader.code.contains("p2_reflection_tex"))
		screen.p1_char_display.position.x += 24.0
		screen.call("_update_character_reflections")
		var moved_p1_rect: Vector4 = river_material.get_shader_parameter("p1_reflection_rect")
		assert_gt(moved_p1_rect.x, p1_rect.x,
				"The reflection sampling rect must follow character and camera-space movement")
	BattleSetup.reset()


func test_scene2_uses_its_own_jade_daylight_character_grade() -> void:
	var screen := (load(BATTLE2_PATH) as PackedScene).instantiate()
	var p1 := screen.get_node("P1CharDisplay") as CharacterDisplay
	var p2 := screen.get_node("P2CharDisplay") as CharacterDisplay

	for character in [p1, p2]:
		assert_eq(character.rim_color, Color(0.72, 0.86, 0.78, 1.0))
		assert_eq(character.shadow_tint, Color(0.48, 0.61, 0.57, 1.0))
		assert_eq(character.fill_color, Color(0.72, 0.83, 0.74, 1.0))
		assert_eq(character.light_dir, Vector2(1.0, -0.8))
		assert_eq(character.rim_strength, 0.68)
		assert_eq(character.rim_width, 3.5)
		assert_eq(character.backlight, 0.16)
		assert_eq(character.warmth_amount, 0.18)
		assert_eq(character.fill_amount, 0.16)
	assert_eq(screen.get_node("P1Shadow").self_modulate,
			Color(0.25, 0.38, 0.35, 0.72))
	assert_eq(screen.get_node("P2Shadow").self_modulate,
			Color(0.25, 0.38, 0.35, 0.72))
	screen.free()


func test_battle_avatar_frames_use_editor_safe_diamond_preview() -> void:
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	var frame := screen.get_node("P1Hud/P1Frame0") as HeroFrame
	var frame_script := frame.get_script() as Script
	var battle_script := screen.get_script() as Script

	assert_true(frame_script.is_tool(),
			"HeroFrame 必须能在编辑器中执行 diamond_mode 的安全视觉预览")
	assert_false(battle_script.is_tool(),
			"完整 BattleScreen 战斗逻辑不得在编辑器中执行")
	assert_true(frame.diamond_mode)
	screen.free()
