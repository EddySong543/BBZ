extends GutTest

const SCENE1_PATH := "res://src/ui/scenes/scene1.tscn"
const SCENE2_PATH := "res://src/ui/scenes/scene2.tscn"
const SCENE3_PATH := "res://src/ui/scenes/scene3.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const BATTLE2_PATH := "res://src/ui/battle_screen2.tscn"
const BATTLE3_PATH := "res://src/ui/battle_screen3.tscn"


func test_battle_screen_entry_names_replace_legacy_paths() -> void:
	assert_true(ResourceLoader.exists(BATTLE_BASE_PATH))
	assert_true(ResourceLoader.exists(BATTLE1_PATH))
	assert_true(ResourceLoader.exists(BATTLE2_PATH))
	assert_true(ResourceLoader.exists(BATTLE3_PATH))
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


func test_battle_screen3_statically_uses_scene3() -> void:
	BattleSetup.reset()
	var battle_source := FileAccess.get_file_as_string(BATTLE3_PATH)
	assert_false(battle_source.contains('parent="StageSlot/Stage"'),
			"BattleScreen3 must not serialize stale overrides for Scene3 child nodes")
	assert_false(battle_source.contains('[editable path="StageSlot/Stage"]'),
			"Scene3 composition must be edited only in scene3.tscn")
	var screen := (load(BATTLE3_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"),
			"BattleScreen3 must bind the shared BattleScreen stage interface")
	assert_eq(screen.stage.scene_file_path, SCENE3_PATH,
			"The independent Scene3 battle variant must load the Scene3 stage")
	assert_true(screen.stage.pointer_parallax,
			"Scene3 keeps the mature BattleScreen pointer-parallax contract")
	assert_false(screen.stage.demo_click_shake,
			"Scene3 must not keep standalone preview click shake when embedded")
	assert_not_null(screen.get_node_or_null("WorldGroup"),
			"Scene3 keeps the mature battle world grouping for characters and shadows")
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	BattleSetup.reset()


func test_scene3_uses_formal_alpha_assets_and_chain_platform() -> void:
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var scene_source := FileAccess.get_file_as_string(SCENE3_PATH)
	var contract := {
		"DawnSky": "res://assets/scenes/scene3/scene3_sky1.png",
		"DawnSkyOverlay": "res://assets/scenes/scene3/scene3_sky2.png",
		"DistantMountainRangeMid": "res://assets/scenes/scene2/scene2_far_mountain.png",
		"DistantMountainRangeNear": "res://assets/scenes/scene2/scene2_far_mountain.png",
		"LeftFarMountain": "res://assets/scenes/scene3/scene3_left_far_mountain.png",
		"RightFarMountain": "res://assets/scenes/scene3/scene3_right_far_mountain.png",
		"DawnSun": "res://assets/scenes/scene3/scene3_sun.png",
		"LeftCliff": "res://assets/scenes/scene3/scene3_left_mountain.png",
		"RightCliff": "res://assets/scenes/scene3/scene3_right_mountain.png",
		"MainChain": "res://assets/scenes/scene3/scene3_chain.png",
	}

	assert_false(scene_source.contains("res://assets/import/"),
			"Scene3 must not directly reference the temporary import folder")
	assert_false(scene_source.contains("res://assets/scenes/scene2/scene2_mid_mountain.png"),
			"Scene3 must not reuse Scene2's deep-purple middle mountain")
	assert_false(
			FileAccess.get_file_as_string(SCENE1_PATH).contains("scene3_mid_sword_grave"),
			"The Scene3 sword grave must not leak into Scene1")
	assert_false(
			FileAccess.get_file_as_string(SCENE2_PATH).contains("scene3_mid_sword_grave"),
			"The Scene3 sword grave must not leak into Scene2")
	for node_name: String in contract:
		assert_true(stage.has_node(node_name),
				"Scene3 must contain %s as an editable authored layer" % node_name)
		if not stage.has_node(node_name):
			continue
		var layer := stage.get_node(node_name) as TextureRect
		assert_eq(layer.texture.resource_path, contract[node_name])
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
				"%s must retain hard pixel edges" % node_name)
		assert_true(layer.has_meta("parallax_factor"))
		if node_name not in ["DawnSky", "DawnSkyOverlay"]:
			assert_not_null(layer.material,
					"%s must receive the dawn sword-grave material grade" % node_name)
	var sun := stage.get_node("DawnSun") as TextureRect
	var sun_material := sun.material as ShaderMaterial
	assert_eq(
			sun_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene3_sun_grade.gdshader")
	var sun_mid: Color = sun_material.get_shader_parameter("mid_color")
	var sun_highlight: Color = sun_material.get_shader_parameter("highlight_color")
	assert_gt(sun_mid.r - sun_mid.b, 0.3,
			"The sun midtones must match the warm peach-gold lower sky")
	assert_gt(sun_mid.g - sun_mid.b, 0.1,
			"The sun must not collapse back into gray-yellow")
	assert_gt(sun_highlight.r, sun_highlight.b,
			"The sun highlight must remain warm instead of gray-white")
	assert_between(
			float(sun_material.get_shader_parameter("alpha_scale")),
			0.65,
			0.96,
			"The sun should sit softly inside the cloud sea")
	assert_gte(
			float(sun_material.get_shader_parameter("outline_soften_strength")),
			0.2,
			"The sun's complete dark ring must dissolve into the horizon atmosphere")
	assert_lte(
			float(sun_material.get_shader_parameter("fade_end")),
			0.58,
			"The cloud sea must conceal more than half of the oversized sun disc")
	assert_true(sun_material.shader.code.contains("exposed_edge"),
			"The sun shader must soften its actual alpha edge rather than flattening all detail")
	assert_almost_eq(sun.size.x, sun.size.y, 0.1,
			"The new round sun must not be stretched into the old half-sun rectangle")
	var cloud_back := stage.get_node("CloudSeaBack") as ColorRect
	assert_lt(sun.position.y, cloud_back.position.y)
	assert_gt(sun.position.y + sun.size.y, cloud_back.position.y,
			"The cloud sea must cross the round sun near its middle")
	var sun_halo := stage.get_node("SunHalo") as ColorRect
	var halo_material := sun_halo.material as ShaderMaterial
	assert_not_null(halo_material,
			"Scene3 needs the same separate subject-and-halo treatment as Scene1")
	if halo_material != null and halo_material.shader != null:
		assert_eq(
				halo_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene3_sun_halo.gdshader")
		assert_true(halo_material.shader.code.contains("blend_add"),
				"The sun halo must add light without replacing the sky")
		var halo_color: Color = halo_material.get_shader_parameter("glow_color")
		assert_gt(halo_color.r - halo_color.b, 0.25,
				"The halo must share the lower sky's peach-gold family")
		assert_lte(float(halo_material.get_shader_parameter("core_size")), 0.18,
				"The halo core must not reinforce the egg-yolk silhouette")
		assert_gte(float(halo_material.get_shader_parameter("glow_size")), 0.58,
				"The low-intensity atmospheric glow needs a broad falloff")
		assert_lte(float(halo_material.get_shader_parameter("core_intensity")), 0.14)
		assert_lte(float(halo_material.get_shader_parameter("glow_intensity")), 0.1)
	assert_true(stage.has_node("SunAtmosphereVeil"),
			"Scene3 needs a foreground dawn veil crossing the sun disc")
	if stage.has_node("SunAtmosphereVeil"):
		var sun_veil := stage.get_node("SunAtmosphereVeil") as ColorRect
		var veil_material := sun_veil.material as ShaderMaterial
		assert_not_null(veil_material)
		if veil_material != null and veil_material.shader != null:
			assert_eq(
					veil_material.shader.resource_path,
					"res://assets/shaders/canvas_env_scene3_sun_veil.gdshader")
			assert_true(veil_material.shader.code.contains("veil_band"))
			assert_between(
					float(veil_material.get_shader_parameter("veil_strength")),
					0.14,
					0.3,
					"The veil must cross the disc visibly without becoming opaque fog")
	assert_true(stage.has_node("MidSwordGrave"),
			"Scene3 needs a restrained midground sword-grave silhouette layer")
	if stage.has_node("MidSwordGrave"):
		var sword_grave := stage.get_node("MidSwordGrave") as Control
		assert_eq(sword_grave.position, Vector2.ZERO)
		assert_eq(sword_grave.size, Vector2(1920, 1080))
		assert_gt(
				float(sword_grave.get_meta("parallax_factor")),
				float(stage.get_node("RightFarMountain").get_meta("parallax_factor")))
		assert_lt(
				float(sword_grave.get_meta("parallax_factor")),
				float(stage.get_node("CloudSeaBack").get_meta("parallax_factor")))
		assert_gt(sword_grave.get_index(), stage.get_node("RightFarMountain").get_index())
		assert_lt(sword_grave.get_index(), stage.get_node("SunAtmosphereVeil").get_index())
		for cluster_name: String in ["LeftCluster", "RightCluster"]:
			var cluster := sword_grave.get_node(cluster_name) as TextureRect
			var atlas := cluster.texture as AtlasTexture
			var sword_grave_material := cluster.material as ShaderMaterial
			assert_not_null(atlas)
			if atlas != null and atlas.atlas != null:
				assert_eq(
						atlas.atlas.resource_path,
						"res://assets/scenes/scene3/scene3_mid_sword_grave.png")
			assert_not_null(sword_grave_material)
			if sword_grave_material != null and sword_grave_material.shader != null:
				assert_eq(
						sword_grave_material.shader.resource_path,
						"res://assets/shaders/canvas_env_scene3_sword_grave_grade.gdshader")
				assert_true(sword_grave_material.shader.code.contains("sun_rim"))
				assert_between(
						float(sword_grave_material.get_shader_parameter("alpha_scale")),
						0.45,
						0.8,
						"The sword grave must stay behind the playable chain")

	var chain := stage.get_node("MainChain") as TextureRect
	assert_almost_eq(
			float(chain.get_meta("parallax_factor")),
			float(stage.get("ground_parallax")),
			0.0001,
			"The battle chain must share the exact character-world parallax")
	assert_lt(chain.position.y, 720.0)
	assert_gt(chain.position.y + chain.size.y, 740.0,
			"The chain platform must sit under the battle stance and contact shadows")
	assert_true(stage.has_node("ChainFootOccluder"),
			"Scene3 needs a narrow foreground chain edge to bite over character shoes")
	if stage.has_node("ChainFootOccluder"):
		var chain_occluder := stage.get_node("ChainFootOccluder") as TextureRect
		var occluder_material := chain_occluder.material as ShaderMaterial
		assert_eq(chain_occluder.texture.resource_path, chain.texture.resource_path)
		assert_eq(chain_occluder.position, chain.position)
		assert_eq(chain_occluder.size, chain.size)
		assert_eq(
				float(chain_occluder.get_meta("parallax_factor")),
				float(chain.get_meta("parallax_factor")))
		assert_gt(chain_occluder.z_index, 0,
				"The chain foot edge must draw in front of the live characters")
		assert_not_null(occluder_material)
		if occluder_material != null and occluder_material.shader != null:
			assert_eq(
					occluder_material.shader.resource_path,
					"res://assets/shaders/canvas_env_scene3_chain_foot_occluder.gdshader")
			assert_true(occluder_material.shader.code.contains("upper_edge"))
			assert_true(occluder_material.shader.code.contains("p1_foot_zone"))
			assert_true(occluder_material.shader.code.contains("p2_foot_zone"))
	var decorative_chain_names: Array[String] = [
		"BackgroundChain",
		"BackgroundChain2",
		"BackgroundChain3",
	]
	var decorative_chains: Array[TextureRect] = []
	var decorative_materials: Array[ShaderMaterial] = []
	for chain_name: String in decorative_chain_names:
		assert_true(stage.has_node(chain_name))
		if not stage.has_node(chain_name):
			continue
		var decorative_chain := stage.get_node(chain_name) as TextureRect
		var decorative_material := decorative_chain.material as ShaderMaterial
		decorative_chains.append(decorative_chain)
		decorative_materials.append(decorative_material)
		assert_eq(decorative_chain.texture.resource_path, chain.texture.resource_path)
		assert_not_null(decorative_material,
				"%s needs its own atmospheric depth material" % chain_name)
		if decorative_material == null or decorative_material.shader == null:
			continue
		assert_ne(decorative_material, chain.material)
		assert_eq(
				decorative_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene3_chain_depth.gdshader")
		assert_true(decorative_material.shader.code.contains("atmosphere_strength"))
		assert_true(decorative_material.shader.code.contains("outline_lift"))
		var effective_alpha := float(
				decorative_material.get_shader_parameter("alpha_scale")
		) * decorative_chain.self_modulate.a
		assert_lte(
				effective_alpha,
				0.62,
				"%s combined alpha must remain decorative instead of competing with MainChain"
				% chain_name)
		assert_gte(
				float(decorative_material.get_shader_parameter("atmosphere_strength")),
				0.34,
				"%s needs visible cloud-depth integration" % chain_name)
	if decorative_chains.size() == 3:
		assert_gt(
				absf(decorative_chains[0].size.x - decorative_chains[1].size.x),
				64.0,
				"Far and middle chains need visibly different link scales")
		assert_gt(
				absf(decorative_chains[1].size.x - decorative_chains[2].size.x),
				64.0,
				"Middle and lower chains need visibly different spans")
		assert_lt(
				float(decorative_chains[0].get_meta("parallax_factor")),
				float(decorative_chains[1].get_meta("parallax_factor")))
		assert_lt(
				float(decorative_chains[1].get_meta("parallax_factor")),
				float(decorative_chains[2].get_meta("parallax_factor")))
		assert_lt(
				float(decorative_chains[2].get_meta("parallax_factor")),
				float(chain.get_meta("parallax_factor")))
	if decorative_materials.size() == 3:
		assert_ne(decorative_materials[0], decorative_materials[1])
		assert_ne(decorative_materials[1], decorative_materials[2])
	var cloud_materials: Dictionary = {}
	var cloud_seeds: Dictionary = {}
	for cloud_name: String in ["CloudSeaBack", "CloudSeaMid", "CloudSeaFront"]:
		assert_true(stage.has_node(cloud_name),
				"Scene3 sword-grave valley needs layered lower cloud sea")
		if not stage.has_node(cloud_name):
			continue
		var cloud := stage.get_node(cloud_name) as ColorRect
		var cloud_material := cloud.material as ShaderMaterial
		assert_not_null(cloud_material,
				"%s must use the Scene3 procedural cloud-sea shader" % cloud_name)
		if cloud_material != null and cloud_material.shader != null:
			assert_eq(
					cloud_material.shader.resource_path,
					"res://assets/shaders/canvas_env_scene3_cloud_sea.gdshader")
			assert_eq(float(cloud_material.get_shader_parameter("mode_isolated")), 0.0)
			assert_eq(float(cloud_material.get_shader_parameter("row_count")), 4.0)
			assert_eq(float(cloud_material.get_shader_parameter("inner_contrast")), 0.0)
			assert_gt(float(cloud_material.get_shader_parameter("bank_join_height")), 0.0)
			assert_gt(float(cloud_material.get_shader_parameter("scene3_roll_amount")), 0.0)
			assert_gt(float(cloud_material.get_shader_parameter("scene3_billow_amount")), 0.0)
			var local_sun_rim := float(
					cloud_material.get_shader_parameter("local_sun_rim_strength"))
			if cloud_name == "CloudSeaBack":
				assert_gte(local_sun_rim, 0.55,
						"The rear cloud bank needs a visible local gold lining near the sun")
				var back_rim_radius: Vector2 = cloud_material.get_shader_parameter(
						"local_sun_rim_radius")
				assert_lte(back_rim_radius.x, 0.28,
						"The gold lining must stay near the sun-cloud contact")
			if cloud_name == "CloudSeaMid":
				assert_gt(
						float(cloud_material.get_shader_parameter("scene3_roll_amount")),
						0.08,
						"Scene3 middle cloud roll must read clearly during play")
				assert_gte(local_sun_rim, 0.3,
						"The middle cloud bank must catch some moving sunlight")
				var mid_rim_radius: Vector2 = cloud_material.get_shader_parameter(
						"local_sun_rim_radius")
				assert_lte(mid_rim_radius.x, 0.23,
						"The middle cloud gold edge must not span the whole valley")
			elif cloud_name == "CloudSeaFront":
				assert_gt(
						float(cloud_material.get_shader_parameter("scene3_billow_amount")),
						0.4,
						"Scene3 foreground cloud billow must not be imperceptible")
				assert_eq(local_sun_rim, 0.0,
						"The foreground cloud bank must not receive a global gold outline")
			cloud_materials[cloud_name] = cloud_material
			cloud_seeds[float(cloud_material.get_shader_parameter("seed"))] = true
		assert_true(cloud.has_meta("parallax_factor"))
	assert_eq(cloud_seeds.size(), 3,
			"Scene3 cloud layers need distinct seeds so their silhouettes do not move in lockstep")
	if cloud_materials.size() == 3:
		assert_lt(float(cloud_materials["CloudSeaBack"].get_shader_parameter("flow_speed")), 0.0)
		assert_gt(float(cloud_materials["CloudSeaMid"].get_shader_parameter("flow_speed")), 0.0)
		assert_lt(float(cloud_materials["CloudSeaFront"].get_shader_parameter("flow_speed")), 0.0)
	assert_lt(stage.get_node("DawnSkyOverlay").get_index(),
			stage.get_node("DistantMountainRangeMid").get_index())
	assert_lt(stage.get_node("DistantMountainRangeMid").get_index(),
			stage.get_node("DistantMountainRangeNear").get_index())
	assert_lt(stage.get_node("DistantMountainRangeNear").get_index(),
			stage.get_node("BackFog").get_index())
	assert_lt(stage.get_node("BackFog").get_index(),
			stage.get_node("LeftFarMountain").get_index())
	assert_lt(stage.get_node("BackFog").get_index(),
			stage.get_node("RightFarMountain").get_index())
	assert_lt(stage.get_node("BackgroundChain").get_index(),
			stage.get_node("LeftFarMountain").get_index())
	assert_lt(stage.get_node("BackgroundChain2").get_index(),
			stage.get_node("LeftFarMountain").get_index())
	assert_lt(stage.get_node("RightCliff").get_index(),
			stage.get_node("BackgroundChain3").get_index())
	assert_lt(stage.get_node("BackgroundChain3").get_index(),
			stage.get_node("CloudSeaFront").get_index())
	assert_lt(stage.get_node("LeftFarMountain").get_index(),
			stage.get_node("CloudSeaBack").get_index())
	assert_lt(stage.get_node("RightFarMountain").get_index(),
			stage.get_node("CloudSeaBack").get_index())
	assert_lt(stage.get_node("SunHalo").get_index(),
			stage.get_node("SunRayField").get_index())
	assert_lt(stage.get_node("SunRayField").get_index(),
			stage.get_node("DawnSun").get_index())
	assert_lt(stage.get_node("DawnSun").get_index(),
			stage.get_node("RightFarMountain").get_index())
	assert_lt(stage.get_node("RightFarMountain").get_index(),
			stage.get_node("MidSwordGrave").get_index())
	assert_lt(stage.get_node("MidSwordGrave").get_index(),
			stage.get_node("SunAtmosphereVeil").get_index())
	assert_lt(stage.get_node("DawnSun").get_index(),
			stage.get_node("SunAtmosphereVeil").get_index())
	assert_lt(stage.get_node("SunAtmosphereVeil").get_index(),
			stage.get_node("CloudSeaBack").get_index())
	assert_lt(stage.get_node("SunRayField").get_index(),
			stage.get_node("CloudSeaBack").get_index())
	assert_lt(
			float(stage.get_node("DistantMountainRangeMid").get_meta("parallax_factor")),
			float(stage.get_node("DistantMountainRangeNear").get_meta("parallax_factor")))
	assert_lt(
			float(stage.get_node("DistantMountainRangeNear").get_meta("parallax_factor")),
			float(stage.get_node("LeftFarMountain").get_meta("parallax_factor")))
	assert_lt(
			float(stage.get_node("RightFarMountain").get_meta("parallax_factor")),
			float(stage.get_node("CloudSeaBack").get_meta("parallax_factor")))
	for far_name: String in [
		"DistantMountainRangeMid",
		"DistantMountainRangeNear",
		"LeftFarMountain",
		"RightFarMountain",
	]:
		var far_material := stage.get_node(far_name).material as ShaderMaterial
		assert_not_null(far_material)
		if far_material == null:
			continue
		assert_lt(float(far_material.get_shader_parameter("saturation")), 0.4,
				"%s must read as atmospheric gray rather than cyan" % far_name)
		var atmosphere: Color = far_material.get_shader_parameter("atmosphere_color")
		assert_lt(atmosphere.g - atmosphere.r, 0.08,
				"%s atmosphere must not reinforce a green-cyan cast" % far_name)
		assert_gt(float(far_material.get_shader_parameter("horizon_warm_strength")), 0.1,
				"%s needs warm lower-horizon response for the planned rising sun"
				% far_name)
	for distant_name: String in [
		"DistantMountainRangeMid",
		"DistantMountainRangeNear",
	]:
		var distant := stage.get_node(distant_name) as TextureRect
		var distant_material := distant.material as ShaderMaterial
		assert_gte(distant.self_modulate.a, 0.68,
				"%s must not disappear into the sky layer" % distant_name)
		assert_gte(
				float(distant_material.get_shader_parameter("contrast")),
				0.84,
				"%s needs a readable ridge silhouette" % distant_name)
		assert_lte(
				float(distant_material.get_shader_parameter("atmosphere_strength")),
				0.42,
				"%s must keep atmospheric depth without becoming sky-colored"
				% distant_name)
	var distant_mid := stage.get_node("DistantMountainRangeMid") as TextureRect
	var distant_near := stage.get_node("DistantMountainRangeNear") as TextureRect
	assert_lt(distant_mid.self_modulate.a, distant_near.self_modulate.a)
	assert_lt(
			float((distant_mid.material as ShaderMaterial).get_shader_parameter("contrast")),
			float((distant_near.material as ShaderMaterial).get_shader_parameter("contrast")))
	var right_far_material := stage.get_node("RightFarMountain").material as ShaderMaterial
	assert_eq(
			right_far_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene3_far_mountain_grade.gdshader")
	var right_far_source := right_far_material.shader.code
	assert_true(right_far_source.contains("shadow_palette"))
	assert_true(right_far_source.contains("midtone_palette"))
	assert_true(right_far_source.contains("highlight_palette"))
	assert_false(right_far_source.contains("mix(vec3(luma), tex.rgb"),
			"RightFarMountain must rebuild its palette instead of retaining source blue")
	var ray_material := stage.get_node("SunRayField").material as ShaderMaterial
	assert_not_null(ray_material)
	if ray_material != null and ray_material.shader != null:
		assert_eq(
				ray_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene3_sun_rays.gdshader")
		var ray_source := ray_material.shader.code
		assert_true(ray_source.contains("cloud_gap_opening"),
				"Cloud motion must reveal local shaft sources")
		assert_true(ray_source.contains("rising_shaft"),
				"Scene3 light must rise through distributed cloud openings")
		assert_true(ray_source.contains("hidden_sun_center"),
				"All shafts need one hidden sun direction source")
		assert_true(ray_source.contains("semicircle_direction"),
				"Ray directions must spread across the hidden sun's upper semicircle")
		assert_gte(ray_source.count("rising_shaft("), 7,
				"The shader needs six candidate shafts plus its helper")
		assert_false(ray_source.contains("halo"),
				"The removed sun must not leave a radial halo")
		assert_false(ray_source.contains("ray_fan"),
				"Independent cloud openings must not become one solid fan")
		var hidden_sun_center: Vector2 = ray_material.get_shader_parameter(
				"hidden_sun_center")
		assert_between(hidden_sun_center.x, 0.4, 0.6,
				"The hidden sun direction source must stay near the valley center")
		assert_gt(hidden_sun_center.y, 0.95,
				"The hidden sun direction source must stay below the cloud field")
		assert_between(
				float(ray_material.get_shader_parameter("shaft_width_scale")),
				2.0,
				3.5,
				"Cloud rays must be substantially broader than the old columns")
		assert_gte(float(ray_material.get_shader_parameter("outer_feather_px")), 10.0,
				"Cloud rays need a wide outer bloom for soft sunlight edges")
		assert_lte(float(ray_material.get_shader_parameter("source_drift")), 0.008,
				"Cloud openings may breathe but must not sweep across the valley")
		var mid_material: ShaderMaterial = cloud_materials.get("CloudSeaMid")
		if mid_material != null:
			assert_almost_eq(
					float(ray_material.get_shader_parameter("cloud_roll_speed")),
					float(mid_material.get_shader_parameter("scene3_roll_speed")),
					0.0001)
			assert_almost_eq(
					float(ray_material.get_shader_parameter("cloud_billow_speed")),
					float(mid_material.get_shader_parameter("scene3_billow_speed")),
					0.0001)
			assert_almost_eq(
					float(ray_material.get_shader_parameter("cloud_roll_phase")),
					float(mid_material.get_shader_parameter("scene3_roll_phase")),
					0.0001)
			assert_almost_eq(
					float(ray_material.get_shader_parameter("cloud_billow_phase")),
					float(mid_material.get_shader_parameter("scene3_billow_phase")),
					0.0001)
		assert_between(
				float(ray_material.get_shader_parameter("ray_intensity")),
				0.18,
				0.42,
				"Cloud shafts must stay visible without becoming searchlights")
	assert_lt(stage.get_node("CloudSeaBack").get_index(),
			stage.get_node("MainChain").get_index())
	assert_lt(stage.get_node("CloudSeaMid").get_index(),
			stage.get_node("MainChain").get_index())
	assert_lt(stage.get_node("RightCliff").get_index(),
			stage.get_node("CloudSeaFront").get_index())
	assert_lt(stage.get_node("CloudSeaFront").get_index(),
			stage.get_node("FrontFog").get_index())

	for cliff_name: String in ["LeftCliff", "RightCliff"]:
		var cliff := stage.get_node(cliff_name) as TextureRect
		var cliff_material := cliff.material as ShaderMaterial
		assert_not_null(cliff_material,
				"%s must retain its Scene3 color grade and local grass motion"
				% cliff_name)
		if cliff_material == null or cliff_material.shader == null:
			continue
		assert_eq(
				cliff_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene3_cliff_grass_sway.gdshader")
		assert_true(cliff_material.shader.code.contains("grass_mask"),
				"%s may animate only explicitly masked grass pixels" % cliff_name)
		assert_true(cliff_material.shader.code.contains("underpaint_texture"),
				"%s needs hinge underpaint so moving grass leaves no holes" % cliff_name)
		assert_true(cliff_material.shader.code.contains("inverse_rotate_pixel_uv"),
				"%s grass must pivot locally instead of warping the whole cliff"
				% cliff_name)
		var grass_mask := cliff_material.get_shader_parameter("grass_mask") as Texture2D
		var underpaint := cliff_material.get_shader_parameter(
				"underpaint_texture") as Texture2D
		assert_not_null(grass_mask)
		assert_not_null(underpaint)
		if grass_mask != null:
			assert_eq(
					grass_mask.resource_path,
					"res://assets/scenes/scene3/scene3_%s_cliff_grass_mask.png"
					% cliff_name.trim_suffix("Cliff").to_snake_case())
		if underpaint != null:
			assert_eq(
					underpaint.resource_path,
					"res://assets/scenes/scene3/scene3_%s_cliff_grass_underpaint.png"
					% cliff_name.trim_suffix("Cliff").to_snake_case())
		assert_between(
				float(cliff_material.get_shader_parameter("red_angle_deg")),
				0.5,
				1.0,
				"%s grass motion must stay restrained" % cliff_name)
		assert_between(
				float(cliff_material.get_shader_parameter("green_angle_deg")),
				0.5,
				1.0,
				"%s secondary grass group must stay restrained" % cliff_name)
		assert_lte(float(cliff_material.get_shader_parameter("motion_fps")), 6.0,
				"%s grass motion must retain stepped pixel timing" % cliff_name)
		assert_gt(float(cliff_material.get_shader_parameter("exposure")), 1.15,
				"%s needs visible exposure lift instead of the previous near-black grade"
				% cliff_name)
		assert_gt(float(cliff_material.get_shader_parameter("midtone_lift")), 0.06,
				"%s needs a visible midtone lift" % cliff_name)
		assert_lt(float(cliff_material.get_shader_parameter("shadow_strength")), 0.25,
				"%s must not crush its lower half back into black" % cliff_name)
		assert_lt(float(cliff_material.get_shader_parameter("saturation")), 0.7,
				"%s must neutralize the source asset's green cast" % cliff_name)
		var cliff_tint: Color = cliff_material.get_shader_parameter("tint_color")
		assert_gt(cliff_tint.r, cliff_tint.g,
				"%s needs a warm-neutral stone tint rather than green" % cliff_name)
	for path: String in [
		"res://assets/scenes/scene3/scene3_sky2.png",
		"res://assets/scenes/scene3/scene3_chain.png",
		"res://assets/scenes/scene3/scene3_left_mountain.png",
		"res://assets/scenes/scene3/scene3_right_mountain.png",
		"res://assets/scenes/scene3/scene3_left_far_mountain.png",
		"res://assets/scenes/scene3/scene3_right_far_mountain.png",
		"res://assets/scenes/scene3/scene3_sun.png",
		"res://assets/scenes/scene3/scene3_mid_sword_grave.png",
	]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image)
		if image == null:
			continue
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE,
				"Scene3 formal assets must carry true alpha after keying their source background")
	var sword_grave_image := Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/scenes/scene3/scene3_mid_sword_grave.png"))
	assert_not_null(sword_grave_image)
	if sword_grave_image != null:
		for corner: Vector2i in [
			Vector2i(0, 0),
			Vector2i(sword_grave_image.get_width() - 1, 0),
			Vector2i(0, sword_grave_image.get_height() - 1),
			Vector2i(
					sword_grave_image.get_width() - 1,
					sword_grave_image.get_height() - 1),
		]:
			assert_lte(sword_grave_image.get_pixelv(corner).a, 0.02,
					"The generated sword-grave layer needs transparent corners")
		var sampled_pixels := 0
		var visible_pixels := 0
		var green_spill_pixels := 0
		for y in range(0, sword_grave_image.get_height(), 8):
			for x in range(0, sword_grave_image.get_width(), 8):
				var sword_pixel := sword_grave_image.get_pixel(x, y)
				sampled_pixels += 1
				if sword_pixel.a > 0.2:
					visible_pixels += 1
					if (
							sword_pixel.g > sword_pixel.r + 0.35
							and sword_pixel.g > sword_pixel.b + 0.35
					):
						green_spill_pixels += 1
		var visible_ratio := float(visible_pixels) / float(maxi(sampled_pixels, 1))
		assert_between(visible_ratio, 0.002, 0.14,
				"The sword grave should be sparse silhouettes, not a full painted backdrop")
		assert_eq(green_spill_pixels, 0,
				"The chroma-key source must not leave green fringe in the scene asset")

	var sky1 := Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/scenes/scene3/scene3_sky1.png"))
	assert_not_null(sky1)
	if sky1 != null:
		var sampled := 0
		var purple_pixels := 0
		for y in range(0, int(sky1.get_height() * 0.72), 8):
			for x in range(0, sky1.get_width(), 8):
				var color := sky1.get_pixel(x, y)
				sampled += 1
				if color.a > 0.0 and color.r > color.g + 0.04 and color.b > color.g + 0.04:
					purple_pixels += 1
		assert_eq(purple_pixels, 0,
				"Scene3 sky1 upper sky must be recolored away from the purple source palette")


func test_scene3_chain_grounding_uses_link_occlusion_and_segmented_shadows() -> void:
	var screen := (load(BATTLE3_PATH) as PackedScene).instantiate()
	var p1 := screen.get_node("P1CharDisplay") as Control
	var p2 := screen.get_node("P2CharDisplay") as Control
	assert_eq(p1.position, Vector2(92, 258),
			"Scene3 preserves the authored P1 x and ground-authored baseline")
	assert_eq(p2.position, Vector2(1056, 258),
			"Scene3 restores both fighters before lowering the playable chain")

	for shadow_name: String in ["P1Shadow", "P2Shadow"]:
		var shadow := screen.get_node(shadow_name) as TextureRect
		var shadow_material := shadow.material as ShaderMaterial
		assert_not_null(shadow_material)
		if shadow_material == null or shadow_material.shader == null:
			continue
		assert_eq(
				shadow_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene3_chain_contact_shadow.gdshader")
		var shadow_source := shadow_material.shader.code
		assert_true(shadow_source.contains("left_foot"))
		assert_true(shadow_source.contains("right_foot"))
		assert_true(shadow_source.contains("link_break"))
		assert_lte(shadow.size.y, 32.0,
				"Chain contact shadows must stay on the narrow link surface")
		assert_lte(
				float(shadow_material.get_shader_parameter("shadow_strength")),
				0.68,
				"Chain shadows must not read as opaque ground decals")
		assert_lt(shadow.get_index(), p1.get_index(),
				"Chain contact shadows must remain behind both live characters")
	screen.free()


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
	if stage.has_node("MountainLeft") and stage.has_node("MountainRight"):
		assert_lt(stage.get_node("Waterfall").get_index(),
				stage.get_node("MountainLeft").get_index(),
				"The left framing mountain must naturally occlude the waterfall edge")
		assert_lt(stage.get_node("Waterfall").get_index(),
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
	assert_not_null((stage.get_node("MidMountain") as TextureRect).material,
			"The mid mountain must receive a non-blurring atmospheric grade")
	var far_mountain_path := "res://assets/scenes/scene2/scene2_far_mountain.png"
	var far_layers: Array[TextureRect] = []
	for child: Node in stage.get_children():
		if child is not TextureRect:
			continue
		var texture_rect := child as TextureRect
		if texture_rect.texture != null \
				and texture_rect.texture.resource_path == far_mountain_path:
			far_layers.append(texture_rect)
	assert_gt(far_layers.size(), 0,
			"Scene2 must retain at least one editable far-mountain layer")
	var far_mountain_materials: Array[Material] = []
	for far_layer: TextureRect in far_layers:
		assert_not_null(far_layer.material,
				"%s must expose its own editable depth material" % far_layer.name)
		if far_layer.material == null:
			continue
		for prior_material: Material in far_mountain_materials:
			assert_ne(far_layer.material, prior_material,
					"Far-mountain copies must not share one material instance")
		far_mountain_materials.append(far_layer.material)
	if stage.has_node("MountainLeft") and stage.has_node("MountainRight"):
		assert_true((stage.get_node("MountainLeft") as TextureRect).visible)
		assert_true((stage.get_node("MountainRight") as TextureRect).visible)
	var tree_material := (stage.get_node("BlossomTree") as TextureRect).material \
			as ShaderMaterial
	assert_not_null(tree_material,
			"The replacement tree needs its motion-only sway material")
	if tree_material != null and tree_material.shader != null:
		assert_ne(
				tree_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene2_depth_grade.gdshader",
				"The tree must display its authored palette without the rejected quiet-zone grade")
	var bridge := stage.get_node("StoneBridge") as TextureRect
	var bridge_material := bridge.material as ShaderMaterial
	assert_not_null(bridge_material,
			"The playable bridge needs a local receiving-light material")
	if bridge_material != null:
		assert_eq(bridge_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene2_bridge_light.gdshader")
	assert_eq(bridge.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"Receiving light must preserve crisp nearest-neighbour bridge pixels")


func test_scene2_p1_depth_grades_follow_relative_atmospheric_hierarchy() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var graded_layers: Array[TextureRect] = [
		stage.get_node("CloudFar") as TextureRect,
		stage.get_node("CloudMid") as TextureRect,
		stage.get_node("MidMountain") as TextureRect,
	]
	var far_mountain_path := "res://assets/scenes/scene2/scene2_far_mountain.png"
	var far_mountains: Array[TextureRect] = []
	for child: Node in stage.get_children():
		if child is not TextureRect:
			continue
		var texture_rect := child as TextureRect
		if texture_rect.texture != null \
				and texture_rect.texture.resource_path == far_mountain_path:
			far_mountains.append(texture_rect)
			graded_layers.append(texture_rect)
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

	var mid_mountain_material := (
			(stage.get_node("MidMountain") as TextureRect).material as ShaderMaterial)
	assert_gt(far_mountains.size(), 0)
	for far_mountain: TextureRect in far_mountains:
		var far_material := far_mountain.material as ShaderMaterial
		assert_lte(
				float(far_material.get_shader_parameter("saturation")),
				float(mid_mountain_material.get_shader_parameter("saturation")),
				"Far geometry must be less saturated than mid geometry")
		assert_lte(
				float(far_material.get_shader_parameter("contrast")),
				float(mid_mountain_material.get_shader_parameter("contrast")),
				"Far geometry must be lower contrast than mid geometry")
		assert_gte(
				float(far_material.get_shader_parameter("atmosphere_strength")),
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
	assert_true(stage.has_node("Waterfall"),
			"Scene2 must expose one editable full-height waterfall node")
	assert_false(stage.has_node("WaterfallImpactLeft"),
			"The retired waterfall-impact overlay must stay removed")
	if not stage.has_node("Waterfall"):
		return

	var waterfall := stage.get_node("Waterfall") as ColorRect
	var material := waterfall.material as ShaderMaterial
	var bridge := stage.get_node("StoneBridge") as TextureRect
	var river := stage.get_node("River") as ColorRect
	var scene_source := FileAccess.get_file_as_string(SCENE2_PATH)
	var shader_source := material.shader.code

	assert_false(stage.has_node("WaterfallUpper"))
	assert_false(stage.has_node("WaterfallMiddle"))
	assert_false(stage.has_node("WaterfallLower"))
	assert_false(scene_source.contains("WaterfallUpperMat"))
	assert_false(scene_source.contains("WaterfallMiddleMat"))
	assert_false(scene_source.contains("WaterfallLowerMat"))
	assert_true(waterfall.visible)
	assert_gt(waterfall.size.y, 720.0,
			"The authored waterfall must remain a tall background element")
	assert_lt(waterfall.get_index(), bridge.get_index())
	assert_lt(waterfall.get_index(), river.get_index())
	assert_not_null(material)
	assert_eq(material.shader.resource_path,
			"res://assets/shaders/canvas_env_pixel_waterfall.gdshader")
	assert_eq(int(material.get_shader_parameter("render_part")), 0)
	assert_eq(material.get_shader_parameter("size_px"), waterfall.size)
	assert_lt(
			float(material.get_shader_parameter("top_y")),
			float(material.get_shader_parameter("bottom_y")),
			"The editable waterfall body must retain a valid vertical span")
	assert_eq(float(material.get_shader_parameter("section_width_wobble_px")), 0.0,
			"The approved vertical profile must not add random section-width drift")
	assert_eq(float(material.get_shader_parameter("section_center_wobble_px")), 0.0,
			"The approved vertical profile must not add random center drift")
	assert_gt(float(material.get_shader_parameter("px_size")), 0.0)
	assert_lte(float(material.get_shader_parameter("px_size")), 8.0,
			"The waterfall pixel grid must remain within its shader's authored range")
	assert_gte(float(material.get_shader_parameter("anim_fps")), 8.0,
			"The waterfall must expose all eight ref26-inspired water states clearly")
	assert_lte(float(material.get_shader_parameter("anim_fps")), 10.0,
			"The distant waterfall cadence must stay calmer than foreground motion")
	assert_lte(float(material.get_shader_parameter("fall_speed_px")), 105.0)
	assert_lte(float(material.get_shader_parameter("mouth_highlight_density")), 0.40)
	assert_lte(float(material.get_shader_parameter("cross_join_density")), 0.08)
	assert_gte(float(material.get_shader_parameter("lane_width_px")), 6.0)
	assert_lte(float(material.get_shader_parameter("lane_width_px")), 10.0,
			"Ref28-style fine highlights must not return to broad rectangular lanes")
	assert_gte(float(material.get_shader_parameter("streak_period_px")), 80.0)
	assert_lte(float(material.get_shader_parameter("streak_period_px")), 110.0)
	assert_lte(float(material.get_shader_parameter("flow_highlight_density")), 0.12)
	assert_lte(float(material.get_shader_parameter("flow_gap_strength")), 0.12)
	assert_gte(float(material.get_shader_parameter("body_alpha")), 0.98,
			"The waterfall body must remain visually solid behind atmospheric layers")
	assert_lte(float(material.get_shader_parameter("edge_drop_density")), 0.04)
	assert_eq(int(material.get_shader_parameter("vertical_profile_enabled")), 1,
			"Scene2 must use the restrained long-bank pixel-waterfall silhouette")
	for parameter_name: String in [
		"left_edge_upper_px",
		"left_edge_middle_px",
		"left_edge_lower_px",
		"right_edge_upper_px",
		"right_edge_middle_px",
		"right_edge_lower_px",
		"vertical_step_one_y",
		"vertical_step_two_y",
	]:
		assert_not_null(material.get_shader_parameter(parameter_name),
				"The vertical waterfall profile must expose %s for art direction"
				% parameter_name)
	var top_waterfall_width := (
			float(material.get_shader_parameter("right_edge_upper_px"))
			- float(material.get_shader_parameter("left_edge_upper_px")))
	var bottom_waterfall_width := (
			float(material.get_shader_parameter("right_edge_lower_px"))
			- float(material.get_shader_parameter("left_edge_lower_px")))
	var middle_waterfall_width := (
			float(material.get_shader_parameter("right_edge_middle_px"))
			- float(material.get_shader_parameter("left_edge_middle_px")))
	for waterfall_width: float in [
		top_waterfall_width,
		middle_waterfall_width,
		bottom_waterfall_width,
	]:
		assert_gt(waterfall_width, 0.0,
				"Every editable waterfall tier must retain a valid silhouette")
	assert_lt(
			float(material.get_shader_parameter("vertical_step_one_y")),
			float(material.get_shader_parameter("vertical_step_two_y")),
			"The waterfall's two deliberate ledges must remain ordered")
	for marker: String in [
		"mouth_vertical",
		"rare_cross_join",
		"top_lip_segments",
		"ref26_frame_blocks",
		"vertical_profile_steps",
		"ref28_body_bands",
		"ref26_vertical_flow",
		"ref28_source_lip",
		"ref28_mid_lip",
		"ref28_lower_lip",
		"body_shadow_plane",
		"bank_contact_shadow",
		"bank_contact_notch",
		"waterfall_cloud_cut",
	]:
		assert_true(shader_source.contains(marker),
				"The waterfall shader must implement %s" % marker)
	assert_false(shader_source.contains("foam_cycle"),
			"The old synchronized foam cycle must be removed")
	assert_true(shader_source.contains("major_streak_density"),
			"The waterfall must expose one density control for its broad moving water bands")
	if shader_source.contains("major_streak_density"):
		assert_lte(float(material.get_shader_parameter("major_streak_density")), 0.55)
	var flow_cycle_frames: Variant = material.get_shader_parameter("flow_cycle_frames")
	assert_not_null(flow_cycle_frames,
			"The waterfall body must expose its stepped animation cycle")
	if flow_cycle_frames != null:
		assert_gte(float(flow_cycle_frames), 8.0,
				"The waterfall body must have enough stepped states for a readable pixel loop")
	for marker: String in ["flow_cycle_frame", "ribbon_a", "mouth_cap"]:
		assert_true(shader_source.contains(marker),
				"The waterfall shader must preserve the reference-style %s motion" % marker)


func test_scene2_waterfall_ridge_group_uses_one_subtle_shared_grade() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var waterfall := stage.get_node("Waterfall")
	var upper_cloud := stage.get_node("WaterfallCloudUpper")
	var ridges: Array[TextureRect] = []
	for child in stage.get_children():
		if child is TextureRect and String(child.name).begins_with("WaterfallRidgeLeft"):
			ridges.append(child as TextureRect)
	assert_gt(ridges.size(), 0,
			"Scene2 needs at least one authored mountain behind its waterfall")
	if ridges.is_empty():
		return

	var ridge := ridges[0]
	var ridge_material := ridge.material as ShaderMaterial
	assert_not_null(ridge_material,
			"The waterfall mountain group needs one shared, non-destructive grade")
	if ridge_material != null:
		assert_eq(ridge_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene2_waterfall_mountain_grade.gdshader")
		assert_lte(float(ridge_material.get_shader_parameter("atmosphere_strength")), 0.08,
				"The group grade must remain subtle instead of remapping the authored ridge")
	for ridge_copy in ridges:
		assert_eq(ridge_copy.texture.resource_path,
				"res://assets/scenes/scene2/scene2_waterfall_ridge.png")
		assert_eq(ridge_copy.material, ridge_material,
				"All authored ridge copies must read as one graded mountain mass")
		assert_eq(int(ridge_copy.texture_filter), CanvasItem.TEXTURE_FILTER_NEAREST,
				"The shared grade must preserve crisp pixel-art sampling")
		assert_lt(ridge_copy.get_index(), waterfall.get_index(),
				"Every ridge copy must remain behind the waterfall")
	var ridge_image := Image.load_from_file(ProjectSettings.globalize_path(
			ridge.texture.resource_path))
	assert_not_null(ridge_image)
	if ridge_image != null:
		assert_ne(ridge_image.detect_alpha(), Image.ALPHA_NONE,
				"The authored backdrop ridge must retain a true transparent background")
	assert_true(stage.has_node("WaterfallRidgeContact"),
			"The ridge group must expose authored foreground contact pixels")
	if stage.has_node("WaterfallRidgeContact"):
		var contact := stage.get_node("WaterfallRidgeContact") as TextureRect
		assert_eq(contact.texture.resource_path,
				"res://assets/scenes/scene2/scene2_waterfall_ridge_contact.png")
		assert_eq(contact.material, ridge_material,
				"The foreground contact slice must share the mountain group's subtle grade")
		assert_eq(int(contact.texture_filter), CanvasItem.TEXTURE_FILTER_NEAREST,
				"The contact slice must preserve crisp pixel-art sampling")
		var contact_image := Image.load_from_file(ProjectSettings.globalize_path(
				contact.texture.resource_path))
		assert_not_null(contact_image)
		if contact_image != null and ridge_image != null:
			assert_eq(contact_image.get_size(), ridge_image.get_size())
			assert_ne(contact_image.detect_alpha(), Image.ALPHA_NONE,
					"Ridge contact must remain a sparse true-alpha pixel slice")
		assert_lt(waterfall.get_index(), contact.get_index(),
				"Authored ridge contact pixels must interlock in front of the water")
		assert_lt(contact.get_index(), upper_cloud.get_index(),
				"Waterfall cloud veil must remain above the ridge contact slice")
	assert_lt(waterfall.get_index(), upper_cloud.get_index(),
			"The waterfall cloud veil must stay in front of the water")
	assert_false(stage.has_node("WaterfallRidgeRight"),
			"Scene2 uses the authored left-ridge family instead of the removed right asset")


func test_scene2_waterfall_is_broken_up_by_cloud_veils_and_calm_distant_water() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	for node_name: String in ["WaterfallCloudUpper", "WaterfallCloudLower"]:
		assert_true(stage.has_node(node_name),
				"Scene2 needs an editable cloud veil named %s" % node_name)
	if not stage.has_node("WaterfallCloudUpper") or not stage.has_node("WaterfallCloudLower"):
		return

	var waterfall := stage.get_node("Waterfall") as ColorRect
	var upper_cloud_node := stage.get_node("WaterfallCloudUpper")
	var lower_cloud_node := stage.get_node("WaterfallCloudLower")
	assert_true(upper_cloud_node is ColorRect,
			"The upper waterfall veil must use Scene1's procedural pixel-cloud ColorRect")
	assert_true(lower_cloud_node is ColorRect,
			"The lower waterfall veil must use Scene1's procedural pixel-cloud ColorRect")
	if not upper_cloud_node is ColorRect or not lower_cloud_node is ColorRect:
		return
	var upper_cloud := upper_cloud_node as ColorRect
	var lower_cloud := lower_cloud_node as ColorRect
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
	for cloud: ColorRect in [upper_cloud, lower_cloud]:
		var cloud_material := cloud.material as ShaderMaterial
		assert_not_null(cloud_material)
		if cloud_material == null or cloud_material.shader == null:
			continue
		assert_eq(cloud_material.shader.resource_path,
				"res://assets/shaders/canvas_env_dark_smoke.gdshader")
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
	assert_true(distant_material.shader.code.contains("waterfall_landing_response"),
			"The far-water landing response must remain integrated instead of restoring an impact node")
	assert_gt(float(distant_material.get_shader_parameter(
			"landing_light_strength")), 0.0)
	assert_gt(float(distant_material.get_shader_parameter(
			"landing_shadow_strength")), 0.0)
	assert_gte(float(distant_material.get_shader_parameter(
			"landing_period_sec")), 5.0,
			"The distant landing response must pulse more slowly than the foreground water")
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


func test_scene2_primary_waterfall_veils_reuse_scene1_pixel_cloud_method() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var scene1 := (load("res://src/ui/scenes/scene1.tscn") as PackedScene).instantiate()
	add_child_autofree(scene1)
	var primary_names: Array[String] = [
		"WaterfallCloudUpper",
		"WaterfallCloudLower",
		"WaterfallCloudLower2",
	]
	var scene1_shader_path := \
			"res://assets/shaders/canvas_env_dark_smoke.gdshader"
	var materials: Array[ShaderMaterial] = []
	var seeds := {}

	for cloud_name: String in primary_names:
		assert_true(stage.has_node(cloud_name),
				"Scene2 needs a primary waterfall veil named %s" % cloud_name)
		if not stage.has_node(cloud_name):
			continue
		var cloud_node := stage.get_node(cloud_name)
		assert_true(cloud_node is ColorRect,
				"%s must precisely replace the old cloud texture with a procedural ColorRect"
				% cloud_name)
		if not cloud_node is ColorRect:
			continue
		var cloud := cloud_node as ColorRect
		var material := cloud.material as ShaderMaterial
		assert_not_null(material)
		if material == null or material.shader == null:
			continue
		materials.append(material)
		assert_eq(material.shader.resource_path, scene1_shader_path)
		assert_gte(float(material.get_shader_parameter("row_count")), 3.0)
		if float(material.get_shader_parameter("mode_isolated")) < 0.5:
			assert_gte(float(material.get_shader_parameter("isolated_len_cap")), 1.0)
		assert_eq(float(material.get_shader_parameter("lobe_profile")), 1.0)
		assert_lte(absf(float(material.get_shader_parameter("flow_speed"))), 0.02)
		assert_lte(float(material.get_shader_parameter("alpha_max")), 0.9)
		var pixel_grid: Vector2 = material.get_shader_parameter("pixel_grid")
		assert_gte(pixel_grid.x, 320.0)
		assert_gte(pixel_grid.y, 24.0)
		seeds[float(material.get_shader_parameter("seed"))] = true

	assert_eq(materials.size(), primary_names.size())
	if materials.size() == primary_names.size():
		assert_ne(materials[0], materials[1],
				"Upper and lower pixel clouds need independent Scene2 palettes and timing")
		assert_ne(materials[1], materials[2],
				"The second lower veil needs its own material instead of repeating the first")
		assert_eq(float(materials[0].get_shader_parameter("mode_isolated")), 1.0,
				"The upper veil must remain a sparse group of discrete cloud masses")
		assert_true(materials[0].shader.code.contains("water_reflect_underside"),
				"The shared cloud method must expose an opt-in hard underside reflection")
		assert_gt(float(materials[0].get_shader_parameter(
				"water_reflect_strength")), 0.0,
				"Scene2's upper waterfall veil should receive the local water reflection")
		assert_eq(float(materials[1].get_shader_parameter("mode_isolated")), 0.0,
				"The lower veil must use Scene1's continuous cloud-wall mode")
		assert_eq(float(materials[2].get_shader_parameter("mode_isolated")), 0.0,
				"The lower overlay must remain a continuous cloud-wall layer")
		assert_gte(absf(float(materials[0].get_shader_parameter("flow_speed"))), 0.005,
				"The center waterfall clouds must not drift imperceptibly slowly")
		assert_lte(float(materials[0].get_shader_parameter("isolated_forced_stride")), 2.0,
				"The upper veil must guarantee a cloud at least every two cells")
		assert_gt(float(materials[0].get_shader_parameter("isolated_break_stride")), 0.0,
				"Upper compound groups need scheduled breaks instead of one long strip")
		assert_gte(float(materials[0].get_shader_parameter("keep")), 0.65,
				"Optional upper groups must fill the large gaps between guaranteed clouds")
		assert_gte(float(materials[0].get_shader_parameter("lobe_shape_variation")), 0.5,
				"Upper groups need the same seeded compound-lobe language as Lower")
		assert_gt(
				absf(float(materials[0].get_shader_parameter("flow_speed"))),
				absf(float(materials[1].get_shader_parameter("flow_speed"))),
				"Upper clouds must drift faster than the Lower bank")
		assert_lt(
				float(materials[1].get_shader_parameter("flow_speed"))
						* float(materials[2].get_shader_parameter("flow_speed")),
				0.0,
				"The two lower cloud banks must drift in opposite directions")
		for lower_material: ShaderMaterial in [materials[1], materials[2]]:
			assert_lt(float(lower_material.get_shader_parameter("lobe_height_scale")), 0.8,
					"Lower cloud peaks must remain compressed")
			assert_gt(float(lower_material.get_shader_parameter("bank_valley_depth")), 0.0,
					"The lower bank must dip beneath the waterfall")
			assert_lt(float(lower_material.get_shader_parameter("bank_valley_peak_scale")), 0.7,
					"Random peaks must not visually cancel the waterfall-center dip")
			assert_gt(float(lower_material.get_shader_parameter("bank_side_rise")), 0.0,
					"The cloud bank must rise toward the left mountain and right blossom tree")
			assert_gt(float(lower_material.get_shader_parameter("bank_join_height")), 0.0,
					"The lower bank needs a connected shoulder above its solid baseline")
			assert_gte(float(lower_material.get_shader_parameter("lobe_min_step_px")), 2.0,
					"Lower lobe crests must not produce one-pixel-wide vertical spikes")
			assert_lte(float(lower_material.get_shader_parameter("continuous_bob_scale")), 0.3,
					"Lower independent bobbing must stay subtle enough to avoid choppy seams")
		for material: ShaderMaterial in materials:
			assert_eq(float(material.get_shader_parameter("inner_contrast")), 0.0,
					"Moving tone blocks must not read as reverse-travelling holes")
	assert_eq(seeds.size(), primary_names.size(),
			"Every moving Scene2 cloud layer must use a distinct deterministic distribution")

	for scene1_name: String in ["SmokeRoof", "SmokeRoofNear"]:
		var scene1_material := scene1.get_node(scene1_name).material as ShaderMaterial
		assert_eq(scene1_material.shader.resource_path, scene1_shader_path,
				"Scene2 must reuse the proven Scene1 procedural pixel-cloud method")

	for preserved_name: String in ["CloudFar", "CloudFar2", "CloudMid", "CloudMid2"]:
		assert_true(stage.has_node(preserved_name),
				"Replacing the two primary veils must preserve %s" % preserved_name)
		if not stage.has_node(preserved_name):
			continue
		var preserved_cloud := stage.get_node(preserved_name)
		assert_true(preserved_cloud is TextureRect,
				"%s must remain an editable texture background layer" % preserved_name)
		if preserved_cloud is TextureRect:
			assert_not_null((preserved_cloud as TextureRect).texture)


func test_scene2_blossom_tree_moves_masked_branches_not_the_trunk() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	assert_true(stage.has_node("BlossomTree"))
	if not stage.has_node("BlossomTree"):
		return
	var tree := stage.get_node("BlossomTree") as TextureRect
	var material := tree.material as ShaderMaterial
	assert_not_null(material)
	if material == null or material.shader == null:
		return
	assert_eq(
			material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene2_tree_sway.gdshader")
	var branch_mask := material.get_shader_parameter("branch_mask") as Texture2D
	assert_not_null(branch_mask,
			"Tree sway requires an authored terminal-branch mask")
	if branch_mask != null:
		assert_eq(
				branch_mask.resource_path,
				"res://assets/scenes/scene2/scene2_blossom_branch_mask.png")
	var underpaint := material.get_shader_parameter("underpaint_texture") as Texture2D
	assert_not_null(underpaint,
			"Moving branches need a separately painted hidden-trunk layer")
	if underpaint != null:
		assert_eq(
				underpaint.resource_path,
				"res://assets/scenes/scene2/scene2_blossom_underpaint.png")
	assert_lte(float(material.get_shader_parameter("motion_fps")), 8.0)
	assert_lte(float(material.get_shader_parameter("max_angle_deg")), 1.0)
	assert_lte(float(material.get_shader_parameter("bouquet_angle_deg")), 1.5)
	assert_lt(
			float(material.get_shader_parameter("bouquet_cycle_sec")),
			float(material.get_shader_parameter("cycle_sec")),
			"The hanging blossom needs a lighter rhythm than the large branch groups")
	var shader_source := material.shader.code
	assert_true(shader_source.contains("floor(TIME * motion_fps)"),
			"Tree sway must advance on pixel-art animation frames")
	assert_true(shader_source.contains("moving_here"),
			"Only explicitly masked branch pixels may leave the static source")
	assert_true(shader_source.contains("inverse_rotate_pixel_uv"),
			"Branches should hinge around fixed attachment points")
	assert_true(shader_source.contains("bouquet_here"),
			"The small hanging blossom must have its own encoded motion group")
	assert_true(shader_source.contains("underpaint_texture"),
			"Branch attachment gaps must be filled by a real hidden-trunk texture")
	assert_false(shader_source.contains("1.0 - UV.y"),
			"The rejected whole-image height ripple must not return")


func test_scene2_p1_reuses_scene1_particle_profiles_without_petals() -> void:
	var scene1 := (load(SCENE1_PATH) as PackedScene).instantiate()
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(scene1)
	add_child_autofree(stage)
	var scene_source := FileAccess.get_file_as_string(SCENE2_PATH)
	var waterfall := stage.get_node("Waterfall") as ColorRect
	var river := stage.get_node("River") as ColorRect
	var waterfall_material := waterfall.material as ShaderMaterial
	var river_material := river.material as ShaderMaterial

	assert_eq(float(waterfall_material.get_shader_parameter("anim_fps")), 8.0)
	assert_lt(
			float(river_material.get_shader_parameter("anim_fps")),
			float(waterfall_material.get_shader_parameter("anim_fps")),
			"Scene2 P2 keeps the waterfall as the leading environmental motion")
	for material: ShaderMaterial in [waterfall_material, river_material]:
		assert_gt(float(material.get_shader_parameter("px_size")), 0.0)
		assert_lte(float(material.get_shader_parameter("px_size")), 8.0,
				"Animated water must stay on an explicit hard-pixel grid")

	assert_false(stage.has_node("PetalFar"),
			"Distant petals read as blurry background damage and must remain removed")
	assert_false(stage.has_node("PetalMid"),
			"Scene2 uses one intentional foreground petal layer instead of particle clutter")
	assert_false(stage.has_node("PetalNear"))
	assert_false(scene_source.contains("Petal"),
			"Scene2 must remove the rejected petal system instead of hiding it")

	var profile_pairs := {
		"PollenFar": "EmberFar",
		"ValleyDust": "MoonDust",
		"GroundPollen": "GroundEmber",
		"PollenNear": "EmberNear",
	}
	for scene2_name: String in profile_pairs:
		var scene1_name: String = profile_pairs[scene2_name]
		assert_true(stage.has_node(scene2_name))
		if not stage.has_node(scene2_name):
			continue
		var scene2_particles := stage.get_node(scene2_name) as GPUParticles2D
		var scene1_particles := scene1.get_node(scene1_name) as GPUParticles2D
		var scene2_process := scene2_particles.process_material as ParticleProcessMaterial
		var scene1_process := scene1_particles.process_material as ParticleProcessMaterial
		var scene2_texture := scene2_particles.texture as GradientTexture2D

		assert_not_null(scene2_texture)
		if scene2_texture != null:
			assert_eq(scene2_texture.get_width(), 8)
			assert_eq(scene2_texture.get_height(), 8)
		assert_not_null(scene2_texture.gradient)
		assert_eq(scene2_texture.fill, GradientTexture2D.FILL_RADIAL)
		assert_eq(scene2_texture.fill_from, Vector2(0.5, 0.5))
		assert_eq(scene2_texture.fill_to, Vector2(1.0, 0.5))
		assert_eq(scene2_particles.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_lte(scene2_particles.amount, scene1_particles.amount,
				"Scene2 keeps Scene1's particle method with a calmer count budget")
		assert_between(
				scene2_particles.lifetime,
				scene1_particles.lifetime * 0.8,
				scene1_particles.lifetime * 1.5,
				"Longer sparse lifetimes may replace dense constant emission")
		assert_gte(scene2_particles.randomness, 0.5,
				"Scene2 staggers particle emission instead of synchronizing it")
		assert_eq(scene2_particles.preprocess, scene1_particles.preprocess)
		assert_eq(
				float(scene2_particles.get_meta("parallax_factor")),
				float(scene1_particles.get_meta("parallax_factor")))
		assert_not_null(scene2_process)
		assert_not_null(scene1_process)
		if scene2_process == null or scene1_process == null:
			continue
		assert_eq(scene2_process.emission_shape, scene1_process.emission_shape)
		assert_eq(scene2_process.emission_box_extents, scene1_process.emission_box_extents)
		assert_eq(scene2_process.spread, scene1_process.spread)
		assert_gt(scene2_process.initial_velocity_min, 0.0)
		assert_lte(
				scene2_process.initial_velocity_min,
				scene1_process.initial_velocity_min,
				"Scene2 particles remain subordinate to the waterfall")
		assert_lte(
				scene2_process.initial_velocity_max,
				scene1_process.initial_velocity_max,
				"Scene2 particles remain subordinate to the waterfall")
		assert_eq(scene2_process.scale_min, scene1_process.scale_min)
		assert_eq(scene2_process.scale_max, scene1_process.scale_max)
		assert_eq(
				scene2_process.turbulence_noise_strength,
				scene1_process.turbulence_noise_strength)
		assert_eq(
				scene2_process.turbulence_noise_scale,
				scene1_process.turbulence_noise_scale)
		assert_ne(scene2_process.direction, scene1_process.direction,
				"Scene2 must adapt the copied particle direction to the valley wind")
		assert_ne(scene2_process.color, scene1_process.color,
				"Scene2 must adapt the copied particle color to the peach-blossom palette")


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


func test_scene2_river_uses_quiet_directional_flow_parameters() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var river := stage.get_node("River") as ColorRect
	var material := river.material as ShaderMaterial

	assert_almost_eq(
			float(material.get_shader_parameter("slice_shift_px")),
			5.0, 0.001,
			"Reflection bands must breathe gently instead of swinging side to side")
	assert_almost_eq(
			float(material.get_shader_parameter("slice_speed")),
			0.11, 0.001)
	assert_almost_eq(
			float(material.get_shader_parameter("breakup_strength")),
			0.20, 0.001)
	assert_almost_eq(
			float(material.get_shader_parameter("ripple_speed_px")),
			8.0, 0.001,
			"Ripple rows should carry a quiet directional current")
	assert_almost_eq(
			float(material.get_shader_parameter("shore_cluster_drift_px")),
			1.5, 0.001)
	assert_almost_eq(
			float(material.get_shader_parameter("anim_fps")),
			6.0, 0.001,
			"Calmer motion must not become low-frame-rate stutter")


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

	for far_name in ["BambooFarLeft", "BambooFarRight"]:
		var far_material := stage.get_node(far_name).material as ShaderMaterial
		assert_eq(far_material.shader.resource_path,
				"res://assets/shaders/canvas_env_night_foliage.gdshader")

	var main_masks := {
		"BambooLeft": [
			"res://assets/scenes/scene1/scene1_bamboo_left_leaf_mask.png",
			"res://assets/scenes/scene1/scene1_bamboo_left_underpaint.png"],
		"BambooRight": [
			"res://assets/scenes/scene1/scene1_bamboo_right_leaf_mask.png",
			"res://assets/scenes/scene1/scene1_bamboo_right_underpaint.png"],
	}
	var phase_offsets: Array[float] = []
	for main_name in ["BambooLeft", "BambooRight"]:
		assert_eq((stage.get_node(main_name) as TextureRect).texture_filter,
				CanvasItem.TEXTURE_FILTER_NEAREST)
		var main_material := stage.get_node(main_name).material as ShaderMaterial
		assert_eq(main_material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene1_bamboo_leaf_sway.gdshader")
		assert_almost_eq(float(main_material.get_shader_parameter("alpha_scale")),
				1.0, 0.001, "Main bamboo must remain fully opaque")
		var leaf_mask := main_material.get_shader_parameter("leaf_mask") as Texture2D
		var underpaint := main_material.get_shader_parameter(
				"underpaint_texture") as Texture2D
		assert_eq(leaf_mask.resource_path, main_masks[main_name][0])
		assert_eq(underpaint.resource_path, main_masks[main_name][1])
		assert_eq(leaf_mask.get_size(), contract[main_name][1],
				"Leaf masks must stay at source resolution for pixel-stable pivots")
		assert_eq(underpaint.get_size(), contract[main_name][1])
		assert_almost_eq(float(main_material.get_shader_parameter("motion_fps")),
				6.0, 0.001)
		assert_gte(float(main_material.get_shader_parameter("cycle_sec")), 8.0)
		assert_between(
				float(main_material.get_shader_parameter("red_angle_deg")),
				0.1, 0.85)
		assert_between(
				float(main_material.get_shader_parameter("green_angle_deg")),
				0.1, 1.0)
		phase_offsets.append(float(
				main_material.get_shader_parameter("phase_offset")))
		var shader_source := main_material.shader.code
		assert_true(shader_source.contains("TIME"))
		assert_true(shader_source.contains("leaf_mask"))
		assert_true(shader_source.contains("underpaint_texture"))
		assert_true(shader_source.contains("inverse_rotate_pixel_uv"))

	assert_ne(phase_offsets[0], phase_offsets[1],
			"Left and right leaf groups must not sway in lockstep")

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


func test_character_idle_cycle_duration_is_shared_across_frame_counts() -> void:
	var display := CharacterDisplay.new()
	add_child_autofree(display)
	await get_tree().process_frame

	for frame_count: int in [3, 6, 12]:
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		for _frame_index: int in range(frame_count):
			frames.add_frame("idle", null)
		display.sprite_frames = frames
		var fps := frames.get_animation_speed("idle")
		var cycle_duration := float(frame_count) / fps
		assert_almost_eq(
				cycle_duration,
				float(display.idle_ref_frames) / display.idle_base_fps,
				0.001,
				"P1/P2 idle light changes must share one cycle duration")


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
		assert_between(
				float(river_material.get_shader_parameter("character_reflection_strength")),
				0.60,
				0.75,
				"Character reflections must remain visible without overpowering the river")
		assert_lte(
				float(river_material.get_shader_parameter("character_reflection_saturation")),
				0.45,
				"Character reflections need the river's restrained jade palette")
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


func test_scene2_characters_preserve_authored_pixels_with_only_a_thin_warm_rim() -> void:
	var screen := (load(BATTLE2_PATH) as PackedScene).instantiate()
	var p1 := screen.get_node("P1CharDisplay") as CharacterDisplay
	var p2 := screen.get_node("P2CharDisplay") as CharacterDisplay

	for character in [p1, p2]:
		assert_eq(character.light_dir, Vector2(1.0, -0.8))
		assert_gt(character.rim_strength, 0.0)
		assert_lte(character.rim_strength, 0.2)
		assert_eq(character.rim_width, 1.0)
		assert_eq(character.backlight, 0.0)
		assert_eq(character.warmth_amount, 0.0)
		assert_eq(character.fill_amount, 0.0)

	var p1_sprite := screen.get_node("P1CharDisplay/SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	var p2_sprite := screen.get_node("P2CharDisplay/SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	for sprite in [p1_sprite, p2_sprite]:
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		assert_eq(material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene2_character_light.gdshader")
		assert_eq(float(material.get_shader_parameter("source_saturation")), 1.0)
		assert_eq(float(material.get_shader_parameter("source_contrast")), 1.0)
		assert_gt(float(material.get_shader_parameter("rim_strength")), 0.0)
		assert_lte(float(material.get_shader_parameter("rim_strength")), 0.2)
		assert_eq(float(material.get_shader_parameter("rim_width")), 1.0)
		assert_eq(float(material.get_shader_parameter("backlight")), 0.0)
		assert_eq(float(material.get_shader_parameter("warmth_amount")), 0.0)
		assert_eq(float(material.get_shader_parameter("fill_amount")), 0.0)
		assert_eq(float(material.get_shader_parameter("water_bounce_amount")), 0.0)
		assert_true(material.shader.code.contains("node_modulate"),
				"Scene2 must not multiply the authored character texture twice")
		assert_true(material.shader.code.contains("flash_amount"),
				"Neutral Scene2 character rendering must preserve combat hit feedback")

	var p1_shadow := screen.get_node("P1Shadow") as TextureRect
	var p2_shadow := screen.get_node("P2Shadow") as TextureRect
	for shadow in [p1_shadow, p2_shadow]:
		var material := shadow.material as ShaderMaterial
		assert_not_null(material)
		if material != null:
			assert_eq(material.shader.resource_path,
					"res://assets/shaders/canvas_env_scene2_character_contact_shadow.gdshader")
			assert_gt(float(material.get_shader_parameter("tail_strength")), 0.0)
		assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_lt(shadow.size.y, 48.0,
				"Bridge contact shadows must stay compact instead of reading as soft floor decals")
		assert_lt(shadow.get_index(), p1.get_index(),
				"Contact shadows must remain behind both live characters")
	screen.free()


func test_scene2_postfx_skips_disabled_blur_and_inactive_impact_work() -> void:
	var scene1 := (load(BATTLE1_PATH) as PackedScene).instantiate()
	var scene2 := (load(BATTLE2_PATH) as PackedScene).instantiate()
	var scene1_material := scene1.get_node("PostFX").material as ShaderMaterial
	var scene2_material := scene2.get_node("PostFX").material as ShaderMaterial
	var shader_source := scene2_material.shader.code

	assert_gt(float(scene1_material.get_shader_parameter("edge_blur_amount")), 0.0,
			"Scene1 must retain its authored five-tap edge blur")
	assert_eq(float(scene2_material.get_shader_parameter("edge_blur_amount")), 0.0,
			"Scene2 opts into the single-sample post-process path")
	assert_true(shader_source.contains("if (edge_blur_amount <= 0.0001)"),
			"Disabled edge blur must avoid four redundant full-screen texture samples")
	assert_true(shader_source.contains("if (impact_strength > 0.0001)"),
			"Inactive impact frames must skip their full-screen hash and atan work")

	scene1.free()
	scene2.free()


func test_alive_characters_do_not_keep_the_death_shader_across_scenes() -> void:
	for scene_number: int in range(1, 8):
		BattleSetup.reset()
		var packed := load(
				"res://src/ui/battle_screen%d.tscn" % scene_number) as PackedScene
		var screen := packed.instantiate()
		add_child(screen)
		await get_tree().process_frame
		for display: CharacterDisplay in [
				screen.p1_char_display,
				screen.p2_char_display,
		]:
			assert_null(
					display.material,
					"Scene%d alive characters must keep their original render chain"
					% scene_number)
			var sprite := display.get_node(
					"SubViewport/AnimatedSprite2D") as AnimatedSprite2D
			assert_not_null(sprite.material,
					"Scene%d still needs its own character-light material" % scene_number)
			display.set_death_dissolve(0.25, true, 12)
			var death_material := display.material as ShaderMaterial
			assert_not_null(death_material)
			assert_eq(
					death_material.shader.resource_path,
					"res://assets/shaders/canvas_ui_character_death_dissolve.gdshader")
			display.reset_death_dissolve()
			assert_null(display.material,
					"Scene%d must unload the death pass after reset" % scene_number)
		screen.free()
		await get_tree().process_frame


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
