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

	assert_eq(screen.p1_char_display.position, Vector2(96, 282))
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
	var tree := stage.get_node("BlossomTree") as TextureRect
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
	assert_eq(bridge_scale, Vector2(7, 7),
			"The bridge must preserve its authored square pixels at an integer scale")
	assert_true(bridge.flip_h,
			"The asymmetric bridge is mirrored so its two deck heights match the authored Scene2 stances")
	assert_almost_eq(p1_support.x, 480.0, 1.01)
	assert_almost_eq(p2_support.x, 1440.0, 1.01)
	assert_almost_eq(p1_support.y, 769.68, 3.01,
			"The lower left deck must support the unchanged P1 foot position")
	assert_almost_eq(p2_support.y, 745.68, 3.01,
			"The upper right deck must support the unchanged P2 foot position")
	assert_lt(bridge.position.y, river.position.y)
	assert_gt(bridge.position.y + bridge.size.y, river.position.y,
			"The bridge must cross the river waterline so its lower body is grounded in water")
	assert_gt(tree.position.y + tree.size.y, bridge.position.y)
	assert_lt(tree.position.y + tree.size.y, river.position.y,
			"The blossom tree root must remain between the bridge top and river waterline")
	assert_eq(distant_water.position, Vector2(-48, 845))
	assert_eq(distant_water.size, Vector2(2016, 65))
	assert_gte(distant_water.position.y - maxf(p1_support.y, p2_support.y), 70.0,
			"Ref24-style bridge piers need visible depth before the distant water begins")
	assert_eq(river.position.x, -48.0)
	assert_almost_eq(river.size.x, 2016.0, 0.01)
	assert_gte(river.position.y, distant_water.position.y)
	assert_lte(river.position.y, distant_water.position.y + distant_water.size.y,
			"River may be art-directed vertically but must overlap DistantWater without a seam")
	assert_gte(river.position.y - maxf(p1_support.y, p2_support.y), 90.0,
			"The foreground waterline must sit below the bridge deck instead of touching the actors' feet")
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
		"CloudFar": [
			"res://assets/scenes/scene2/scene2_cloud_bank.png",
			Vector2(1521, 1019), 0.02],
		"FarMountain": [
			"res://assets/scenes/scene2/scene2_far_mountain.png",
			Vector2(1608, 508), 0.04],
		"CloudMid": [
			"res://assets/scenes/scene2/scene2_cloud_tower.png",
			Vector2(1513, 486), 0.06],
		"MidMountain": [
			"res://assets/scenes/scene2/scene2_mid_mountain.png",
			Vector2(1672, 752), 0.08],
		"MountainLeft": [
			"res://assets/scenes/scene2/scene2_mountain_left.png",
			Vector2(122, 194), 0.24],
		"MountainRight": [
			"res://assets/scenes/scene2/scene2_mountain_right.png",
			Vector2(140, 235), 0.24],
		"BlossomTree": [
			"res://assets/scenes/scene2/scene2_blossom_tree.png",
			Vector2(208, 125), 0.48],
		"StoneBridge": [
			"res://assets/scenes/scene2/scene2_stone_bridge.png",
			Vector2(237, 55), 1.0],
	}

	for node_name: String in contract:
		assert_true(stage.has_node(node_name),
				"Scene2 must contain the formal %s layer" % node_name)
		if not stage.has_node(node_name):
			continue
		var node := stage.get_node(node_name) as TextureRect
		var expected_path: String = contract[node_name][0]
		var expected_texture_size: Vector2 = contract[node_name][1]
		var expected_parallax: float = contract[node_name][2]
		assert_eq(node.texture.resource_path, expected_path,
				"%s must use the newly imported Scene2 asset" % node_name)
		assert_eq(node.texture.get_size(), expected_texture_size)
		assert_gt(node.size.x, 0.0)
		assert_gt(node.size.y, 0.0)
		assert_eq(float(node.get_meta("parallax_factor")), expected_parallax)
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
		assert_lt(stage.get_node("MountainLeft").get_index(),
				stage.get_node("MountainRight").get_index())
		assert_lt(stage.get_node("MountainRight").get_index(),
				stage.get_node("HorizonHaze").get_index(),
				"Both framing mountains must receive the existing horizon atmosphere")
	assert_not_null((stage.get_node("CloudFar") as TextureRect).material,
			"The far cloud bank must receive the Scene2 atmospheric grade")
	assert_not_null((stage.get_node("CloudMid") as TextureRect).material,
			"The mid cloud tower must receive the Scene2 atmospheric grade")
	assert_null((stage.get_node("FarMountain") as TextureRect).material,
			"The new far mountain must keep its hard pixel edge")
	assert_null((stage.get_node("MidMountain") as TextureRect).material,
			"The new mid mountain must keep its hard pixel edge")
	if stage.has_node("MountainLeft") and stage.has_node("MountainRight"):
		assert_true((stage.get_node("MountainLeft") as TextureRect).visible)
		assert_true((stage.get_node("MountainRight") as TextureRect).visible)
		assert_eq((stage.get_node("MountainLeft") as TextureRect).size,
				Vector2(366, 582),
				"The left mountain must use a crisp integer 3x scale")
		assert_eq((stage.get_node("MountainRight") as TextureRect).size,
				Vector2(420, 705),
				"The right mountain must use a crisp integer 3x scale")
	assert_null((stage.get_node("BlossomTree") as TextureRect).material,
			"The replacement tree must display its authored palette without the rejected quiet-zone grade")
	assert_null((stage.get_node("StoneBridge") as TextureRect).material,
			"The playable bridge must remain crisp and ungraded")


func test_scene2_new_framing_mountains_have_true_alpha() -> void:
	var contract := {
		"res://assets/scenes/scene2/scene2_mountain_left.png": Vector2i(122, 194),
		"res://assets/scenes/scene2/scene2_mountain_right.png": Vector2i(140, 235),
	}
	for path: String in contract:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image)
		if image == null:
			continue
		assert_eq(image.get_size(), contract[path])
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_eq(image.get_pixel(image.get_width() - 1, 0).a, 0.0)
		assert_eq(image.get_pixel(0, image.get_height() - 1).a, 0.0)
		assert_eq(image.get_pixel(
				image.get_width() - 1, image.get_height() - 1).a, 0.0)
		var visible_pixels := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					visible_pixels += 1
		assert_gt(visible_pixels, int(image.get_width() * image.get_height() * 0.2),
				"The keyed mountain must retain substantial authored rock detail")


func test_scene2_bridge_alpha_removes_outer_outline_and_keeps_internal_shadows() -> void:
	var bridge_path := "res://assets/scenes/scene2/scene2_stone_bridge.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(bridge_path))
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(237, 55))

	for pixel: Vector2i in [
		Vector2i(120, 0),
		Vector2i(147, 0),
		Vector2i(94, 1),
		Vector2i(147, 1),
		Vector2i(31, 6),
	]:
		assert_eq(image.get_pixelv(pixel).a, 0.0,
				"Dark pixels outside the colored bridge silhouette must be transparent")

	for pixel: Vector2i in [
		Vector2i(94, 4),
		Vector2i(147, 5),
		Vector2i(210, 23),
		Vector2i(212, 24),
	]:
		assert_eq(image.get_pixelv(pixel).a, 1.0,
				"Dark shadows inside the authored bridge structure must stay opaque")

	for pixel: Vector2i in [
		Vector2i(0, 0),
		Vector2i(236, 54),
		Vector2i(120, 35),
	]:
		assert_eq(image.get_pixelv(pixel).a, 0.0,
				"Outer background and the authored main arch must stay transparent")


func test_scene2_uses_one_left_full_height_waterfall() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	assert_true(stage.has_node("WaterfallLeft"),
			"Scene2 must expose one editable left-side waterfall node")
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
	assert_eq(waterfall.position, Vector2(-80, -96))
	assert_eq(waterfall.size, Vector2(720, 1216))
	assert_eq(impact.position, waterfall.position)
	assert_eq(impact.size, waterfall.size)
	assert_true(waterfall.visible)
	assert_true(impact.visible)
	assert_lte(waterfall.position.y, 0.0)
	assert_gte(waterfall.position.y + waterfall.size.y, 1080.0)
	assert_eq(float(waterfall.get_meta("parallax_factor")), 0.18)
	assert_eq(float(impact.get_meta("parallax_factor")), 0.18)
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
	var body_right_edge := (
			waterfall.position.x
			+ waterfall.size.x * float(material.get_shader_parameter("center_x"))
			+ float(material.get_shader_parameter("bend_px"))
			+ float(material.get_shader_parameter("bottom_half_width_px"))
			+ float(material.get_shader_parameter("edge_wobble_px")))
	assert_lte(body_right_edge, 460.0,
			"The waterfall body must stay left of the unchanged P1 silhouette")


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
